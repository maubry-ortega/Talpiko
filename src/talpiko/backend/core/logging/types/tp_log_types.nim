import ./tp_base_types
import ../../types/primitives/tp_result

type
  TpLogHandler* = ref object of RootObj
    formatter*: proc(record: TpLogRecord): string

  TpLogger* = ref object
    handlers*: seq[TpLogHandler]
    level*: TpLogLevel

  TpLogResult* = TpResult[void]