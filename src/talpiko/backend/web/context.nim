# src/talpiko/backend/web/context.nim
## Módulo de contexto para las peticiones HTTP
## Agrupa la Request, Response, Logger y otras utilidades que
## se inyectan a cada TpHandler.

import json, tables, httpcore
import ../core/types
import ../core/logging

proc newTpContext*(req: TpRequest, res: TpResponse, logger: TpLogger): TpContext =
  ## Crea un nuevo contexto.
  result = new TpContext
  result.req = req
  result.res = res
  result.logger = logger
  
template ok*[T](ctx: TpContext, data: T) =
  ## Envía una respuesta 200 OK con el objeto serializado como JSON (Compile-time).
  ctx.res.code = Http200
  ctx.res.body = $(%*data)
  ctx.res.headers["Content-Type"] = "application/json"

proc html*(ctx: TpContext, htmlStr: string, code: HttpCode = Http200) =
  ctx.res.html(htmlStr, code)

template resp*[T](ctx: TpContext, data: T, statusCode: HttpCode = Http200) =
  ## Envía una respuesta con el código y objeto especificado serializado como JSON (Compile-time).
  ctx.res.code = statusCode
  ctx.res.body = $(%*data)
  ctx.res.headers["Content-Type"] = "application/json"

template error*(ctx: TpContext, errorCode: TpErrorCode, msg: string, statusCode: HttpCode = Http400) =
  ## Envía una respuesta de error formal usando el modelo TpErrorResponse.
  let errResp = TpErrorResponse(code: $errorCode, message: msg)
  ctx.res.code = statusCode
  ctx.res.body = $(%*errResp)
  ctx.res.headers["Content-Type"] = "application/json"
  
proc send*(ctx: TpContext, body: string, code: HttpCode = Http200) =
  ctx.res.code = code
  ctx.res.body = body

# Procs para acceso ergonómico a la Request
proc params*(ctx: TpContext): Table[string, string] = ctx.req.params
proc query*(ctx: TpContext): Table[string, string] = ctx.req.query
proc body*(ctx: TpContext): string = ctx.req.body
proc jsonBody*(ctx: TpContext): JsonNode = ctx.req.jsonBody

proc getParam*(ctx: TpContext, key: string, default: string = ""): string =
  ## Obtiene un parámetro de la ruta (/users/:id -> getParam("id"))
  if ctx.req.params.hasKey(key):
    return ctx.req.params[key]
  return default

proc getQuery*(ctx: TpContext, key: string, default: string = ""): string =
  ## Obtiene un parámetro de la query string (?page=2 -> getQuery("page"))
  if ctx.req.query.hasKey(key):
    return ctx.req.query[key]
  return default
