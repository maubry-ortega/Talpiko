# tests/test_suite.nim
import ../src/talpiko/logging/logger
import ../src/talpiko/utils/core

proc testLoggerCreation() =
  let logger = newLogger("DEBUG")
  assert logger.level == "DEBUG"
  logger.log("Prueba de logger iniciada a las 11:54 AM")

proc testResultCreation() =
  let success = createResult[int](true, 42)
  assert success.isOk and success.value == 42
  let failure = createResult[int](false, error = "Test error")
  assert not failure.isOk and failure.error == "Test error"

proc testParseIntSafe() =
  let logger = newLogger("INFO")
  let valid = parseIntSafe("42", logger)
  assert valid.isOk and valid.value == 42
  let invalid = parseIntSafe("abc", logger)
  assert not invalid.isOk and invalid.error == "Invalid integer"

when isMainModule:
  testLoggerCreation()
  testResultCreation()
  testParseIntSafe()
  echo "Todos los tests pasaron exitosamente!"