# 🖱️ ¡Captura Eventos con Pikpo en Talpiko Framework!

¡Haz que tu interfaz cobre vida con **Pikpo** y su sistema de eventos! Este módulo te permite conectar acciones del usuario con macros, creando interacciones mágicas en Nim puro. ¡Es hora de escuchar a tu audiencia!

## 🚀 ¿Qué son los Eventos en Pikpo?
Los eventos son los latidos de tu UI, diseñados para:
- **Asociar Acciones**: Vincula clics, teclas o movimientos.
- **Sintaxis Clara**: Usa `onclick={proc() ...}` u otros.
- **Respuesta Dinámica**: Actualiza el DOM al instante.

## 🛠️ Cómo Usarlo
Imagina un botón:
- Escribe `talpiko: <button onclick={proc() = inc count}>{count}</button>` (detalles en guías técnicas).
- Pikpo ejecuta la acción y actualiza.

## 🌱 Amplía tus Eventos
- Añade soporte para `onkeyup` o `onscroll`.
- Crea eventos personalizados para tu proyecto.

## 🎉 Ejemplo Práctico
Piensa en un clic:
- "Contador: 1" se convierte en "Contador: 2" con un clic a las 10:47 AM.

## 🎨 Un Toque Visual
Visualiza el flujo de eventos:
```
   [Clic] --> [onclick] --> [Acción]
      ↓         ↓         ↓
   [Estado] --> [Macro] --> [¡Actualización!]
```
¡Tu conexión con el usuario!

**¡Captura eventos con Pikpo y anima tu interfaz! 🎨**