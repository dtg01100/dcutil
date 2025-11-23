#!/usr/bin/env bash
echo "Testing lock"
exec 9>/tmp/test.lock || true
flock -x 9 || true
echo "Locked"
sleep 1
flock -u 9 || true
exec 9>&- || true
echo "Unlocked"
