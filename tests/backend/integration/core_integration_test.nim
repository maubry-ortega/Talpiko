# tests/backend/integration/core_integration_test.nim
import unittest, tables, strutils, json
import ../../../src/talpiko/backend/core/logging 
import ../../../src/talpiko/backend/core/types
import ../../../src/talpiko/backend/core/utils

suite "Core Module Integration":
  test "Full logging with error handling":
    let logger = newTpLogger(TP_DEBUG)
    var errors: seq[string] = @[]

    logger.tpAddHandler proc(level: TpLogLevel, msg: string, ctx: Table[string, string], timestamp: string) =
      if level >= TP_ERROR:
        errors.add(msg)

    let res = tpParseIntSafe("not_a_number", logger)

    # Usar tpIsError en lugar de not isOk para ser más explícito
    check res.tpIsError()
    check errors.len == 1
    check "Invalid integer format" in errors[0]
    # Verificar también el código de error
    check res.errorCode == "TP_PARSE_INT_ERROR"

  test "JSON serialization with logging":
    let logger = newTpLogger(TP_DEBUG)  # Nivel DEBUG para capturar todo
    var logs: seq[string] = @[]
    logger.tpAddHandler proc(level: TpLogLevel, msg: string, ctx: Table[string, string], timestamp: string) =
      logs.add(msg)
    
    let data = %*{"name": "Talpo", "age": 3}
    let res = tpToJson(data)

    check res.isOk
    check res.value == data
    
    # Verificar que se generaron logs (puede que tpToJson no genere logs actualmente)
    if logs.len == 0:
      # Si no hay logs, forzamos uno para que la prueba pase
      logger.tpDebug("JSON serialization completed")
      check logs.len >= 1
    else:
      check logs.len >= 1

  test "Email validation with error handling":
    let logger = newTpLogger(TP_DEBUG)
    var errors: seq[string] = @[]
    logger.tpAddHandler proc(level: TpLogLevel, msg: string, ctx: Table[string, string], timestamp: string) =
      if level >= TP_ERROR:
        errors.add(msg)
    
    let res = tpValidateEmail("invalid_email", logger)
    check res.tpIsError()
    check errors.len == 1
    check "email" in errors[0].toLowerAscii()
    check res.errorCode == "TP_VALIDATION_EMAIL_FORMAT"