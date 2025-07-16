# tests/backend/core/types_test.nim
## Tests para el módulo de tipos de Talpiko Framework

import unittest
import ../../../src/talpiko/backend/core/types

type TestObj = ref object
  id: int

suite "TpResult Type Tests":
  test "Monad chaining":
    let res = tpOk(42) >>= proc(x: int): TpResult[string] = tpOk($x)
    check res.kind == tpSuccess
    check res.value == "42"

  test "Error propagation":
    let res = tpErr[int]("Error", "TP_TEST_CODE") >>= proc(x: int): TpResult[string] = tpOk($x)
    check res.kind == tpFailure
    check res.error.msg == "Error"
    check res.error.code == "TP_TEST_CODE"

  test "Map operator":
    let res = tpMap(tpOk(42), proc(x: int): string = $x)
    check res.kind == tpSuccess
    check res.value == "42"

  test "TryOr macro":
    proc alwaysFails(): int =
      if true: raise newException(ValueError, "Test error")
      discard 42
      0
    let res = tpTryCatch[int](alwaysFails)
    check res.kind == tpFailure
    check res.error.msg == "Test error"
    # No hay code personalizado, así que solo se verifica el mensaje

  test "TryOr macro success":
    proc alwaysSucceeds(): int =
      42
    let res = tpTryCatch[int](alwaysSucceeds)
    check res.kind == tpSuccess
    check res.value == 42

  test "Error with exception":
    let exc = newException(ValueError, "Test error")
    let res = tpErr[int](exc.msg, "TP_EXC_CODE", original=exc)
    check res.kind == tpFailure
    check res.error.msg == "Test error"
    check res.error.code == "TP_EXC_CODE"

  test "TryOr macro null value":
    proc nullFails(): TestObj =
      if true: raise newException(ValueError, "Null error")
      discard TestObj(nil)
      TestObj(nil)
    let resNull = tpTryCatch[TestObj](nullFails)
    check resNull.kind == tpFailure
    check resNull.error.msg == "Null error"
    # No hay code personalizado, así que solo se verifica el mensaje

  test "Unwrap success":
    let res = tpOk(42)
    check tpUnwrap(res) == 42

  test "Unwrap error":
    let res = tpErr[int]("Error", "TP_TEST_CODE")
    expect ValueError:
      discard tpUnwrap(res)

  test "Get or default":
    let resOk = tpOk(42)
    let resErr = tpErr[int]("Error", "TP_TEST_CODE")
    check tpGetOrDefault(resOk, 0) == 42
    check tpGetOrDefault(resErr, 0) == 0

  test "IsError check":
    let resOk = tpOk(42)
    let resErr = tpErr[int]("Error", "TP_TEST_CODE")
    check not tpIsFailure(resOk)
    check tpIsFailure(resErr)

  test "OrElse method":
    let resErr = tpErr[int]("Error", "TP_TEST_CODE")
    let res = if resErr.kind == tpSuccess: resErr else: tpOk(100)
    check res.kind == tpSuccess
    check res.value == 100

  test "Nil value for ref types":
    let resOk = tpOk[TestObj](nil)
    let resErr = tpErr[TestObj]("Error", "TP_TEST_CODE")
    check resOk.kind == tpSuccess
    check resOk.value.isNil
    check resErr.kind == tpFailure
    check not resErr.error.isNil