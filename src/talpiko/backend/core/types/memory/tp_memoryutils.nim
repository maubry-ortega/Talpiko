## 📄 tp_memoryutils.nim
##
## 📌 Utilidades de memoria manual para el framework Talpiko
## ⚠️ Sustituye el uso de `new()` para mayor control sobre la inicialización en heap
##
## 🎯 Características:
## - Sin dependencias externas
## - Cero dependencias de GC en tiempo de ejecución
## - Inspirado en `Box<T>` de Rust y control RAII

template newByCopy*[T](initVal: T): ref T =
  ## 📦 Crea una `ref T` inicializada en heap copiando desde stack
  let tmp = initVal
  let p = cast[ref T](alloc0(sizeof(T)))
  copyMem(addr(p[]), addr(tmp), sizeof(T))
  p

template newByZeroedRef*[T](): ref T =
  ## 🧼 Crea un `ref T` en memoria limpia (zeroed)
  cast[ref T](alloc0(sizeof(T)))
