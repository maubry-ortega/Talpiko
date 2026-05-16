# src/talpiko/backend/talpo.nim
## Punto de entrada principal para el Backend de Talpiko (Talpo)

import asyncdispatch, json, tables, httpcore, strutils
import ./core/types
import ./core/logging
import ./core/db
import ./core/di/container
import ./web/server
import ./web/router except parseSegments, TpRouteSegment, TpRouteEntry
import ./web/context
import ./web/rpc
import ./web/middleware

export asyncdispatch, json, tables, httpcore, strutils
export types, logging, container, db
export types, logging, context, server, rpc, middleware, db
export router.TpRouter, router.newTpRouter, router.addRoute, router.matchRoute
export router.tpRoute, router.get, router.post, router.put, router.delete,
    router.patch, router.options, router.use

# Instancia global de la aplicación (para facilidad de uso)
var tpApp* = newTpServer()

proc run*(port: int = 8080) =
  ## Inicia la aplicación Talpo en el puerto especificado
  tpApp.start(port)
