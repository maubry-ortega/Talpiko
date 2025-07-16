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
##   let logger = newTpLogger("example", TP_INFO)
##   logger.tpAddHandler(consoleHandler)
##   logger.tpInfo("Aplicación iniciada", {"version": "1.0.0"}.toTable)
##   logger.tpError("Error crítico", {"module": "auth"}.toTable)

import 
  times, strutils, tables, sequtils,
  std/[os, strformat, json, locks]

when defined(useAsyncLogging):
  import asyncdispatch, asynctools

# Importar tipos del framework
import types

type
  TpLogLevel* = enum
    ## Niveles de logging disponibles ordenados por prioridad
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

  TpLoggerError* = object of TpResultError
    ## Error específico del sistema de logging
    loggerName*: string
    level*: TpLogLevel

  TpLogger* = ref object
    ## Logger principal con configuración flexible
    name*: string                ## Nombre identificador del logger
    level*: TpLogLevel           ## Nivel mínimo de logging
    handlers*: seq[TpLogHandler] ## Handlers registrados
    context*: TpLogContext       ## Contexto global
    lastTimestamp: string        ## Cache del último timestamp
    lastTime: Time              ## Cache de la última hora
    messageCount: int           ## Contador de mensajes para estadísticas
    when defined(useAsyncLogging):
      queue: AsyncQueue[tuple[
        level: TpLogLevel,
        msg: string,
        ctx: TpLogContext,
        timestamp: string
      ]]
    lock: Lock                   ## Lock para thread-safety

const
  DefaultLogFormat* = "[$timestamp] [$level] [$logger] $message $context"
    ## Formato por defecto para los mensajes de log
  MaxLogSize* = 10_000_000     ## 10MB tamaño máximo por defecto para rotación
  TimeFormat* = "yyyy-MM-dd'T'HH:mm:ss.fffzzz"
    ## Formato ISO 8601 para timestamps con milisegundos
  MaxHandlers* = 50            ## Límite máximo de handlers por logger
  MaxContextSize* = 1024       ## Tamaño máximo del contexto en caracteres

# Comparación de niveles de log
proc `<`*(a, b: TpLogLevel): bool =
  ord(a) < ord(b)

proc `<=`*(a, b: TpLogLevel): bool =
  ord(a) <= ord(b)

var 
  defaultTpLogger* {.threadvar.}: TpLogger
    ## Logger por defecto (thread-local para seguridad en hilos)
  globalLoggerRegistry: Table[string, TpLogger]
    ## Registro global de loggers
  registryLock: Lock
    ## Lock para el registro global

proc initLoggingSystem*() =
  ## Inicializa el sistema de logging global
  initLock(registryLock)
  globalLoggerRegistry = initTable[string, TpLogger]()

proc initDefaultLogger() =
  ## Inicializa el logger por defecto
  defaultTpLogger = TpLogger(
    name: "default",
    level: when defined(release): TP_INFO else: TP_DEBUG,
    handlers: @[],
    context: initTable[string, string](),
    messageCount: 0
  )
  initLock(defaultTpLogger.lock)

proc getDefaultLogger*(): TpLogger =
  ## Obtiene el logger por defecto (thread-safe)
  if defaultTpLogger.isNil:
    initDefaultLogger()
  result = defaultTpLogger

proc tpValidateLoggerName(name: string): TpResult[string] =
  ## Valida que el nombre del logger sea válido
  if name.len == 0:
    return tpErr[string]("Nombre de logger no puede estar vacío", "TP_LOGGER_EMPTY_NAME")
  
  if name.len > 64:
    return tpErr[string]("Nombre de logger excede 64 caracteres", "TP_LOGGER_NAME_TOO_LONG")
  
  for ch in name:
    if not (ch.isAlphaNumeric or ch in {'-', '_', '.'}):
      return tpErr[string]("Nombre de logger contiene caracteres inválidos", "TP_LOGGER_INVALID_NAME")
  
  tpOk(name)

proc newTpLogger*(
  name: string = "", 
  level: TpLogLevel = TP_INFO,
  initialContext: TpLogContext = initTable[string, string](),
  registerGlobally: bool = true
): TpResult[TpLogger] =
  ## Crea una nueva instancia de logger con validación robusta
  ## 
  ## Args:
  ##   name: Identificador único para el logger
  ##   level: Nivel mínimo de logging
  ##   initialContext: Contexto inicial para todos los mensajes
  ##   registerGlobally: Si debe registrarse en el registro global
  ##
  ## Returns:
  ##   TpResult[TpLogger] con el logger creado o error

  let loggerName = if name.len > 0: name else: "logger-" & $getTime().toUnix()
  
  # Validar nombre
  let nameValidation = tpValidateLoggerName(loggerName)
  if nameValidation.isError:
    return tpErr[TpLogger](nameValidation.error, nameValidation.errorCode)
  
  # Validar contexto inicial
  let contextSize = ($initialContext).len
  if contextSize > MaxContextSize:
    return tpErr[TpLogger](
      fmt"Contexto inicial excede tamaño máximo ({contextSize} > {MaxContextSize})", 
      "TP_LOGGER_CONTEXT_TOO_LARGE"
    )
  
  # Verificar si ya existe en registro global
  if registerGlobally:
    withLock registryLock:
      if loggerName in globalLoggerRegistry:
        return tpErr[TpLogger](
          fmt"Logger '{loggerName}' ya existe en el registro global", 
          "TP_LOGGER_ALREADY_EXISTS"
        )
  
  var logger = TpLogger(
    name: loggerName,
    level: level,
    handlers: @[],
    context: initialContext,
    messageCount: 0
  )
  
  initLock(logger.lock)
  
  when defined(useAsyncLogging):
    logger.queue = newAsyncQueue[tuple[
      level: TpLogLevel,
      msg: string,
      ctx: TpLogContext,
      timestamp: string
    ]](1000)
  
  # Registrar globalmente si se solicita
  if registerGlobally:
    withLock registryLock:
      globalLoggerRegistry[loggerName] = logger
  
  tpOk(logger)

proc tpGetLogger*(name: string): TpResult[TpLogger] =
  ## Obtiene un logger del registro global
  withLock registryLock:
    if name in globalLoggerRegistry:
      tpOk(globalLoggerRegistry[name])
    else:
      tpErr[TpLogger](fmt"Logger '{name}' no encontrado", "TP_LOGGER_NOT_FOUND")

proc tpAddHandler*(
  self: TpLogger,
  handler: TpLogHandler,
  deduplicate: bool = true
): TpResult[void] =
  ## Añade un handler al logger con validación
  ## 
  ## Args:
  ##   handler: Procedimiento que procesa los logs
  ##   deduplicate: Si se deben evitar duplicados
  ##
  ## Returns:
  ##   TpResult[void] indicando éxito o error
  
  withLock self.lock:
    if self.handlers.len >= MaxHandlers:
      return tpErr[void](
        fmt"Máximo número de handlers alcanzado ({MaxHandlers})", 
        "TP_LOGGER_MAX_HANDLERS"
      )
    
    if not deduplicate or handler notin self.handlers:
      self.handlers.add(handler)
  
  tpOk()

proc tpRemoveHandler*(self: TpLogger, handler: TpLogHandler): TpResult[void] =
  ## Remueve un handler específico del logger
  withLock self.lock:
    let originalLen = self.handlers.len
    self.handlers = self.handlers.filter(proc(h: TpLogHandler): bool = h != handler)
    
    if self.handlers.len == originalLen:
      return tpErr[void]("Handler no encontrado", "TP_LOGGER_HANDLER_NOT_FOUND")
  
  tpOk()

proc tpClearHandlers*(self: TpLogger) =
  ## Remueve todos los handlers del logger
  withLock self.lock:
    self.handlers.setLen(0)

proc tpSetLogLevel*(self: TpLogger, level: TpLogLevel) =
  ## Cambia el nivel de logging del logger
  withLock self.lock:
    self.level = level

proc tpGetLogLevel*(self: TpLogger): TpLogLevel =
  ## Obtiene el nivel de logging actual
  withLock self.lock:
    result = self.level

proc tpGetMessageCount*(self: TpLogger): int =
  ## Obtiene el número total de mensajes procesados
  withLock self.lock:
    result = self.messageCount

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
    let contextStr = $(%ctx)
    result = result.replace("$context", contextStr)
  else:
    result = result.replace("$context", "")

proc tpLogImpl(
  self: TpLogger,
  level: TpLogLevel,
  msg: string,
  extra: TpLogContext
): TpResult[void] =
  ## Implementación central de logging con manejo de errores
  if level < self.level:
    return tpOk()

  let currentTime = getTime()
  var timestamp: string

  # Optimización: reutilizar timestamp si es el mismo milisegundo
  if currentTime == self.lastTime:
    timestamp = self.lastTimestamp
  else:
    timestamp = currentTime.format(TimeFormat)
    self.lastTimestamp = timestamp
    self.lastTime = currentTime

  # Combinar contexto global con contexto específico
  var combinedCtx = initTable[string, string]()
  
  withLock self.lock:
    # Incrementar contador
    inc self.messageCount
    
    # Combinar contextos
    for k, v in self.context:
      combinedCtx[k] = v
    
    for k, v in extra:
      combinedCtx[k] = v
    
    # Validar tamaño del contexto
    let contextSize = ($combinedCtx).len
    if contextSize > MaxContextSize:
      return tpErr[void](
        fmt"Contexto combinado excede tamaño máximo ({contextSize} > {MaxContextSize})", 
        "TP_LOGGER_CONTEXT_TOO_LARGE"
      )
    
    # Enviar a todos los handlers
    for handler in self.handlers:
      try:
        handler(level, msg, combinedCtx, timestamp, self.name)
      except Exception as e:
        # Registrar error en stderr para evitar recursión
        stderr.writeLine fmt"[LOGGER_ERROR] Error en handler: {e.msg}"
        return tpErr[void](
          fmt"Error en handler de logging: {e.msg}", 
          "TP_LOGGER_HANDLER_ERROR"
        )
  
  tpOk()

when defined(useAsyncLogging):
  proc tpAsyncLoggerWorker(self: TpLogger) {.async.} =
    ## Worker para procesamiento asíncrono de logs
    try:
      while true:
        let logEntry = await self.queue.pop()
        let result = tpLogImpl(self, logEntry.level, logEntry.msg, logEntry.ctx)
        if result.isError:
          stderr.writeLine fmt"[ASYNC_LOGGER_ERROR] {result.errorMsg}"
    except Exception as e:
      stderr.writeLine fmt"[ASYNC_LOGGER_FATAL] Worker error: {e.msg}"

proc tpLog*(
  self: TpLogger,
  level: TpLogLevel,
  msg: string,
  extra: TpLogContext = initTable[string, string]()
): TpResult[void] =
  ## Registra un mensaje de log
  when defined(useAsyncLogging):
    try:
      let timestamp = getTime().format(TimeFormat)
      asyncCheck self.queue.add((level, msg, extra, timestamp))
      tpOk()
    except Exception as e:
      tpErr[void](fmt"Error en logging asíncrono: {e.msg}", "TP_LOGGER_ASYNC_ERROR")
  else:
    tpLogImpl(self, level, msg, extra)

# Templates para diferentes niveles de log
template tpTrace*(self: TpLogger, msg: string, extra: TpLogContext = initTable[string, string]()): untyped =
  ## Log nivel TRACE (seguimiento detallado)
  self.tpLog(TP_TRACE, msg, extra)

template tpDebug*(self: TpLogger, msg: string, extra: TpLogContext = initTable[string, string]()): untyped =
  ## Log nivel DEBUG (información de depuración)
  self.tpLog(TP_DEBUG, msg, extra)

template tpInfo*(self: TpLogger, msg: string, extra: TpLogContext = initTable[string, string]()): untyped =
  ## Log nivel INFO (información general)
  self.tpLog(TP_INFO, msg, extra)

template tpWarn*(self: TpLogger, msg: string, extra: TpLogContext = initTable[string, string]()): untyped =
  ## Log nivel WARN (advertencias)
  self.tpLog(TP_WARN, msg, extra)

template tpError*(self: TpLogger, msg: string, extra: TpLogContext = initTable[string, string]()): untyped =
  ## Log nivel ERROR (errores recuperables)
  self.tpLog(TP_ERROR, msg, extra)

template tpFatal*(self: TpLogger, msg: string, extra: TpLogContext = initTable[string, string]()): untyped =
  ## Log nivel FATAL (errores críticos)
  self.tpLog(TP_FATAL, msg, extra)

# Handlers predefinidos
proc consoleHandler*(
  level: TpLogLevel,
  msg: string,
  ctx: TpLogContext,
  timestamp: string,
  loggerName: string
) {.gcsafe.} =
  ## Handler para escribir logs en consola con colores
  const
    Reset = "\e[0m"
    Colors: array[TpLogLevel, string] = [
      TP_TRACE: "\e[37m",    # Gris claro
      TP_DEBUG: "\e[36m",    # Cyan
      TP_INFO: "\e[32m",     # Verde
      TP_WARN: "\e[33m",     # Amarillo
      TP_ERROR: "\e[31m",    # Rojo
      TP_FATAL: "\e[41m\e[37m"  # Rojo fondo, texto blanco
    ]
  
  let formatted = tpFormatMessage(level, msg, ctx, timestamp, loggerName)
  
  # Escribir a stderr para errores y warnings, stdout para el resto
  if level >= TP_WARN:
    stderr.writeLine Colors[level] & formatted & Reset
  else:
    stdout.writeLine Colors[level] & formatted & Reset

when defined(useFileLogging):
  proc tpFileHandler*(
    logFile: string,
    maxSize: int64 = MaxLogSize,
    format: string = DefaultLogFormat,
    compress: bool = false
  ): TpResult[TpLogHandler] =
    ## Crea un handler que escribe logs en archivo con rotación
    ## 
    ## Args:
    ##   logFile: Ruta del archivo de log
    ##   maxSize: Tamaño máximo antes de rotar
    ##   format: Formato personalizado para los mensajes
    ##   compress: Si se debe comprimir el archivo rotado
    ##
    ## Returns:
    ##   TpResult[TpLogHandler] con el handler creado o error
    
    # Validar que el directorio existe
    let logDir = parentDir(logFile)
    if not dirExists(logDir):
      return tpErr[TpLogHandler](
        fmt"Directorio de log no existe: {logDir}", 
        "TP_LOGGER_INVALID_LOG_DIR"
      )
    
    var fileLock: Lock
    initLock(fileLock)
    
    let handler = proc(
      level: TpLogLevel,
      msg: string,
      ctx: TpLogContext,
      timestamp: string,
      loggerName: string
    ) {.gcsafe.} =
      withLock fileLock:
        try:
          # Verificar rotación
          if fileExists(logFile) and getFileSize(logFile) > maxSize:
            let backupFile = logFile & "." & getTime().format("yyyyMMdd_HHmmss")
            moveFile(logFile, backupFile)
            
            when defined(useCompression) and compress:
              # Comprimir archivo rotado (requiere biblioteca externa)
              discard
          
          let formatted = tpFormatMessage(level, msg, ctx, timestamp, loggerName, format)
          let f = open(logFile, fmAppend)
          defer: f.close()
          f.writeLine(formatted)
          f.flushFile()  # Asegurar que se escriba inmediatamente
          
        except IOError as e:
          stderr.writeLine fmt"[FILE_HANDLER_ERROR] Error escribiendo log: {e.msg}"
        except Exception as e:
          stderr.writeLine fmt"[FILE_HANDLER_ERROR] Error inesperado: {e.msg}"
    
    tpOk(handler)

# Funciones de conveniencia para el logger por defecto
template tpLog*(level: TpLogLevel, msg: string, extra: TpLogContext = initTable[string, string]()): untyped =
  getDefaultLogger().tpLog(level, msg, extra)

template tpTrace*(msg: string, extra: TpLogContext = initTable[string, string]()): untyped =
  getDefaultLogger().tpTrace(msg, extra)

template tpDebug*(msg: string, extra: TpLogContext = initTable[string, string]()): untyped =
  getDefaultLogger().tpDebug(msg, extra)

template tpInfo*(msg: string, extra: TpLogContext = initTable[string, string]()): untyped =
  getDefaultLogger().tpInfo(msg, extra)

template tpWarn*(msg: string, extra: TpLogContext = initTable[string, string]()): untyped =
  getDefaultLogger().tpWarn(msg, extra)

template tpError*(msg: string, extra: TpLogContext = initTable[string, string]()): untyped =
  getDefaultLogger().tpError(msg, extra)

template tpFatal*(msg: string, extra: TpLogContext = initTable[string, string]()): untyped =
  getDefaultLogger().tpFatal(msg, extra)

# Inicialización del sistema
initLoggingSystem()
initDefaultLogger()

# Añadir handler de consola por defecto en modo debug
when not defined(release):
  discard getDefaultLogger().tpAddHandler(consoleHandler, deduplicate = false)