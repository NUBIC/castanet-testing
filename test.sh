#!/usr/bin/env bash

set -xe

JASIG_PORT=$1
CALLBACK_PORT=$2

if [ -z $CALLBACK_PORT ]; then
	echo "Usage: $0 [CAS port] [callback port]"
	exit 1
fi

bundle exec rake castanet:testing:jasig:delete_scratch_dir castanet:testing:callback:delete_scratch_dir
bundle exec rake castanet:testing:jasig:download

PORT=$JASIG_PORT bundle exec rake castanet:testing:jasig:start &
JASIG_PID=$!

PORT=$CALLBACK_PORT bundle exec rake castanet:testing:callback:start &
CALLBACK_PID=$!

sleep 10

# CAS and the callback should start.
bundle exec rake castanet:testing:jasig:waitall castanet:testing:callback:waitall

# Shut things down...
kill -TERM $JASIG_PID && wait $JASIG_PID
kill -TERM $CALLBACK_PID && wait $CALLBACK_PID

# ...and make sure we've cleaned up.
! find /tmp/castanet-testing | egrep 'jasig\.|callback\.'
