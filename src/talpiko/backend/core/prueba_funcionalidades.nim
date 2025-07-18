# 📁 Archivo: src/talpiko/backend/core/prueba_funcionalidades.nim
# 🎯 Demostración de flujo monádico + async en Talpo/Talpiko

import std/asyncdispatch
import std/strutils
import ./types
import ./types/extensions/async

# ─────────────────────────────────────────────────────────────────────────────
# 📦 Validación tipada del ID del usuario
# ─────────────────────────────────────────────────────────────────────────────

proc validateUserId(id: string): TpResult[int] =
  ## Intenta convertir un string a ID entero positivo.
  ## Devuelve error si no es convertible o si es negativo/cero.
  try:
    let num = parseInt(id)
    if num <= 0:
      return tpErr[int]("ID must be positive", code = "INVALID_ID")
    tpOk(num)
  except ValueError as e:
    tpFromException[int](e, code = "PARSE_ERROR")

# ─────────────────────────────────────────────────────────────────────────────
# 📦 Simulación asincrónica de acceso a base de datos
# ─────────────────────────────────────────────────────────────────────────────

proc fetchUserFromDb(id: int): Future[TpResult[string]] =
  ## Simula la consulta a una base de datos.
  ## Falla si el ID es 42 (usuario no encontrado).
  tpAsync(proc(): TpResult[string] =
    if id == 42:
      tpErr[string]("User not found", code = "NOT_FOUND", severity = tpMedium)
    else:
      tpOk("User#" & $id)
  )

# ─────────────────────────────────────────────────────────────────────────────
# 📦 Formateo de nombre
# ─────────────────────────────────────────────────────────────────────────────

proc formatUser(name: string): string =
  ## Devuelve el nombre en mayúsculas.
  name.toUpperAscii()

# ─────────────────────────────────────────────────────────────────────────────
# 🧠 Lógica principal: validar → buscar → formatear
# ─────────────────────────────────────────────────────────────────────────────

proc getUserDisplay(idStr: string): Future[string] {.async.} =
  ## Flujo completo con manejo monádico y asincrónico:
  ## 1. Valida ID
  ## 2. Consulta usuario (async)
  ## 3. Formatea nombre
  ## 4. Recupera con valor por defecto si ocurre error

  # 1️⃣ Validación
  let validated = validateUserId(idStr)

  # 2️⃣ Logs de validación
  discard validated
    .tpTap(proc(validId: int) =
      echo "✅ Validated user ID: ", validId
    )
    .tpTapError(proc(err: ref TpResultError) =
      echo "⚠️ [Validation Error] ", err.msg
    )

  # 3️⃣ Si la validación falla, retorna directamente con fallback
  if validated.tpIsFailure():
    return "UNKNOWN_USER"

  # 4️⃣ Consulta asincrónica a DB
  let fetched = await validated.tpThenAsync(proc(validId: int): Future[TpResult[string]] =
    fetchUserFromDb(validId)
  )

  # 5️⃣ Logs de fetch
  discard fetched
    .tpTap(proc(name: string) =
      echo "✅ Fetched user: ", name
    )
    .tpTapError(proc(err: ref TpResultError) =
      echo "⚠️ [DB Error] ", err.msg
    )

  # 6️⃣ Formatea o recupera si hay error
  return fetched
    .tpMap(formatUser)
    .tpUnwrapOr("UNKNOWN_USER")

# ─────────────────────────────────────────────────────────────────────────────
# 🧪 Ejecución interactiva (pruebas básicas)
# ─────────────────────────────────────────────────────────────────────────────

when isMainModule:
  echo waitFor getUserDisplay("12")   # ✅ válido
  echo "---"
  echo waitFor getUserDisplay("42")   # ❌ no encontrado
  echo "---"
  echo waitFor getUserDisplay("abc")  # ❌ inválido (parse error)
  echo "---"
  echo waitFor getUserDisplay("-1")   # ❌ ID negativo
