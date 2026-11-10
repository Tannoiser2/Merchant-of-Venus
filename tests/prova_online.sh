#!/bin/sh
# Partita online completa fra due istanze sul finto Firebase. Uso: sh tests/prova_online.sh [godot]
G=${1:-godot}
cd "$(dirname "$0")/.."
python3 tests/firebase_mock.py 8765 >/tmp/mov_mock.log 2>&1 &
M=$!
sleep 1
rm -f /tmp/mov_code.txt
export SF_DB_URL=http://127.0.0.1:8765/db SF_AUTH_URL=http://127.0.0.1:8765/signup SF_REFRESH_URL=http://127.0.0.1:8765/refresh SF_CODEFILE=/tmp/mov_code.txt
SF_ROLE=host SF_SESSION=/tmp/mov_host.cfg $G --headless --path . -s tests/online_play.gd > /tmp/mov_host.log 2>&1 &
H=$!
SF_ROLE=guest SF_SESSION=/tmp/mov_guest.cfg $G --headless --path . -s tests/online_play.gd > /tmp/mov_guest.log 2>&1
wait $H
kill $M
grep MOVTEST /tmp/mov_host.log /tmp/mov_guest.log
