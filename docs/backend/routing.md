# 🗺️ ¡Navega con las Rutas de Talpo en Talpiko Framework!

¡Define rutas con el módulo `web.nim` de **Talpo**! Crea endpoints seguros, middleware modular y validaciones en compile-time con Nim puro, listo para el 12 de julio de 2025 a las 15:58.

## 🚀 ¿Qué son las Rutas en Talpo?
- **Endpoints Dinámicos**: Rutas como `/users/{id:int}` validadas en compile-time.
- **Middleware Modular**: Autenticación, logging, rate-limiting.
- **Validaciones**: Macros aseguran entradas seguras.

## 🛠️ Cómo Usarlo
Define una ruta:
```nim
route "/users/{id:int}", get, Auth:
  let user = getUserById(id)
  resp(Http200, user)
```

Añade middleware:
```nim
middleware Auth:
  validateHeader("Authorization")
  decodeJWT()
```

## 🌱 Extiende tus Senderos
- Soporta métodos HTTP avanzados (PUT, DELETE).
- Genera documentación automática de rutas.

## 🎉 Ejemplo Práctico
`/users/1` → "Usuario: Talpo".

## 🎨 Un Toque Visual
```
   [Solicitud] --> [Ruta] --> [Middleware]
      ↓           ↓         ↓
   [Validar] --> [Procesar] --> [Respuesta]
```

**¡Explora y domina las rutas con Talpo! 🐾**