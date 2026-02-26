#!/bin/bash
# tests/benchmarks/run_external_audit.sh
# Multi-core Performance Audit for Talpiko.

BIN_DIR="./bin"
BOMBARDIER="$BIN_DIR/bombardier"
SERVER_BIN="./build/example"
LOG_FILE="./bench_audit.log"
PORT=8080
TARGET="http://localhost:$PORT"

echo "=== Talpiko Multi-core Performance Audit ===" | tee $LOG_FILE

# 1. Start Server in Release mode
echo "[1/4] Compiling server in release mode..."
nim c -d:release --gc:orc --threads:on build/example.nim

echo "[2/4] Starting server with 4 workers..."
$SERVER_BIN > /dev/null 2>&1 &
SERVER_PID=$!
sleep 3 # Warm up

# 2. Baseline Benchmark (125 connections, 10 seconds)
echo "[3/4] Running Baseline (125 conns, 10s)..."
$BOMBARDIER -c 125 -d 10s $TARGET | tee -a $LOG_FILE

# 3. High Concurrency (1000 connections)
echo "[4/4] Running High Concurrency (1000 conns, 10s)..."
$BOMBARDIER -c 1000 -d 10s $TARGET | tee -a $LOG_FILE

# 4. Malformed Requests / Stability
echo "[5/4] Testing Stability (Malformed paths)..."
$BOMBARDIER -c 50 -d 5s "$TARGET/invalid/path/test" | tee -a $LOG_FILE

# 5. Cleanup
echo "Cleaning up..."
pkill -P $SERVER_PID
kill $SERVER_PID
pkill example # Ensure all workers are dead

echo "Audit complete. Results in $LOG_FILE."
