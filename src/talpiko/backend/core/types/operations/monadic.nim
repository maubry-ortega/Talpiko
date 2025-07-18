## monadic.nim
## Módulo: Operadores Monádicos
## Sistema: Talpo / Talpiko - Result Monad
## Responsabilidad: Este módulo define operadores funcionales para la monada `TpResult[T]`, permitiendo composición fluida y segura de operaciones que pueden fallar.

import ../primitives/[tp_result, tp_error, tp_interfaces]
import std/tables

when defined(release):
  {.push checks: off.}
else:
  {.push stackTrace: on.}

# ─────────────────────────────────────────────────────────────────────────────
# 🧮 Operador Monádico (bind)
# ─────────────────────────────────────────────────────────────────────────────

proc `>>=`*[T, R](
  res: TpResult[T],
  op: proc(x: T): TpResult[R] {.noSideEffect.}
): TpResult[R] {.inline.} =
  ## Operador `bind` para composición de operaciones que pueden fallar.
  ##
  ## Comportamiento:
  ## - Si `res` es éxito: aplica `op` al valor y retorna su resultado
  ## - Si `res` es error: retorna el mismo error sin ejecutar `op`
  ##
  ## Seguridad:
  ## - Usa `unsafeGet` sólo si `isSuccess`, garantizado por short-circuit
  ## - Captura excepciones lanzadas por `op`, envolviéndolas en `TpResultError`
  ##
  ## Rendimiento:
  ## - Ideal para composición en pipelines funcionales
  ## - Inlineado, cero branching adicional en happy path

  if likely(res.tpIsSuccess()):
    try:
      return op(res.tpUnsafeGet())
    except CatchableError as e:
      return TpResult[R](
        kind: tpFailureKind,
        error: newTpResultErrorRef(
          msg = e.msg,
          code = "TP_MONAD_BIND_EXCEPTION",
          severity = tpHigh,
          context = initTable[string, string](),
          original = e
        )
      )
  else:
    return TpResult[R](
      kind: tpFailureKind,
      error: res.error
    )

# ─────────────────────────────────────────────────────────────────────────────
# 📚 Alternativa Semántica: `tpAndThen`
# ─────────────────────────────────────────────────────────────────────────────

proc tpAndThen*[T, R](
  res: TpResult[T],
  op: proc(x: T): TpResult[R]
): TpResult[R] {.inline.} =
  ## Versión más legible del operador `bind`
  ##
  ## Semántica:
  ## - `res.tpAndThen(f)` es equivalente a `res >>= f`
  ## - Más expresiva en entornos donde `>>=` puede ser menos legible
  ##
  ## Recomendado cuando:
  ## - Se prioriza claridad sobre concisión
  ## - El operador `>>=` resulta confuso en proyectos nuevos

  res >>= op

{.pop.}