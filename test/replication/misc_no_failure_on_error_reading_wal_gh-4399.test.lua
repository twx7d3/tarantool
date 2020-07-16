test_run = require('test_run').new()
test_run:cmd("restart server default")
uuid = require('uuid')
fiber = require('fiber')

--
-- gh-4399 Check that an error reading WAL directory on subscribe
-- doesn't lead to a permanent replication failure.
--
box.schema.user.grant("guest", "replication")
test_run:cmd("create server replica with rpl_master=default, script='replication/replica.lua'")
test_run:cmd("start server replica")

-- Make the WAL directory inaccessible.
fio = require('fio')
path = fio.abspath(box.cfg.wal_dir)
fio.chmod(path, 0)

-- Break replication on timeout.
replication_timeout = box.cfg.replication_timeout
box.cfg{replication_timeout = 9000}
test_run:cmd("switch replica")
test_run:wait_cond(function() return box.info.replication[1].upstream.status ~= 'follow' end)
require('fiber').sleep(box.cfg.replication_timeout)
test_run:cmd("switch default")
box.cfg{replication_timeout = replication_timeout}

-- Restore access to the WAL directory.
-- Wait for replication to be reestablished.
fio.chmod(path, tonumber('777', 8))
test_run:cmd("switch replica")
test_run:wait_cond(function() return box.info.replication[1].upstream.status == 'follow' end)
test_run:cmd("switch default")

test_run:cmd("stop server replica")
test_run:cmd("cleanup server replica")
test_run:cmd("delete server replica")
test_run:cleanup_cluster()
box.schema.user.revoke('guest', 'replication')
