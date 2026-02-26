# src/talpiko/backend/core/logging.nim
## Módulo de logging para Talpiko Framework
## Proporciona un sistema flexible de registro de eventos con niveles y contextos.

import times, strutils
when defined(useFileLogging):
  import os

type
  TpLogLevel* = enum
    tpllDebug, tpllInfo, tpllWarn, tpllError, tpllFatal


  TpLogHandler* = proc(level: TpLogLevel, msg: string, ctx: seq[(string, string)], timestamp: string) {.gcsafe.}


  TpLogger* = ref object
    level*: TpLogLevel
    handlers*: seq[TpLogHandler]
    context*: seq[(string, string)]

    lastTimestamp*: string
    lastTime*: Time

proc newTpLogger*(level: TpLogLevel = tpllInfo): TpLogger =
  ## Crea una nueva instancia de TpLogger con el nivel de log especificado.
  ## Args:
  ##   level: Nivel mínimo de severidad para los mensajes de log.

  new result
  result.level = level
  result.handlers = @[]
  result.context = @[]
  result.lastTimestamp = ""
  result.lastTime = getTime()

var defaultTpLogger* = newTpLogger(tpllInfo)


proc tpAddHandler*(self: TpLogger, handler: TpLogHandler) =
  ## Añade un handler al logger, evitando duplicados.
  ## Args:
  ##   handler: Procedimiento que procesa los mensajes de log.
  if handler notin self.handlers:
    self.handlers.add(handler)

proc tpFormatLogLine*(level: TpLogLevel, msg: string, ctx: seq[(string, string)], timestamp: string): string {.inline, gcsafe.} =
  ## Formatea una línea de log de manera eficiente.
  let levelStr = alignLeft($level, 5)
  result = "[$1] [$2] $3" % [timestamp, levelStr, msg]
  if ctx.len > 0:
    result &= " ("
    for i, pair in ctx:
      if i > 0: result &= ", "
      result &= pair[0] & "=" & pair[1]
    result &= ")"


proc tpLog*(self: TpLogger, level: TpLogLevel, msg: string, extra: openArray[(string, string)] = []) {.gcsafe.} =
  ## Registra un mensaje con nivel y contexto.
  if level >= self.level:
    let currentTime = getTime()
    let timestamp = if currentTime == self.lastTime:
      self.lastTimestamp
    else:
      self.lastTimestamp = currentTime.format("yyyy-MM-dd HH:mm:ss")
      self.lastTime = currentTime
      self.lastTimestamp
    
    var ctx: seq[(string, string)] = @[]
    if self.context.len > 0:
      ctx.add(self.context)
    if extra.len > 0:
      for pair in extra:
        ctx.add(pair)
    
    for handler in self.handlers:
      handler(level, msg, ctx, timestamp)


template tpDebug*(self: TpLogger, msg: string, extra: openArray[(string, string)] = []) =
  self.tpLog(tpllDebug, msg, extra)

template tpInfo*(self: TpLogger, msg: string, extra: openArray[(string, string)] = []) =
  self.tpLog(tpllInfo, msg, extra)

template tpWarn*(self: TpLogger, msg: string, extra: openArray[(string, string)] = []) =
  self.tpLog(tpllWarn, msg, extra)

template tpError*(self: TpLogger, msg: string, extra: openArray[(string, string)] = []) =
  self.tpLog(tpllError, msg, extra)

template tpFatal*(self: TpLogger, msg: string, extra: openArray[(string, string)] = []) =
  self.tpLog(tpllFatal, msg, extra)



# Handler por defecto (Consola)
defaultTpLogger.tpAddHandler proc(level: TpLogLevel, msg: string, ctx: seq[(string, string)], timestamp: string) {.gcsafe.} =
  stdout.write tpFormatLogLine(level, msg, ctx, timestamp) & "\n"


when defined(useFileLogging):
  proc tpFileHandler*(logFile: string, maxSize: int64 = 10_000_000): TpLogHandler =
    ## Crea un handler que escribe logs en un archivo con rotación.
    ## Args:
    ##   logFile: Ruta del archivo donde se escribirán los logs.
    ##   maxSize: Tamaño máximo del archivo antes de rotar (en bytes).
    result = proc(level: TpLogLevel, msg: string, ctx: seq[(string, string)], timestamp: string) =

      if fileExists(logFile) and getFileSize(logFile) > maxSize:
        moveFile(logFile, logFile & ".bak")
      let logLine = tpFormatLogLine(level, msg, ctx, timestamp)
      try:
        let f = open(logFile, fmAppend)
        defer: f.close()
        f.writeLine(logLine)
      except IOError as e:
        stdout.write "Failed to write to log file: $1\n" % [e.msg]