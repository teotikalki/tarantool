test_run = require('test_run').new()
engine = test_run:get_cfg('engine')
box.sql.execute('pragma sql_default_engine=\''..engine..'\'')
box.sql.execute('pragma interactive_mode=0;')

box.cfg{}

box.sql.execute("select (9223372036854775807)")
box.sql.execute("select (-9223372036854775808)")

box.sql.execute("select (9223372036854775808)")
box.sql.execute("select (-9223372036854775809)")
