#!/usr/bin/env bash

INSTANCE_DIR=$1

if [ -z $INSTANCE_DIR ]; then
	echo "Usage: $0 [instance_dir]"
	exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"

cd $INSTANCE_DIR
bin/jetty.sh run &
JETTY_PID=$!

trap "kill -TERM $JETTY_PID" SIGINT SIGTERM SIGQUIT
echo "Jetty at $INSTANCE_DIR running in PID $JETTY_PID"

wait $JETTY_PID

set -x
rm -rf $INSTANCE_DIR
