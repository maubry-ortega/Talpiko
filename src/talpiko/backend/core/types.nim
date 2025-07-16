## types.nim
##
## Punto de Entrada del Sistema de Tipos de Talpo
##
## Sistema: Talpo / Talpiko - Core Types
##
## Responsabilidad:
##   Este módulo centraliza y expone todo el sistema de tipos:
##   - Tipos base (`TpResult`, `TpError`, `TpResultError`)
##   - Constructores (`tpOk`, `tpErr`)
##   - Operadores (`>>=`, `tpAndThen`)
##   - Extensiones (`tpAwait`, `tpAsync`)
##
## Características Clave:
## - Encapsula tipos funcionales reutilizables
## - Diseño modular y extensible
## - Exportaciones limpias y controladas
## - Base común para todo el backend de Talpo

{.experimental: "strictDefs".}

# ─────────────────────────────────────────────────────────────────────────────
# 📦 Importaciones Modulares
# ─────────────────────────────────────────────────────────────────────────────

import
  ./types/primitives/tp_interfaces,         ## Enumeraciones y tipo base de error
  ./types/primitives/tp_result,             ## Monad TpResult
  ./types/primitives/tp_error,              ## TpResultError enriquecido

  ./types/constructors/tp_success,               ## tpOk, tpSuccess
  ./types/constructors/tp_failure,              ## tpErr, tpFailure
  ./types/constructors/tp_conversions,             ## tpFromException, tpFromBool, etc.

  ./types/operations/monadic,            ## >>=, tpAndThen
  ./types/operations/tap,                ## tpTap, tpTapError
  ./types/operations/recover,            ## tpOrElse, tpGetOrDefault, tpIsError
  ./types/operations/map,                ## tpMap, tpMapError

  ./types/extensions/async               ## tpAsync, tpAwait

# ─────────────────────────────────────────────────────────────────────────────
# 🔁 Reexportación Pública
# ─────────────────────────────────────────────────────────────────────────────

export
  tp_interfaces, tp_result, tp_error,
  tp_success, tp_failure, tp_conversions,
  monadic, tap, recover,
  map,
  async,
  tpUnsafeGet