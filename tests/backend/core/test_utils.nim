# tests/test_utils.nim
## Utilidades para pruebas en Talpiko Framework

import strutils, ../../../src/talpiko/backend/core/logging

proc createTestTpLogger*(): TpLogger =
  ## Crea un logger configurado para pruebas.
  result = newTpLogger(tpllDebug)
  result.tpAddHandler proc(level: TpLogLevel, msg: string, ctx: seq[(string, string)], timestamp: string) {.gcsafe.} =
    echo "[TEST] [$1] $2 $3" % [$level, msg, $ctx]