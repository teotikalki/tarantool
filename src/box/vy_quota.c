/*
 * Copyright 2010-2018, Tarantool AUTHORS, please see AUTHORS file.
 *
 * Redistribution and use in source and binary forms, with or
 * without modification, are permitted provided that the following
 * conditions are met:
 *
 * 1. Redistributions of source code must retain the above
 *    copyright notice, this list of conditions and the
 *    following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above
 *    copyright notice, this list of conditions and the following
 *    disclaimer in the documentation and/or other materials
 *    provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY AUTHORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
 * AUTHORS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
 * BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
 * THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */
#include "vy_quota.h"

#include <assert.h>
#include <stddef.h>
#include <stdint.h>
#include <math.h>
#include <tarantool_ev.h>

#include "diag.h"
#include "fiber.h"
#include "fiber_cond.h"
#include "say.h"
#include "histogram.h"
#include "trivia/util.h"

enum {
	/**
	 * Time interval between successive updates of
	 * quota watermark and use rate, in seconds.
	 */
	VY_QUOTA_UPDATE_INTERVAL = 1,
	/**
	 * Period of time over which the quota use rate
	 * is averaged, in seconds.
	 */
	VY_QUOTA_RATE_AVG_PERIOD = 5,
};

/*
 * Until we dump anything, assume bandwidth to be 10 MB/s,
 * which should be fine for initial guess.
 */
static const size_t VY_DEFAULT_DUMP_BANDWIDTH = 10 * 1024 * 1024;

/**
 * Histogram percentile used for estimating dump bandwidth.
 * For details see the comment to vy_quota::dump_bw_hist.
 */
enum { VY_DUMP_BANDWIDTH_PCT = 10 };

/**
 * Wake up the next fiber in the line waiting for quota
 * provided quota is available.
 */
static inline void
vy_quota_signal(struct vy_quota *q)
{
	if (q->used < q->limit)
		fiber_cond_signal(&q->cond);
}

/**
 * Trigger memory dump if memory usage is above the wateramrk
 * and dump hasn't been triggered yet.
 */
static inline void
vy_quota_check_watermark(struct vy_quota *q)
{
	if (!q->dump_in_progress && q->used >= q->watermark)
		q->dump_in_progress = q->quota_exceeded_cb(q);
}

static void
vy_quota_timer_cb(ev_loop *loop, ev_timer *timer, int events)
{
	(void)loop;
	(void)events;

	struct vy_quota *q = timer->data;

	/*
	 * Update the quota use rate with the new measurement.
	 */
	const double weight = 1 - exp(-VY_QUOTA_UPDATE_INTERVAL /
				      (double)VY_QUOTA_RATE_AVG_PERIOD);
	q->use_rate = (1 - weight) * q->use_rate +
		weight * q->use_curr / VY_QUOTA_UPDATE_INTERVAL;
	q->use_curr = 0;

	/*
	 * Due to log structured nature of the lsregion allocator,
	 * which is used for allocating statements, we cannot free
	 * memory in chunks, only all at once. Therefore we should
	 * configure the watermark so that by the time we hit the
	 * limit, all memory have been dumped, i.e.
	 *
	 *   limit - watermark      watermark
	 *   ----------------- = --------------
	 *        use_rate       dump_bandwidth
	 */
	q->watermark = ((double)q->limit * q->dump_bw /
			(q->dump_bw + q->use_rate + 1));
	vy_quota_check_watermark(q);
}

int
vy_quota_create(struct vy_quota *q, vy_quota_exceeded_f quota_exceeded_cb)
{
	enum { KB = 1024, MB = KB * KB };
	static int64_t dump_bandwidth_buckets[] = {
		100 * KB, 200 * KB, 300 * KB, 400 * KB, 500 * KB, 600 * KB,
		700 * KB, 800 * KB, 900 * KB,   1 * MB,   2 * MB,   3 * MB,
		  4 * MB,   5 * MB,   6 * MB,   7 * MB,   8 * MB,   9 * MB,
		 10 * MB,  15 * MB,  20 * MB,  25 * MB,  30 * MB,  35 * MB,
		 40 * MB,  45 * MB,  50 * MB,  55 * MB,  60 * MB,  65 * MB,
		 70 * MB,  75 * MB,  80 * MB,  85 * MB,  90 * MB,  95 * MB,
		100 * MB, 200 * MB, 300 * MB, 400 * MB, 500 * MB, 600 * MB,
		700 * MB, 800 * MB, 900 * MB,
	};

	q->dump_bw_hist = histogram_new(dump_bandwidth_buckets,
					lengthof(dump_bandwidth_buckets));
	if (q->dump_bw_hist == NULL) {
		diag_set(OutOfMemory, 0, "histogram_new",
			 "dump bandwidth histogram");
		return -1;
	}

	q->limit = SIZE_MAX;
	q->watermark = SIZE_MAX;
	q->used = 0;
	q->use_curr = 0;
	q->use_rate = 0;
	q->too_long_threshold = TIMEOUT_INFINITY;
	q->dump_bw = VY_DEFAULT_DUMP_BANDWIDTH;
	q->quota_exceeded_cb = quota_exceeded_cb;
	q->dump_in_progress = false;
	fiber_cond_create(&q->cond);
	ev_timer_init(&q->timer, vy_quota_timer_cb, 0,
		      VY_QUOTA_UPDATE_INTERVAL);
	q->timer.data = q;
	ev_timer_start(loop(), &q->timer);
	return 0;
}

void
vy_quota_destroy(struct vy_quota *q)
{
	ev_timer_stop(loop(), &q->timer);
	histogram_delete(q->dump_bw_hist);
	fiber_cond_broadcast(&q->cond);
	fiber_cond_destroy(&q->cond);
}

void
vy_quota_set_limit(struct vy_quota *q, size_t limit)
{
	q->limit = q->watermark = limit;
	vy_quota_check_watermark(q);
	vy_quota_signal(q);
}

void
vy_quota_reset_dump_bw(struct vy_quota *q, size_t max)
{
	histogram_reset(q->dump_bw_hist);
	q->dump_bw = MIN(VY_DEFAULT_DUMP_BANDWIDTH, max);
}

void
vy_quota_force_use(struct vy_quota *q, size_t size)
{
	q->used += size;
	q->use_curr += size;
	vy_quota_check_watermark(q);
}

void
vy_quota_dump(struct vy_quota *q, size_t size, double duration)
{
	assert(q->used >= size);
	q->used -= size;
	q->dump_in_progress = false;
	vy_quota_signal(q);

	/* Account dump bandwidth. */
	if (duration > 0) {
		histogram_collect(q->dump_bw_hist, size / duration);
		/*
		 * To avoid unpredictably long stalls, we need to
		 * know the worst (smallest) dump bandwidth so use
		 * a lower-bound percentile estimate.
		 */
		q->dump_bw = histogram_percentile_lower(q->dump_bw_hist,
							VY_DUMP_BANDWIDTH_PCT);
	}
}

int
vy_quota_try_use(struct vy_quota *q, size_t size, double timeout)
{
	double start_time = ev_monotonic_now(loop());
	double deadline = start_time + timeout;

	q->used += size;
	while (q->used > q->limit) {
		vy_quota_check_watermark(q);
		q->used -= size;
		int rc = fiber_cond_wait_deadline(&q->cond, deadline);
		q->used += size;
		if (rc != 0)
			break; /* timed out */
	}
	double wait_time = ev_monotonic_now(loop()) - start_time;
	if (wait_time > q->too_long_threshold) {
		say_warn("waited for %zu bytes of vinyl memory quota "
			 "for too long: %.3f sec", size, wait_time);
	}
	if (q->used > q->limit) {
		/*
		 * In case of faiure diag should have been set by
		 * fiber_cond_wait_deadline().
		 */
		assert(!diag_is_empty(diag_get()));
		q->used -= size;
		return -1;
	}
	q->use_curr += size;
	vy_quota_check_watermark(q);

	/* Wake up the next fiber in the line waiting for quota. */
	vy_quota_signal(q);
	return 0;
}

void
vy_quota_commit_use(struct vy_quota *q, size_t reserved, size_t used)
{
	if (reserved > used) {
		size_t excess = reserved - used;
		assert(q->used >= excess);
		q->used -= excess;
		if (q->use_curr >= excess)
			q->use_curr -= excess;
		else /* was reset by timeout */
			q->use_curr = 0;
		vy_quota_signal(q);
	}
	if (reserved < used)
		vy_quota_force_use(q, used - reserved);
}
