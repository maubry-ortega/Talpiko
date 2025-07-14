# src/talpiko/backend/core/logging.nim
## Sistema avanzado de logging para Talpiko Framework
##
## Proporciona:
## - Sistema de logging estructurado con múltiples niveles
## - Contexto enriquecido para cada mensaje
## - Handlers configurables (consola, archivo, red, etc.)
## - Rotación de logs automática
## - Formateo personalizable
## - Soporte para logging asíncrono
##
## Ejemplo básico:
## runnableExamples:
##   let logger = newTpLogger(TP_INFO)
##   logger.tpInfo("Aplicación iniciada", {"version": "1.0.0"}.toTable)
##   logger.tpAddHandler(consoleHandler)
##   logger.tpError("Error crítico", {"module": "auth"}.toTable)

import 
  times, strutils, tables,
  std/[os, strformat, json, locks]

when defined(useAsyncLogging):
  import asyncdispatch

type
  TpLogLevel* = enum
    ## Niveles de logging disponibles
    TP_TRACE = "TRACE"   ## Mensajes detallados de seguimiento
    TP_DEBUG = "DEBUG"   ## Información de depuración
    TP_INFO = "INFO"     ## Información general
    TP_WARN = "WARN"     ## Advertencias
    TP_ERROR = "ERROR"   ## Errores recuperables
    TP_FATAL = "FATAL"   ## Errores críticos

  TpLogContext* = Table[string, string]
    ## Contexto adicional para los mensajes de log

  TpLogHandler* = proc(
    level: TpLogLevel, 
    msg: string, 
    ctx: TpLogContext, 
    timestamp: string,
    loggerName: string
  ) {.gcsafe.}
    ## Tipo para handlers de logging personalizados

  TpLogger* = ref object
    ## Logger principal con configuración flexible
    name*: string               ## Nombre identificador del logger
    level*: TpLogLevel          ## Nivel mínimo de logging
    handlers*: seq[TpLogHandler] ## Handlers registrados
    context*: TpLogContext      ## Contexto global
    lastTimestamp: string       ## Cache del último timestamp
    lastTime: Time             ## Cache de la última hora
    when defined(useAsyncLogging):
      queue: AsyncQueue[tuple[
        level: TpLogLevel,
        msg: string,
        ctx: TpLogContext
      ]]
    else:
      lock: Lock               ## Lock para thread-safety

const
  DefaultLogFormat* = "[$timestamp] [$level] $message $context"
    ## Formato por defecto para los mensajes de log
  MaxLogSize* = 10000000     ## 10MB tamaño máximo por defecto para rotación
  TimeFormat* = "yyyy-MM-dd'T'HH:mm:sszzz"
    ## Formato ISO 8601 para timestamps

var 
  defaultTpLogger* {.threadvar.}: TpLogger
    ## Logger por defecto (thread-local para seguridad en hilos)

proc initDefaultLogger() =
  ## Inicializa el logger por defecto
  defaultTpLogger = TpLogger(
    name: "default",
    level: when defined(release): TP_INFO else: TP_DEBUG,
    handlers: @[],
    context: initTable[string, string]()
  )
  initLock(defaultTpLogger.lock)

proc getDefaultLogger*(): TpLogger =
  ## Obtiene el logger por defecto (thread-safe)
  if defaultTpLogger.isNil:
    initDefaultLogger()
  result = defaultTpLogger

proc newTpLogger*(
  name: string = "", 
  level: TpLogLevel = TP_INFO,
  initialContext: TpLogContext = initTable[string, string]()
): TpLogger =
  ## Crea una nueva instancia de logger configurable
  ## 
  ## Args:
  ##   name: Identificador único para el logger
  ##   level: Nivel mínimo de logging
  ##   initialContext: Contexto inicial para todos los mensajes
  ##
  ## Returns:
  ##   Nueva instancia de TpLogger configurada
  
  result = TpLogger(
    name: if name.len > 0: name else: "logger-" & $getTime().toUnix(),
    level: level,
    handlers: @[],
    context: initialContext
  )
  initLock(result.lock)

  when defined(useAsyncLogging):
    result.queue = newAsyncQueue[tuple[
      level: TpLogLevel,
      msg: string,
      ctx: TpLogContext
    ]](1000)  # Capacidad de la cola

proc tpAddHandler*(
  self: TpLogger,
  handler: TpLogHandler,
  deduplicate: bool = true
) =
  ## Añade un handler al logger
  ## 
  ## Args:
  ##   handler: Procedimiento que procesa los logs
  ##   deduplicate: Si se deben evitar duplicados
  
  withLock self.lock:
    if not deduplicate or handler notin self.handlers:
      self.handlers.add(handler)

proc tpRemoveHandler*(self: TpLogger, handler: TpLogHandler) =
  ## Remueve un handler específico del logger
  withLock self.lock:
    self.handlers.keepIf(proc(h: TpLogHandler): bool = h != handler)

proc tpClearHandlers*(self: TpLogger) =
  ## Remueve todos los handlers del logger
  withLock self.lock:
    self.handlers.setLen(0)

proc tpFormatMessage*(
  level: TpLogLevel,
  msg: string,
  ctx: TpLogContext,
  timestamp: string,
  loggerName: string,
  format: string = DefaultLogFormat
): string =
  ## Formatea un mensaje de log según el patrón especificado
  result = format
    .replace("$timestamp", timestamp)
    .replace("$level", alignLeft($level, 5))
    .replace("$message", msg)
    .replace("$logger", loggerName)
  
  if ctx.len > 0:
    result = result.replace("$context", $(%ctx))

proc tpLogImpl(
  self: TpLogger,
  level: TpLogLevel,
  msg: string,
  extra: TpLogContext
) =
  ## Implementación central de logging (thread-safe)
  if level < self.level:
    return

  let currentTime = getTime()
  var timestamp: string

  # Optimización: reutilizar timestamp si es el mismo segundo
  if currentTime == self.lastTime:
    timestamp = self.lastTimestamp
  else:
    timestamp = currentTime.format(TimeFormat)
    self.lastTimestamp = timestamp
    self.lastTime = currentTime

  # Combinar contexto global con contexto específico
  var combinedCtx = initTable[string, string]()
  withLock self.lock:
    for k, v in self.context:
      combinedCtx[k] = v
  
  for k, v in extra:
    combinedCtx[k] = v

  # Enviar a todos los handlers
  for handler in self.handlers:
    try:
      handler(level, msg, combinedCtx, timestamp, self.name)
    except Exception as e:
      stderr.writeLine fmt"Error en handler de log: {e.msg}"

when defined(useAsyncLogging):
  proc tpAsyncLoggerWorker(self: TpLogger) {.async.} =
    ## Worker para procesamiento asíncrono de logs
    while true:
      let (level, msg, ctx) = await self.queue.pop()
      tpLogImpl(self, level, msg, ctx)

proc tpLog*(
  self: TpLogger,
  level: TpLogLevel,
  msg: string,
  extra: TpLogContext = initTable[string, string]()
) =
  ## Registra un mensaje de log
  when defined(useAsyncLogging):
    asyncCheck self.queue.add((level, msg, extra))
  else:
    withLock self.lock:
      tpLogImpl(self, level, msg, extra)

template tpTrace*(self: TpLogger, msg: string, extra: TpLogContext = initTable[string, string]()) =
  ## Log nivel TRACE (seguimiento detallado)
  self.tpLog(TP_TRACE, msg, extra)

template tpDebug*(self: TpLogger, msg: string, extra: TpLogContext = initTable[string, string]()) =
  ## Log nivel DEBUG (información de depuración)
  self.tpLog(TP_DEBUG, msg, extra)

template tpInfo*(self: TpLogger, msg: string, extra: TpLogContext = initTable[string, string]()) =
  ## Log nivel INFO (información general)
  self.tpLog(TP_INFO, msg, extra)

template tpWarn*(self: TpLogger, msg: string, extra: TpLogContext = initTable[string, string]()) =
  ## Log nivel WARN (advertencias)
  self.tpLog(TP_WARN, msg, extra)

template tpError*(self: TpLogger, msg: string, extra: TpLogContext = initTable[string, string]()) =
  ## Log nivel ERROR (errores recuperables)
  self.tpLog(TP_ERROR, msg, extra)

template tpFatal*(self: TpLogger, msg: string, extra: TpLogContext = initTable[string, string]()) =
  ## Log nivel FATAL (errores críticos)
  self.tpLog(TP_FATAL, msg, extra)

# Handlers predefinidos
proc consoleHandler*(
  level: TpLogLevel,
  msg: string,
  ctx: TpLogContext,
  timestamp: string,
  loggerName: string
) =
  ## Handler para escribir logs en consola con colores
  const
    Reset = "\e[0m"
    Colors: array[TpLogLevel, string] = [
      TP_TRACE: "\e[37m",    # Gris claro
      TP_DEBUG: "\e[36m",    # Cyan
      TP_INFO: "\e[32m",     # Verde
      TP_WARN: "\e[33m",     # Amarillo
      TP_ERROR: "\e[31m",    # Rojo
      TP_FALTA: "\e[41m"    # Rojo fondo blanco
    ]
  
  let formatted = tpFormatMessage(level, msg, ctx, timestamp, loggerName)
  stdout.writeLine Colors[level] & formatted & Reset

when defined(useFileLogging):
  proc tpFileHandler*(
    logFile: string,
    maxSize: int64 = MaxLogSize,
    format: string = DefaultLogFormat
  ): TpLogHandler =
    ## Crea un handler que escribe logs en archivo con rotación
    var fileLock: Lock
    initLock(fileLock)
    
    result = proc(
      level: TpLogLevel,
      msg: string,
      ctx: TpLogContext,
      timestamp: string,
      loggerName: string
    ) =
      withLock fileLock:
        try:
          if fileExists(logFile) and getFileSize(logFile) > maxSize:
            let backupFile = logFile & "." & getTime().format("yyyyMMdd_HHmmss")
            moveFile(logFile, backupFile)
          
          let formatted = tpFormatMessage(level, msg, ctx, timestamp, loggerName, format)
          let f = open(logFile, fmAppend)
          defer: f.close()
          f.writeLine(formatted)
        except IOError as e:
          stderr.writeLine "Error escribiendo log: " & e.msg

# Inicialización automática del logger por defecto
initDefaultLogger()

# Añadir handler de consola por defecto en modo debug
when not defined(release):
  getDefaultLogger().tpAddHandler(consoleHandler, deduplicate = false)

when isMainModule:
  # Ejemplo de uso
  let logger = newTpLogger("example")
  logger.tpAddHandler(consoleHandler)
  
  logger.tpInfo("Aplicación iniciada", {
    "version": "1.0.0",
    "environment": "development"
  }.toTable)
  
  logger.tpError("Error de conexión", {
    "module": "database",
    "attempt": "3"
  }.toTable)