# src/talpiko/backend/core/config/env_loader.nim
## Módulo para cargar variables de entorno en Talpiko Framework
## Lee archivos .env y configura el entorno del sistema.

import os, strutils, logging, types

proc loadEnv*(path: string = ".env", logger: Logger = defaultLogger): Result[void] =
  ## Carga variables de entorno desde un archivo .env.
  ## Ignora líneas vacías y comentarios.
  logger.debug("Loading environment", {"path": path}.toTable)
  try:
    if not fileExists(path):
      logger.error("Environment file not found", {"path": path}.toTable)
      return err[void]("File not found: " & path, "ENV_NOT_FOUND")
    
    for line in lines(path):
      let cleaned = line.strip()
      if cleaned.startsWith('#') or cleaned.len == 0:
        continue
      
      let parts = cleaned.split('=', 1)
      if parts.len != 2:
        logger.warn("Invalid env line", {"line": cleaned}.toTable)
        continue
      
      let key = parts[0].strip()
      let value = parts[1].strip()
      if key.len == 0:
        logger.warn("Empty env key", {"line": cleaned}.toTable)
        continue
      
      putEnv(key, value)
      logger.debug("Set env var", {key: value}.toTable)
    
    ok()
  except IOError as e:
    logger.error("Failed to load .env file", {"error": e.msg}.toTable)
    err[void](e.msg, "ENV_LOAD_ERROR")

proc getEnvOrDefault*(key: string, default: string, logger: Logger = defaultLogger): Result[string] =
  ## Obtiene una variable de entorno o retorna un valor por defecto.
  let value = getEnv(key, default)
  if value.len == 0:
    logger.warn("Missing env var, using default", {"key": key, "default": default}.toTable)
    err[string]("Missing env var: " & key, "ENV_NOT_FOUND")
  else:
    ok(value)