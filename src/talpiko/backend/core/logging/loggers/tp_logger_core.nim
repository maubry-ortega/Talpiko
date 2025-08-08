import std/times
import ../types/tp_base_types
import ../types/tp_log_types

proc log*(logger: TpLogger, level: TpLogLevel, msg: string): TpLogResult =
  let record = TpLogRecord(
    msg: msg,
    level: level,
    timestamp: now(),
    metadata: @[]
  )
  
  try:
    for handler in logger.handlers:
      {.cast(gcsafe).}:
        handler.handle(record)  # Llamada correcta al método
    tpOk()
  except Exception as e:
    tpErr("Logging failed: " & e.msg, "LOG_ERROR")