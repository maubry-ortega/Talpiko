import ../types/tp_log_types
import ../handlers/tp_console_handler

proc newLogger*(): TpLogger =
  new(result)
  result.handlers = @[newConsoleHandler()]
  result.level = lvlInfo