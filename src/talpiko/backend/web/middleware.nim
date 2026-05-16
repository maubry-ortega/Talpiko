# src/talpiko/backend/web/middleware.nim
import asyncdispatch, strutils, httpcore
import ../core/types
import ./context

proc tpCors*(ctx: TpContext): Future[bool] {.async.} =
  ## Middleware básico de CORS.
  ctx.res.headers["Access-Control-Allow-Origin"] = "*"
  ctx.res.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
  ctx.res.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
  return true

proc tpAuthToken*(token: string): TpMiddleware =
  ## Middleware de ejemplo para validación de token estático.
  return proc(ctx: TpContext): Future[bool] {.async, closure, gcsafe.} =
    # Intentar obtener de cabeceras directamente desde la request
    let authHeader = ctx.getHeader("Authorization")
    if authHeader == "Bearer " & token:
      return true

    ctx.error(tpecUnauthorized, "Invalid or missing token", Http401)
    return false
