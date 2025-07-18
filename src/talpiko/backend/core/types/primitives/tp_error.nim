## 📄 tp_error.nim
##
## 📌 Módulo: Error Enriquecido para TpResult
## 📦 Parte del sistema de tipos de Talpo / Talpiko
##
## 🎯 Define `TpResultError`, error estructurado para trazabilidad y control
##
## 🧠 Integración completa con JSON, metadatos y error original

import std/[times, tables, json]
import ./tp_interfaces
import ../memory/tp_boxing

# ─────────────────────────────────────────────────────────────────────────────
# 🔧 Compilación
# ─────────────────────────────────────────────────────────────────────────────

when defined(release):
  {.push checks: off.}
else:
  {.push stackTrace: on, checks: on.}

# ─────────────────────────────────────────────────────────────────────────────
# 📦 Tipo principal
# ─────────────────────────────────────────────────────────────────────────────

type
  TpResultError* = object
    ## Error enriquecido usado en `TpResult[T]`
    timestamp*: float64
    stackTrace*: string
    msg*: string
    code*: string
    severity*: TpErrorSeverity
    context*: Table[string, string]
    originalException*: ref Exception

const MaxErrorContextSize* = 32

# ─────────────────────────────────────────────────────────────────────────────
# 🛠️ Constructores
# ─────────────────────────────────────────────────────────────────────────────

proc newTpResultError*(
  msg: string,
  code: string = "TP_UNKNOWN",
  severity: TpErrorSeverity = tpMedium,
  context: Table[string, string] = initTable[string, string](),
  original: ref Exception = nil
): TpResultError =
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
  ## 🚀 Usa `box` para inicialización manual y segura (heap-safe, sin GC)
  box[TpResultError]:
    it.timestamp = epochTime()
    it.stackTrace = getStackTrace()
    it.msg = msg
    it.code = code
    it.severity = severity
    it.originalException = original
    it.context = initTable[string, string]()

    if context.len > 0:
      for k, v in context.pairs:
        if it.context.len < MaxErrorContextSize:
          it.context[k] = v
        else:
          it.msg.add(" [CONTEXT_TRUNCATED]")
          break

# ─────────────────────────────────────────────────────────────────────────────
# 🔁 Serialización
# ─────────────────────────────────────────────────────────────────────────────

proc toJson*(err: TpResultError): JsonNode =
  %*{
    "timestamp": err.timestamp,
    "msg": err.msg,
    "code": err.code,
    "severity": $err.severity
  }

{.pop.}
