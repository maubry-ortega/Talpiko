import ../types/tp_base_types

type
  TpLogHandler* = ref object of RootObj
    formatter*: proc(record: TpLogRecord): string

method handle*(self: TpLogHandler, record: TpLogRecord) {.base, gcsafe.} =
  ## Método base que debe ser implementado por handlers concretos
  raise newException(Exception, "handle method not implemented")