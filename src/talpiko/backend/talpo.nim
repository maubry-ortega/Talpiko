# src/talpiko/backend/talpo.nim
## Punto de entrada principal para el Backend de Talpiko (Talpo)

import asyncdispatch, json, tables, httpcore, strutils
import ./core/types
import ./core/logging
import ./core/di/container
import ./web/server
import ./web/router
import ./web/context
import ./web/rpc

export asyncdispatch, json, tables, httpcore, strutils
export types, logging, container
export server, router, context, rpc

# Instancia global de la aplicación (para facilidad de uso)
var tpApp* = newTpServer()

proc run*(port: int = 8080) =
  ## Inicia la aplicación Talpo en el puerto especificado
  tpApp.start(port)
