## tp_success.nim
##
## 📘 Módulo: Constructores de Éxito (`tpOk`)
## 🔧 Sistema: Talpo / Talpiko - Core Types
##
## 📌 Responsabilidad:
##   Define los constructores para `TpResult[T]` en estado exitoso (`tpSuccess`),
##   con inlineado, seguridad de tipos, y sin overhead innecesario.
##
## 🚀 Características:
## - Constructor `tpOk` inlineado
## - Alias `tpSuccess` estilo Rust pero con prefijo `tp`
## - Preparado para trazabilidad y profiling
## - Diseño extensible y tipo-safe
##
## 📎 Estándar de Código:
## - Siempre usar prefijo `tp` (prohibido usar `Ok`)
## - Consistencia en toda la API pública de Talpiko

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
  ## - Preparado para trazabilidad (cuando `-d:tpTrace`)
  ##
  ## Ejemplo:
  ## ```nim
  ## let resultado = tpOk(123)  # TpResult[int]
  ## ```
  when defined(tpTrace):
    echo "[tpOk] => ", value

  TpResult[T](
    kind: tpSuccessKind,
    value: value
  )

template tpSuccess*[T](value: T): TpResult[T] =
  ## Alias semántico de `tpOk`, similar a `Ok` en Rust, pero con el estándar `tp`.
  ##
  ## Uso:
  ## ```nim
  ## let res = tpSuccess("todo bien")  # TpResult[string]
  ## ```
  tpOk(value)

{.pop.}
