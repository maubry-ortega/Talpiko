## tp_result.nim
##
## 📦 Módulo: Monad de Resultados Tipados (TpResult)
## 🔧 Sistema: Talpo / Talpiko - Core Types
##
## 🎯 Responsabilidad:
##   Proveer un tipo monádico seguro y eficiente para el manejo explícito
##   de éxito o fallo en operaciones empresariales, distribuidas o críticas.
##
## 🚀 Características Clave:
## - Tipado fuerte y genérico
## - Representación explícita de éxito/fallo
## - Integración con errores enriquecidos (`TpResultError`)
## - Sin dependencias del GC: se usa memoria manual con `box`
## - Preparado para async, tracing, observabilidad y ARC/ORC
##
## 🧠 Memoria:
## - Usa referencias `ref TpResultError` asignadas en heap de forma manual.
## - Se debe usar `box` para instanciar errores (`tpErr`) en lugar de `new()`.
##
## 🧼 Buenas Prácticas:
## - Usar siempre los constructores `tpOk`, `tpErr`
## - No acceder directamente a los campos
## - Evitar `new()`, usar `box()` o `newByCopy()`
##
## 🧪 Ejemplo de uso:
## ```nim
## let res: TpResult[int] = tpOk(42)
## if res.tpIsSuccess():
##   echo res.value
## else:
##   echo res.error.msg
## ```

import ./tp_interfaces       # Incluye TpResultKind y TpErrorSeverity
import ./tp_error            # Incluye TpResultError y helpers de construcción
import std/[times, json]

when defined(release):
  {.push checks: off.}
else:
  {.push stackTrace: on.}

# ─────────────────────────────────────────────────────────────────────────────
# 📦 Tipos Principales
# ─────────────────────────────────────────────────────────────────────────────

type
  TpResultMetadata* = object
    ## 🕓 Metadata adicional para diagnóstico y trazabilidad
    creationTime*: float64

  TpResult*[T] = object
    ## 🔄 Monad funcional que encapsula éxito o error
    metadata*: TpResultMetadata
    case kind*: TpResultKind
    of tpSuccessKind:
      value*: T
    of tpFailureKind:
      error*: ref TpResultError

# ─────────────────────────────────────────────────────────────────────────────
# ⚙️ Configuración: Códigos estándar de error
# ─────────────────────────────────────────────────────────────────────────────

const
  tpDefaultErrorCode*    = "TP_UNKNOWN"
  tpInternalErrorCode*   = "TP_INTERNAL"
  tpValidationErrorCode* = "TP_VALIDATION"
  tpNetworkErrorCode*    = "TP_NETWORK"
  tpDatabaseErrorCode*   = "TP_DATABASE"

# ─────────────────────────────────────────────────────────────────────────────
# 🛠️ Implementación Principal
# ─────────────────────────────────────────────────────────────────────────────

proc tpIsSuccess*[T](res: TpResult[T]): bool {.inline.} =
  ## ✅ Verifica si el resultado representa éxito
  res.kind == tpSuccessKind

proc tpIsFailure*[T](res: TpResult[T]): bool {.inline.} =
  ## ❌ Verifica si el resultado representa un fallo
  res.kind == tpFailureKind

proc tpUnwrap*[T](res: TpResult[T]): T =
  ## ⚠️ Retorna el valor en caso de éxito o lanza excepción si hay error
  if res.tpIsFailure():
    if not res.error.originalException.isNil:
      raise res.error.originalException
    else:
      raise newException(ValueError, res.error.msg)
  res.value

proc tpUnwrapOr*[T](res: TpResult[T], fallback: T): T {.inline.} =
  ## 🔓 Retorna el valor si es éxito, o `fallback` si es error.
  ##
  ## Alternativa segura a `tpUnwrap` que evita lanzar excepciones.
  ##
  ## 🧪 Ejemplo:
  ## ```nim
  ## let resOk = tpOk(42)
  ## let resErr = tpErr[int]("fallo")
  ##
  ## echo resOk.tpUnwrapOr(0)   # 42
  ## echo resErr.tpUnwrapOr(0)  # 0
  ## ```
  if res.tpIsSuccess():
    res.value
  else:
    fallback


proc tpGetOrDefault*[T](res: TpResult[T], fallback: T): T {.inline.} =
  ## 🔁 Retorna el valor si es éxito, o `fallback` si es error
  if res.tpIsSuccess():
    res.value
  else:
    fallback

proc tpUnsafeGet*[T](res: TpResult[T]): T {.inline.} =
  ## 🧨 Acceso directo sin validación (solo si garantizas que es éxito)
  {.push checks: off.}
  result = res.value
  {.pop.}

proc toJson*[T](res: TpResult[T]): JsonNode =
  ## 📤 Serializa el resultado a JSON para logging, trazabilidad, observabilidad
  case res.kind
  of tpSuccess:
    result = %*{
      "kind": "Success",
      "value": res.value
    }
  of tpFailure:
    result = %*{
      "kind": "Failure",
      "error": res.error.toJson(),
      "metadata": %*res.metadata
    }

# ─────────────────────────────────────────────────────────────────────────────
# 🏎️ Notas de rendimiento
# ─────────────────────────────────────────────────────────────────────────────
## - Todas las operaciones son O(1) (excepto serialización)
## - El objeto es inmutable tras construcción
## - Listo para integrarse con memory pools, ARC, ORC o entornos embebidos
## - Compatible con sistemas async y modelos de tracing modernos
