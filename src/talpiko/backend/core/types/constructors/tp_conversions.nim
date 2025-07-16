## from.nim
##
## Módulo: Constructores Derivados (`tpFrom*`)
## Sistema: Talpo / Talpiko - Core Types
##
## Responsabilidad:
##   Facilitar la conversión de estructuras comunes (`Option`, `bool`, `ref Exception`)
##   al sistema de tipos `TpResult[T]` para integrar sistemas externos o legados.
##
## Características Clave:
## - Adaptación de tipos externos a `TpResult[T]`
## - Tipado genérico seguro
## - Fallbacks personalizables
## - Soporte para excepciones

import std/[options, tables, strutils]
import ../primitives/[tp_result, tp_error, tp_interfaces]
import ./tp_failure, ./tp_success

when defined(release):
  {.push checks: off.}
else:
  {.push stackTrace: on.}

# ─────────────────────────────────────────────────────────────────────────────
# 🔁 Conversión desde Option[T]
# ─────────────────────────────────────────────────────────────────────────────

proc tpFromOption*[T](
  opt: Option[T],
  fallbackMsg: string = "Valor ausente",
  fallbackCode: string = tpValidationErrorCode
): TpResult[T] {.inline.} =
  ## Convierte un `Option[T]` a `TpResult[T]`
  ##
  ## Si `opt` es `some`, retorna éxito. Si es `none`, retorna error validado.
  ##
  ## Ejemplo:
  ## ```nim
  ## let res = tpFromOption(findUser(), "Usuario no encontrado")
  ## ```
  if opt.isSome:
    tpOk(opt.get())
  else:
    tpErr[T](fallbackMsg, fallbackCode)

# ─────────────────────────────────────────────────────────────────────────────
# 🔁 Conversión desde Bool
# ─────────────────────────────────────────────────────────────────────────────

proc tpFromBool*[T](
  cond: bool,
  value: T,
  errMsg: string = "Condición no cumplida",
  errCode: string = tpValidationErrorCode
): TpResult[T] {.inline.} =
  ## Construye un `TpResult[T]` desde un valor booleano
  ##
  ## Si `cond` es `true`, retorna `value`. Si no, construye un error.
  ##
  ## Ejemplo:
  ## ```nim
  ## let res = tpFromBool(age > 18, user, "Debe ser mayor de edad")
  ## ```
  if cond:
    tpOk(value)
  else:
    tpErr[T](errMsg, errCode)

# ─────────────────────────────────────────────────────────────────────────────
# ⚠️ Conversión desde Exception
# ─────────────────────────────────────────────────────────────────────────────

proc tpFromException*[T](e: ref Exception): TpResult[T] {.inline.} =
  ## Convierte una excepción atrapada en un `TpResult[T]` de error
  ##
  ## La excepción original se conserva en el campo `originalException`
  tpErr[T](
    msg = e.msg,
    code = tpInternalErrorCode,
    severity = tpHigh,
    original = e
  )

# ─────────────────────────────────────────────────────────────────────────────
# 🌀 Try/Catch Funcional
# ─────────────────────────────────────────────────────────────────────────────

proc tpTryCatch*[T](op: proc (): T): TpResult[T] =
  ## Ejecuta una operación que puede lanzar excepción, devolviendo `TpResult[T]`
  ##
  ## Uso seguro para integrar APIs que aún no retornan `TpResult`.
  ##
  ## Ejemplo:
  ## ```nim
  ## let res = tpTryCatch(proc(): int = parseInt(input))
  ## ```
  try:
    tpOk(op())
  except Exception as e:
    tpFromException[T](e)

{.pop.}
