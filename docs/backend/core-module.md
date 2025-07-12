# 🧠 ¡Desbloquea el Núcleo de Talpo en Talpiko Framework!

¡Explora el módulo `core.nim` de **Talpo**, el taller donde el topo gris organiza herramientas esenciales! Con configuración tipada, logging estructurado y errores robustos, es la base sólida de tu backend, lista para el 12 de julio de 2025 a las 15:58.

## 🚀 ¿Qué hace el Módulo Core?
- **Configuración Tipada**: Carga `.env` o `.toml` con validación en compile-time.
- **Logging Estructurado**: Registra eventos en JSON o texto con niveles `info`, `error`, `debug`.
- **Errores Tipados**: Define `HttpError`, `DbError` para manejo seguro.
- **Helpers**: Utilidades como `tryParseInt` para conversiones seguras.

## 🛠️ Cómo Usarlo
Carga una configuración:
```nim
type Config = object
  port: int
  env: string
let conf = loadConfig(Config, "config.toml")
echo conf.port # Validado en compile-time
```

Registra un evento:
```nim
logInfo("Servidor iniciado", {"time": "15:58", "env": conf.env})
```

## 🌱 Extiende tu Núcleo
- Añade helpers para formateo de fechas dinámicas.
- Crea un sistema de auditoría para logs.

## 🎉 Ejemplo Práctico
```nim
logInfo("🐾 Talpo: Servidor iniciado a las 15:58!", {"port": $conf.port})
```

## 🎨 Un Toque Visual
```
   [Config] --> [loadConfig] --> [Logger]
      ↓           ↓            ↓
   [Errores] --> [logInfo] --> [Monitoreo]
```

**¡Domina el núcleo con Talpo y haz brillar tu backend! 🐾**