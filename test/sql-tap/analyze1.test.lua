#!/usr/bin/env tarantool
test = require("sqltester")
test:plan(38)

--!./tcltestrunner.lua
-- 2005 July 22
--
-- The author disclaims copyright to this source code.  In place of
-- a legal notice, here is a blessing:
--
--    May you do good and not evil.
--    May you find forgiveness for yourself and forgive others.
--    May you share freely, never taking more than you give.
--
-------------------------------------------------------------------------
-- This file implements regression tests for SQLite library.
-- This file implements tests for the ANALYZE command.
--


-- Basic sanity checks.
--
test:do_catchsql_test(
    "analyze-1.1",
    [[
        ANALYZE no_such_table
    ]], {
        -- <analyze-1.1>
        1, "no such table: NO_SUCH_TABLE"
        -- </analyze-1.1>
    })

test:do_execsql_test(
    "analyze-1.6",
    [[
        SELECT count(*) FROM "_space" WHERE "name"='_sql_stat1'
    ]], {
        -- <analyze-1.6>
        1
        -- </analyze-1.6>
    })

-- Tarantool's sql_stat table is no-rowid table and actually
-- can be indexed.
-- test:do_catchsql_test(
--     "analyze-1.6.2",
--     [[
--         CREATE INDEX stat1"idx" ON _sql_stat1(idx);
--     ]], {
--         -- <analyze-1.6.2>
--         1, "table sqlite_stat1 may not be indexed"
--         -- </analyze-1.6.2>
--     })

-- test:do_catchsql_test(
--     "analyze-1.6.3",
--     [[
--         CREATE INDEX main.stat1idx ON SQLite_stat1(idx);
--     ]], {
--         -- <analyze-1.6.3>
--         1, "table sqlite_stat1 may not be indexed"
--         -- </analyze-1.6.3>
--     })

test:do_execsql_test(
    "analyze-1.7",
    [[
        SELECT * FROM "_sql_stat1" WHERE "idx" IS NOT NULL
    ]], {
        -- <analyze-1.7>
        -- </analyze-1.7>
    })

test:do_catchsql_test(
    "analyze-1.8",
    [[
        ANALYZE
    ]], {
        -- <analyze-1.8>
        0
        -- </analyze-1.8>
    })

test:do_execsql_test(
    "analyze-1.9",
    [[
        SELECT * FROM "_sql_stat1" WHERE "idx" IS NOT NULL
    ]], {
        -- <analyze-1.9>
        -- </analyze-1.9>
    })

-- MUST_WORK_TEST
test:do_catchsql_test(
    "analyze-1.10",
    [[
        CREATE TABLE t1(id INTEGER PRIMARY KEY AUTOINCREMENT, a,b);
        ANALYZE t1;
    ]], {
        -- <analyze-1.10>
        0
        -- </analyze-1.10>
    })

test:do_execsql_test(
    "analyze-1.11",
    [[
        SELECT * FROM "_sql_stat1"
    ]], {
        -- <analyze-1.11>
        -- </analyze-1.11>
    })

-- Create some indices that can be analyzed.  But do not yet add
-- data.  Without data in the tables, no analysis is done.
--
test:do_execsql_test(
    "analyze-2.1",
    [[
        CREATE INDEX t1i1 ON t1(a);
        ANALYZE t1;
        SELECT * FROM "_sql_stat1" ORDER BY "idx";
    ]], {
        -- <analyze-2.1>
        -- </analyze-2.1>
    })

test:do_execsql_test(
    "analyze-2.2",
    [[
        CREATE INDEX t1i2 ON t1(b);
        ANALYZE t1;
        SELECT * FROM "_sql_stat1" ORDER BY "idx";
    ]], {
        -- <analyze-2.2>
        -- </analyze-2.2>
    })

test:do_execsql_test(
    "analyze-2.3",
    [[
        CREATE INDEX t1i3 ON t1(a,b);
        ANALYZE;
        SELECT * FROM "_sql_stat1" ORDER BY "idx";
    ]], {
        -- <analyze-2.3>
        -- </analyze-2.3>
    })

-- MUST_WORK_TEST
-- Start adding data to the table.  Verify that the analysis
-- is done correctly.
--
test:do_execsql_test(
    "analyze-3.1",
    [[
        INSERT INTO t1 VALUES(1, 1,2);
        INSERT INTO t1 VALUES(2, 1,3);
        ANALYZE t1;
        SELECT "idx", "stat" FROM "_sql_stat1" ORDER BY "idx";
    ]], {
        -- <analyze-3.1>
        0, "2 1", 1, "2 2", 2, "2 1", 3, "2 2 1"
        -- </analyze-3.1>
    })

test:do_execsql_test(
    "analyze-3.2",
    [[
        INSERT INTO t1 VALUES(3, 1,4);
        INSERT INTO t1 VALUES(4, 1,5);
        ANALYZE t1;
        SELECT "idx", "stat" FROM "_sql_stat1" ORDER BY "idx";
    ]], {
        -- <analyze-3.2>
        0, "4 1", 1, "4 4", 2, "4 1", 3, "4 4 1"
        -- </analyze-3.2>
    })

test:do_execsql_test(
    "analyze-3.3",
    [[
        INSERT INTO t1 (a,b) VALUES(2,5);
        ANALYZE;
        SELECT "idx", "stat" FROM "_sql_stat1" ORDER BY "idx";
    ]], {
        -- <analyze-3.3>
        0,"5 1", 1, "5 3", 2, "5 2", 3, "5 3 1"
        -- </analyze-3.3>
    })

test:do_execsql_test(
    "analyze-3.4",
    [[
        CREATE TABLE t2 (id INTEGER PRIMARY KEY AUTOINCREMENT, a, b);
        INSERT INTO t2 SELECT * FROM t1;
        CREATE INDEX t2i1 ON t2(a);
        CREATE INDEX t2i2 ON t2(b);
        CREATE INDEX t2i3 ON t2(a,b);
        ANALYZE;
        SELECT "idx", "stat" FROM "_sql_stat1" ORDER BY "idx";
    ]], {
        -- <analyze-3.4>
        0,"5 1",0,"5 1",1,"5 3",1,"5 3",2,"5 2",2,"5 2",3,"5 3 1",3,"5 3 1"
        -- </analyze-3.4>
    })

test:do_execsql_test(
    "analyze-3.5",
    [[
        DROP INDEX t2i3 ON t2;;
        ANALYZE t1;
        SELECT "idx", "stat" FROM "_sql_stat1" ORDER BY "idx";
    ]], {
        -- <analyze-3.5>
        0,"5 1",0,"5 1",1,"5 3",1,"5 3",2,"5 2",2,"5 2",3,"5 3 1"
        -- </analyze-3.5>
    })

test:do_execsql_test(
    "analyze-3.6",
    [[
        ANALYZE t2;
        SELECT "idx", "stat" FROM "_sql_stat1" ORDER BY "idx";
    ]], {
        -- <analyze-3.6>
        0,"5 1",0,"5 1",1,"5 3",1,"5 3",2,"5 2",2,"5 2",3,"5 3 1"
        -- </analyze-3.6>
    })

test:do_execsql_test(
    "analyze-3.7",
    [[
        DROP INDEX t2i2 ON t2;
        ANALYZE t2;
        SELECT "idx", "stat" FROM "_sql_stat1" ORDER BY "idx";
    ]], {
        -- <analyze-3.7>
        0,"5 1",0,"5 1",1,"5 3",1,"5 3",2,"5 2",3,"5 3 1"
        -- </analyze-3.7>
    })

test:do_execsql_test(
    "analyze-3.8",
    [[
        CREATE TABLE t3 (id INTEGER PRIMARY KEY AUTOINCREMENT, a,b,c,d);
        INSERT INTO t3 (a,b,c,d) SELECT a, b, id AS c, 'hi' AS d FROM t1;
        CREATE INDEX t3i1 ON t3(a);
        CREATE INDEX t3i2 ON t3(a,b,c,d);
        CREATE INDEX t3i3 ON t3(d,b,c,a);
        DROP TABLE t1;
        DROP TABLE t2;
        SELECT "idx", "stat" FROM "_sql_stat1" ORDER BY "idx";
    ]], {
        -- <analyze-3.8>      
        -- </analyze-3.8>
    })

test:do_execsql_test(
    "analyze-3.9",
    [[
        ANALYZE;
        SELECT "idx", "stat" FROM "_sql_stat1" ORDER BY "idx";
    ]], {
        -- <analyze-3.9>
        0,"5 1",1,"5 3",2,"5 3 1 1 1",3,"5 5 2 1 1"
        -- </analyze-3.9>
    })

-- TODO: Need  to support such strange identifiers in Tatantool's SQL
-- test:do_execsql_test(
--     "analyze-3.10",
--     [[
--         CREATE TABLE [silly " name](id INTEGER PRIMARY KEY AUTOINCREMENT, a, b, c);
--         CREATE INDEX 'foolish '' name' ON [silly " name](a, b);
--         CREATE INDEX 'another foolish '' name' ON [silly " name](c);
--         INSERT INTO [silly " name] (a,b,c) VALUES(1, 2, 3);
--         INSERT INTO [silly " name] (a,b,c) VALUES(4, 5, 6);
--         ANALYZE;
--         SELECT "idx", "stat" FROM "_sql_stat1" ORDER BY "idx";
--     ]], {
--         -- <analyze-3.10>
--         "another foolish ' name", "2 1", "foolish ' name", "2 1 1", "t3i1", "5 3", "t3i2", "5 3 1 1 1", "t3i3", "5 5 2 1 1"
--         -- </analyze-3.10>
--     })

-- test:do_execsql_test(
--     "analyze-3.11",
--     [[
--         DROP INDEX "foolish ' name";
--         SELECT "idx", "stat" FROM sqlite_stat1 ORDER BY "idx";
--     ]], {
--         -- <analyze-3.11>
--         "another foolish ' name", "2 1", "t3i1", "5 3", "t3i2", "5 3 1 1 1", "t3i3", "5 5 2 1 1"
--         -- </analyze-3.11>
--     })

-- test:do_execsql_test(
--     "analyze-3.11",
--     [[
--         DROP TABLE "silly "" name";
--         SELECT "idx", "stat" FROM sqlite_stat1 ORDER BY "idx";
--     ]], {
--         -- <analyze-3.11>
--         "t3i1", "5 3", "t3i2", "5 3 1 1 1", "t3i3", "5 5 2 1 1"
--         -- </analyze-3.11>
--     })

-- Try corrupting the sqlite_stat1 table and make sure that
-- the database is still able to function.
--
test:do_execsql_test(
    "analyze-4.0",
    [[
        CREATE TABLE t4(id INTEGER PRIMARY KEY AUTOINCREMENT, x,y,z);
        CREATE INDEX t4i1 ON t4(x);
        CREATE INDEX t4i2 ON t4(y);
        INSERT INTO t4 SELECT id,a,b,c FROM t3;
        ANALYZE;
        SELECT "idx", "stat" FROM "_sql_stat1" ORDER BY "idx";
    ]], {
        -- <analyze-4.0>
        0, "5 1", 0, "5 1", 1, "5 3", 1, "5 3", 2, "5 3 1 1 1", 2, "5 2", 3, "5 5 2 1 1"
        -- </analyze-4.0>
    })

t4 = box.space.T4

test:do_execsql_test(
    "analyze-4.1",
    string.format([[
        DELETE FROM "_sql_stat1";
        INSERT INTO "_sql_stat1" VALUES(%i, %i, 'nonsense');
        INSERT INTO "_sql_stat1" VALUES(%i, %i, '432653287412874653284129847632');
        SELECT * FROM t4 WHERE x = 1234;
    ]], t4.id, t4.index['T4I1'].id, t4.id, t4.index['T4I2'].id), {
        -- <analyze-4.1>
        -- </analyze-4.1>
    })

test:do_execsql_test(
    "analyze-4.2",
    string.format([[
        INSERT INTO "_sql_stat1" VALUES(%i, 12345, '0 1 2 3');
        SELECT * FROM t4 WHERE x = 1234;
    ]], t4.id), {
        -- <analyze-4.2>
        -- </analyze-4.2>
    })



-- Verify that DROP TABLE and DROP INDEX remove entries from the 
-- sqlite_stat1, sqlite_stat3 and sqlite_stat4 tables.
--
test:do_execsql_test(
    "analyze-5.0",
    [[
        DELETE FROM t3;
        DROP TABLE IF EXISTS t4;
        CREATE TABLE t4(ud INTEGER PRIMARY KEY AUTOINCREMENT, x,y,z);
        CREATE INDEX t4i1 ON t4(x);
        CREATE INDEX t4i2 ON t4(y);
        INSERT INTO t3 (a,b,c,d) VALUES(1,2,3,4);
        INSERT INTO t3 (a,b,c,d) VALUES(5,6,7,8);
        INSERT INTO t3 (a,b,c,d) SELECT a+8, b+8, c+8, d+8 FROM t3;
        INSERT INTO t3 (a,b,c,d) SELECT a+16, b+16, c+16, d+16 FROM t3;
        INSERT INTO t3 (a,b,c,d) SELECT a+32, b+32, c+32, d+32 FROM t3;
        INSERT INTO t3 (a,b,c,d) SELECT a+64, b+64, c+64, d+64 FROM t3;
        INSERT INTO t4 (x,y,z) SELECT a, b, c FROM t3;
        ANALYZE;
        SELECT COUNT(DISTINCT "tbl") FROM "_sql_stat1" ORDER BY 1;
    ]], {
        -- <analyze-5.0>
        2
        -- </analyze-5.0>
    })

test:do_execsql_test(
    "analyze-5.0.1",
    [[
        SELECT "idx" FROM "_sql_stat1" ORDER BY 1;
    ]], {
        -- <analyze-5.0>
        0, 0, 1, 1, 2, 2, 3
        -- </analyze-5.0>
    })

stat = "_sql_stat4"

test:do_execsql_test(
    "analyze-5.1",
    string.format([[
            SELECT DISTINCT "idx" FROM "%s" ORDER BY 1;
        ]], stat, stat), {
        -- <analyze-5.1>
        0, 1, 2, 3
        -- </analyze-5.1>
    })

test:do_execsql_test(
    "analyze-5.1.1",
    string.format([[
            SELECT COUNT(DISTINCT "tbl") FROM "%s" ORDER BY 1;
        ]], stat, stat), {
        -- <analyze-5.1>
        2
        -- </analyze-5.1>
    })

test:do_execsql_test(
    "analyze-5.2",
    [[
        DROP INDEX t3i2 ON t3;
        ANALYZE;
        SELECT "idx" FROM "_sql_stat1" ORDER BY 1;
    ]], {
        -- <analyze-5.2>
        0, 0, 1, 1, 2, 3
        -- </analyze-5.2>
    })

test:do_execsql_test(
    "analyze-5.2.1",
    [[
        SELECT COUNT(DISTINCT "tbl") FROM "_sql_stat1" ORDER BY 1;
    ]], {
        -- <analyze-5.2>
        2
        -- </analyze-5.2>
    })

test:do_execsql_test(
    "analyze-5.3",
    string.format([[
            SELECT DISTINCT "idx" FROM "%s" ORDER BY 1;
        ]], stat, stat), {
        -- <analyze-5.3>
        0, 1, 2, 3
        -- </analyze-5.3>
    })

test:do_execsql_test(
    "analyze-5.3.1",
    string.format([[
            SELECT COUNT(DISTINCT "tbl") FROM "%s" ORDER BY 1;
        ]], stat, stat), {
        -- <analyze-5.3>
        2
        -- </analyze-5.3>
    })

test:do_execsql_test(
    "analyze-5.4",
    [[
        DROP TABLE IF EXISTS t3;
        ANALYZE;
        SELECT DISTINCT "idx" FROM "_sql_stat1" ORDER BY 1;
    ]], {
        -- <analyze-5.4>
        0, 1, 2
        -- </analyze-5.4>
    })

test:do_execsql_test(
    "analyze-5.4.1",
    [[
        SELECT COUNT(DISTINCT "tbl") FROM "_sql_stat1" ORDER BY 1;
    ]], {
        -- <analyze-5.4>
        1
        -- </analyze-5.4>
    })

test:do_execsql_test(
    "analyze-5.5",
    string.format([[
            SELECT DISTINCT "idx" FROM "%s" ORDER BY 1;
        ]], stat), {
        -- <analyze-5.5>
        0, 1, 2
        -- </analyze-5.5>
    })

test:do_execsql_test(
    "analyze-5.5.1",
    string.format([[
            SELECT COUNT(DISTINCT "tbl") FROM "%s" ORDER BY 1;
        ]], stat), {
        -- <analyze-5.5>
        1
        -- </analyze-5.5>
    })

test:do_test(
    "analyze-6.1.1",
    function()
        test:execsql("DROP TABLE IF EXISTS t1 ")
        test:execsql("CREATE TABLE t1(id INTEGER PRIMARY KEY AUTOINCREMENT, a, b, c, d, e);")
        test:execsql("CREATE INDEX i1 ON t1(a, b, c, d);")
        test:execsql("CREATE INDEX i2 ON t1(e);")

        for i = 0, 100 do
            box.sql.execute(string.format("INSERT INTO t1 VALUES(null, 'x', 'y', 'z', %s, %s);", i, math.floor(i / 2)))
        end;
        for i = 0, 20 do
            box.sql.execute("INSERT INTO t1 VALUES(null, 'x', 'y', 'z', 101, "..i..");")
        end;
        for i = 102, 200 do
            box.sql.execute(string.format("INSERT INTO t1 VALUES(null, 'x', 'y', 'z', %s, %s);", i, math.floor(i / 2)))
        end;

        test:execsql("ANALYZE;")
        return test:execsql("SELECT COUNT(* )FROM t1 WHERE a='x' AND b='y' AND c='z' AND d=101;;")
    end, {
    -- <analyze-6.1.1>
    21
    -- </analyze-6.1.1>
})

t1 = box.space.T1

test:do_execsql_test(
    "analyze-6.1.2",
    string.format([[
            SELECT "idx", "stat" FROM "_sql_stat1" where "tbl"=%i and "idx"=%i LIMIT 1;
    ]], t1.id, t1.index['I1'].id), {
    -- <analyze-6.1.2>
    1, "221 221 221 221 2"
    -- </analyze-6.1.2>
})

test:do_execsql_test(
    "analyze-6.1.3",
    string.format([[
            SELECT "idx", "neq", "nlt", "ndlt" FROM "_sql_stat4" where "tbl"=%i and "idx"=%i ORDER BY "nlt" LIMIT 1;
    ]], t1.id, t1.index['I1'].id), {
    -- <analyze-6.1.3>
    1, "221 221 221 1", "0 0 0 10", "0 0 0 10"
    -- </analyze-6.1.3>
})

test:do_execsql_test(
    "analyze-6.1.4",
    string.format([[
            SELECT "idx", "neq", "nlt", "ndlt" FROM "_sql_stat4" where "tbl"=%i and "idx"=%i ORDER BY "nlt" DESC LIMIT 1;
    ]], t1.id, t1.index['I1'].id), {
    -- <analyze-6.1.4>
    1, "221 221 221 1", "0 0 0 99", "0 0 0 99"
    -- </analyze-6.1.4>
})

-- # This test corrupts the database file so it must be the last test
-- # in the series.
-- #
-- do_test analyze-99.1 {
--   execsql {
--     PRAGMA writable_schema=on;
--     UPDATE sqlite_master SET sql='nonsense' WHERE name='sqlite_stat1';
--   }
--   db close
--   catch { sqlite3 db test.db }
--   catchsql {
--     ANALYZE
--   }
-- } {1 {malformed database schema (sqlite_stat1)}}

test:finish_test()
