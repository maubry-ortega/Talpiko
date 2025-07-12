# tests/backend/core_test.nim
import unittest, strutils
import ../../src/talpiko/backend/core/[logging, types, utils]
import ../../src/talpiko/backend/core/di/container
import ../../src/talpiko/backend/core/config/env_loader

suite "Core Module Tests":
  setup:
    var testLogger = newLogger(DEBUG)
    testLogger.addHandler(proc(level: LogLevel, msg: string, ctx: Table[string, string]) =
      echo "[TEST] ", msg
    )

  test "Logger System":
    var logMessages: seq[string] = @[]
    let testHandler = proc(level: LogLevel, msg: string, ctx: Table[string, string]) =
      logMessages.add(msg)
    
    let logger = newLogger(DEBUG)
    logger.addHandler(testHandler)
    
    logger.debug("Debug message")
    logger.info("Info message")
    logger.log(ERROR, "Error message")
    
    check logMessages.len == 3
    check "Debug message" in logMessages
    check "Error message" in logMessages

  test "Result Type Monad":
    let success = ok(42)
    check success.isOk
    check success.value == 42
    
    let failure = err[int]("Test error", "TEST_CODE")
    check not failure.isOk
    check failure.errorMsg == "Test error"
    check failure.errorCode == "TEST_CODE"
    
    # Test monadic operations
    let res = success >>= proc(x: int): Result[string] = ok($x)
    check res.isOk
    check res.value == "42"

  test "Utilities":
    block: # parseIntSafe
      let valid = parseIntSafe("42", testLogger)
      check valid.isOk
      check valid.value == 42
      
      let invalid = parseIntSafe("abc", testLogger)
      check not invalid.isOk
      check invalid.errorCode == "PARSE_ERROR"
    
    block: # JSON Serialization
      let data = %*{"name": "Talpo", "age": 3}
      let parsed = fromJson(data, type(Table[string, JsonNode]))
      check parsed.isOk
      check parsed.value["name"].getStr == "Talpo"

  test "Dependency Injection":
    var container = newServiceContainer()
    
    container.register[Logger, Logger]()
    container.register[File, File](Transient)
    
    let loggerService = container.resolve[Logger]()
    check loggerService of Logger
    
    let fileService1 = container.resolve[File]()
    let fileService2 = container.resolve[File]()
    check fileService1 != fileService2  # Transient creates new instances

  test "Configuration Loading":
    writeFile("test.env", """
    DB_HOST=localhost
    DB_PORT=5432
    # COMMENTED=value
    """)
    
    let loadResult = loadEnv("test.env", testLogger)
    check loadResult.isOk
    check getEnv("DB_HOST") == "localhost"
    check getEnv("DB_PORT") == "5432"
    check getEnv("COMMENTED") == ""
    
    removeFile("test.env")

  test "Error Handling":
    let result = tryOr[int]:
      raise newException(ValueError, "Test error")
    do (e: ref Exception):
      err[int](e)
    
    check not result.isOk
    check result.errorMsg == "Test error"

suite "Integration Tests":
  test "Logger with Result Integration":
    let logger = newLogger(INFO)
    var errorMessages: seq[string] = @[]
    
    logger.addHandler proc(level: LogLevel, msg: string, ctx: Table[string, string]) =
      if level == ERROR:
        errorMessages.add(msg)
    
    let operation = proc(): Result[int] =
      let parsed = parseIntSafe("invalid", logger)
      if not parsed.isOk:
        logger.error("Parse failed", {"input": "invalid"}.toTable)
      parsed
    
    let res = operation()
    check not res.isOk
    check errorMessages.len == 1
    check "Parse failed" in errorMessages[0]

when isMainModule:
  unittest.run()