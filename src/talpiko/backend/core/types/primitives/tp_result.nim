## tp_result.nim
##
## Módulo: Monad de Resultados Tipados (TpResult)
## Sistema: Talpo / Talpiko - Core Types
##
## Responsabilidad:
##   Proveer un tipo monádico seguro y eficiente para el manejo de éxito/fallo en operaciones empresariales y distribuidas.
##
## Características Clave:
## - Tipado fuerte y genérico
## - Representación explícita de éxito/fallo
## - Integración con errores enriquecidos
## - Optimización para hot path y bajo overhead
## - Preparado para async, tracing y serialización
##
## Buenas Prácticas:
## - Usar siempre los constructores `tpOk` y `tpErr`
## - No acceder directamente a los campos, usar helpers
## - Documentar los códigos de error y casos de uso
##
## Ejemplo de uso:
## ```nim
## let res: TpResult[int] = tpOk(42)
## if res.tpIsSuccess():
##   echo res.value
## else:
##   echo res.error.msg
## ```

import ./tp_interfaces
import ./tp_error
import std/[times, json]

when defined(release):
  {.push checks: off.}  # Optimización producción
else:
  {.push stackTrace: on.}

# ─────────────────────────────────────────────────────────────────────────────
# 📦 Tipos Principales
# ─────────────────────────────────────────────────────────────────────────────

type
  TpResultKind* = enum
    ## Estado de un resultado
    tpSuccess = "Success"
    tpFailure = "Failure"

  TpResultMetadata* = object
    ## Metadata adicional para diagnóstico
    creationTime*: float64

  TpResult*[T] = object
    ## Monad funcional que encapsula éxito o error
    case kind*: TpResultKind
    of tpSuccess:
      value*: T
    of tpFailure:
      error*: ref TpResultError
      metadata*: TpResultMetadata

# ─────────────────────────────────────────────────────────────────────────────
# ⚙️ Configuración
# ─────────────────────────────────────────────────────────────────────────────

const
  tpDefaultErrorCode* = "TP_UNKNOWN"
  tpInternalErrorCode* = "TP_INTERNAL"
  tpValidationErrorCode* = "TP_VALIDATION"
  tpNetworkErrorCode* = "TP_NETWORK"
  tpDatabaseErrorCode* = "TP_DATABASE"

# ─────────────────────────────────────────────────────────────────────────────
# 🛠️ Implementación Principal
# ─────────────────────────────────────────────────────────────────────────────

proc tpIsSuccess*[T](res: TpResult[T]): bool {.inline.} =
  ## Verifica si el resultado es exitoso
  res.kind == tpSuccess

proc tpIsFailure*[T](res: TpResult[T]): bool {.inline.} =
  ## Verifica si el resultado es un fallo
  res.kind == tpFailure

proc tpUnwrap*[T](res: TpResult[T]): T =
  ## Retorna el valor o lanza excepción con el mensaje del error
  if res.tpIsFailure():
    raise newException(ValueError, res.error.msg)
  res.value

proc tpGetOrDefault*[T](res: TpResult[T], fallback: T): T {.inline.} =
  ## Retorna el valor en caso de éxito, o el valor por defecto si hay error
  if res.tpIsSuccess():
    res.value
  else:
    fallback

proc tpUnsafeGet*[T](res: TpResult[T]): T {.inline.} =
  ## Acceso directo al valor de éxito sin validación.
  ##
  ## ¡ADVERTENCIA!: Solo debe usarse si se garantiza que el resultado es tpSuccess.
  ## Si se usa sobre un error, el comportamiento es indefinido y puede causar fallos.
  ##
  ## Ejemplo:
  ## ```nim
  ## let val = res.tpUnsafeGet() # Solo si res.tpIsSuccess()
  ## ```
  {.push checks: off.}
  result = res.value
  {.pop.}

proc toJson*[T](res: TpResult[T]): JsonNode =
  ## Serializa el resultado a JSON para logging/tracing
  case res.kind
  of tpSuccess:
    result = %*{"kind": "Success", "value": res.value}
  of tpFailure:
    result = %*{
      "kind": "Failure",
      "error": res.error.toJson(),
      "metadata": %*res.metadata
    }

# ─────────────────────────────────────────────────────────────────────────────
# 🏎️ Notas de rendimiento
# ─────────────────────────────────────────────────────────────────────────────
## - Todas las operaciones son O(1) salvo serialización (O(n) en error/context)
## - El objeto es inmutable tras creación
## - Preparado para integración con memory pools y ARC/ORC