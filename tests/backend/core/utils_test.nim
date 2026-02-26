# tests/backend/core/utils_test.nim
import unittest, json
import ../../../src/talpiko/backend/core/utils
import ../../../src/talpiko/backend/core/types
import ../core/test_utils

suite "TpUtils Tests":
  test "Integer parsing safely returns Ok":
    let logger = createTestTpLogger()
    let res = tpParseIntSafe("42", logger)
    check res.isOk
    check res.value == 42

  test "Integer parsing with invalid format returns Err":
    let logger = createTestTpLogger()
    let res = tpParseIntSafe("invalid", logger)
    check res.tpIsError()

  test "JSON serialization and deserialization":
    let logger = createTestTpLogger()
    
    type Person = object
      name: string
      age: int
      
    let p = Person(name: "Talpo", age: 5)
    let jsonRes = tpToJson(p, logger)
    check jsonRes.isOk
    
    let parsedRes = tpFromJson(jsonRes.value, Person, logger)
    check parsedRes.isOk
    check parsedRes.value.name == "Talpo"
    check parsedRes.value.age == 5

  test "Email validation handles valid emails":
    let logger = createTestTpLogger()
    let res = tpValidateEmail("user@example.com", logger)
    check res.isOk
    check res.value == "user@example.com"

  test "Email validation catches missing @":
    let logger = createTestTpLogger()
    let res = tpValidateEmail("userexample.com", logger)
    check res.tpIsError()

  test "URL validation handles valid URLs":
    let res = tpValidateUrl("https://github.com/maubry-ortega/talpiko")
    check res.isOk

  test "URL validation catches missing schemes":
    let res = tpValidateUrl("github.com")
    check res.tpIsError()

  test "Phone validation handles valid phones":
    let res = tpValidatePhone("1234567890")
    check res.isOk
    
  test "Phone validation catches too short and letters":
    check tpValidatePhone("123").tpIsError()
    check tpValidatePhone("12345678a").tpIsError()
