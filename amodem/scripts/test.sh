#!/bin/bash
set -u
set -e

run() {
	echo "SRC $HOST ($DIR): $*" 1>&2
	if [ "$HOST" == "localhost" ]; then
		echo "$*" | bash
	else
		ssh $HOST "cd $DIR; $*"
	fi
}

run_src() {
	DIR=${SRC_DIR:-"$PWD"}
	HOST=${SRC_HOST:-localhost}
	run "$*"
}

run_dst() {
	DIR=${DST_DIR:-"$PWD"}
	HOST=${DST_HOST:-localhost}
	run "$*"
}

run_src true
run_dst true

## generate 1Mbit of random data
run_src dd if=/dev/urandom of=data.send bs=125kB count=1 status=none
SRC_HASH=`run_src sha256sum data.send`

# modulate data into audio file
run_src "./send.py <data.send >audio.send"

# stop old recording and start a new one
run_src killall -q aplay || true
run_dst killall -q arecord || true

run_dst "./wave.py record audio.recv" &
sleep 1  # let audio.recv be filled

# play the modulated data
run_src ./wave.py play   audio.send &

# start the receiever
run_dst "./recv.py <audio.recv >data.recv"

# stop recording after playing is over
run_src killall -q aplay || true
run_dst killall -q arecord || true

# verify transmittion
DST_HASH=`run_dst sha256sum data.recv`

echo -e "$SRC_HASH\n$DST_HASH"