# src/talpiko/backend/core/types.nim
## Módulo de tipos fundamentales para Talpiko Framework
## Define el monad `TpResult` para manejo funcional de errores.

import macros

type
  TpErrorCode* = enum
    ## Códigos de error estructurados para Talpiko.
    ## El orden del enum define el índice para los const arrays de abajo.
    tpecOk = 0,
    tpecUnknown,
    tpecError,
    tpecNotFound,
    tpecValidationError,
    tpecSerializationError,
    tpecDeserializationError,
    tpecParseError,
    tpecUnauthorized,
    tpecForbidden,
    tpecInternalError


  TpError* = object
    ## Estructura de error tipada
    code*: TpErrorCode
    msg*: string

  TpResult*[T] = object
    ## Monad Result para manejo funcional de errores.
    case isOk*: bool
    of true:
      value*: T
    of false:
      error*: TpError

  TpResultError* = object of CatchableError
    ## Excepción base para resultados, hereda de CatchableError.
    code*: TpErrorCode

proc tpOk*[T](value: T): TpResult[T] =
  ## Crea un resultado exitoso con un valor.
  TpResult[T](isOk: true, value: value)

proc tpErr*[T](msg: string, code: TpErrorCode = tpecUnknown): TpResult[T] =
  ## Crea un resultado de error con un mensaje y código.
  TpResult[T](isOk: false, error: TpError(code: code, msg: msg))

proc tpErr*[T](e: ref Exception, code: TpErrorCode = tpecUnknown): TpResult[T] =

  ## Crea un resultado de error con una excepción.
  TpResult[T](isOk: false, error: TpError(code: code, msg: e.msg))

proc tpIsError*[T](res: TpResult[T]): bool {.inline.} =
  ## Retorna true si el TpResult es un error.
  not res.isOk

proc tpIsOkOrError*[T](res: TpResult[T]): bool {.inline.} =
  ## Retorna true si el TpResult está en estado ok o error.
  true # TpResult siempre es uno de los dos

proc `>>=`*[T, R](res: TpResult[T], op: proc(x: T): TpResult[R]): TpResult[R] {.inline.} =
  ## Operador bind para encadenar operaciones en el monad TpResult.
  if res.isOk: op(res.value)
  else: tpErr[R](res.error.msg, res.error.code)

proc tpMap*[T, R](res: TpResult[T], op: proc(x: T): R): TpResult[R] {.inline.} =
  ## Transforma el valor de un TpResult usando una función.
  if res.isOk: tpOk(op(res.value))
  else: tpErr[R](res.error.msg, res.error.code)

proc tpUnwrap*[T](res: TpResult[T]): T {.inline.} =
  ## Extrae el valor de un TpResult, lanza excepción si es error.
  if res.isOk: res.value
  else: raise (ref TpResultError)(msg: res.error.msg, code: res.error.code)

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

# --- Compile-Time Error Mappings ---
# These arrays are indexed by TpErrorCode and evaluated purely at compile time.
# Zero runtime cost: no $errorCode, no match expressions on the hot path.

import httpcore as httpcore_mod

const tpErrorHttpCode*: array[TpErrorCode, HttpCode] = [
  tpecOk: Http200,
  tpecUnknown: Http500,
  tpecError: Http500,
  tpecNotFound: Http404,
  tpecValidationError: Http422,
  tpecSerializationError: Http500,
  tpecDeserializationError: Http400,
  tpecParseError: Http400,
  tpecUnauthorized: Http401,
  tpecForbidden: Http403,
  tpecInternalError: Http500,
]

const tpErrorCodeStr*: array[TpErrorCode, string] = [
  tpecOk: "OK",
  tpecUnknown: "UNKNOWN_ERROR",
  tpecError: "ERROR",
  tpecNotFound: "NOT_FOUND",
  tpecValidationError: "VALIDATION_ERROR",
  tpecSerializationError: "SERIALIZATION_ERROR",
  tpecDeserializationError: "DESERIALIZATION_ERROR",
  tpecParseError: "PARSE_ERROR",
  tpecUnauthorized: "UNAUTHORIZED",
  tpecForbidden: "FORBIDDEN",
  tpecInternalError: "INTERNAL_ERROR",
]

# --- Talpiko Web Types ---

when defined(js) or defined(wasm):
  when defined(js):
    import std/[asyncjs, json]
    export asyncjs.Future
  else:
    import std/json
    type Future*[T] = ref object
  type
    TpContext* = ref object # Placeholder para el cliente
else:
  import json, tables, asyncdispatch, asynchttpserver, httpcore
  import ./logging
  type
    TpHttpMethod* = enum
      HttpGet = "GET"
      HttpPost = "POST"
      HttpPut = "PUT"
      HttpDelete = "DELETE"
      HttpPatch = "PATCH"
      HttpOptions = "OPTIONS"
      HttpHead = "HEAD"

    TpRequest* = ref object
      req*: Request
      reqMethod*: TpHttpMethod
      path*: string
      query*: Table[string, string]
      params*: Table[string, string]
      body*: string
      jsonBody*: JsonNode

    TpResponse* = ref object
      code*: HttpCode
      headers*: HttpHeaders
      body*: string

    TpContext* = ref object
      req*: TpRequest
      res*: TpResponse
      logger*: TpLogger

type
  User* = object
    id*: int
    fullName*: string

  MessageResponse* = object
    message*: string
    status*: string

  TpHandler* = proc(ctx: TpContext): Future[void] {.closure, gcsafe.}
    ## Firma estándar de un controlador / manejador de ruta en Talpiko

  TpMiddleware* = proc(ctx: TpContext): Future[bool] {.closure, gcsafe.}
    ## Firma de un middleware. Si retorna false, se detiene la cadena.

  TpErrorResponse* = object
    ## Modelo estándar para respuestas de error de la API
    code*: string
    message*: string
    status*: string = "error"

when not defined(js) and not defined(wasm):
  proc newTpResponse*(code: HttpCode = Http200, body: string = "",
      contentType: string = "text/plain"): TpResponse =
    ## Crea una nueva respuesta base.
    result = new TpResponse
    result.code = code
    result.body = body
    result.headers = newHttpHeaders([("Content-Type", contentType)])

  proc json*(res: TpResponse, data: JsonNode, code: HttpCode = Http200) =
    ## Modifica la respuesta para devolver JSON
    res.code = code
    res.body = $data
    res.headers["Content-Type"] = "application/json"

  proc html*(res: TpResponse, htmlStr: string, code: HttpCode = Http200) =
    ## Modifica la respuesta para devolver HTML
    res.code = code
    res.body = htmlStr
    res.headers["Content-Type"] = "text/html"

  proc status*(res: TpResponse, code: HttpCode) =
    ## Solo ajusta el código de status
    res.code = code
