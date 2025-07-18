## 📄 tp_conversions.nim
##
## 📌 Módulo: Constructores Derivados (`tpFrom*`)
## 📦 Parte del sistema de tipos de Talpo / Talpiko
##
## 🎯 Responsabilidad:
##   Facilitar la conversión segura de estructuras comunes (`Option[T]`, `bool`, `ref Exception`)
##   a `TpResult[T]` para adaptar sistemas legados o externos sin refactorizar lógica.
##
## 🔍 Características clave:
## - Conversiones seguras sin panics
## - Adaptadores tipados con `TpResult[T]`
## - Fallbacks estándar para errores
## - Manejo de excepciones funcional (`try/catch`)

# ─────────────────────────────────────────────────────────────────────────────
# 📦 Importaciones necesarias
# ─────────────────────────────────────────────────────────────────────────────

import std/[options, tables]
import ../primitives/[tp_result, tp_interfaces, tp_error]
import ./tp_failure, ./tp_success

# ─────────────────────────────────────────────────────────────────────────────
# ⚙️ Configuración condicional de compilación
# ─────────────────────────────────────────────────────────────────────────────

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
): TpResult[T] {.inline, noSideEffect.} =
  ## 🔄 Convierte un `Option[T]` a un `TpResult[T]`
  ##
  ## Si `opt` contiene un valor (`some`), se retorna `tpOk(valor)`.
  ## Si no (`none`), retorna `tpErr[T](fallbackMsg, fallbackCode)`.
  ##
  ## 🚨 El mensaje y código por defecto indican validación ausente.
  ##
  ## 🧪 runnableExamples:
  ## ```nim
  ## assert tpFromOption(some(123)).isSuccess
  ## assert tpFromOption(none(int)).isFailure
  ## ```
  if opt.isSome:
    tpOk[T](opt.get())
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
): TpResult[T] {.inline, noSideEffect.} =
  ## 🧠 Convierte una condición booleana en un `TpResult[T]`
  ##
  ## Si `cond` es `true`, retorna `tpOk(value)`.  
  ## Si `cond` es `false`, genera un error con `tpErr[T](errMsg, errCode)`.
  ##
  ## Ideal para validaciones simples y expresivas.
  ##
  ## 🧪 runnableExamples:
  ## ```nim
  ## assert tpFromBool(true, "ok").isSuccess
  ## assert tpFromBool(false, "bad", "Falló").isFailure
  ## ```
  if cond:
    tpOk(value)
  else:
    tpErr[T](errMsg, errCode)

# ─────────────────────────────────────────────────────────────────────────────
# ⚠️ Conversión desde Exception
# ─────────────────────────────────────────────────────────────────────────────

proc tpFromException*[T](
  e: ref Exception,
  code: string = "EXCEPTION",
  severity: TpErrorSeverity = tpHigh,
  context: Table[string, string] = initTable[string, string]()
): TpResult[T] =
  tpErr[T](
    msg = e.msg,
    code = code,
    severity = severity,
    context = context,
    original = e
  )

# ─────────────────────────────────────────────────────────────────────────────
# 🌀 Try/Catch Funcional
# ─────────────────────────────────────────────────────────────────────────────

proc tpTryCatch*[T](op: proc (): T): TpResult[T] =
  ## 🌀 Ejecuta un bloque `proc () -> T` atrapando excepciones como `TpResult[T]`
  ##
  ## Si la operación ejecuta correctamente, retorna `tpOk(valor)`.
  ## Si lanza una excepción, se captura y se convierte con `tpFromException`.
  ##
  ## Esta función permite integrar código no monádico de forma segura.
  ##
  ## 🧪 runnableExamples:
  ## ```nim
  ## proc f(): int = raise newException(IOError, "fail")
  ## let res = tpTryCatch[int](f)
  ## assert res.isFailure
  ##
  ## let res2 = tpTryCatch[int](proc() => 42)
  ## assert res2 == tpOk(42)
  ## ```
  try:
    tpOk(op())
  except CatchableError as e:
    tpFromException[T](e)

# ─────────────────────────────────────────────────────────────────────────────
# 🔚 Finaliza configuración
# ─────────────────────────────────────────────────────────────────────────────

{.pop.}
