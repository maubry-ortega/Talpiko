import std/times
import ../../types/primitives/tp_result

type
  TpLogLevel* = enum
    lvlDebug, lvlInfo, lvlWarn, lvlError, lvlFatal
  
  TpLogRecord* = object
    msg*: string
    level*: TpLogLevel
    timestamp*: DateTime
    metadata*: seq[(string, string)]

  TpLogger* = ref object
    handlers*: seq[TpLogHandler]
    level*: TpLogLevel

  TpLogResult* = TpResult[void]