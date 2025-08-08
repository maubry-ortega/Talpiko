## 📄 tp_memoryutils.nim
##
## 📌 Utilidades de memoria manual para el framework Talpiko
## ⚠️ Requiere compilación con --gc:none o manejo manual explícito

when not defined(gcNone) and not defined(gcDestructors):
  {.fatal: "Este módulo requiere --gc:none o --gc:destructors".}

template newByCopy*[T](initVal: T): ref T =
  ## 📦 Crea una `ref T` inicializada en heap copiando desde stack
  ## ⚠️ El tipo T debe tener tamaño conocido en tiempo de compilación
  {.line.}:
    when sizeof(T) == 0:
      {.error: "No se puede crear referencia a tipo de tamaño cero".}
    
    let tmp = initVal
    let p = cast[ref T](alloc(sizeof(T)))
    copyMem(addr(p[]), addr(tmp), sizeof(T))
    p

template newByZeroedRef*[T](): ref T =
  ## 🧼 Crea un `ref T` en memoria inicializada a cero
  ## ✅ Más seguro que newByCopy para tipos complejos
  {.line.}:
    when sizeof(T) == 0:
      {.error: "No se puede crear referencia a tipo de tamaño cero".}
    
    cast[ref T](alloc0(sizeof(T)))

proc deallocRef*[T](r: ref T) =
  ## 🗑️ Libera memoria de un ref T creado con newByCopy/newByZeroedRef
  ## ⚠️ Asegúrate de que no hay referencias restantes
  if not isNil(r):
    `=destroy`(r[])  # Llama a destructores si existen
    dealloc(cast[pointer](r))