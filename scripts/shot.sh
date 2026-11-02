#!/bin/bash
# shot.sh <sim-id> <bundle-id> <out.png> [launch args...]  — relaunch the app with args and screenshot it
SIM=$1; BID=$2; OUT=$3; shift 3
xcrun simctl terminate "$SIM" "$BID" >/dev/null 2>&1
xcrun simctl launch "$SIM" "$BID" "$@" >/dev/null
sleep ${WAIT:-6}
xcrun simctl io "$SIM" screenshot "$OUT" >/dev/null 2>&1
