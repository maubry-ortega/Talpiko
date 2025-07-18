## recover.nim
##
## 📦 Módulo: tpRecover
## 🎯 Sistema: Talpo / Talpiko - TpResult Monad
##
## Funciones de recuperación ante errores:
## - `tpRecover`: valor por defecto
## - `tpRecoverWith`: función generadora (lazy)
## - `tpRecoverResult`: retorno alternativo tipo TpResult
##
## Uso: tolerancia a fallos sin panics ni excepciones

import ../primitives/tp_result
import ../primitives/tp_interfaces
import ../primitives/tp_error

# ─────────────────────────────────────────────────────────────────────────────
# 📦 Fallback directo: valor por defecto
# ─────────────────────────────────────────────────────────────────────────────

proc tpRecover*[T](res: TpResult[T], fallback: T): T {.inline.} =
  ## Retorna `res.value` si es éxito, o `fallback` si es error.
  ##
  ## Ejemplo:
  ## ```nim
  ## let valor = getConfig().tpRecover("default")
  ## ```
  if res.tpIsSuccess():
    res.value
  else:
    fallback

# ─────────────────────────────────────────────────────────────────────────────
# 💤 Fallback diferido (lazy)
# ─────────────────────────────────────────────────────────────────────────────

proc tpRecoverWith*[T](res: TpResult[T], recovery: proc(): T {.closure.}): T {.inline.} =
  ## Ejecuta `recovery()` si hay error; retorna su resultado como fallback.
  ##
  ## Ejemplo:
  ## ```nim
  ## let valor = getUserById(id).tpRecoverWith(proc(): string = getCachedUser())
  ## ```
  ##
  ## Ventajas:
  ## - No se evalúa `recovery()` a menos que ocurra un fallo
  ##
  if res.tpIsSuccess():
    res.value
  else:
    recovery()

# ─────────────────────────────────────────────────────────────────────────────
# 🔁 Fallback funcional: otro TpResult
# ─────────────────────────────────────────────────────────────────────────────

proc tpRecoverResult*[T](res: TpResult[T], recovery: proc(): TpResult[T] {.closure.}): TpResult[T] {.inline.} =
  ## Si `res` es error, ejecuta `recovery()` para obtener un nuevo `TpResult`.
  ## Si es éxito, se retorna `res` con su metadata original.
  ##
  ## Ejemplo:
  ## ```nim
  ## let res = getUser()
  ##   .tpRecoverResult(proc() = getDefaultUser())
  ## ```
  if res.tpIsSuccess():
    # ✅ Se conserva metadata en éxito original
    TpResult[T](kind: res.kind, value: res.value, metadata: res.metadata)
  else:
    try:
      recovery()
    except CatchableError as e:
      # ⚠️ Fallback también falló (opcional: envolverlo en TpResult)
      TpResult[T](
        kind: tpFailureKind,
        error: newTpResultErrorRef(
          msg = "Recovery failed: " & e.msg,
          code = "TP_RECOVERY_EXCEPTION",
          severity = tpHigh,
          original = e
        ),
        metadata: res.metadata
      )
