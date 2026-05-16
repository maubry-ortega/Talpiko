/**
 * Pikpo Minimal Runtime for WASM-First Architecture
 * This bridge allows the WASM-compiled Nim code to interact with the DOM.
 */

const PikpoRuntime = {
    // String management (WASM uses linear memory)
    getString: (buffer, length) => {
        const bytes = new Uint8Array(PikpoRuntime.wasmMemory.buffer, buffer, length);
        return new TextDecoder().decode(bytes);
    },

    // DOM Operations
    createElement: (tagPtr, tagLen) => {
        const tag = PikpoRuntime.getString(tagPtr, tagLen);
        const el = document.createElement(tag);
        const id = PikpoRuntime.registerElement(el);
        return id;
    },

    setAttribute: (elId, keyPtr, keyLen, valPtr, valLen) => {
        const el = PikpoRuntime.elements[elId];
        const key = PikpoRuntime.getString(keyPtr, keyLen);
        const val = PikpoRuntime.getString(valPtr, valLen);
        el.setAttribute(key, val);
    },

    appendChild: (parentId, childId) => {
        const parent = PikpoRuntime.elements[parentId];
        const child = PikpoRuntime.elements[childId];
        parent.appendChild(child);
    },

    setTextContent: (elId, textPtr, textLen) => {
        const el = PikpoRuntime.elements[elId];
        const text = PikpoRuntime.getString(textPtr, textLen);
        el.textContent = text;
    },

    mount: (elId, containerIdPtr, containerIdLen) => {
        const el = PikpoRuntime.elements[elId];
        const containerId = PikpoRuntime.getString(containerIdPtr, containerIdLen);
        const container = document.getElementById(containerId);
        container.innerHTML = '';
        container.appendChild(el);
    },

    // Event Management
    addEventListener: (elId, eventNamePtr, eventNameLen, handlerIdx) => {
        const el = PikpoRuntime.elements[elId];
        const eventName = PikpoRuntime.getString(eventNamePtr, eventNameLen);
        el.addEventListener(eventName, (e) => {
            // Callback to WASM
            PikpoRuntime.wasmExports.pikpo_dispatch_event(handlerIdx, PikpoRuntime.registerEvent(e));
        });
    },

    // element/event registry
    elements: {},
    nextElementId: 1,
    registerElement: (el) => {
        const id = PikpoRuntime.nextElementId++;
        PikpoRuntime.elements[id] = el;
        return id;
    },

    events: {},
    nextEventId: 1,
    registerEvent: (ev) => {
        const id = PikpoRuntime.nextEventId++;
        PikpoRuntime.events[id] = ev;
        return id;
    },

    // To be set by the loader
    wasmMemory: null,
    wasmExports: null
};

window.PikpoRuntime = PikpoRuntime;
