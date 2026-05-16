/**
 * Pikpo WASM Loader
 */

async function loadPikpo(wasmPath) {
    const response = await fetch(wasmPath);
    const bytes = await response.arrayBuffer();

    const importObject = {
        env: {
            "pkCreateElement": (tagPtr, tagLen) => PikpoRuntime.createElement(tagPtr, tagLen),
            "pkSetAttribute": (elId, kPtr, kLen, vPtr, vLen) => PikpoRuntime.setAttribute(elId, kPtr, kLen, vPtr, vLen),
            "pkAppendChild": (parentId, childId) => PikpoRuntime.appendChild(parentId, childId),
            "pkSetTextContent": (elId, tPtr, tLen) => PikpoRuntime.setTextContent(elId, tPtr, tLen),
            "pkAddEventListener": (elId, nPtr, nLen, hIdx) => PikpoRuntime.addEventListener(elId, nPtr, nLen, hIdx),
            "pkMount": (elId, cPtr, cLen) => PikpoRuntime.mount(elId, cPtr, cLen),

            // Standard C/Nim requirements for WASM
            "memory": new WebAssembly.Memory({ initial: 256 }),
            "__stack_pointer": new WebAssembly.Global({ value: 'i32', mutable: true }, 0),
        }
    };

    const { instance } = await WebAssembly.instantiate(bytes, importObject);

    PikpoRuntime.wasmMemory = instance.exports.memory || importObject.env.memory;
    PikpoRuntime.wasmExports = instance.exports;

    // Initialize Nim if needed
    if (instance.exports.NimMain) {
        instance.exports.NimMain();
    }

    return instance;
}

window.loadPikpo = loadPikpo;
