## ✅ Tests para el módulo de tipos de Talpiko Framework
## 📦 Archivo: tests/backend/core/types_test.nim
## 📋 Este archivo valida el comportamiento de TpResult y sus operadores semánticos

import std/unittest
import ../../../src/talpiko/backend/core/types

type TestObj = ref object
  id: int

suite "🧪 TpResult Type Tests":

  test "Monadic chaining con tpAndThen":
    let res = tpOk(42).tpAndThen(proc(x: int): TpResult[string] = tpOk($x))
    check res.kind == tpSuccessKind
    check res.value == "42"

  test "Propagación de errores con tpBind":
    let res = tpErr[int]("Error", "TP_TEST_CODE").tpBind(proc(x: int): TpResult[string] = tpOk($x))
    check res.kind == tpFailureKind
    check res.error.msg == "Error"
    check res.error.code == "TP_TEST_CODE"

  test "Encadenamiento usando >>==":
    let res = tpOk(21) >>== proc(x: int): TpResult[int] = tpOk(x * 2)
    check res.kind == tpSuccessKind
    check res.value == 42

  test "tpMap aplica función sobre tpOk":
    let res = tpMap(tpOk(42), proc(x: int): string = $x)
    check res.kind == tpSuccessKind
    check res.value == "42"

  test "tpTryCatch captura excepciones":
    proc alwaysFails(): int =
      raise newException(ValueError, "Test error")

    let res = tpTryCatch[int](alwaysFails)
    check res.kind == tpFailureKind
    check res.error.msg == "Test error"

  test "tpTryCatch captura correctamente éxito":
    proc alwaysSucceeds(): int =
      42

    let res = tpTryCatch[int](alwaysSucceeds)
    check res.kind == tpSuccessKind
    check res.value == 42

  test "tpErr desde excepción con original":
    let exc = newException(ValueError, "Test error")
    let res = tpErr[int](exc.msg, "TP_EXC_CODE", original=exc)
    check res.kind == tpFailureKind
    check res.error.msg == "Test error"
    check res.error.code == "TP_EXC_CODE"

  test "tpTryCatch con valor nulo":
    proc nullFails(): TestObj =
      raise newException(ValueError, "Null error")

    let res = tpTryCatch[TestObj](nullFails)
    check res.kind == tpFailureKind
    check res.error.msg == "Null error"

  test "tpUnwrap extrae valor correctamente":
    let res = tpOk(42)
    check tpUnwrap(res) == 42

  test "tpUnwrap lanza excepción si hay error":
    let res = tpErr[int]("Error", "TP_TEST_CODE")
    expect ValueError:
      discard tpUnwrap(res)

  test "tpGetOrDefault retorna valor o default":
    let resOk = tpOk(42)
    let resErr = tpErr[int]("Error", "TP_TEST_CODE")
    check tpGetOrDefault(resOk, 0) == 42
    check tpGetOrDefault(resErr, 0) == 0

  test "tpIsFailure distingue éxito y error":
    let resOk = tpOk(42)
    let resErr = tpErr[int]("Error", "TP_TEST_CODE")
    check not tpIsFailure(resOk)
    check tpIsFailure(resErr)

  test "Uso explícito de fallback manual con 'else'":
    let resErr = tpErr[int]("Error", "TP_TEST_CODE")
    let res = if resErr.kind == tpSuccessKind: resErr else: tpOk(100)
    check res.kind == tpSuccessKind
    check res.value == 100

  test "Valor nulo aceptado en tpOk":
    let resOk = tpOk[TestObj](nil)
    let resErr = tpErr[TestObj]("Error", "TP_TEST_CODE")
    check resOk.kind == tpSuccessKind
    check resOk.value.isNil
    check resErr.kind == tpFailureKind
    check not resErr.error.isNil
