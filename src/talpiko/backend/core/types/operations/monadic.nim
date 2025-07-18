## monadic.nim
##
## 📦 Módulo: Operadores Monádicos para TpResult
## 🔧 Sistema: Talpo / Talpiko - Monad Core
##
## 🎯 Responsabilidad:
##   - Definir operadores de composición (`tpBind`, `tpAndThen`)
##   - Permitir encadenamiento seguro de operaciones con posible fallo
##
## 🚀 Características:
## - Captura errores de ejecución de forma segura
## - Preserva metadata
## - Compatible con funciones *closure* y `inline`

import ../primitives/[tp_result, tp_error, tp_interfaces]
import std/tables

when defined(release):
  {.push checks: off.}
else:
  {.push stackTrace: on.}

# ─────────────────────────────────────────────────────────────────────────────
# 🔗 Operador Monádico: `tpBind`
# ─────────────────────────────────────────────────────────────────────────────

proc tpBind*[T, R](
  res: TpResult[T],
  op: proc(x: T): TpResult[R] {.closure.}
): TpResult[R] {.inline.} =
  ## Encadena una operación que devuelve un `TpResult[R]`.
  ##
  ## Ejemplo:
  ## ```nim
  ## let res = tpOk(1).tpBind(proc(x: int): TpResult[string] = tpOk($x))
  ## ```
  ##
  ## - Si `res` es éxito: se ejecuta `op(x)` sobre el valor
  ## - Si falla: se propaga el error original con metadata
  ## - Si `op` lanza excepción: se transforma en `TpResultError`

  if likely(res.tpIsSuccess()):
    try:
      return op(res.tpUnsafeGet())
    except CatchableError as e:
      when defined(tpTrace):
        echo "[tpBind Exception] ", e.name, ": ", e.msg
      return TpResult[R](
        kind: tpFailureKind,
        error: newTpResultErrorRef(
          msg = e.msg,
          code = "TP_MONAD_BIND_EXCEPTION",
          severity = tpHigh,
          context = initTable[string, string](),
          original = e
        ),
        metadata: res.metadata
      )
  else:
    return TpResult[R](
      kind: tpFailureKind,
      error: res.error,
      metadata: res.metadata
    )

# ─────────────────────────────────────────────────────────────────────────────
# 🧾 Alias Semántico: `tpAndThen`
# ─────────────────────────────────────────────────────────────────────────────

proc tpAndThen*[T, R](
  res: TpResult[T],
  op: proc(x: T): TpResult[R] {.closure.}
): TpResult[R] {.inline.} =
  ## Alias semántico de `tpBind`, para estilo más expresivo.
  ##
  ## Uso típico:
  ## ```nim
  ## let resultado = res.tpAndThen(proc(x) = ...)
  ## ```
  ##
  ## Beneficios:
  ## - Más claridad que el operador `tpBind`
  ## - Mejor para flujos de datos extensos

  tpBind(res, op)

# ─────────────────────────────────────────────────────────────────────────────
# 🛠️ Alias de operador: `>>==` como reemplazo simbólico
# ─────────────────────────────────────────────────────────────────────────────

proc `>>==`*[T, R](
  res: TpResult[T],
  op: proc(x: T): TpResult[R] {.closure.}
): TpResult[R] {.inline.} =
  ## Operador alternativo más claro que `>>=`, igual funcionalidad.
  ##
  ## Ejemplo:
  ## ```nim
  ## let res = tpOk(1) >>== proc(x: int): TpResult[string] = tpOk($x)
  ## ```

  tpBind(res, op)

{.pop.}
