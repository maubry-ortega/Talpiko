## ok.nim
##
## Módulo: Constructores de Éxito (`tpOk`)
## Sistema: Talpo / Talpiko - Core Types
##
## Responsabilidad:
##   Define los constructores para `TpResult[T]` en estado exitoso (`tpSuccess`),
##   con inlineado, seguridad de tipos, y sin overhead innecesario.
##
## Características:
## - Constructor `tpOk` inlineado
## - Alias `tpSuccess` estilo Rust
## - Diseño extensible y tipo-safe

import ../primitives/tp_result
import ../primitives/tp_interfaces

when defined(release):
  {.push checks: off.}
else:
  {.push stackTrace: on.}

# ─────────────────────────────────────────────────────────────────────────────
# 🛠️ Constructores de Éxito
# ─────────────────────────────────────────────────────────────────────────────

proc tpOk*[T](value: T): TpResult[T] {.inline.} =
  ## Constructor principal para resultados exitosos.
  ##
  ## Parámetros:
  ## - `value`: Valor de tipo `T` que representa el éxito
  ##
  ## Ventajas:
  ## - Alta performance (`inline`)
  ## - No genera allocaciones
  TpResult[T](kind: tpSuccess, value: value)

template tpSuccess*[T](value: T): TpResult[T] =
  ## Alias semántico de `tpOk`, similar a `Ok` en Rust.
  ##
  ## Uso:
  ## ```nim
  ## let res = tpSuccess(123)  # TpResult[int]
  ## ```
  tpOk(value)

{.pop.}
