## 📄 tp_failure.nim
##
## 📌 Módulo: Constructores de Error para TpResult
## 📦 Parte del sistema de tipos de Talpo / Talpiko
##
## 🎯 Responsabilidad:
##   Provee constructores seguros para resultados fallidos de tipo `TpResult[T]`
##   encapsulando errores enriquecidos (`TpResultError`) con metadata, contexto
##   adicional y fallback automático ante fallas de construcción.
##
## 🔍 Características clave:
## - Retorna `TpResult[T]` en estado `tpFailure`
## - Captura excepciones y evita panics
## - Generación segura de `ref TpResultError`
## - Compatible con logs, debug y serialización

# ─────────────────────────────────────────────────────────────────────────────
# 📦 Importaciones necesarias
# ─────────────────────────────────────────────────────────────────────────────

import ../primitives/[tp_result, tp_error, tp_interfaces]
import std/[tables, times]

# ─────────────────────────────────────────────────────────────────────────────
# ⚙️ Configuración condicional de compilación
# ─────────────────────────────────────────────────────────────────────────────

when defined(release):
  {.push checks: off.}
else:
  {.push stackTrace: on.}

# ─────────────────────────────────────────────────────────────────────────────
# 🛠️ Constructor Seguro de Resultados Fallidos
# ─────────────────────────────────────────────────────────────────────────────

proc tpErr*[T](
  msg: string,
  code: string = tpDefaultErrorCode,
  severity: TpErrorSeverity = tpMedium,
  context: Table[string, string] = initTable[string, string](),
  original: ref Exception = nil
): TpResult[T] =
  ## 🔧 Crea un `TpResult[T]` en estado `tpFailure` con un error estructurado
  ##
  ## Seguridad:
  ## - Maneja cualquier excepción lanzada al construir el error
  ## - Nunca lanza panics: usa fallback automático con severidad `tpCritical`
  ##
  ## Uso típico:
  ## ```nim
  ## let result = tpErr[int]("Algo falló", "TP_FAIL", tpHigh)
  ## ```
  ##
  ## Argumentos:
  ## - `msg`: mensaje descriptivo del error
  ## - `code`: código de error (por defecto: `TP_UNKNOWN`)
  ## - `severity`: nivel de severidad (default: `tpMedium`)
  ## - `context`: metadatos adicionales
  ## - `original`: excepción original (opcional)
  ##
  ## Retorna:
  ## - `TpResult[T]` en estado `tpFailure` con error adjunto
  var errorObj: ref TpResultError
  try:
    errorObj = newTpResultErrorRef(msg, code, severity, context, original)
  except CatchableError as e:
    ## Fallback extremo si falla incluso la creación del error
    echo "Error creating error: " & e.msg
    errorObj = newTpResultErrorRef(
      "Error creating error: " & e.msg,
      "TP_ERROR_FAILURE",
      tpCritical
    )

  TpResult[T](
    kind: tpFailure,
    error: errorObj,
    metadata: TpResultMetadata(creationTime: epochTime())
  )

# ─────────────────────────────────────────────────────────────────────────────
# 🪄 Template Semántico: `tpFailure`
# ─────────────────────────────────────────────────────────────────────────────

template tpFailure*[T](
  msg: string,
  code: string = tpDefaultErrorCode,
  severity: TpErrorSeverity = tpMedium,
  context: Table[string, string] = initTable[string, string](),
  original: ref Exception = nil
): TpResult[T] =
  ## 🪄 Azúcar sintáctico para `tpErr[T]`, más legible y expresivo
  ##
  ## Ventajas:
  ## - Más claro al expresar intencionalidad semántica (`tpFailure`)
  ## - Ideal para proyectos donde se prioriza legibilidad
  ##
  ## Equivalente a:
  ## ```nim
  ## tpFailure[string]("Ocurrió un error", "TP_API_INVALID")
  ## ```
  tpErr[T](msg, code, severity, context, original)

# ─────────────────────────────────────────────────────────────────────────────
# 🔚 Finaliza configuración de compilación
# ─────────────────────────────────────────────────────────────────────────────

{.pop.}