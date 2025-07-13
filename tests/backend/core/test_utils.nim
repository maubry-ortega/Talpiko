# tests/backend/core/test_utils.nim
import tables, strutils
import ../../../src/talpiko/backend/core/logging

proc createTestTpLogger*(): TpLogger =
  ## Crea un logger configurado para pruebas
  result = newTpLogger(TP_DEBUG)
  result.tpAddHandler proc(level: TpLogLevel, msg: string, 
                         ctx: Table[string, string], timestamp: string) =
    echo "[TEST] [$1] $2" % [timestamp, msg]