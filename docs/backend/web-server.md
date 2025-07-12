# 🌐 ¡Construye con el Servidor Web de Talpo en Talpiko Framework!

¡Levanta servidores HTTP con el módulo `web.nim` de **Talpo**! Define rutas, middleware y WebSockets con Nim puro, optimizados para el 12 de julio de 2025 a las 15:58.

## 🚀 ¿Qué ofrece el Servidor Web?
- **Servidores Ligeros**: Usa sockets nativos con `asyncdispatch`.
- **Rutas Dinámicas**: Validadas en compile-time (`/hello/{id:int}`).
- **Middleware Modular**: Autenticación, logging, CORS.
- **WebSockets**: Conexiones en tiempo real.

## 🛠️ Cómo Usarlo
Crea un servidor:
```nim
import web
let server = newServer(8080)
route "/hello", get:
  resp(Http200, "¡Hola, Talpo!")
server.run()
```

Define un WebSocket:
```nim
websocket "/chat":
  on connect:
    send("Bienvenido")
  on message(msg):
    broadcast(msg)
```

## 🌱 Extiende tu Servidor
- Añade compresión gzip nativa.
- Optimiza WebSockets con `async`.

## 🎉 Ejemplo Práctico
Visita `http://localhost:8080/hello` → "¡Hola, Talpo!".

## 🎨 Un Toque Visual
```
   [Solicitud] --> [newServer] --> [Rutas]
      ↓           ↓            ↓
   [Middleware] --> [Respuesta] --> [¡Éxito!]
```

**¡Activa tu servidor con Talpo y conquista la web! 🐾**