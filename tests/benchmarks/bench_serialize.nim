# tests/benchmarks/bench_serialize.nim
## Benchmark: static tpSerialize vs dynamic %* JsonNode.
## Compile with: nim c -r --opt:speed tests/benchmarks/bench_serialize.nim

import times, algorithm, sequtils, json
import ../../src/talpiko/backend/core/serialize

const kIter = 100_000

type
  User = object
    id:     int
    name:   string
    email:  string
    active: bool
    score:  float

  ApiResponse = object
    status:  string
    message: string
    data:    User

proc runBench(label: string, iters: int, body: proc()) =
  var samples = newSeq[float64](iters)
  for _ in 0 ..< 1000: body()  # warmup
  for i in 0 ..< iters:
    let t0   = cpuTime()
    body()
    samples[i] = (cpuTime() - t0) * 1_000_000.0
  samples.sort()
  let total = samples.foldl(a + b, 0.0)
  let p50   = samples[int(iters.float * 0.50)]
  let p95   = samples[int(iters.float * 0.95)]
  let p99   = samples[int(iters.float * 0.99)]
  let rps   = float(iters) / (total / 1_000_000.0)
  echo "── " & label
  echo "   p50: " & $p50 & " µs  |  p95: " & $p95 & " µs  |  p99: " & $p99 & " µs  |  " & $int(rps) & " op/s"
  echo ""

proc main() =
  let user = User(id: 42, name: "Alice", email: "alice@example.com",
                  active: true, score: 9.87)
  let resp = ApiResponse(status: "ok", message: "success", data: user)

  echo "=== Serialization Benchmark (", kIter, " iterations) ==="
  echo ""

  # Static: tpSerialize writes straight to buffer
  var staticBuf = newStringOfCap(256)
  runBench("tpSerialize (static, direct buffer)", kIter) do:
    staticBuf.setLen(0)
    tpSerialize(resp, staticBuf)

  # Dynamic: stdlib %* creates full JsonNode tree
  runBench("%* + $ (dynamic JsonNode)", kIter) do:
    let _ = $(%*resp)

  echo "Expected: static is significantly faster (no JsonNode allocation)"

main()
