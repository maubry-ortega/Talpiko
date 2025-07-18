## 📄 tp_success.nim
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
## - Preparado para trazabilidad, validación y profiling
## - Diseño extensible y tipo-safe
##
## 📎 Estándar de Código:
## - Siempre usar prefijo `tp` (prohibido usar `Ok`)
## - Consistencia en toda la API pública de Talpiko

# ─────────────────────────────────────────────────────────────────────────────
# 📦 Importaciones necesarias
# ─────────────────────────────────────────────────────────────────────────────

import ../primitives/tp_result
import ../primitives/tp_interfaces
import std/times

# ─────────────────────────────────────────────────────────────────────────────
# ⚙️ Configuración condicional
# ─────────────────────────────────────────────────────────────────────────────

when defined(release):
  {.push checks: off.}
else:
  {.push stackTrace: on.}

# ─────────────────────────────────────────────────────────────────────────────
# 🛠️ Constructores de Éxito
# ─────────────────────────────────────────────────────────────────────────────

proc tpOk*[T](value: T): TpResult[T] {.inline.} =
  ## 🛠️ Crea un `TpResult[T]` con estado exitoso.
  ##
  ## 📥 Argumentos:
  ## - `value` → valor del resultado exitoso (tipo `T`)
  ##
  ## 📤 Retorna:
  ## - `TpResult[T]` en estado `tpSuccessKind` con valor adjunto
  ##
  ## 🧠 Características:
  ## - Inlineado y sin allocs
  ## - Preparado para trazabilidad con `-d:tpTrace`
  ## - Compatible con `tpFailure`, `tpResult`, `tpTryCatch`, etc.
  ##
  ## 🧪 Ejemplo:
  ## ```nim
  ## let r = tpOk(42)
  ## assert r.isSuccess
  ## ```

  when defined(tpStrictSuccess):
    static: assert not T is ref or T isnot Nil, "tpOk: valor por referencia no puede ser nil"

  when defined(tpTrace):
    echo "[tpOk] => ", value

  TpResult[T](
    kind: tpSuccessKind,
    value: value,
    metadata: TpResultMetadata(creationTime: epochTime()) # opcional para trazabilidad
  )

template tpSuccess*[T](value: T): TpResult[T] =
  ## 🪄 Alias semántico de `tpOk`, estilo Rust pero con prefijo `tp`.
  ##
  ## Úsalo cuando prefieras claridad semántica:
  ## ```nim
  ## let x = tpSuccess("Listo")
  ## ```
  tpOk(value)

# ─────────────────────────────────────────────────────────────────────────────
# 🔚 Finaliza configuración condicional
# ─────────────────────────────────────────────────────────────────────────────

{.pop.}
