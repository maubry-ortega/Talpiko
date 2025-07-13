# tests/backend/core/utils_test.nim
## Pruebas unitarias para el módulo de utilidades de Talpiko

import unittest, json, tables, strutils
import ../../../src/talpiko/backend/core/utils
import ../../../src/talpiko/backend/core/types
import ../../../src/talpiko/backend/core/logging

# Crear un logger de prueba
let testLogger = newTpLogger(TP_DEBUG)

suite "TpUtils Module Tests":
  test "tpParseIntSafe con entrada válida":
    let res = tpParseIntSafe("42", testLogger)
    check res.isOk
    check res.value == 42

  test "tpParseIntSafe con entrada inválida":
    let res = tpParseIntSafe("abc", testLogger)
    check not res.isOk
    check "invalid integer format" in res.errorMsg.toLowerAscii()

  test "tpToJson con datos simples":
    let data = {"key1": "value1", "key2": "value2"}.toTable
    let res = tpToJson(data)
    check res.isOk
    check res.value["key1"].getStr() == "value1"
    check res.value["key2"].getStr() == "value2"

  test "tpFromJson con datos válidos":
    let jsonData = %*{"field1": "test", "field2": "123"}
    type TestType = Table[string, string]
    let res = tpFromJson(jsonData, TestType)
    check res.isOk
    check res.value["field1"] == "test"
    check res.value["field2"] == "123"

  test "tpValidateEmail con email válido":
    let res = tpValidateEmail("user@example.com")
    check res.isOk
    check res.value == "user@example.com"

  test "tpValidateEmail con email inválido":
    let res = tpValidateEmail("invalid-email")
    check not res.isOk
    check "email" in res.errorMsg.toLowerAscii()

  test "tpValidateUrl con URL válida":
    let res = tpValidateUrl("https://example.com")
    check res.isOk
    check res.value == "https://example.com"

  test "tpValidateUrl con URL inválida":
    let res = tpValidateUrl("example.com")
    check not res.isOk
    check "url" in res.errorMsg.toLowerAscii()

  test "tpValidatePhone con teléfono válido":
    let res = tpValidatePhone("12345678")
    check res.isOk
    check res.value == "12345678"

  test "tpValidatePhone con teléfono inválido (caracteres no numéricos)":
    let res = tpValidatePhone("1234abcd")
    check not res.isOk
    check "dígitos" in res.errorMsg.toLowerAscii()

  test "tpValidatePhone con teléfono demasiado corto":
    let res = tpValidatePhone("123")
    check not res.isOk
    check "corto" in res.errorMsg.toLowerAscii()