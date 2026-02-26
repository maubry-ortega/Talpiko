import unittest, json, strutils

import ../../../src/talpiko/backend/core/logging
import ../../../src/talpiko/backend/core/types
import ../../../src/talpiko/backend/core/utils
import ../core/test_utils

suite "Core Module Integration":
  test "Full logging with error handling":
    let logger = createTestTpLogger()
    var errors: seq[string] = @[]
    
    logger.tpAddHandler proc(level: TpLogLevel, msg: string, ctx: seq[(string, string)], timestamp: string) {.gcsafe.} =

      {.cast(gcsafe).}:
        if level >= tpllError:
          errors.add(msg)

    let res = tpParseIntSafe("not_a_number", logger)
    check res.tpIsError()
    check errors.len == 1
    check errors[0] == "Invalid integer format: not_a_number"

  test "JSON serialization with logging":
    let logger = createTestTpLogger()
    var logs: seq[string] = @[]
    logger.tpAddHandler proc(level: TpLogLevel, msg: string, ctx: seq[(string, string)], timestamp: string) {.gcsafe.} =

      {.cast(gcsafe).}:
        logs.add(msg)
    
    let data = %*{"name": "Talpo", "age": 3}
    let res = tpToJson(data, logger)
    check res.isOk
    check res.value == data
    check logs.len >= 1

  test "Email validation with error handling":
    let logger = createTestTpLogger()
    var errors: seq[string] = @[]
    logger.tpAddHandler proc(level: TpLogLevel, msg: string, ctx: seq[(string, string)], timestamp: string) {.gcsafe.} =

      {.cast(gcsafe).}:
        if level >= tpllError:
          errors.add(msg)
    
    let res = tpValidateEmail("invalid_email", logger)
    check res.tpIsError()
    check errors.len >= 1
    check errors[0].startsWith("Invalid email format")