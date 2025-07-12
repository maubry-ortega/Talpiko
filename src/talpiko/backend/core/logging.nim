# src/talpiko/backend/core/logging.nim
## Módulo de logging para Talpiko Framework
## Proporciona un sistema flexible de registro de eventos con niveles y contextos.

import times, strutils, tables
when defined(useFileLogging):
  import os

type
  TpLogLevel* = enum
    TP_DEBUG, TP_INFO, TP_WARN, TP_ERROR, TP_FATAL

  TpLogHandler* = proc(level: TpLogLevel, msg: string, ctx: Table[string, string], timestamp: string)

  TpLogger* = ref object
    level*: TpLogLevel
    handlers*: seq[TpLogHandler]
    context*: Table[string, string]
    lastTimestamp*: string
    lastTime*: Time

proc newTpLogger*(level: TpLogLevel = TP_INFO): TpLogger =
  ## Crea una nueva instancia de TpLogger con el nivel de log especificado.
  ## Args:
  ##   level: Nivel mínimo de severidad para los mensajes de log.
  new result
  result.level = level
  result.handlers = @[]
  result.context = initTable[string, string]()
  result.lastTimestamp = ""
  result.lastTime = getTime()

var defaultTpLogger* = newTpLogger(TP_INFO)

proc tpAddHandler*(self: TpLogger, handler: TpLogHandler) =
  ## Añade un handler al logger, evitando duplicados.
  ## Args:
  ##   handler: Procedimiento que procesa los mensajes de log.
  if handler notin self.handlers:
    self.handlers.add(handler)

proc tpFormatLogLine(level: TpLogLevel, msg: string, ctx: Table[string, string], timestamp: string): string {.inline.} =
  ## Formatea una línea de log de manera eficiente.
  let levelStr = alignLeft($level, 5)
  result = "[$1] [$2] $3" % [timestamp, levelStr, msg]
  if ctx.len > 0:
    result &= " $1" % [$ctx]

proc tpLog*(self: TpLogger, level: TpLogLevel, msg: string, extra: Table[string, string] = initTable[string, string]()) =
  ## Registra un mensaje con nivel y contexto.
  ## Args:
  ##   level: Nivel de severidad del mensaje.
  ##   msg: Mensaje a registrar.
  ##   extra: Contexto adicional como pares clave-valor.
  if level >= self.level:
    let currentTime = getTime()
    let timestamp = if currentTime == self.lastTime:
      self.lastTimestamp
    else:
      self.lastTimestamp = currentTime.format("yyyy-MM-dd HH:mm:ss")
      self.lastTimestamp
    var ctx: Table[string, string]
    if self.context.len > 0 or extra.len > 0:
      ctx = initTable[string, string]()
      for k, v in self.context: ctx[k] = v
      for k, v in extra: ctx[k] = v
    
    for handler in self.handlers:
      handler(level, msg, ctx, timestamp)

template tpDebug*(self: TpLogger, msg: string, extra: Table[string, string] = initTable[string, string]()) =
  self.tpLog(TP_DEBUG, msg, extra)

template tpInfo*(self: TpLogger, msg: string, extra: Table[string, string] = initTable[string, string]()) =
  self.tpLog(TP_INFO, msg, extra)

template tpWarn*(self: TpLogger, msg: string, extra: Table[string, string] = initTable[string, string]()) =
  self.tpLog(TP_WARN, msg, extra)

template tpError*(self: TpLogger, msg: string, extra: Table[string, string] = initTable[string, string]()) =
  self.tpLog(TP_ERROR, msg, extra)

template tpFatal*(self: TpLogger, msg: string, extra: Table[string, string] = initTable[string, string]()) =
  self.tpLog(TP_FATAL, msg, extra)

# Handler por defecto (Consola)
defaultTpLogger.tpAddHandler proc(level: TpLogLevel, msg: string, ctx: Table[string, string], timestamp: string) =
  stdout.write tpFormatLogLine(level, msg, ctx, timestamp) & "\n"

when defined(useFileLogging):
  proc tpFileHandler*(logFile: string, maxSize: int64 = 10_000_000): TpLogHandler =
    ## Crea un handler que escribe logs en un archivo con rotación.
    ## Args:
    ##   logFile: Ruta del archivo donde se escribirán los logs.
    ##   maxSize: Tamaño máximo del archivo antes de rotar (en bytes).
    result = proc(level: TpLogLevel, msg: string, ctx: Table[string, string], timestamp: string) =
      if fileExists(logFile) and getFileSize(logFile) > maxSize:
        moveFile(logFile, logFile & ".bak")
      let logLine = tpFormatLogLine(level, msg, ctx, timestamp)
      try:
        let f = open(logFile, fmAppend)
        defer: f.close()
        f.writeLine(logLine)
      except IOError as e:
        stdout.write "Failed to write to log file: $1\n" % [e.msg]