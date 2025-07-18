## 📄 tp_boxing.nim
##
## 📌 Boxing seguro de objetos inicializados manualmente
##
## 🎯 Crea `ref T` mutables inicializables dentro del bloque (`it`):
## - Reemplaza `new()` + inicialización separada
## - Usar como: `box[MyType]: it.field = "valor"`

import ./tp_memoryutils

template box*[T](body: untyped): ref T =
  ## 📦 Crea un objeto `ref T` inicializado manualmente con campos mutables
  ##
  ## Acceso como `it`: el objeto mutable sobre el cual puedes asignar campos.
  ##
  ## Ejemplo:
  ## ```nim
  ## let user = box[User]:
  ##   it.name = "Alice"
  ##   it.age = 30
  ## ```
  let p = newByZeroedRef[T]()
  block:
    var it {.inject.} = p[]
    body
    p[] = it
  p
