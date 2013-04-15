#!/usr/bin/env bash

INSTANCE_DIR=$1

if [ -z "$INSTANCE_DIR" ]; then
	echo "Usage: $0 [instance_dir]"
	exit 1
fi

cd "$INSTANCE_DIR"
java -jar start.jar &
JETTY_PID=$!

trap "kill -TERM $JETTY_PID" SIGINT SIGTERM SIGQUIT
echo "Jetty at $INSTANCE_DIR running in PID $JETTY_PID"

wait $JETTY_PID

set -x
rm -rf "$INSTANCE_DIR"
