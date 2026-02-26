# tests/benchmarks/bench_request.nim
## Benchmark: full request cycle (parse → dispatch → serialize → respond overhead).
## Tests the in-process cost of the hot path without network I/O.
## Compile with: nim c -r --opt:speed tests/benchmarks/bench_request.nim

import times, algorithm, sequtils, tables, httpcore, asyncdispatch
import ../../src/talpiko/backend/core/types
import ../../src/talpiko/backend/core/utils
import ../../src/talpiko/backend/core/serialize
import ../../src/talpiko/backend/web/router
import ../../src/talpiko/backend/web/context

const kIter = 100_000

type
  HelloResp = object
    message: string
    status:  string

proc runBench(label: string, iters: int, body: proc()) =
  for _ in 0 ..< 1000: body()
  var samples = newSeq[float64](iters)
  for i in 0 ..< iters:
    let t0   = cpuTime()
    body()
    samples[i] = (cpuTime() - t0) * 1_000_000.0
  samples.sort()
  let p50  = samples[int(iters.float * 0.50)]
  let p95  = samples[int(iters.float * 0.95)]
  let p99  = samples[int(iters.float * 0.99)]
  let total = samples.foldl(a + b, 0.0)
  let rps  = float(iters) / (total / 1_000_000.0)
  echo "── " & label
  echo "   p50: " & $p50 & " µs  |  p95: " & $p95 & " µs  |  p99: " & $p99 & " µs  |  " & $int(rps) & " op/s"
  echo ""

proc main() =
  # Set up a realistic router
  let router = newTpRouter()
  proc helloHandler(ctx: TpContext): Future[void] {.async.} =
    ctx.ok(HelloResp(message: "ok", status: "success"))
  proc userHandler(ctx: TpContext): Future[void] {.async.} =
    let id = ctx.getParam("id")
    ctx.ok(HelloResp(message: "user:" & id, status: "success"))
  router.get("/api/ping",       helloHandler)
  router.get("/api/users/:id",  userHandler)

  echo "=== Request Cycle Benchmark (", kIter, " iterations) ==="
  echo ""

  # ── tpParseHttpMethod (no alloc)
  runBench("tpParseHttpMethod (GET)", kIter) do:
    discard tpParseHttpMethod("GET")

  # ── tpParseQuery (index arithmetic)
  let testUrl = "/api/ping?foo=bar&baz=42&page=1"
  runBench("tpParseQuery (3 params)", kIter) do:
    discard tpParseQuery(testUrl)

  # ── Route match + param extraction
  runBench("matchRoute static /api/ping", kIter) do:
    discard router.matchRoute(HttpGet, "/api/ping")

  runBench("matchRoute dynamic /api/users/99", kIter) do:
    discard router.matchRoute(HttpGet, "/api/users/99")

  # ── Static serialization
  let resp = HelloResp(message: "hello", status: "ok")
  var buf = newStringOfCap(128)
  runBench("tpSerialize HelloResp", kIter) do:
    buf.setLen(0)
    tpSerialize(resp, buf)

  # ── Error response via const arrays
  runBench("error const-array lookup (tpecNotFound)", kIter) do:
    let _ = tpErrorHttpCode[tpecNotFound]
    let _ = tpErrorCodeStr[tpecNotFound]

main()
