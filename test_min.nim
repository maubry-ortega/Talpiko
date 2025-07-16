import std/times

type
  TpResultError = ref object
    timestamp: float64
    msg: string
    code: string

proc newTpResultError(msg, code: string): TpResultError =
  new(result)
  result.timestamp = epochTime()
  result.msg = msg
  result.code = code

let e = newTpResultError("hello", "E001")
echo e.msg, " ", e.code, " ", e.timestamp