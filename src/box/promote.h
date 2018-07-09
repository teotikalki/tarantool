#ifndef INCLUDES_TARANTOOL_BOX_PROMOTE_H
#define INCLUDES_TARANTOOL_BOX_PROMOTE_H
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
 * THIS SOFTWARE IS PROVIDED BY <COPYRIGHT HOLDER> ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
 * <COPYRIGHT HOLDER> OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
 * BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
 * THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */
#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

struct info_handler;
struct promote_msg;

/**
 * Decode the MessagePack encoded promotion message into @a msg.
 * @param data MessagePack data to decode. Tuple from _promotion.
 * @param[out] msg Object to fill up.
 *
 * @retval -1 Error during decoding.
 * @retval 0 Success.
 */
struct promote_msg *
promote_msg_new_from_tuple(const char *data);

/** Schedule promotion message processing. */
void
promote_msg_push(struct promote_msg *msg);

/** Destructor of a promotion message for fiber channel. */
void
promote_msg_delete(struct promote_msg *msg);

/**
 * Promote the current instance to be a master in the fullmesh
 * master-master cluster. The old master, if exists, is demoted.
 * Once a promotion attempt is done anywhere, manual change of
 * read_only flag is disabled.
 * @param timeout Timeout during which the promotion should be
 *        finished.
 * @param quorum The promotion quorum of instances who should
 *        approve the promotion and sync with the old master
 *        before demotion. The quorum should be at least half of
 *        the cluster size + 1 and include the old master. If an
 *        old master does not exist, then the quorum is ignored
 *        and the promotion waits for 100% of the cluster
 *        members.
 *
 * @retval -1 Error.
 * @retval 0 Success.
 */
int
box_ctl_promote(double timeout, int quorum);

/**
 * Show status of the current active promotion round or the last
 * finished one.
 * @param info Info handler to collect the info into.
 */
void
box_ctl_promote_info(struct info_handler *info);

/**
 * Remove all the promotion rounds from the history. That allows
 * to change read_only manually again.
 */
int
box_ctl_promote_reset(void);

/** Initialize the promotion subsystem. */
int
box_ctl_promote_init(void);

/** Free promote resources. */
void
box_ctl_promote_free(void);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* INCLUDES_TARANTOOL_BOX_PROMOTE_H */
