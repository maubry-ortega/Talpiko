# tests/backend/core/types_test.nim
## Tests para el módulo de tipos de Talpiko Framework

import unittest
import ../../../src/talpiko/backend/core/types

suite "TpResult Type Tests":
  test "Monad chaining":
    let res = tpOk(42) >>= proc(x: int): TpResult[string] = tpOk($x)
    check res.isOk
    check res.value == "42"

  test "Error propagation":
    let res = tpErr[int]("Error", "TP_TEST_CODE") >>= proc(x: int): TpResult[string] = tpOk($x)
    check not res.isOk
    check res.errorMsg == "Error"
    check res.errorCode == "TP_TEST_CODE"

  test "Map operator":
    let res = tpOk(42).tpMap(proc(x: int): string = $x)
    check res.isOk
    check res.value == "42"

  test "Error with exception":
    let exc = newException(ValueError, "Test error")
    let res = tpErr[int](exc, "TP_EXC_CODE")
    check not res.isOk
    check res.errorMsg == "Test error"
    check res.errorCode == "TP_EXC_CODE"

  test "TryOr macro":
    let res = tpTryOr[int]:
      if true: raise newException(ValueError, "Test error")
      42
    do (e: ref CatchableError) -> TpResult[int]:
      tpErr[int](e.msg, "TP_TRY_ERROR")
    check not res.isOk
    check res.errorMsg == "Test error"
    check res.errorCode == "TP_TRY_ERROR"

  test "TryOr macro success":
    let res = tpTryOr[int]:
      42
    do (e: ref CatchableError) -> TpResult[int]:
      tpErr[int](e.msg, "TP_TRY_ERROR")
    check res.isOk
    check res.value == 42

  test "TryOr macro null value":
    type TestObj = ref object
      id: int
    let res = tpTryOr[TestObj]:
      if true: raise newException(ValueError, "Null error")
      nil
    do (e: ref CatchableError) -> TpResult[TestObj]:
      tpErr[TestObj](e.msg, "TP_NULL_ERROR")
    check not res.isOk
    check res.errorMsg == "Null error"
    check res.errorCode == "TP_NULL_ERROR"

  test "Unwrap success":
    let res = tpOk(42)
    check res.tpUnwrap() == 42

  test "Unwrap error":
    let res = tpErr[int]("Error", "TP_TEST_CODE")
    expect TpResultError:
      discard res.tpUnwrap()

  test "Get or default":
    let resOk = tpOk(42)
    let resErr = tpErr[int]("Error", "TP_TEST_CODE")
    check resOk.tpGetOrDefault(0) == 42
    check resErr.tpGetOrDefault(0) == 0

  test "IsError check":
    let resOk = tpOk(42)
    let resErr = tpErr[int]("Error", "TP_TEST_CODE")
    check not resOk.tpIsError()  # Cambiado a llamada a función
    check resErr.tpIsError()     # Cambiado a llamada a función

  test "OrElse method":
    let resErr = tpErr[int]("Error", "TP_TEST_CODE")
    let res = resErr.tpOrElse(proc(): TpResult[int] = tpOk(100))
    check res.isOk
    check res.value == 100

  test "Nil value for ref types":
    type TestObj = ref object
      id: int
    let resOk = tpOk[TestObj](nil)
    let resErr = tpErr[TestObj]("Error", "TP_TEST_CODE")
    check resOk.isOk
    check resOk.value.isNil
    check not resErr.isOk      # Cambiado de isError a not isOk
    check resErr.value.isNil