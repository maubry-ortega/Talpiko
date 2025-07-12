# 🌟 ¡Empecemos con Talpiko Framework!

¡Hola, aventurero del código! Estás a punto de explorar **Talpiko Framework**, donde **Talpo** (backend) y **Pikpo** (frontend) te guiarán para crear aplicaciones modernas con **Nim**. Este tutorial te llevará a tu primer "Hello World" compilado a JavaScript puro, listo para brillar el 12 de julio de 2025 a las 11:46 AM.

## 🛠️ ¿Qué necesitas?
- **Nim**: Descárgalo desde [nim-lang.org](https://nim-lang.org) (versión 2.0+).
- **Editor**: VSCode con el plugin Nim para autocompletado y resaltado.
- **Navegador**: Cualquier navegador moderno para ejecutar el JS generado.
- **Entusiasmo**: ¡Tu ingrediente secreto para dominar Talpiko!

## 🚀 ¡A instalar y configurar!
1. **Instala Nim**: Sigue las instrucciones en [nim-lang.org](https://nim-lang.org). Es rápido y sencillo.
2. **Verifica la instalación**: Ejecuta `nim --version` en tu terminal. Deberías ver la versión instalada.
3. **Crea tu proyecto**:
   - Crea una carpeta: `mkdir mi-talpiko && cd mi-talpiko`.
   - Inicializa: `pikpo new mi-app --frontend` (esto configura un proyecto Pikpo para frontend).
4. **Estructura inicial**:
   ```
   mi-talpiko/
   ├── pages/
   │   ├── Home.nim
   ├── dist/
   ├── pikpo.toml
   ```

## 🎉 Tu Primer "Hello World"
Crea un archivo `pages/Home.nim` con un template sencillo que se compila a JS:

```nim
template Home:
  <div class="greeting">
    <h1>¡Hola, Talpiko!</h1>
  </div>
```

### Compila y ejecuta:
1. **Compilar a JS**: `pikpo build Home` (genera `dist/templates/Home.js`).
2. **Servir el proyecto**: Crea un `index.html` para cargar el módulo JS:
   ```html
   <!DOCTYPE html>
   <html>
   <head>
     <script type="module" src="./dist/templates/Home.js"></script>
   </head>
   <body>
     <div id="app"></div>
     <script type="module">
       import { Home } from './dist/templates/Home.js';
       document.getElementById('app').innerHTML = Home();
     </script>
   </body>
   </html>
   ```
3. **Ejecutar**: Usa `pikpo dev` para iniciar un servidor local con Hot Reload (~50ms).
4. Abre tu navegador en `http://localhost:9000` y ¡mira tu "Hello World"!

### Salida Compilada
```javascript
// dist/templates/Home.js
export function Home() {
  return `<div class="greeting"><h1>¡Hola, Talpiko!</h1></div>`;
}
```

## 🌱 Consejos para Principiantes
- **Experimenta**: Cambia el texto en `Home.nim` y usa `pikpo dev` para ver actualizaciones instantáneas.
- **Explora la CLI**: Prueba `pikpo build` para compilar todo o `pikpo build Home` para un template específico.
- **Comunidad**: Únete a la comunidad en X para compartir ideas o resolver dudas.

## 🎨 Un Toque Visual
Imagina tu viaje:
```
   [Instalar Nim] --> [Crear Proyecto] --> [Compilar JS] --> [¡Hola Mundo!]
          ↓                ↓                ↓                ↓
   [Aprender]     [Explorar CLI]    [Hot Reload]     [¡Crecer con Talpiko!]
```

**¡Tu aventura con Talpiko comienza ahora! 🐾🎨**