# tests/backend/web/router_test.nim
import unittest, asyncdispatch, tables
import ../../../src/talpiko/backend/web/router
import ../../../src/talpiko/backend/core/types

suite "TpRouter Tests":
  setup:
    let r = newTpRouter()

  test "Matches a simple static route":
    proc myHandler(ctx: TpContext): Future[void] {.async.} = discard
    r.get("/api/ping", myHandler)
    
    let match = r.matchRoute(HttpGet, "/api/ping")
    check match.matched
    check match.handler != nil
    check match.params.len == 0

  test "Fails on unmatched static route":
    proc myHandler(ctx: TpContext): Future[void] {.async.} = discard
    r.get("/api/ping", myHandler)
    
    let match = r.matchRoute(HttpGet, "/api/pong")
    check not match.matched
    check match.handler == nil
    
  test "Fails on wrong HTTP method":
    proc myHandler(ctx: TpContext): Future[void] {.async.} = discard
    r.post("/api/ping", myHandler)
    
    let match = r.matchRoute(HttpGet, "/api/ping")
    check not match.matched

  test "Matches a dynamic route with :param":
    proc myHandler(ctx: TpContext): Future[void] {.async.} = discard
    r.get("/users/:id", myHandler)
    
    let match = r.matchRoute(HttpGet, "/users/123")
    check match.matched
    check match.params.hasKey("id")
    check match.params["id"] == "123"

  test "Matches a dynamic route with {param}":
    proc myHandler(ctx: TpContext): Future[void] {.async.} = discard
    r.get("/posts/{slug}/comments", myHandler)
    
    let match = r.matchRoute(HttpGet, "/posts/hello-world/comments")
    check match.matched
    check match.params.hasKey("slug")
    check match.params["slug"] == "hello-world"

  test "Matches multiple dynamic params":
    proc myHandler(ctx: TpContext): Future[void] {.async.} = discard
    r.get("/users/:uid/posts/:pid", myHandler)
    
    let match = r.matchRoute(HttpGet, "/users/99/posts/5")
    check match.matched
    check match.params["uid"] == "99"
    check match.params["pid"] == "5"

  test "Matches ignoring trailing slashes":
    proc myHandler(ctx: TpContext): Future[void] {.async.} = discard
    r.get("/api/v1/", myHandler)
    
    let match = r.matchRoute(HttpGet, "/api/v1")
    check match.matched
