#!/bin/bash
# tests/benchmarks/monitor_mem.sh

echo "Monitoring Talpiko workers memory usage..."
BOMBARDIER="./bin/bombardier"
TARGET="http://localhost:8080"

# Start load in background
$BOMBARDIER -c 200 -d 30s $TARGET > /dev/null 2>&1 &
BOMB_PID=$!

echo "Interval | Worker PIDs | RSS (KB)"
for i in {1..6}; do
  MEMS=$(ps -o rss= -p $(pgrep example) | tr '\n' ' ')
  echo "  $i s   | $(pgrep example | tr '\n' ' ') | $MEMS"
  sleep 5
done

wait $BOMB_PID
echo "Monitoring complete."
