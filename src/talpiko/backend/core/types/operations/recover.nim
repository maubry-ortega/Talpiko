## recover.nim
##
## Módulo: tpRecover
## Sistema: Talpo / Talpiko - TpResult Operations
##
## Responsabilidad:
##   Permitir el manejo seguro de errores mediante recuperación
##   con un valor alternativo o función, sin lanzar excepciones.
##
## Características Clave:
## - Control seguro de errores sin panics
## - Opciones funcionales y declarativas
## - Útil en operaciones tolerantes a fallos

import ../primitives/tp_result

proc tpRecover*[T](res: TpResult[T], fallback: T): T {.inline.} =
  ## Retorna el valor si es éxito o `fallback` si es error
  if res.tpIsSuccess():
    res.value
  else:
    fallback

proc tpRecoverWith*[T](res: TpResult[T], recovery: proc(): T): T {.inline.} =
  ## Ejecuta una función si hay error para obtener valor alternativo
  ##
  ## Ventajas:
  ## - Lazy evaluation del valor de recuperación
  if res.tpIsSuccess():
    res.value
  else:
    recovery()

proc tpRecoverResult*[T](res: TpResult[T], recovery: proc(): TpResult[T]): TpResult[T] {.inline.} =
  ## Ejecuta función de recuperación que retorna otro `TpResult`
  ##
  ## Útil cuando el fallback también puede fallar o ser complejo
  if res.tpIsSuccess():
    res
  else:
    recovery()
