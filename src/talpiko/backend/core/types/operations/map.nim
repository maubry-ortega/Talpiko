## map.nim
##
## Módulo: Transformaciones Monádicas
## Sistema: Talpo / Talpiko - Result Monad
##
## Responsabilidad:
##   Este módulo define funciones de transformación (`map`, `mapError`) para
##   resultados de tipo `TpResult[T]`, siguiendo el estilo funcional de Rust/Elm.
##
## Características Clave:
## - Aplica transformaciones al valor si es éxito (`tpMap`)
## - Transforma error sin tocar el valor (`tpMapError`)
## - Compatibles con operaciones chainable (`>>=`, `andThen`)
## - Inlineadas y sin impacto en el happy path
##
## Requiere:
## - `TpResult`, `TpResultError`

import ../primitives/[tp_result, tp_error, tp_interfaces]
import std/tables

when defined(release):
  {.push checks: off.}
else:
  {.push stackTrace: on.}

# ─────────────────────────────────────────────────────────────────────────────
# 🔁 tpMap: Mapea el valor si es éxito
# ─────────────────────────────────────────────────────────────────────────────

proc tpMap*[T, R](
  res: TpResult[T],
  f: proc(x: T): R {.noSideEffect.}
): TpResult[R] {.inline.} =
  ## Transforma el valor si el resultado es éxito, deja error intacto
  ##
  ## Características:
  ## - Seguro y sin efectos colaterales
  ## - Compatible con composición funcional
  ##
  ## Ejemplo:
  ## ```nim
  ## let r = tpOk(2)
  ## let r2 = r.tpMap(proc(x: int): string = $x)
  ## ```
  if res.tpIsSuccess():
    TpResult[R](kind: tpSuccessKind, value: f(res.tpUnsafeGet()))
  else:
    TpResult[R](kind: tpFailureKind, error: res.error)

# ─────────────────────────────────────────────────────────────────────────────
# 🚨 tpMapError: Mapea el error si es fallo
# ─────────────────────────────────────────────────────────────────────────────

proc tpMapError*[T](
  res: TpResult[T],
  f: proc(e: ref TpResultError): ref TpResultError {.noSideEffect.}
): TpResult[T] {.inline.} =
  ## Transforma el error si el resultado es fallo, deja valor intacto
  ##
  ## Útil para:
  ## - Agregar más contexto
  ## - Cambiar código de error
  ## - Envolver o traducir errores
  ##
  ## Ejemplo:
  ## ```nim
  ## let r = someFailingOp()
  ## let r2 = r.tpMapError(proc(e) = newTpResultError("envuelto: " & e.msg))
  ## ```
  if res.tpIsFailure():
    TpResult[T](kind: tpFailureKind, error: f(res.error))
  else:
    res
