# src/talpiko/backend/core/utils.nim
## Módulo de utilidades para Talpiko Framework
## Proporciona funciones para parsing seguro, serialización JSON y validaciones.

import json, tables, strutils, logging, types
import ./patterns

# Los tipos de error ahora se manejan vía TpErrorCode en TpResult.


# ----------------------------
# Funciones de parsing seguro
# ----------------------------
proc tpParseIntSafe*(s: string, logger: TpLogger = defaultTpLogger): TpResult[int] =
  ## Parsea un string a entero de forma segura con logging.
  logger.tpDebug("Parsing integer", {"input": s})
  try:
    let value = parseInt(s.strip())
    logger.tpDebug("Parse successful", {"value": $value})
    tpOk(value)
  except ValueError:
    let msg = "Invalid integer format: " & s
    logger.tpError(msg, {"input": s})
    tpErr[int](msg, tpecParseError)

# ----------------------------
# Funciones de serialización JSON
# ----------------------------
proc tpToJson*[T](value: T, logger: TpLogger = defaultTpLogger): TpResult[JsonNode] =
  ## Serializa un valor genérico a JSON.
  try:
    let node = %*value
    logger.tpDebug("Serialized to JSON", {"type": $typeof(value)})
    tpOk(node)
  except JsonParsingError as e:
    logger.tpError("JSON serialization error", {"msg": e.msg})
    tpErr[JsonNode](e.msg, tpecSerializationError)

proc tpFromJson*[T](json: JsonNode, _: type[T], logger: TpLogger = defaultTpLogger): TpResult[T] =
  ## Deserializa un nodo JSON a un tipo genérico.
  try:
    let val = json.to(T)
    logger.tpDebug("Deserialized from JSON", {"type": $T})
    tpOk(val)
  except JsonParsingError as e:
    logger.tpError("JSON deserialization error", {"msg": e.msg})
    tpErr[T](e.msg, tpecDeserializationError)

# ----------------------------
# Funciones de validación (usando nuestro sistema de patrones)
# ----------------------------
proc tpValidateEmail*(email: string, logger: TpLogger = defaultTpLogger): TpResult[string] =
  ## Valida el formato de un email con nuestro sistema de patrones.
  let emailPattern = tpCompilePattern("*@*.*")
  let cleaned = email.strip()
  
  # Validaciones adicionales para mejorar la precisión
  if cleaned.count('@') != 1:
    logger.tpError("Invalid email format (count @ != 1): " & cleaned, {"input": cleaned})
    return tpErr[string]("Email debe contener exactamente un @", tpecValidationError)
  
  if not cleaned.tpMatch(emailPattern):
    logger.tpError("Invalid email format (pattern mismatch): " & cleaned, {"input": cleaned})
    return tpErr[string]("Formato de email inválido", tpecValidationError)
  
  let parts = cleaned.split('@')
  if parts[1].count('.') < 1:
    return tpErr[string]("Falta dominio después del @", tpecValidationError)
  
  if cleaned.len > 254:
    return tpErr[string]("Email demasiado largo", tpecValidationError)
  
  tpOk(cleaned)

proc tpValidateUrl*(url: string): TpResult[string] =
  ## Valida el formato básico de una URL.
  let urlPattern = tpCompilePattern("http*://*.*")
  let cleaned = url.strip()
  
  if not cleaned.tpMatch(urlPattern):
    return tpErr[string]("Formato de URL inválido", tpecValidationError)
  
  if cleaned.len > 2048:
    return tpErr[string]("URL demasiado larga", tpecValidationError)
  
  if not (cleaned.startsWith("http://") or cleaned.startsWith("https://")):
    return tpErr[string]("URL debe comenzar con http:// o https://", tpecValidationError)
  
  tpOk(cleaned)

# ----------------------------
# Funciones adicionales de utilidad
# ----------------------------
proc tpValidatePhone*(phone: string): TpResult[string] =
  ## Valida un número de teléfono básico (solo dígitos, longitud mínima)
  let cleaned = phone.strip()
  if cleaned.len < 8:
    return tpErr[string]("Teléfono demasiado corto", tpecValidationError)
  
  for ch in cleaned:
    if not ch.isDigit:
      return tpErr[string]("Teléfono debe contener solo dígitos", tpecValidationError)
  
  tpOk(cleaned)

# ----------------------------
# Utilidades Web
# ----------------------------
proc tpParseQuery*(url: string): Table[string, string] =
  ## Extrae query params de una url (/ruta?a=1&b=2).
  ## Escaneo lineal con aritmética de índices sobre `url` — sin split intermedio.
  result = initTable[string, string]()
  var qi = url.find('?')
  if qi < 0: return
  inc qi  # skip '?'
  let n = url.len
  var i = qi
  while i < n:
    # Find '=' separator
    var j = i
    while j < n and url[j] != '=' and url[j] != '&': inc j
    if j >= n or url[j] != '=': break
    let key = url[i ..< j]
    inc j  # skip '='
    # Find '&' or end
    var k = j
    while k < n and url[k] != '&': inc k
    let val = url[j ..< k]
    if key.len > 0:
      result[key] = val
    i = k + 1  # skip '&'

proc tpParseHttpMethod*(s: string): TpHttpMethod =
  ## Convierte string HTTPMethod a enum TpHttpMethod.
  ## Usa comparación directa de bytes — sin toUpperAscii, sin alloc.
  if s.len == 3:
    if s[0] == 'G': return HttpGet   # GET
    if s[0] == 'P': return HttpPut   # PUT
  elif s.len == 4:
    if s[0] == 'P': return HttpPost  # POST  (len=4 vs PUT len=3)
    if s[0] == 'H': return HttpHead  # HEAD
  elif s.len == 5:
    if s[0] == 'P': return HttpPatch # PATCH
  elif s.len == 6:
    if s[0] == 'D': return HttpDelete  # DELETE
    if s[0] == 'O': return HttpOptions # OPTIONS... fallthrough to len==7
  elif s.len == 7:
    if s[0] == 'O': return HttpOptions
  return HttpGet  # fallback

# ----------------------------
# Serialización Estática (Phase 4)
# ----------------------------
template tpBindBody*[T](ctx: TpContext, _: type[T]): TpResult[T] =
  ## Enlaza el cuerpo de la petición directamente a un objeto de tipo T.
  ## Favorece la seguridad de tipos y el rendimiento.
  try:
    if ctx.req.body == "":
      tpErr[T]("Cuerpo de petición vacío", tpecValidationError)
    else:
      # Usamos json.to(T) que es eficiente en Nim 2.x
      let node = parseJson(ctx.req.body)
      tpOk(node.to(T))
  except CatchableError as e:
    tpErr[T]("Error de binding: " & e.msg, tpecValidationError)