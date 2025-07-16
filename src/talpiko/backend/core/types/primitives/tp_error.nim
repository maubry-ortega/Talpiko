## 📄 tp_error.nim
##
## 📌 Módulo: Error Enriquecido para TpResult
## 📦 Parte del sistema de tipos de Talpo / Talpiko
##
## 🎯 Responsabilidad:
##   Define el tipo `TpResultError`, un error estructurado y enriquecido con
##   metadatos útiles para diagnóstico, trazabilidad, y reporting.
##
## 🔍 Características clave:
## - Tipado fuerte (`object`) y versionado explícito
## - Incluye mensaje, código, severidad, contexto y traza
## - Soporta origen original (`ref Exception`)
## - Dos constructores: valor (stack local) y `ref` (para `TpResult`)
## - Exporta conversión a JSON para serialización

import std/[times, tables, json]
import ./tp_interfaces

# ─────────────────────────────────────────────────────────────────────────────
# ⚙️ Configuración de Compilación
# ─────────────────────────────────────────────────────────────────────────────

when defined(release):
  {.push checks: off.}
else:
  {.push stackTrace: on, checks: on.}

# ─────────────────────────────────────────────────────────────────────────────
# 📦 Tipo Principal de Error Enriquecido
# ─────────────────────────────────────────────────────────────────────────────

type
  TpResultError* = object
    ## Error enriquecido usado en la monada `TpResult[T]`
    ##
    ## Campos exportables:
    ## - `timestamp`: Marca de tiempo UNIX en segundos
    ## - `stackTrace`: Traza completa del punto de error
    ## - `msg`: Mensaje descriptivo del error
    ## - `code`: Código de error estándar del sistema
    ## - `severity`: Severidad tipada (`low`, `medium`, `high`, `critical`)
    ## - `context`: Diccionario con contexto adicional
    ## - `originalException`: Excepción original si aplica (usada internamente)
    timestamp*: float64
    stackTrace*: string
    msg*: string
    code*: string
    severity*: TpErrorSeverity
    context*: Table[string, string]
    originalException*: ref Exception

# ─────────────────────────────────────────────────────────────────────────────
# 🧱 Constantes del Sistema de Error
# ─────────────────────────────────────────────────────────────────────────────

const MaxErrorContextSize* = 32
  ## Límite máximo de entradas en el campo `context` para evitar overflow

# ─────────────────────────────────────────────────────────────────────────────
# 🛠️ Constructores de Errores
# ─────────────────────────────────────────────────────────────────────────────

proc newTpResultError*(
  msg: string,
  code: string = "TP_UNKNOWN",
  severity: TpErrorSeverity = tpMedium,
  context: Table[string, string] = initTable[string, string](),
  original: ref Exception = nil
): TpResultError =
  ## 🔧 Constructor de error por valor (sin `ref`)
  ##
  ## Uso recomendado para pruebas o cuando no se necesita compatibilidad con `TpResult`
  ##
  ## Argumentos:
  ## - `msg`: mensaje de error
  ## - `code`: código de error (por defecto: "TP_UNKNOWN")
  ## - `severity`: nivel de severidad del error
  ## - `context`: metadatos adicionales (clave-valor)
  ## - `original`: excepción original capturada
  ##
  ## Retorna:
  ## - Instancia local de `TpResultError` (por valor)
  result.timestamp = epochTime()
  result.stackTrace = getStackTrace()
  result.msg = msg
  result.code = code
  result.severity = severity
  result.originalException = original
  result.context = initTable[string, string]()

  if context.len > 0:
    for k, v in context.pairs:
      if result.context.len < MaxErrorContextSize:
        result.context[k] = v
      else:
        result.msg.add(" [CONTEXT_TRUNCATED]")
        break

proc newTpResultErrorRef*(
  msg: string,
  code: string = "TP_UNKNOWN",
  severity: TpErrorSeverity = tpMedium,
  context: Table[string, string] = initTable[string, string](),
  original: ref Exception = nil
): ref TpResultError =
  ## 🔧 Constructor seguro que devuelve `ref TpResultError`
  ##
  ## Ideal para operaciones que devuelven errores dentro de `TpResult[T]`.
  ## Usa asignación de bajo nivel para evitar `new()` (que da errores con Nim 2.2.4).
  ##
  ## Retorna:
  ## - Referencia heap-safe de `TpResultError` (`ref`)
  var errorObj: TpResultError = newTpResultError(msg, code, severity, context, original)
  result = cast[ref TpResultError](alloc0(sizeof(TpResultError)))
  copyMem(addr(result[]), addr(errorObj), sizeof(TpResultError))

# ─────────────────────────────────────────────────────────────────────────────
# 🔁 Serialización a JSON
# ─────────────────────────────────────────────────────────────────────────────

proc toJson*(err: TpResultError): JsonNode =
  ## 🔄 Convierte el error a un objeto JSON para exportación o log remoto.
  ##
  ## Campos incluidos:
  ## - `timestamp`, `msg`, `code`, `severity`
  %*{
    "timestamp": err.timestamp,
    "msg": err.msg,
    "code": err.code,
    "severity": $err.severity
  }

{.pop.}