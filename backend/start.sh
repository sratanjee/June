#!/bin/sh
set -e

# Background supercronic so it ticks on the crontab schedule, then exec the
# Node server in the foreground. If the Node server dies, the container dies —
# which is what we want under Fly's supervisor.
#
# supercronic logs to stderr by default, so Fly's log aggregator picks both
# streams up. JOB_KEY (and any other env vars referenced in the crontab) are
# already exported by Fly into PID 1's environment, which supercronic inherits.

if [ -x /usr/local/bin/supercronic ] && [ -f /app/crontab ]; then
  /usr/local/bin/supercronic /app/crontab &
fi

exec node dist/server.js
