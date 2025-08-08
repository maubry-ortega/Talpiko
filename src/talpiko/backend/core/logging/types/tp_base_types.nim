import std/times

type
  TpLogLevel* = enum
    lvlDebug, lvlInfo, lvlWarn, lvlError, lvlFatal

  TpLogRecord* = object
    msg*: string
    level*: TpLogLevel
    timestamp*: DateTime
    metadata*: seq[(string, string)]