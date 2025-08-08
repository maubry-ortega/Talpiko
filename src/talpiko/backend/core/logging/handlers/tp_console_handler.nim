# src/talpiko/backend/core/logging/handlers/tp_console_handler.nim

import ../types/tp_base_types
import ../types/tp_log_types

type
  TpConsoleHandler* = ref object of TpLogHandler
    colorEnabled*: bool
    formatter*: proc(record: TpLogRecord): string {.gcsafe.}  # Añadido {.gcsafe.}

method handle*(self: TpConsoleHandler, record: TpLogRecord) {.gcsafe.} =
  ## Implementación segura para GC del handler de consola
  try:
    let formattedMsg = 
      if not self.formatter.isNil:
        self.formatter(record)  # Ahora es seguro para GC
      else:
        "[" & $record.level & "] " & record.msg
    
    echo formattedMsg
  except Exception as e:
    stderr.writeLine "ConsoleHandler error: " & e.msg

proc newConsoleHandler*(): TpConsoleHandler =
  ## Crea un nuevo handler de consola configurado por defecto
  new(result)
  result.colorEnabled = true
  result.formatter = proc(record: TpLogRecord): string {.gcsafe.} =
    # Formateador por defecto seguro para GC
    const levelStrs = ["DEBUG", "INFO", "WARN", "ERROR", "FATAL"]
    "[" & levelStrs[ord(record.level)] & "] " & record.msg