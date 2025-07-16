## async.nim
##
## Módulo: Extensiones Async/Await para TpResult
## Sistema: Talpo / Talpiko - Core Types
##
## Responsabilidad:
##   Este módulo proporciona integración nativa entre el sistema de tipos TpResult
##   y operaciones asincrónicas usando `Future` y `await`, de forma segura y sin overhead.
##
## Características Clave:
## - Compatibilidad directa con `async/await`
## - Futuro tipado: `TpAsyncResult[T]`
## - Manejo seguro de errores en contextos asincrónicos
## - Cero coste en caminos exitosos (happy path)
## - Preparado para ARC/ORC y threading

when defined(nimHasArc):
  import std/asyncdispatch
  import ../constructors/[ok, err]
  import ../primitives/result

  # ─────────────────────────────────────────────────────────────────────────────
  # 📦 Tipos Principales
  # ─────────────────────────────────────────────────────────────────────────────

  type
    TpAsyncResult*[T] = Future[TpResult[T]]
      ## Futuro tipado para operaciones que retornan `TpResult[T]` asincrónicamente
      ##
      ## Uso común:
      ## ```nim
      ## proc fetchData(): TpAsyncResult[int] = async:
      ##   await sleepAsync(100)
      ##   tpOk(200)
      ## ```

  # ─────────────────────────────────────────────────────────────────────────────
  # 🛠️ Integración Async/Await
  # ─────────────────────────────────────────────────────────────────────────────

  proc tpAwait*[T](fut: TpAsyncResult[T]): TpResult[T] {.inline.} =
    ## Espera el resultado de una operación asincrónica y lo adapta a `TpResult`
    ##
    ## Características:
    ## - Zero-cost en camino exitoso
    ## - Propaga errores de forma segura
    ##
    ## Uso:
    ## ```nim
    ## let res = tpAwait(await fetchSomething())
    ## if res.tpIsSuccess: echo res.tpUnsafeGet
    ## ```
    let res = await fut
    if res.tpIsSuccess:
      tpOk(res.tpUnsafeGet)
    else:
      tpErr[T](res.error)

  proc tpAsync*[T](op: proc(): TpResult[T] {.gcsafe.}): TpAsyncResult[T] {.inline.} =
    ## Convierte una operación síncrona en `async` retornando un `TpAsyncResult`
    ##
    ## Ventajas:
    ## - Compatible con `async`/`await` de Nim
    ## - Facilita transición de funciones sincrónicas a asincrónicas
    ##
    ## Ejemplo:
    ## ```nim
    ## let fut = tpAsync(proc(): TpResult[int] = tpOk(123))
    ## echo (await fut).tpUnsafeGet
    ## ```
    asyncCheck op()  # No retorna directamente, solo lanza async
