# src/talpiko/backend/web/context.nim
## Módulo de contexto para las peticiones HTTP.
## TpContext es una estructura ligera que agrupa Request, Response y Logger
## inyectados a cada TpHandler.
##
## Hot-path guarantees:
##  - `ok`, `resp`, `error` usan serialización estática (sin JsonNode)
##  - `error` usa const arrays de TpErrorCode → HttpCode / string
##  - Soporta pooling: `resetContext` limpia sin desalocar

import tables, httpcore
import ../core/types
import ../core/logging
import ../core/serialize   # static buffer serializer

# ── Factory ──────────────────────────────────────────────────────────────────

proc newTpContext*(req: TpRequest, res: TpResponse, logger: TpLogger): TpContext =
  ## Crea un nuevo contexto para una petición.
  result = new TpContext
  result.req = req
  result.res = res
  result.logger = logger

proc resetTpContext*(ctx: TpContext, req: TpRequest, res: TpResponse) {.inline.} =
  ## Reinicia el contexto para reutilización en el pool.
  ## No desaloca ningún objeto — sólo actualiza las referencias.
  ctx.req = req
  ctx.res = res
  ctx.res.code = Http200
  ctx.res.body.setLen(0)
  # Re-set Content-Type to default
  ctx.res.headers["Content-Type"] = "text/plain"

# ── Response helpers (hot path — static serialization only) ──────────────────

template ok*[T](ctx: TpContext, data: T) =
  ## 200 OK con objeto serializado estáticamente al buffer.
  ## Sin JsonNode, sin `%*`.
  ctx.res.code = Http200
  ctx.res.body.setLen(0)
  tpSerialize(data, ctx.res.body)
  ctx.res.headers["Content-Type"] = "application/json"

template resp*[T](ctx: TpContext, data: T, statusCode: HttpCode = Http200) =
  ## Respuesta con código y objeto serializado estáticamente.
  ctx.res.code = statusCode
  ctx.res.body.setLen(0)
  tpSerialize(data, ctx.res.body)
  ctx.res.headers["Content-Type"] = "application/json"

template error*(ctx: TpContext, errorCode: TpErrorCode, msg: string,
                statusCode: HttpCode = tpErrorHttpCode[errorCode]) =
  ## Respuesta de error usando const arrays de compile-time.
  ## Sin `$errorCode` en runtime, sin HttpCode hardcodeado.
  ctx.res.code = statusCode
  ctx.res.body.setLen(0)
  # Serialize TpErrorResponse directly into the buffer (no JsonNode)
  ctx.res.body.add("{\"code\":")
  tpEscapeJsonStr(tpErrorCodeStr[errorCode], ctx.res.body)
  ctx.res.body.add(",\"message\":")
  tpEscapeJsonStr(msg, ctx.res.body)
  ctx.res.body.add(",\"status\":\"error\"}")
  ctx.res.headers["Content-Type"] = "application/json"

proc html*(ctx: TpContext, htmlStr: string, code: HttpCode = Http200) =
  ctx.res.html(htmlStr, code)

proc send*(ctx: TpContext, body: string, code: HttpCode = Http200) =
  ctx.res.code = code
  ctx.res.body = body

# ── Request accessors ────────────────────────────────────────────────────────

proc params*(ctx: TpContext): Table[string, string] = ctx.req.params
proc query*(ctx: TpContext): Table[string, string]  = ctx.req.query
proc body*(ctx: TpContext): string                  = ctx.req.body

proc getParam*(ctx: TpContext, key: string, default: string = ""): string {.inline.} =
  ## Obtiene un parámetro de la ruta (/users/:id → getParam("id")).
  result = ctx.req.params.getOrDefault(key, default)

proc getQuery*(ctx: TpContext, key: string, default: string = ""): string {.inline.} =
  ## Obtiene un parámetro de la query string (?page=2 → getQuery("page")).
  result = ctx.req.query.getOrDefault(key, default)
