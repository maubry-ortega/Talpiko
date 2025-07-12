# src/talpiko/backend/core/types.nim
## Módulo de tipos fundamentales para Talpiko Framework
## Define el monad `TpResult` para manejo funcional de errores.

import macros

type
  TpResult*[T] = object
    ## Monad Result para manejo funcional de errores.
    isOk*: bool
    value*: T
    error*: ref Exception
    errorMsg*: string
    errorCode*: string
  
  TpResultError* = object of CatchableError
    ## Excepción base para resultados, hereda de CatchableError.
    code*: string

proc tpOk*[T](value: T): TpResult[T] =
  ## Crea un resultado exitoso con un valor.
  ## Args:
  ##   value: Valor a encapsular en el TpResult.
  TpResult[T](isOk: true, value: value, errorMsg: "", errorCode: "")

proc tpErr*[T](error: string, code: string = "TP_UNKNOWN"): TpResult[T] =
  ## Crea un resultado de error con un mensaje.
  ## Args:
  ##   error: Mensaje de error.
  ##   code: Código de error opcional.
  TpResult[T](
    isOk: false,
    error: newException(TpResultError, error),
    errorMsg: error,
    errorCode: code
  )

proc tpErr*[T](error: ref Exception, code: string = "TP_UNKNOWN"): TpResult[T] =
  ## Crea un resultado de error con una excepción.
  ## Args:
  ##   error: Excepción a encapsular.
  ##   code: Código de error opcional.
  TpResult[T](
    isOk: false,
    error: error,
    errorMsg: error.msg,
    errorCode: code
  )

proc tpIsError*[T](res: TpResult[T]): bool {.inline.} =
  ## Retorna true si el TpResult es un error.
  not res.isOk

proc tpIsOkOrError*[T](res: TpResult[T]): bool {.inline.} =
  ## Retorna true si el TpResult está en estado ok o error.
  res.isOk or res.tpIsError

proc `>>=`*[T, R](res: TpResult[T], op: proc(x: T): TpResult[R]): TpResult[R] {.inline.} =
  ## Operador bind para encadenar operaciones en el monad TpResult.
  if res.isOk: op(res.value)
  else: tpErr[R](res.errorMsg, res.errorCode)

proc tpMap*[T, R](res: TpResult[T], op: proc(x: T): R): TpResult[R] {.inline.} =
  ## Transforma el valor de un TpResult usando una función.
  if res.isOk: tpOk(op(res.value))
  else: tpErr[R](res.errorMsg, res.errorCode)

proc tpUnwrap*[T](res: TpResult[T]): T {.inline.} =
  ## Extrae el valor de un TpResult, lanza excepción si es error.
  if res.isOk: res.value
  else: raise newException(TpResultError, res.errorMsg)

proc tpGetOrDefault*[T](res: TpResult[T], default: T): T {.inline.} =
  ## Retorna el valor de un TpResult o un valor por defecto si es error.
  if res.isOk: res.value else: default

proc tpOrElse*[T](res: TpResult[T], op: proc(): TpResult[T]): TpResult[T] {.inline.} =
  ## Ejecuta una operación alternativa si el TpResult es un error.
  if res.isOk: res
  else: op()

template tpTryOr*[T](body: untyped, errorHandler: untyped): TpResult[T] =
  ## Macro para manejar excepciones con TpResult.
  ## Args:
  ##   body: Expresión a ejecutar.
  ##   errorHandler: Función que maneja la excepción.
  var result: TpResult[T]
  block:
    try:
      let value: T = body
      result = tpOk[T](value)
    except CatchableError as e:
      result = errorHandler(e)
  result