# tests/backend/web/server_test.nim
import unittest, asyncdispatch, asynchttpserver, tables, json, httpclient
import ../../../src/talpiko/backend/web/server
import ../../../src/talpiko/backend/core/types
import ../../../src/talpiko/backend/web/router
import ../../../src/talpiko/backend/web/context
import ../../../src/talpiko/backend/core/utils

suite "TpServer Tests":
  test "Context correctly sets JSON responses":
    let s = newTpServer()
    proc myHandler(ctx: TpContext): Future[void] {.async.} =
      ctx.json(%*{"msg": "Hello"}, Http200)

    s.router.get("/api/data", myHandler)

    
  test "Query string parser works correctly":
    let q = tpParseQuery("/api/search?q=nim&page=2")
    check q.hasKey("q")
    check q.hasKey("page")
    check q["q"] == "nim"
    check q["page"] == "2"

  test "Query string parser handles empty queries":
    let q = tpParseQuery("/api/search")
    check q.len == 0

  test "Method parser handles all verbs":
    check tpParseHttpMethod("GeT") == HttpGet
    check tpParseHttpMethod("PosT") == HttpPost
    check tpParseHttpMethod("PaTcH") == HttpPatch
    check tpParseHttpMethod("INVALID") == HttpGet # Default
