# 🗄️ ¡Gestiona Estados Complejos con Pikpo!

¡Domina el estado con **Pikpo** y sus señales estructuradas y stores globales! Maneja estados complejos con validación en compile-time, todo en Nim puro, listo para el 12 de julio de 2025 a las 16:02.

## 🚀 ¿Qué es la Gestión de Estado en Pikpo?
- **Señales Estructuradas**: Soporta estados anidados (`state.name`).
- **Store Global**: Type-safe, inspirado en Redux.
- **Efectos Computados**: Deriva valores reactivos.

## 🛠️ Técnico: Implementación
```nim
type
  Signal[T] = object
    value: T
    subscribers: seq[proc(value: T)]

  Store[T] = object
    state: Signal[T]
    reducers: seq[proc(state: T, action: string): T]

proc createStore[T](initial: T): Store[T] =
  result.state.value = initial
  result.reducers = @[]

proc dispatch[T](store: var Store[T], action: string) =
  try:
    let newState = store.reducers[0](store.state.value, action)
    store.state.value = newState
  except Exception as e:
    logError("Dispatch failed: ", e.msg)
```

## 🎉 Ejemplo Práctico
Añade tareas con un store global:
```nim
template TodoApp:
  estado:
    store: Store[TodoState] = createStore(TodoState(todos: @[], nuevoTodo: ""))
  template:
    <div class="container" aria-label="Lista de tareas">
      <h1>Todo App</h1>
      <input bind={store.state.value.nuevoTodo} @keyup.enter={agregarTodo}>
      <ul>
        {for todo in store.state.value.todos:
          <li key={todo.id}>{todo.texto}</li>
        }
      </ul>
    </div>
  métodos:
    proc agregarTodo() =
      dispatch(store, "add:" & store.state.value.nuevoTodo)
      dispatch(store, "clear")
```

## 🎨 Flujo Visual
```
   [Acción] --> [Store] --> [Señal] --> [JS]
      ↓         ↓         ↓         ↓
   [Estado] --> [Efecto] --> [Actualización] --> [¡Vivo!]
```

**¡Gestiona estados complejos con Pikpo y crea apps robustas! 🎨**