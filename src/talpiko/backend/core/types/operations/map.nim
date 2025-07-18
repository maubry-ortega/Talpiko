## map.nim
##
## 📦 Módulo: Transformaciones Monádicas para TpResult
## 🔧 Sistema: Talpo / Talpiko - Core Result Monad
##
## 🎯 Responsabilidad:
##   - Transformar el valor exitoso (`tpMap`)
##   - Transformar el error (`tpMapError`)
##   - Mantener metadata, trazabilidad y compatibilidad funcional
##
## 🚀 Características Clave:
## - Transforma valor sin tocar el error
## - Transforma error sin tocar el valor
## - Preserva `metadata` en ambos casos
## - Compatible con funciones con efectos colaterales
## - Inlineado para cero overhead

import ../primitives/[tp_result, tp_error, tp_interfaces]
import std/tables

when defined(release):
  {.push checks: off.}
else:
  {.push stackTrace: on.}

# ─────────────────────────────────────────────────────────────────────────────
# 🔁 tpMap: Aplica función sobre valor si es éxito
# ─────────────────────────────────────────────────────────────────────────────

proc tpMap*[T, R](
  res: TpResult[T],
  f: proc(x: T): R         # ❗ Sin restricción noSideEffect
): TpResult[R] {.inline.} =
  ## Transforma el valor si el resultado es `tpSuccessKind`, deja error intacto.
  ## 
  ## Parámetros:
  ## - `res`: Resultado original (`TpResult[T]`)
  ## - `f`: Función a aplicar si el resultado es éxito
  ##
  ## Retorna:
  ## - `TpResult[R]`, resultado transformado o propagación del error original
  ##
  ## Ejemplo:
  ## ```nim
  ## let r = tpOk(2)
  ## let r2 = tpMap(r, proc(x: int): string = $x)
  ## ```
  if res.tpIsSuccess():
    TpResult[R](
      kind: tpSuccessKind,
      value: f(res.tpUnsafeGet()),
      metadata: res.metadata
    )
  else:
    TpResult[R](
      kind: tpFailureKind,
      error: res.error,
      metadata: res.metadata
    )

# ─────────────────────────────────────────────────────────────────────────────
# 🚨 tpMapError: Aplica función sobre error si es fallo
# ─────────────────────────────────────────────────────────────────────────────

proc tpMapError*[T](
  res: TpResult[T],
  f: proc(e: ref TpResultError): ref TpResultError  # ❗ Sin restricción noSideEffect
): TpResult[T] {.inline.} =
  ## Transforma el error si el resultado es `tpFailureKind`, deja valor intacto.
  ##
  ## Parámetros:
  ## - `res`: Resultado original (`TpResult[T]`)
  ## - `f`: Función que transforma el error
  ##
  ## Retorna:
  ## - `TpResult[T]` con error modificado o resultado original si fue éxito
  ##
  ## Ejemplo:
  ## ```nim
  ## let r = someFailingOp()
  ## let r2 = tpMapError(r, proc(e) = newTpResultError("envuelto: " & e.msg))
  ## ```
  if res.tpIsFailure():
    TpResult[T](
      kind: tpFailureKind,
      error: f(res.error),
      metadata: res.metadata
    )
  else:
    res

{.pop.}
