# src/talpiko/backend/web/server.nim
## Servidor HTTP asíncrono que utiliza asynchttpserver para exponer
## la API y utiliza TpRouter para buscar los controladores adecuados.

import asyncdispatch, asynchttpserver, strutils, json, tables
import ../core/logging
import ../core/types
import ../core/utils
import ./router
import ./context

type 
  TpServer* = ref object
    ## Servidor Web Talpo
    router*: TpRouter
    logger*: TpLogger
    port: int
    httpServer: AsyncHttpServer


  
proc processRequest(server: TpServer, req: Request): Future[void] {.async, gcsafe.} =
  ## Procesa una petición cruda de asynchttpserver, construye el 
  ## contexto de Talpiko y busca una ruta para ejecutar el controlador.
  
  server.logger.tpDebug("Inbound Request", {"method": $req.reqMethod, "url": req.url.path})

  
  # Parsear método HTTP
  let tpMethod = tpParseHttpMethod($req.reqMethod)
  
  # Buscar Handler en Router
  let match = server.router.matchRoute(tpMethod, req.url.path)
  
  var params = initTable[string, string]()
  if match.matched:
    params = match.params
    
  # Parsear JSON if application/json
  var jsBody = newJNull()
  if req.headers.hasKey("Content-Type") and req.headers["Content-Type"].contains("application/json") and req.body != "":
    try:
      jsBody = parseJson(req.body)
    except JsonParsingError:
      server.logger.tpError("Failed to parse JSON Body")
      
  # 1. Crear TpRequest (Petición)
  let tReq = TpRequest(
    req: req, 
    reqMethod: tpMethod, 
    path: req.url.path, 
    query: tpParseQuery(req.url.path & (if req.url.query != "": "?" & req.url.query else: "")), 
    params: params,
    body: req.body,
    jsonBody: jsBody
  )
  
  # 2. Crear TpResponse Base (Respuesta)
  let tRes = newTpResponse()

  # 3. Crear Contexto
  let ctx = newTpContext(tReq, tRes, server.logger)
  
  try:
    if match.matched:
      # 4. Ejecutar controlador si se encontró
      await match.handler(ctx)
    else:
      # Handler Not Found (404)
      ctx.error(tpecNotFound, "Route not found: " & req.url.path, Http404)
  except CatchableError as e:
    # Captura de errores catastróficos en el handler (Internal Server Error 500)
    server.logger.tpError("Handler Error: " & e.msg, {"path": req.url.path})
    ctx.error(tpecInternalError, "Internal Server Error: " & e.msg, Http500)
    
  # 5. Enviar Respuesta de vuelta al cliente TCP
  await req.respond(ctx.res.code, ctx.res.body, ctx.res.headers)

proc serveLoop(server: TpServer) {.async.} =
  server.logger.tpInfo("Server listening on port " & $server.port, {"port": $server.port})

  server.httpServer = newAsyncHttpServer()
  proc cb(req: Request): Future[void] {.gcsafe.} = processRequest(server, req)
  await server.httpServer.serve(Port(server.port), cb)

proc start*(server: TpServer, port: int) =
  ## Inicia el servidor asíncrono
  server.port = port
  waitFor server.serveLoop()
  
proc newTpServer*(logger: TpLogger = defaultTpLogger): TpServer =
  new(result)
  result.router = newTpRouter()
  result.logger = logger
