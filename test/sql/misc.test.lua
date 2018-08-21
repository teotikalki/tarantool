test_run = require('test_run').new()
engine = test_run:get_cfg('engine')
box.sql.execute('pragma sql_default_engine=\''..engine..'\'')
box.sql.execute('pragma interactive_mode=0;')

-- Forbid multistatement queries.
box.sql.execute('select 1;')
box.sql.execute('select 1; select 2;')
box.sql.execute('create table t1 (id primary key); select 100;')
box.space.t1 == nil
box.sql.execute(';')
box.sql.execute('')
box.sql.execute('     ;')
box.sql.execute('\n\n\n\t\t\t   ')

--
-- gh-2370: Return a tuple result from SQL
--
box.sql.execute("pragma interactive_mode=1;")
box.sql.execute("CREATE TABLE t (s1 INT, s2 INT, s3 INT, s4 INT PRIMARY KEY);")
box.sql.execute("INSERT INTO t VALUES (1,1,1,2),(1,1,1,5),(1,1,1,6);")
box.sql.execute("UPDATE t SET s2=s2+s1 WHERE s4 IN (SELECT s4 FROM t);");
box.sql.execute("UPDATE t SET s2=s2+s1 WHERE s4=6 OR s4=2;");
dropped = box.sql.execute("DELETE FROM t WHERE s2 = 3;");
dropped
dropped[1]
assert(dropped[1][4] == dropped[1].S4)
assert(dropped[1].S4 == 2)
box.sql.execute("DELETE FROM t;")
box.sql.execute("DROP TABLE t;")
assert(dropped[1].S4 == 2)
box.sql.execute('pragma interactive_mode=0;')
