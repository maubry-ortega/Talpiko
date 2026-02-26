# tests/benchmarks/bench_router.nim
## Benchmark: route matching throughput and latency (p50/p95/p99).
## Compile with: nim c -r --opt:speed tests/benchmarks/bench_router.nim

import times, algorithm, sequtils, asyncdispatch, tables
import ../../src/talpiko/backend/web/router
import ../../src/talpiko/backend/core/types

const
  kIter         = 100_000
  kWarmupIter   = 1_000

proc dummyHandler(ctx: TpContext): Future[void] {.async, gcsafe.} = discard

proc runBench(label: string, iters: int, body: proc()) =
  ## Warm up, then measure `iters` iterations.
  for _ in 0 ..< kWarmupIter: body()

  var samples = newSeq[float64](iters)
  for i in 0 ..< iters:
    let t0 = cpuTime()
    body()
    samples[i] = (cpuTime() - t0) * 1_000_000.0  # µs

  samples.sort()
  let total = samples.foldl(a + b, 0.0)
  let p50   = samples[int(iters.float * 0.50)]
  let p95   = samples[int(iters.float * 0.95)]
  let p99   = samples[int(iters.float * 0.99)]
  let rps   = float(iters) / (total / 1_000_000.0)

  echo "── " & label
  echo "   iterations : " & $iters
  echo "   throughput : " & $int(rps) & " req/s"
  echo "   p50        : " & $p50 & " µs"
  echo "   p95        : " & $p95 & " µs"
  echo "   p99        : " & $p99 & " µs"
  echo ""

proc main() =
  let r = newTpRouter()
  r.get("/",                         dummyHandler)
  r.get("/api/v1/ping",              dummyHandler)
  r.get("/api/v1/users",             dummyHandler)
  r.get("/api/v1/users/:id",         dummyHandler)
  r.get("/api/v1/users/:id/profile", dummyHandler)
  r.post("/api/v1/users",            dummyHandler)
  r.put("/api/v1/users/:id",         dummyHandler)
  r.delete("/api/v1/users/:id",      dummyHandler)

  echo "=== Router Benchmark (", kIter, " iterations) ==="
  echo ""

  runBench("Static root /", kIter) do:
    discard r.matchRoute(HttpGet, "/")

  runBench("Static 3-segment /api/v1/ping", kIter) do:
    discard r.matchRoute(HttpGet, "/api/v1/ping")

  runBench("Dynamic 1-param /api/v1/users/123", kIter) do:
    discard r.matchRoute(HttpGet, "/api/v1/users/123")

  runBench("Dynamic 2-segment /api/v1/users/42/profile", kIter) do:
    discard r.matchRoute(HttpGet, "/api/v1/users/42/profile")

  runBench("POST /api/v1/users", kIter) do:
    discard r.matchRoute(HttpPost, "/api/v1/users")

  runBench("404 miss /not/found", kIter) do:
    discard r.matchRoute(HttpGet, "/not/found")

main()
