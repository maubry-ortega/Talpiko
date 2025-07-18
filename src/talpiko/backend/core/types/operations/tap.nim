## tap.nim
##
## 📦 Módulo: tpTap
## 🎯 Sistema: Talpo / Talpiko - TpResult Monad
##
## Responsabilidad:
## Ejecutar lógica colateral (logging, métricas, debug) sin alterar el flujo de datos
## Compatible con estilo funcional puro.
##
## Casos de uso:
## - Observabilidad
## - Trazabilidad distribuida
## - Registro de errores sin lanzar excepciones
## - Logging detallado de éxito o fallo

import ../primitives/[tp_result, tp_error]

# ─────────────────────────────────────────────────────────────────────────────
# ✅ tpTap: Acción colateral si éxito
# ─────────────────────────────────────────────────────────────────────────────

proc tpTap*[T](
  res: TpResult[T],
  sideEffect: proc(x: T): void {.closure.}
): TpResult[T] {.inline.} =
  ## Ejecuta `sideEffect(x)` si el resultado es `tpSuccess`.
  ##
  ## No modifica el resultado original.
  ##
  ## Ejemplo:
  ## ```nim
  ## let res = getUser()
  ##   .tpTap(proc(u: User) = echo "Obtuve el usuario: ", u.name)
  ## ```
  if res.tpIsSuccess():
    sideEffect(res.value)
  res

# ─────────────────────────────────────────────────────────────────────────────
# ❌ tpTapError: Acción colateral si error
# ─────────────────────────────────────────────────────────────────────────────

proc tpTapError*[T](
  res: TpResult[T],
  sideEffect: proc(err: ref TpResultError): void {.closure.}
): TpResult[T] {.inline.} =
  ## Ejecuta `sideEffect(error)` si el resultado es `tpFailure`.
  ##
  ## No modifica el resultado original.
  ##
  ## Ejemplo:
  ## ```nim
  ## let res = getUser()
  ##   .tpTapError(proc(e) = logError(e.code & ": " & e.msg))
  ## ```
  if res.tpIsFailure():
    sideEffect(res.error)
  res
