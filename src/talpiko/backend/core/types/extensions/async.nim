import std/[asyncdispatch, tables]
import ../constructors/[tp_success, tp_failure]
import ../primitives/[tp_result, tp_error, tp_interfaces]

# ─────────────────────────────────────────────────────────────────────────────
# 🧾 Alias Documental (NO usar como tipo de retorno en proc async)
type
  TpAsyncResult*[T] = Future[TpResult[T]]

# ─────────────────────────────────────────────────────────────────────────────
# 🧱 Primitivas de ejecución asíncrona

proc tpAwait*[T](fut: TpAsyncResult[T]): TpResult[T] {.inline.} =
  ## Espera el resultado y retorna el valor TpResult.
  let res = await fut
  res

proc tpAsync*[T](op: proc(): TpResult[T] {.gcsafe.}): Future[TpResult[T]] {.async.} =
  ## Ejecuta una operación síncrona dentro de un contexto async y captura errores.
  try:
    return op()
  except CatchableError as e:
    return tpErr[T](
      msg = "Exception in tpAsync: " & e.msg,
      code = "TP_ASYNC_EXCEPTION",
      severity = tpHigh
    )

# ─────────────────────────────────────────────────────────────────────────────
# 🔁 Encadenamiento Asíncrono con Result

proc tpAsyncFlatMap*[T, R](
  res: TpResult[T],
  op: proc(x: T): Future[TpResult[R]] {.closure.}
): Future[TpResult[R]] {.async.} =
  ## Encadena un resultado sincrónico a una operación asincrónica.
  if res.tpIsSuccess():
    try:
      let val = res.tpUnsafeGet()
      return await op(val)
    except CatchableError as e:
      return tpErr[R](
        msg = "Exception in tpAsyncFlatMap: " & e.msg,
        code = "TP_ASYNC_FLATMAP_EXCEPTION",
        severity = tpHigh
      )
  else:
    # ⚠️ Aquí estaba el error
    return TpResult[R](
      kind: tpFailureKind,
      error: res.error,
      metadata: res.metadata
    )


proc tpThenAsync*[T, R](
  res: TpResult[T],
  op: proc(x: T): Future[TpResult[R]] {.closure.}
): Future[TpResult[R]] {.inline.} =
  ## Alias para tpAsyncFlatMap
  tpAsyncFlatMap(res, op)

# ─────────────────────────────────────────────────────────────────────────────
# 🔗 Encadenamiento Asíncrono Monádico

proc tpBindAsync*[T, R](
  res: Future[TpResult[T]],
  op: proc(x: T): Future[TpResult[R]] {.closure, gcsafe.}
): Future[TpResult[R]] {.async.} =
  ## Encadena una operación asincrónica que devuelve TpResult dentro de Future.
  let awaited = await res
  if awaited.tpIsSuccess():
    try:
      return await op(awaited.tpUnsafeGet())
    except CatchableError as e:
      when defined(tpTrace):
        echo "[tpBindAsync Exception] ", e.name, ": ", e.msg
      return TpResult[R](
        kind: tpFailureKind,
        error: newTpResultErrorRef(
          msg = e.msg,
          code = "TP_ASYNC_BIND_EXCEPTION",
          severity = tpHigh,
          context = initTable[string, string](),
          original = e
        ),
        metadata: awaited.metadata
      )
  else:
    return TpResult[R](
      kind: tpFailureKind,
      error: awaited.error,
      metadata: awaited.metadata
    )

proc tpAndThenAsync*[T, R](
  res: Future[TpResult[T]],
  op: proc(x: T): Future[TpResult[R]] {.closure, gcsafe.}
): Future[TpResult[R]] {.async.} =
  ## Alias semántico para tpBindAsync
  tpBindAsync(res, op)
