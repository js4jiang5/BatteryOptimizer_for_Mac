#!/bin/bash
ShutDown() {
	sh $HOME/.shutdown
	exit 0
}

trap ShutDown SIGTERM
while true; do
	sleep 86400 &
	wait $!
done