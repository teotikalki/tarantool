env = require('test_run')
test_run = env.new()
test_run:cmd("push filter ".."'\\.lua.*:[0-9]+: ' to '.lua...\"]:<line>: '")
engine = test_run:get_cfg('engine')
box.sql.execute('pragma sql_default_engine=\''..engine..'\'')

--
-- gh-3272: Move SQL CHECK into server
--

-- invalid expression
opts = {checks = {{expr = 'X><5'}}}
format = {{name = 'X', type = 'unsigned'}}
t = {513, 1, 'test', 'memtx', 0, opts, format}
s = box.space._space:insert(t)

opts = {checks = {{expr = 'X>5'}}}
format = {{name = 'X', type = 'unsigned'}}
t = {513, 1, 'test', 'memtx', 0, opts, format}
s = box.space._space:insert(t)
box.space._space:delete(513)

opts = {checks = {{expr = 'X>5', name = 'ONE'}}}
format = {{name = 'X', type = 'unsigned'}}
t = {513, 1, 'test', 'memtx', 0, opts, format}
s = box.space._space:insert(t)
box.space._space:delete(513)

-- extra invlalid field name
opts = {checks = {{expr = 'X>5', name = 'ONE', extra = 'TWO'}}}
format = {{name = 'X', type = 'unsigned'}}
t = {513, 1, 'test', 'memtx', 0, opts, format}
s = box.space._space:insert(t)

opts = {checks = {{expr_invalid_label = 'X>5'}}}
format = {{name = 'X', type = 'unsigned'}}
t = {513, 1, 'test', 'memtx', 0, opts, format}
s = box.space._space:insert(t)

-- invalid field type
opts = {checks = {{name = 123}}}
format = {{name = 'X', type = 'unsigned'}}
t = {513, 1, 'test', 'memtx', 0, opts, format}
s = box.space._space:insert(t)

--
-- gh-3611: Segfault on table creation with check referencing this table
--
box.sql.execute("CREATE TABLE w2 (s1 INT PRIMARY KEY, CHECK ((SELECT COUNT(*) FROM w2) = 0));")
box.sql.execute("DROP TABLE w2;")

--
-- gh-3653: Dissallow bindings for DDL
--
box.sql.execute("CREATE TABLE t1(a INT PRIMARY KEY, b INT);")
space_id = box.space.T1.id
box.sql.execute("CREATE TRIGGER tr1 AFTER INSERT ON t1 WHEN new.a = ? BEGIN SELECT 1; END;")
tuple = {"TR1", space_id, {sql = [[CREATE TRIGGER tr1 AFTER INSERT ON t1 WHEN new.a = ? BEGIN SELECT 1; END;]]}}
box.space._trigger:insert(tuple)
box.sql.execute("DROP TABLE t1;")

box.sql.execute("CREATE TABLE t5(x primary key, y,CHECK( x*y<? ));")

opts = {checks = {{expr = '?>5', name = 'ONE'}}}
format = {{name = 'X', type = 'unsigned'}}
t = {513, 1, 'test', 'memtx', 0, opts, format}
s = box.space._space:insert(t)

test_run:cmd("clear filter")
