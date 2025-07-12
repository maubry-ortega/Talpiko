# src/talpiko/backend/core/utils.nim
## Módulo de utilidades para Talpiko Framework
## Proporciona funciones para parsing seguro, serialización JSON y validaciones.

import strutils, json, tables
import logging, types
import ./patterns

type
  TpSerializationError* = object of TpResultError
    ## Excepción para errores de serialización
  TpValidationError* = object of TpResultError
    ## Excepción para errores de validación

# ----------------------------
# Funciones de parsing seguro
# ----------------------------
proc tpParseIntSafe*(s: string, logger: TpLogger = defaultTpLogger): TpResult[int] =
  ## Parsea un string a entero de forma segura con logging.
  logger.tpDebug("Parsing integer", {"input": s}.toTable)
  try:
    let value = parseInt(s.strip())
    logger.tpDebug("Parse successful", {"value": $value}.toTable)
    tpOk(value)
  except ValueError:
    let msg = "Invalid integer format: " & s
    logger.tpError(msg, {"input": s}.toTable)
    tpErr[int](msg, "TP_PARSE_ERROR")

# ----------------------------
# Funciones de serialización JSON
# ----------------------------
proc tpToJson*[T](value: T): TpResult[JsonNode] =
  ## Serializa un valor genérico a JSON.
  try:
    tpOk(%*value)
  except JsonParsingError as e:
    tpErr[JsonNode](e.msg, "TP_SERIALIZATION_ERROR")

proc tpFromJson*[T](json: JsonNode, _: type[T]): TpResult[T] =
  ## Deserializa un nodo JSON a un tipo genérico.
  try:
    tpOk(json.to(T))
  except JsonParsingError as e:
    tpErr[T](e.msg, "TP_DESERIALIZATION_ERROR")

# ----------------------------
# Funciones de validación (usando nuestro sistema de patrones)
# ----------------------------
proc tpValidateEmail*(email: string): TpResult[string] =
  ## Valida el formato de un email con nuestro sistema de patrones.
  let emailPattern = tpCompilePattern("*@*.*")  # Cambiado de const a let
  let cleaned = email.strip()
  
  # Validaciones adicionales para mejorar la precisión
  if cleaned.count('@') != 1:
    return tpErr[string]("Email debe contener exactamente un @", "TP_VALIDATION_ERROR")
  
  if not cleaned.tpMatch(emailPattern):
    return tpErr[string]("Formato de email inválido", "TP_VALIDATION_ERROR")
  
  let parts = cleaned.split('@')
  if parts[1].count('.') < 1:
    return tpErr[string]("Falta dominio después del @", "TP_VALIDATION_ERROR")
  
  if cleaned.len > 254:
    return tpErr[string]("Email demasiado largo", "TP_VALIDATION_ERROR")
  
  tpOk(cleaned)

proc tpValidateUrl*(url: string): TpResult[string] =
  ## Valida el formato básico de una URL.
  let urlPattern = tpCompilePattern("http*://*.*")  # Cambiado de const a let
  let cleaned = url.strip()
  
  if not cleaned.tpMatch(urlPattern):
    return tpErr[string]("Formato de URL inválido", "TP_VALIDATION_ERROR")
  
  if cleaned.len > 2048:
    return tpErr[string]("URL demasiado larga", "TP_VALIDATION_ERROR")
  
  if not (cleaned.startsWith("http://") or cleaned.startsWith("https://")):
    return tpErr[string]("URL debe comenzar con http:// o https://", "TP_VALIDATION_ERROR")
  
  tpOk(cleaned)

# ----------------------------
# Funciones adicionales de utilidad
# ----------------------------
proc tpValidatePhone*(phone: string): TpResult[string] =
  ## Valida un número de teléfono básico (solo dígitos, longitud mínima)
  let cleaned = phone.strip()
  if cleaned.len < 8:
    return tpErr[string]("Teléfono demasiado corto", "TP_VALIDATION_ERROR")
  
  for ch in cleaned:
    if not ch.isDigit:
      return tpErr[string]("Teléfono debe contener solo dígitos", "TP_VALIDATION_ERROR")
  
  tpOk(cleaned)