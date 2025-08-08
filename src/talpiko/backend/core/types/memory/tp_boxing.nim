## 📄 tp_boxing.nim
##
## 📌 Boxing seguro de objetos inicializados manualmente
## 🛡️ Versión mejorada con verificaciones de seguridad

import ./tp_memoryutils

template box*[T](body: untyped): ref T =
  ## 📦 Crea un objeto `ref T` inicializado manualmente
  ##
  ## Ejemplo seguro:
  ## ```nim
  ## let user = box[User]:
  ##   it.name = "Alice"
  ##   it.age = 30
  ## ```
  {.line.}:
    when sizeof(T) == 0:
      {.error: "No se puede boxear tipo de tamaño cero".}
    
    let p = newByZeroedRef[T]()
    try:
      block:
        var it {.inject.} = p[]
        body
        p[] = it
      p
    except:
      deallocRef(p)
      raise

proc boxWith*[T](initProc: proc(x: var T)): ref T =
  ## 🆕 Versión alternativa con procedimiento de inicialización
  ## Más seguro para inicializaciones complejas
  let p = newByZeroedRef[T]()
  try:
    initProc(p[])
    p
  except:
    deallocRef(p)
    raise