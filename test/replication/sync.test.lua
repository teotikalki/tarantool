--
-- gh-3427: no sync after configuration update
--

env = require('test_run')
test_run = env.new()
engine = test_run:get_cfg('engine')

box.schema.user.grant('guest', 'replication')

test_run:cmd("create server replica with rpl_master=default, script='replication/replica.lua'")
test_run:cmd("start server replica")

s = box.schema.space.create('test', {engine = engine})
index = s:create_index('primary')

-- change replica configuration
test_run:cmd("switch replica")
box.cfg{replication_sync_lag = 0.1}
replication = box.cfg.replication
box.cfg{replication={}}

test_run:cmd("switch default")
-- insert values on the master while replica is unconfigured
a = 3000 box.begin() while a > 0 do a = a-1 box.space.test:insert{a,a} end box.commit()

test_run:cmd("switch replica")
box.cfg{replication = replication}

box.space.test:count() == 3000

test_run:cmd("switch default")

-- cleanup
test_run:cmd("stop server replica")
test_run:cmd("cleanup server replica")
box.space.test:drop()
box.schema.user.revoke('guest', 'replication')
