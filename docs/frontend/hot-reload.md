# 🔥 ¡Acelera el Desarrollo con Hot Reload de Pikpo!

¡Transforma tu flujo de trabajo con el **Hot Reload** de **Pikpo**! Recompila templates en ~50ms, preservando estados con señales estructuradas, usando WebSocket optimizado, listo para el 12 de julio de 2025 a las 16:02.

## 🚀 ¿Qué es el Hot Reload?
- **Recompilación Incremental**: Compila solo el template modificado.
- **Preservación de Estado**: Mantiene señales y stores globales.
- **WebSocket Optimizado**: Envía diffs mínimos.

## 🛠️ Técnico: Implementación
```nim
proc recompileIncremental(file: string): string =
  let ast = parseChangedFile(file)
  let jsCode = genJSCode(ast)
  result = compress(jsCode)

proc applyPatch(template: string, moduleId: string) =
  let jsPatch = toJsPatch(template)
  eval(`import(${moduleId}).then(m => m.default())`)

proc startHotReload(dir: string) {.async.} =
  var server = newAsyncHttpServer()
  proc cb(req: Request) {.async.} =
    if req.url.path == "/ws":
      let ws = await newWebSocket(req)
      watchFiles(dir, proc(file: string) =
        let patch = recompileIncremental(file)
        asyncCheck ws.send("reload:" & patch)
      )
  asyncCheck server.serve(Port(9000), cb)
```

## 🎉 Ejemplo Práctico
Cambia `<h1>Hola</h1>` a `<h1>Bienvenido</h1>`:
```nim
template Saludo:
  estado:
    mensaje: string = "Hola, Pikpo!"
  template:
    <h1>{mensaje}</h1>
```

## 🎨 Flujo Visual
```
   [Cambio] --> [Recompilación] --> [Recarga]
      ↓         ↓              ↓
   [Archivo] --> [JS] --> [¡Interfaz Actualizada!]
```

**¡Acelera tu desarrollo con Pikpo y Hot Reload! 🎨**