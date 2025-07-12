# 🛠️ ¡Depura con Precisión en Pikpo!

¡Simplifica la depuración con las herramientas integradas de **Pikpo**! Rastrea señales estructuradas, módulos JS y errores en tiempo real, todo con Nim puro, listo para el 12 de julio de 2025 a las 16:02.

## 🚀 ¿Qué es el Sistema de Depuración?
- **Inspector de Templates**: Visualiza JS generado por cada template.
- **Monitor de Señales**: Rastrea cambios en señales estructuradas.
- **Validación de Actualizaciones**: Detecta errores en compile-time.

## 🛠️ Técnico: Implementación
```nim
proc debugTemplate(template: Template): string =
  result = "Template Code:\n" & template.jsCode

proc debugSignal[T](signal: Signal[T]): string =
  result = "Signal: " & $signal.value & "\nSubscribers: " & $signal.subscribers.len

proc logError(msg: string, details: varargs[string]) =
  console.error(msg & details.join(" "))
```

## 🎉 Ejemplo Práctico
Depura un store global:
```nim
template DebugPanel:
  estado:
    store: Store[TodoState]
  template:
    <div class="debug-panel" aria-label="Panel de depuración">
      <h2>Template</h2>
      <pre>{debugTemplate(TodoApp)}</pre>
      <h2>Store</h2>
      <pre>{debugSignal(store.state)}</pre>
    </div>
```

## 🎨 Flujo Visual
```
   [Error] --> [Depuración] --> [Visualización]
      ↓         ↓         ↓
   [JS] --> [Señales] --> [¡Solucionado!]
```

**¡Depura con confianza y acelera tu desarrollo con Pikpo! 🎨**