import ../types/tp_types
import ../../types

template tpLogTry*(body: untyped): TpLogResult =
  try:
    body
    tpOk()
  except Exception as e:
    tpErr(e.msg, "LOG_OP_ERROR", original=e)