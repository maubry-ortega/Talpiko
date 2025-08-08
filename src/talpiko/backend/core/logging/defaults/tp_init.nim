import ../loggers/tp_logger_factory
import ../handlers/tp_console_handler

proc initLoggingSystem*(): TpLogResult =
  tpOk()

proc initDefaultLogger*(): TpLogger =
  let logger = newLogger()
  discard logger.addHandler(newConsoleHandler())
  logger