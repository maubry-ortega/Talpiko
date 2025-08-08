# 📁 Archivo: src/talpiko/backend/core/prueba_funcionalidades.nim
# 🎯 Demostración mejorada de flujo monádico + async en Talpo/Talpiko

import std/asyncdispatch
import std/strutils
import std/strformat
import std/unittest
import ../../../src/talpiko/backend/core/types

# ─────────────────────────────────────────────────────────────────────────────
# 🛠️ Constantes y tipos auxiliares
# ─────────────────────────────────────────────────────────────────────────────

const
  DEFAULT_USER = "UNKNOWN_USER"
  USER_PREFIX = "User#"

# ─────────────────────────────────────────────────────────────────────────────
# 📦 Validación tipada del ID del usuario (mejorada)
# ─────────────────────────────────────────────────────────────────────────────

proc validateUserId(id: string): TpResult[int] =
  ## Versión mejorada usando tipos Talpiko
  try:
    let num = id.parseInt()
    if num <= 0:
      let msg = fmt"El ID de usuario debe ser positivo (se recibió: {num})"
      return tpErr[int](msg, code = "INVALID_ID", severity = TpErrorSeverity.tpMedium)
    tpOk(num)
  except ValueError:
    let msg = fmt"No se pudo convertir el ID '{id}' a número"
    tpErr[int](msg, code = "PARSE_ERROR", severity = TpErrorSeverity.tpHigh)

# ─────────────────────────────────────────────────────────────────────────────
# 📦 Simulación asincrónica de acceso a base de datos (mejorada)
# ─────────────────────────────────────────────────────────────────────────────

proc fetchUserFromDb(id: int): Future[TpResult[string]] {.async.} =
  ## Versión mejorada usando convenciones Talpiko
  await sleepAsync(100)  # Simula latencia de red
  
  if id == 42:
    let msg = fmt"Usuario con ID {id} no encontrado en la base de datos"
    return tpErr[string](msg, code = "NOT_FOUND", severity = TpErrorSeverity.tpHigh)
  
  tpOk(USER_PREFIX & $id)

# ─────────────────────────────────────────────────────────────────────────────
# 📦 Formateo de nombre (mejorado)
# ─────────────────────────────────────────────────────────────────────────────

proc formatUser(name: string): string =
  ## Versión mejorada con validación adicional
  if name.len == 0:
    return DEFAULT_USER
  name.toUpperAscii()

# ─────────────────────────────────────────────────────────────────────────────
# 🧠 Lógica principal mejorada (usando operadores Talpiko)
# ─────────────────────────────────────────────────────────────────────────────

proc getUserDisplay(idStr: string): Future[string] {.async.} =
  ## Versión mejorada usando operadores monádicos Talpiko
  
  # 1️⃣ Validación con logging contextual
  let userId = validateUserId(idStr)
    .tpTap(proc(id: int) = echo fmt"[DEBUG] Validación exitosa para ID: {id}")
    .tpTapError(proc(e: ref TpResultError) = 
      echo fmt"[ERROR] Fallo en validación: {e.msg} (código: {e.code})")
  
  if userId.tpIsFailure():
    return DEFAULT_USER

  # 2️⃣ Consulta asincrónica con manejo de errores
  let dbResult = await userId.tpThenAsync(fetchUserFromDb)
  
  let user = dbResult
    .tpTap(proc(name: string) = echo fmt"[DEBUG] Usuario obtenido: {name}")
    .tpTapError(proc(e: ref TpResultError) = 
      echo fmt"[WARN] Error al obtener usuario: {e.msg}")

  # 3️⃣ Formateo final con fallback
  return user
    .tpMap(formatUser)
    .tpUnwrapOr(DEFAULT_USER)

# ─────────────────────────────────────────────────────────────────────────────
# 🧪 Suite de pruebas mejorada
# ─────────────────────────────────────────────────────────────────────────────

when isMainModule:
  suite "Pruebas de getUserDisplay":
    test "ID válido":
      check waitFor(getUserDisplay("12")) == "USER#12"
    
    test "Usuario no encontrado (ID 42)":
      check waitFor(getUserDisplay("42")) == DEFAULT_USER
    
    test "ID inválido (no numérico)":
      check waitFor(getUserDisplay("abc")) == DEFAULT_USER
    
    test "ID negativo":
      check waitFor(getUserDisplay("-1")) == DEFAULT_USER
    
    test "ID cero":
      check waitFor(getUserDisplay("0")) == DEFAULT_USER

  echo "✅ Todas las pruebas pasaron"