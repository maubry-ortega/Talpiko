# src/talpiko/backend/core/utils.nim
## Módulo avanzado de utilidades para Talpiko Framework
## 
## Proporciona:
## - Parsing seguro de tipos con manejo de errores
## - Serialización/deserialización JSON robusta
## - Sistema de validación configurable
## - Funciones utilitarias comunes
## 
## Todas las operaciones retornan TpResult para manejo funcional de errores

import strutils, json, tables, std/[parseutils, strformat]
import logging, types
import ./patterns

type
  TpSerializationError* = object of TpResultError
    ## Error especializado para fallos de serialización
    line*: int
    column*: int

  TpValidationError* = object of TpResultError
    ## Error especializado para validaciones fallidas
    validationType*: string
    inputValue*: string

  TpValidationRule* = proc(input: string): TpResult[string] {.closure.}
    ## Tipo para reglas de validación personalizadas

const
  MaxEmailLength* = 254
  MaxUrlLength* = 2048
  MinPhoneLength* = 8

# ----------------------------
# Funciones de parsing seguro
# ----------------------------

proc tpParseIntSafe*(s: string, logger: TpLogger = defaultTpLogger): TpResult[int] =
  ## Parsea un string a entero de forma segura con logging extensivo.
  ## 
  ## Args:
  ##   s: String a parsear
  ##   logger: Logger para registrar el proceso
  ## 
  ## Returns:
  ##   TpResult[int] con el valor parseado o error detallado
  runnableExamples:
    let valid = tpParseIntSafe("42")
    assert valid.isOk and valid.value == 42
    
    let invalid = tpParseIntSafe("abc")
    assert invalid.isError

  logger.tpDebug("Iniciando parsing de entero", {"input": s}.toTable)
  
  let cleaned = s.strip()
  if cleaned.len == 0:
    let msg = "String vacío no puede ser parseado a entero"
    logger.tpError(msg, {"input": s}.toTable)
    return tpErr[int](msg, "TP_PARSE_EMPTY_STRING")

  var result: int
  let parseSuccess = parseSaturatedInt(cleaned, result)
  
  if not parseSuccess:
    let msg = fmt"Formato de entero inválido: '{cleaned}'"
    logger.tpError(msg, {
      "input": s,
      "reason": "No convertible a entero"
    }.toTable)
    return tpErr[int](msg, "TP_PARSE_INVALID_FORMAT")

  logger.tpDebug("Parseo exitoso", {
    "input": s,
    "result": $result
  }.toTable)
  
  tpOk(result)

proc tpParseFloatSafe*(s: string, logger: TpLogger = defaultTpLogger): TpResult[float] =
  ## Parsea un string a float de forma segura con logging extensivo.
  logger.tpDebug("Iniciando parsing de float", {"input": s}.toTable)
  
  let cleaned = s.strip()
  if cleaned.len == 0:
    let msg = "String vacío no puede ser parseado a float"
    logger.tpError(msg, {"input": s}.toTable)
    return tpErr[float](msg, "TP_PARSE_EMPTY_STRING")

  try:
    let value = parseFloat(cleaned)
    logger.tpDebug("Parseo exitoso", {
      "input": s,
      "result": $value
    }.toTable)
    tpOk(value)
  except ValueError:
    let msg = fmt"Formato de float inválido: '{cleaned}'"
    logger.tpError(msg, {
      "input": s,
      "reason": "No convertible a float"
    }.toTable)
    tpErr[float](msg, "TP_PARSE_INVALID_FORMAT")

# ----------------------------
# Funciones de serialización JSON
# ----------------------------

proc tpToJson*[T](value: T, logger: TpLogger = defaultTpLogger): TpResult[JsonNode] =
  ## Serializa un valor genérico a JSON con manejo robusto de errores.
  ## 
  ## Args:
  ##   value: Valor a serializar
  ##   logger: Logger para registrar el proceso
  ## 
  ## Returns:
  ##   TpResult[JsonNode] con el JSON serializado o error detallado
  runnableExamples:
    let data = %*{"name": "Talpiko"}
    let jsonRes = tpToJson(data)
    assert jsonRes.isOk

  logger.tpDebug("Iniciando serialización JSON", {"type": name(type(T))}.toTable)
  
  try:
    let jsonData = %*value
    logger.tpDebug("Serialización exitosa", {
      "type": name(type(T)),
      "sample": $(jsonData.len > 20 ? jsonData[0..20] & "..." : jsonData)
    }.toTable)
    tpOk(jsonData)
  except JsonParsingError as e:
    let msg = fmt"Error de serialización JSON: {e.msg}"
    logger.tpError(msg, {
      "type": name(type(T)),
      "error": e.msg
    }.toTable)
    let serError = TpSerializationError(
      msg: msg,
      line: e.line,
      column: e.column
    )
    tpErr[JsonNode](serError, "TP_SERIALIZATION_ERROR")
  except Exception as e:
    let msg = fmt"Error inesperado en serialización: {e.msg}"
    logger.tpError(msg, {
      "type": name(type(T)),
      "error": e.msg
    }.toTable)
    tpErr[JsonNode](msg, "TP_SERIALIZATION_UNKNOWN_ERROR")

proc tpFromJson*[T](jsonData: JsonNode, targetType: type[T], logger: TpLogger = defaultTpLogger): TpResult[T] =
  ## Deserializa un nodo JSON a un tipo específico con manejo robusto de errores.
  logger.tpDebug("Iniciando deserialización JSON", {
    "targetType": name(targetType),
    "jsonSize": $jsonData.len
  }.toTable)
  
  try:
    let result = jsonData.to(targetType)
    logger.tpDebug("Deserialización exitosa", {
      "targetType": name(targetType)
    }.toTable)
    tpOk(result)
  except JsonParsingError as e:
    let msg = fmt"Error de deserialización JSON: {e.msg}"
    logger.tpError(msg, {
      "targetType": name(targetType),
      "error": e.msg,
      "jsonSample": $(jsonData.len > 20 ? jsonData[0..20] & "..." : jsonData)
    }.toTable)
    let serError = TpSerializationError(
      msg: msg,
      line: e.line,
      column: e.column
    )
    tpErr[T](serError, "TP_DESERIALIZATION_ERROR")
  except Exception as e:
    let msg = fmt"Error inesperado en deserialización: {e.msg}"
    logger.tpError(msg, {
      "targetType": name(targetType),
      "error": e.msg
    }.toTable)
    tpErr[T](msg, "TP_DESERIALIZATION_UNKNOWN_ERROR")

# ----------------------------
# Sistema de Validación Configurable
# ----------------------------

let
  DefaultEmailPattern* = tpCompilePattern("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")
  DefaultUrlPattern* = tpCompilePattern("^https?://[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}/?.*$")

proc tpValidateWithRules*(input: string, rules: openArray[TpValidationRule], logger: TpLogger = defaultTpLogger): TpResult[string] =
  ## Valida un input contra múltiples reglas de validación.
  logger.tpDebug("Iniciando validación con reglas personalizadas", {
    "input": input,
    "ruleCount": $rules.len
  }.toTable)
  
  let cleaned = input.strip()
  for rule in rules:
    let validationResult = rule(cleaned)
    if validationResult.isError:
      logger.tpError("Validación fallida", {
        "input": input,
        "error": validationResult.errorMsg
      }.toTable)
      return validationResult
  
  logger.tpDebug("Validación exitosa", {"input": input}.toTable)
  tpOk(cleaned)

proc tpValidateEmail*(email: string, pattern: TpPattern = DefaultEmailPattern, logger: TpLogger = defaultTpLogger): TpResult[string] =
  ## Valida el formato de un email con reglas estrictas.
  runnableExamples:
    let valid = tpValidateEmail("test@example.com")
    assert valid.isOk
    
    let invalid = tpValidateEmail("invalid.email")
    assert invalid.isError

  logger.tpDebug("Validando email", {"email": email}.toTable)
  
  let cleaned = email.strip()
  
  # Validación de longitud
  if cleaned.len > MaxEmailLength:
    let msg = fmt"Email excede longitud máxima de {MaxEmailLength} caracteres"
    logger.tpError(msg, {
      "email": email,
      "length": $cleaned.len,
      "maxAllowed": $MaxEmailLength
    }.toTable)
    return tpErr[string](msg, "TP_VALIDATION_EMAIL_TOO_LONG")
  
  # Validación de estructura básica
  if cleaned.count('@') != 1:
    let msg = "Email debe contener exactamente un @"
    logger.tpError(msg, {
      "email": email,
      "ats": $cleaned.count('@')
    }.toTable)
    return tpErr[string](msg, "TP_VALIDATION_EMAIL_AT_COUNT")
  
  # Validación con patrón
  if not cleaned.tpMatch(pattern):
    let msg = "Formato de email inválido"
    logger.tpError(msg, {
      "email": email,
      "pattern": pattern.originalPattern
    }.toTable)
    return tpErr[string](msg, "TP_VALIDATION_EMAIL_FORMAT")
  
  # Validación de dominio
  let parts = cleaned.split('@')
  if parts[1].count('.') < 1:
    let msg = "Falta dominio después del @"
    logger.tpError(msg, {"email": email}.toTable)
    return tpErr[string](msg, "TP_VALIDATION_EMAIL_DOMAIN")
  
  logger.tpInfo("Email validado exitosamente", {"email": email}.toTable)
  tpOk(cleaned)

proc tpValidateUrl*(url: string, pattern: TpPattern = DefaultUrlPattern, logger: TpLogger = defaultTpLogger): TpResult[string] =
  ## Valida el formato de una URL con reglas estrictas.
  logger.tpDebug("Validando URL", {"url": url}.toTable)
  
  let cleaned = url.strip()
  
  # Validación de longitud
  if cleaned.len > MaxUrlLength:
    let msg = fmt"URL excede longitud máxima de {MaxUrlLength} caracteres"
    logger.tpError(msg, {
      "url": url,
      "length": $cleaned.len,
      "maxAllowed": $MaxUrlLength
    }.toTable)
    return tpErr[string](msg, "TP_VALIDATION_URL_TOO_LONG")
  
  # Validación de protocolo
  if not (cleaned.startsWith("http://") or cleaned.startsWith("https://")):
    let msg = "URL debe comenzar con http:// o https://"
    logger.tpError(msg, {"url": url}.toTable)
    return tpErr[string](msg, "TP_VALIDATION_URL_PROTOCOL")
  
  # Validación con patrón
  if not cleaned.tpMatch(pattern):
    let msg = "Formato de URL inválido"
    logger.tpError(msg, {
      "url": url,
      "pattern": pattern.originalPattern
    }.toTable)
    return tpErr[string](msg, "TP_VALIDATION_URL_FORMAT")
  
  logger.tpInfo("URL validada exitosamente", {"url": url}.toTable)
  tpOk(cleaned)

proc tpValidatePhone*(phone: string, minLength: int = MinPhoneLength, logger: TpLogger = defaultTpLogger): TpResult[string] =
  ## Valida un número de teléfono con reglas configurables.
  logger.tpDebug("Validando teléfono", {"phone": phone}.toTable)
  
  let cleaned = phone.strip()
  
  # Validación de longitud
  if cleaned.len < minLength:
    let msg = fmt"Teléfono demasiado corto (mínimo {minLength} dígitos)"
    logger.tpError(msg, {
      "phone": phone,
      "length": $cleaned.len,
      "minRequired": $minLength
    }.toTable)
    return tpErr[string](msg, "TP_VALIDATION_PHONE_TOO_SHORT")
  
  # Validación de caracteres
  for ch in cleaned:
    if not ch.isDigit:
      let msg = "Teléfono debe contener solo dígitos"
      logger.tpError(msg, {
        "phone": phone,
        "invalidChar": $ch
      }.toTable)
      return tpErr[string](msg, "TP_VALIDATION_PHONE_INVALID_CHAR")
  
  logger.tpInfo("Teléfono validado exitosamente", {"phone": phone}.toTable)
  tpOk(cleaned)

# ----------------------------
# Funciones adicionales de utilidad
# ----------------------------

proc tpGenerateId*(prefix: string = "", len: int = 16): string =
  ## Genera un ID aleatorio seguro.
  const Chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  var r = initRand()
  result = newStringOfCap(len + prefix.len)
  result.add(prefix)
  for _ in 1..len:
    result.add(Chars[r.rand(Chars.high)])

when isMainModule:
  # Ejemplos de uso
  echo "Ejemplo tpParseIntSafe: ", tpParseIntSafe("123")
  echo "Ejemplo tpValidateEmail: ", tpValidateEmail("test@example.com")
  echo "Ejemplo tpGenerateId: ", tpGenerateId("user_", 8)