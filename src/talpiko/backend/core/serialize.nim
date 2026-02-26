# src/talpiko/backend/core/serialize.nim
## Compile-time static serialization for Talpiko.
## Writes struct fields directly to a string buffer with no JsonNode intermediary.
##
## Design goals:
##   - Zero heap allocation in the hot path (writes via `buf.add`)
##   - No intermediate JsonNode/string conversion nodes
##   - Compile-time field enumeration via `fieldPairs`
##   - String escaping inline (no stdlib json round-trip)
##   - Works with nested objects and common primitive types

import macros

# ── Low-level string escape ──────────────────────────────────────────────────

proc tpEscapeJsonStr*(s: string, buf: var string) {.inline.} =
  ## Appends `s` to `buf` as a JSON string (with quotes and escaping).
  ## Tight loop, no allocation.
  buf.add('"')
  for c in s:
    if c == '"':      buf.add("\\\"")
    elif c == '\\':   buf.add("\\\\")
    elif c == '\n':   buf.add("\\n")
    elif c == '\r':   buf.add("\\r")
    elif c == '\t':   buf.add("\\t")
    elif ord(c) < 0x20:
      # Other control characters (excluding \n \r \t handled above)
      buf.add("\\u00")
      const hex = "0123456789abcdef"
      buf.add(hex[ord(c) shr 4])
      buf.add(hex[ord(c) and 0xf])
    else:
      buf.add(c)
  buf.add('"')

# ── Primitive serializers (used by tpAppendJson dispatch) ────────────────────

proc tpAppendJson*(val: string, buf: var string) {.inline.} =
  tpEscapeJsonStr(val, buf)

proc tpAppendJson*(val: bool, buf: var string) {.inline.} =
  buf.add(if val: "true" else: "false")

proc tpAppendJson*[T: SomeInteger](val: T, buf: var string) {.inline.} =
  ## Covers int, int8, int16, int32, int64, uint, uint8, uint16, uint32, uint64
  buf.add($val)

proc tpAppendJson*[T: SomeFloat](val: T, buf: var string) {.inline.} =
  ## Covers float, float32, float64
  buf.add($val)

proc tpAppendJson*[T](val: seq[T], buf: var string) {.inline.}
proc tpAppendJson*[T: object | tuple](val: T, buf: var string) {.inline.}

# ── Generic array / seq ──────────────────────────────────────────────────────

proc tpAppendJson*[T](val: seq[T], buf: var string) =
  buf.add('[')
  for i, item in val:
    if i > 0: buf.add(',')
    tpAppendJson(item, buf)
  buf.add(']')

proc tpAppendJson*[N: static[int]; T](val: array[N, T], buf: var string) =
  buf.add('[')
  for i in 0 ..< N:
    if i > 0: buf.add(',')
    tpAppendJson(val[i], buf)
  buf.add(']')

# ── Object / tuple (compile-time field iteration) ───────────────────────────

proc tpAppendJson*[T: object | tuple](val: T, buf: var string) =
  ## Serializes any `object` or `tuple` by iterating its fields at compile time.
  ## Results in a sequence of `buf.add` calls with no intermediate structures.
  buf.add('{')
  var first = true
  for name, field in val.fieldPairs:
    if not first: buf.add(',')
    first = false
    tpEscapeJsonStr(name, buf)
    buf.add(':')
    tpAppendJson(field, buf)
  buf.add('}')

# ── Public API ───────────────────────────────────────────────────────────────

template tpSerialize*[T](val: T, buf: var string) =
  ## Serializes `val` directly into `buf` as JSON.
  ## Use this instead of `$(%*val)` to avoid JsonNode allocation.
  tpAppendJson(val, buf)

proc tpToJsonString*[T](val: T): string =
  ## Allocates a new string and serializes `val` into it.
  ## Prefer `tpSerialize` with a pre-allocated buffer on the hot path.
  result = newStringOfCap(128)
  tpAppendJson(val, result)
