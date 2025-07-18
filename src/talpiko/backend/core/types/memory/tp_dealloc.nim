## ⚠️ Solo usar si usas `--gc:none` y necesitas liberar tú la memoria

proc deallocRef*[T](r: ref T) =
  dealloc(cast[pointer](r))
