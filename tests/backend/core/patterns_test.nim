# tests/backend/core/patterns_test.nim
import unittest
import ../../../src/talpiko/backend/core/patterns

suite "TpPattern Tests":
  test "Compile pattern ignores case sensitivity by default":
    let p = tpCompilePattern("ABC")
    check not p.caseSensitive
    check p.pattern == "ABC"

  test "Case sensitive pattern":
    let p = tpCompilePattern("ABC", true)
    check p.caseSensitive
    check p.pattern == "ABC"

  test "Basic literal matches":
    let p = tpCompilePattern("hello")
    check tpMatch("hello", p)
    check tpMatch("Hello", p) # Default is case-insensitive
    check not tpMatch("world", p)

  test "Basic exact match with case sensitive":
    let p = tpCompilePattern("hello", true)
    check tpMatch("hello", p)
    check not tpMatch("Hello", p)

  test "Wildcard * matches everything":
    let p = tpCompilePattern("*")
    check tpMatch("cualquier_cosa", p)
    check tpMatch("", p)

  test "Wildcard * matches prefix":
    let p = tpCompilePattern("start*")
    check tpMatch("start", p)
    check tpMatch("starting", p)
    check tpMatch("start123", p)
    check not tpMatch("123start", p)

  test "Wildcard * matches suffix":
    let p = tpCompilePattern("*end")
    check tpMatch("end", p)
    check tpMatch("the_end", p)
    check not tpMatch("end123", p)

  test "Wildcard * matches in middle":
    let p = tpCompilePattern("foo*bar")
    check tpMatch("foobar", p)
    check tpMatch("foo123bar", p)
    check tpMatch("foo_something_bar", p)
    check not tpMatch("fooba", p)

  test "Email pattern match":
    let p = tpCompilePattern("*@*.*")
    check tpMatch("test@example.com", p)
    check tpMatch("a@b.c", p)
    # The current pattern logic is very simple and matches any string containing @ and . after it
    # tpMatch just moves until it finds the literals
