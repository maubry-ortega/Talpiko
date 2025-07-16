## tp_failure.nim
## Versión corregida con manejo seguro de errores

import ../primitives/[tp_result, tp_error, tp_interfaces]
import std/[tables, times]

when defined(release):
  {.push checks: off.}
else:
  {.push stackTrace: on.}

proc tpErr*[T](
  msg: string,
  code: string = tpDefaultErrorCode,
  severity: TpErrorSeverity = tpMedium,
  context: Table[string, string] = initTable[string, string](),
  original: ref Exception = nil
): TpResult[T] =
  ## Constructor seguro con manejo de errores
  var errorObj: ref TpResultError = nil
  try:
    errorObj = newTpResultError(msg, code, severity, context, contextPassed = true, original = original)
    if errorObj.isNil:
      echo "Error: newTpResultError returned nil"
      raise newException(Exception, "newTpResultError returned nil")
  except Exception as e:
    # Fallback extremo si falla la creación del error
    echo "Error creating error: " & e.msg
    errorObj = newTpResultError(
      "Error creating error: " & e.msg,
      "TP_ERROR_FAILURE",
      tpCritical
    )

  TpResult[T](
    kind: tpFailure,
    error: errorObj,
    metadata: TpResultMetadata(creationTime: epochTime())
  )

template tpFailure*[T](
  msg: string,
  code: string = tpDefaultErrorCode,
  severity: TpErrorSeverity = tpMedium,
  context: Table[string, string] = initTable[string, string](),
  original: ref Exception = nil
): TpResult[T] =
  tpErr[T](msg, code, severity, context, original)

{.pop.}