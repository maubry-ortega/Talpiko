## tap.nim
##
## Módulo: tpTap
## Sistema: Talpo / Talpiko - TpResult Operations
##
## Responsabilidad:
##   Permitir la ejecución de lógica colateral (logging, tracing, side-effects)
##   sin modificar el resultado original, conservando la semántica funcional.
##
## Características:
## - No altera el flujo de datos
## - Compatibilidad con async/logging
## - Útil para debugging, métricas y observabilidad

import ../primitives/[tp_result, tp_error]

proc tpTap*[T](res: TpResult[T], sideEffect: proc(x: T): void) : TpResult[T] {.inline.} =
  ## Ejecuta una acción colateral si el resultado es exitoso
  ##
  ## Seguridad:
  ## - No altera el valor ni el estado de `res`
  ## - Solo ejecuta `sideEffect` si es `tpSuccess`
  if res.tpIsSuccess():
    sideEffect(res.value)
  res

proc tpTapError*[T](res: TpResult[T], sideEffect: proc(err: ref TpResultError): void): TpResult[T] {.inline.} =
  ## Ejecuta una acción colateral si el resultado es un error
  ##
  ## Uso común:
  ## - Logging de errores
  ## - Registro en tracing distribuido
  if res.tpIsFailure():
    sideEffect(res.error)
  res
