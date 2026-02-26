# tests/backend/core/logging_test.nim
## Tests para el módulo de logging de Talpiko Framework

import unittest

when defined(useFileLogging):
  import os, strutils
import ../../../src/talpiko/backend/core/logging

suite "TpLogging Module Tests":
  test "Logger creation":
    let logger = newTpLogger(tpllDebug)
    check logger.level == tpllDebug

    check logger.handlers.len == 0
    check logger.context.len == 0

  test "Log level filtering":
    var messages: seq[string] = @[]
    let logger = newTpLogger(tpllInfo)

    logger.tpAddHandler proc(level: TpLogLevel, msg: string, ctx: seq[(string, string)], timestamp: string) {.gcsafe.} =
      {.cast(gcsafe).}:
        messages.add(msg)
    
    logger.tpDebug("Debug message")
    logger.tpInfo("Info message")
    logger.tpWarn("Warn message")
    
    check messages.len == 2
    check "Info message" in messages
    check "Warn message" in messages

  test "Default logger":
    check defaultTpLogger != nil
    check defaultTpLogger.level == tpllInfo

    check defaultTpLogger.handlers.len == 1

  when defined(useFileLogging):
    test "Multiple handlers":
      var consoleMessages: seq[string] = @[]
      let logger = newTpLogger(tpllDebug)

      logger.tpAddHandler proc(level: TpLogLevel, msg: string, ctx: seq[(string, string)], timestamp: string) {.gcsafe.} =
        {.cast(gcsafe).}:
          consoleMessages.add(msg)
      logger.tpAddHandler tpFileHandler("test.log")
      
      logger.tpDebug("Test message")
      check consoleMessages.len == 1
      check consoleMessages[0] == "Test message"
      check fileExists("test.log")
      
      let content = readFile("test.log")
      let lines = content.splitLines()
      check lines.len >= 1
      check "Test message" in lines[0]
      
      if fileExists("test.log"):
        removeFile("test.log")

    test "File handler error handling":
      var consoleMessages: seq[string] = @[]
      let logger = newTpLogger(tpllDebug)

      logger.tpAddHandler proc(level: TpLogLevel, msg: string, ctx: seq[(string, string)], timestamp: string) {.gcsafe.} =
        {.cast(gcsafe).}:
          consoleMessages.add(msg)
      logger.tpAddHandler tpFileHandler("/invalid/path/test.log")
      
      logger.tpDebug("Test message")
      check consoleMessages.len == 1
      check consoleMessages[0] == "Test message"
      check not fileExists("/invalid/path/test.log")