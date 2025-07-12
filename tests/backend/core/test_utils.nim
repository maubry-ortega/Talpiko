# tests/test_utils.nim
## Utilidades para pruebas en Talpiko Framework

import ../../src/talpiko/backend/core/logging

proc createTestTpLogger*(): TpLogger =
  ## Crea un logger configurado para pruebas.
  result = newTpLogger(TP_DEBUG)
  result.tpAddHandler proc(level: TpLogLevel, msg: string, ctx: Table[string, string], timestamp: string) =
    echo "[TEST] [$1] $2 $3" % [$level, msg, $ctx]