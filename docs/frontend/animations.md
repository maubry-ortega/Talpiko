# 🎬 ¡Crea Animaciones con Pikpo en Talpiko Framework!

¡Da vida a tu interfaz con **Pikpo** y su sistema de animaciones declarativas! Usa el DSL de Nim para definir transiciones reactivas que se compilan a JS puro con `requestAnimationFrame`, asegurando 60 FPS el 12 de julio de 2025 a las 16:02.

## 🚀 ¿Qué es el Sistema de Animaciones?
- **Declarativo**: Define animaciones en el DSL con triggers como `onUpdate`.
- **JS Puro**: Compila a funciones optimizadas sin manipulación directa del DOM.
- **Reactivo**: Vincula animaciones a señales o stores.

## 🛠️ Técnico: Implementación
```nim
type
  Animation = object
    property: string
    from: float
    to: float
    duration: int
    easing: proc(t: float): float
    trigger: string

macro animate*(input: static string): untyped =
  let parsed = parseAnimation(input)
  result = quote do:
    const anim = Animation(
      property: `parsed.property`,
      from: `parsed.from`,
      to: `parsed.to`,
      duration: `parsed.duration`,
      easing: `parsed.easing`,
      trigger: `parsed.trigger`
    )
    registerAnimation(anim)
```

## 🎉 Ejemplo Práctico
Un título con `fadeIn` reactivo al actualizar un contador:
```nim
template Contador:
  estado:
    count: int = 0
  animation:
    const fadeIn = animate"""
      property: opacity
      from: 0
      to: 1
      duration: 300ms
      easing: cubic-bezier(0.4, 0, 0.2, 1)
      trigger: onUpdate(count)
    """
  template:
    <h1 style={opacity: count}>Contador: {count}</h1>
  métodos:
    proc incrementar() = count += 1
```

## 🎨 Flujo Visual
```
   [Animación] --> [JS Compilado] --> [Render]
      ↓         ↓         ↓
   [DSL] --> [Macro] --> [¡Fluido!]
```

**¡Anima tu interfaz con Pikpo y crea experiencias mágicas! 🎨**