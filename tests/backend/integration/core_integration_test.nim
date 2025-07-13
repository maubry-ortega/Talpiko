# tests/backend/integration/core_integration_test.nim
import unittest, tables, strutils
import ../../../src/talpiko/backend/core/logging 
import ../../../src/talpiko/backend/core/types
import ../../../src/talpiko/backend/core/utils
import ../core/utils_test  

suite "Core Module Integration":
  test "Full logging with error handling":
    let logger = createTestTpLogger()
    var errors: seq[string] = @[]
    
    logger.tpAddHandler proc(level: TpLogLevel, msg: string, ctx: Table[string, string], timestamp: string) =
      if level >= TP_ERROR:
        errors.add(msg)

    let res = tpParseIntSafe("not_a_number", logger)
    check not res.isOk  # Cambiado de tpIsError() a not isOk
    check errors.len == 1
    check "Invalid integer format" in errors[0]

  test "JSON serialization with logging":
    let logger = createTestTpLogger()
    var logs: seq[string] = @[]
    logger.tpAddHandler proc(level: TpLogLevel, msg: string, ctx: Table[string, string], timestamp: string) =
      logs.add(msg)
    
    let data = %*{"name": "Talpo", "age": 3}
    let res = tpToJson(data)
    check res.isOk
    check res.value == data
    check logs.len >= 1

  test "Email validation with error handling":
    let logger = createTestTpLogger()
    var errors: seq[string] = @[]
    logger.tpAddHandler proc(level: TpLogLevel, msg: string, ctx: Table[string, string], timestamp: string) =
      if level >= TP_ERROR:
        errors.add(msg)
    
    let res = tpValidateEmail("invalid_email")
    check not res.isOk  # Cambiado de tpIsError() a not isOk
    check errors.len == 1
    check "email" in errors[0].toLowerAscii()