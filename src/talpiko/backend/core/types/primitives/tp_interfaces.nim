## interfaces.nim
##
## 📘 Módulo: Tipos Fundamentales de Errores
## 🔧 Sistema: Talpo / Talpiko Backend - Core Types
##
## 📌 Responsabilidad:
##   Este módulo define las **interfaces base y enumeraciones esenciales**
##   que representan:
##   - Estados de operaciones (`TpResultKind`)
##   - Severidad de errores (`TpErrorSeverity`)
##
## 🚀 Características Clave:
## - Tipado semántico fuerte
## - Seguridad en tiempo de compilación
## - Preparado para trazabilidad y observabilidad
## - Cero dependencias externas

{.experimental: "strictDefs".}
{.experimental: "views".}

# ─────────────────────────────────────────────────────────────────────────────
# 📦 Enumeraciones
# ─────────────────────────────────────────────────────────────────────────────

type
  TpResultKind* = enum
    ## 🔄 Estado de una operación ejecutada
    ##
    ## - `tpSuccess`: La operación terminó exitosamente.
    ## - `tpFailure`: Ocurrió un error durante la operación.
    tpSuccessKind = "Success"
    tpFailureKind = "Failure"

  TpErrorSeverity* = enum
    ## 🚨 Clasificación de severidad de errores
    ##
    ## Usado para logging, métricas y control de flujo.
    ##
    ## - `tpLow`: Errores menores, recuperables
    ## - `tpMedium`: Afectan funcionalidad secundaria
    ## - `tpHigh`: Impactan funciones críticas
    ## - `tpCritical`: Detienen el sistema o requieren intervención manual
    tpLow = "Low"
    tpMedium = "Medium"
    tpHigh = "High"
    tpCritical = "Critical"
