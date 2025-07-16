## tp_error.nim
## Versión corregida con manejo seguro de memoria

import std/[times, tables, json]
import ./tp_interfaces

when defined(release):
  {.push checks: off.}
else:
  {.push stackTrace: on, checks: on.}

type
  TpResultError* = ref object of RootObj
    timestamp*: float64
    stackTrace*: string
    msg*: string
    code*: string
    severity*: TpErrorSeverity
    context*: Table[string, string]
    originalException*: ref Exception

const MaxErrorContextSize* = 32

proc newTpResultError*(
  msg: string,
  code: string = "TP_UNKNOWN",
  severity: TpErrorSeverity = tpMedium,
  context: Table[string, string] = initTable[string, string](),
  contextPassed: bool = false,
  original: ref Exception = nil
): ref TpResultError =
  ## Constructor seguro con verificación de nil
  new(result)
  if result.isNil:
    echo "Error: Failed to allocate TpResultError"
    raise newException(Exception, "Failed to allocate TpResultError")

  # Inicialización segura
  result.timestamp = 0.0
  result.stackTrace = ""
  result.msg = msg
  result.code = code
  result.severity = severity
  result.originalException = original
  result.context = initTable[string, string]()

  # Manejo seguro del contexto
  if contextPassed:
    try:
      for k, v in context.pairs:
        if result.context.len < MaxErrorContextSize:
          result.context[k] = v
        else:
          result.msg.add(" [CONTEXT_TRUNCATED]")
          break
    except Exception as e:
      result.msg.add(" [CONTEXT_ERROR: " & e.msg & "]")

proc toJson*(err: TpResultError): JsonNode =
  if err.isNil: return %*{"error": "nil"}
  %*{
    "timestamp": err.timestamp,
    "msg": err.msg,
    "code": err.code,
    "severity": $err.severity
  }

{.pop.}