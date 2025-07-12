# ⚙️ ¡Optimiza el Render con Pikpo en Talpiko Framework!

¡Acelera tu frontend con **Pikpo** y su compilación directa a JS! Usa renderizado parcial y lazy templates para actualizaciones eficientes, todo en Nim puro, listo para el 12 de julio de 2025 a las 16:02.

## 🚀 ¿Qué Ofrece el Render de Pikpo?
- **Compilación Directa**: Genera JS sin Virtual DOM.
- **Diffing Fine-Grained**: Actualiza solo nodos afectados.
- **Lazy Templates**: Carga dinámica de componentes.
- **Web Components**: Exporta templates como `customElements`.

## 🛠️ Técnico: Implementación
```nim
type
  TemplateUpdate = object
    id: string
    action: string
    value: string

proc markDirty(template: Template, signal: var string) =
  if signal in template.deps:
    template.needsUpdate = true

proc renderTemplate(oldTemplate, newTemplate: Template): seq[TemplateUpdate] =
  if oldTemplate.key == newTemplate.key and not oldTemplate.needsUpdate:
    return @[]
  result = @[TemplateUpdate(id: newTemplate.id, action: "render", value: newTemplate.content)]
```

## 🎉 Ejemplo Práctico
Lista de tareas con lazy loading:
```nim
lazyTemplate route = "/todos": import TodoList
template TodoList:
  estado:
    todos: seq[string] = @[]
  template:
    <ul>
      {for todo in todos:
        <li>{todo}</li>
      }
    </ul>
```

## 🎨 Flujo Visual
```
   [Cambio] --> [Diffing] --> [JS]
      ↓         ↓         ↓
   [Estado] --> [Compilación] --> [¡Actualizado!]
```

**¡Optimiza el render con Pikpo y lidera el rendimiento! 🎨**