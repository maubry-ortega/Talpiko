# src/talpiko/frontend/pikpo.nim
## Pikpo: Visual Layer for Talpiko (WASM-First)
import std/[macros, strutils, sequtils, tables]

when defined(js):
  import std/asyncjs
import core/types

when defined(js):
  import std/dom
  export dom
  type
    NativeElement* = dom.Element
    NativeEvent* = dom.Event
else:
  type
    NativeElement* = int32 # Handles for WASM
    NativeEvent* = int32

type
  PikpEvent* = ref object
    native*: NativeEvent
    targetId*: string

  PikpoNode* = ref object
    tag*: string
    attrs*: seq[(string, string)]
    events*: seq[(string, proc(ev: PikpEvent))]
    children*: seq[PikpoNode]
    text*: string
    isText*: bool

# --- DSL Helpers (Templates for name resolution) ---
template tdiv*(args: varargs[untyped]) = discard
template th1*(args: varargs[untyped]) = discard
template th2*(args: varargs[untyped]) = discard
template tp*(args: varargs[untyped]) = discard
template tul*(args: varargs[untyped]) = discard
template tli*(args: varargs[untyped]) = discard
template tbutton*(args: varargs[untyped]) = discard
template tspan*(args: varargs[untyped]) = discard

proc h*(tag: string, attrs: seq[(string, string)] = @[],
        events: seq[(string, proc(ev: PikpEvent))] = @[],
        children: seq[PikpoNode] = @[]): PikpoNode =
  PikpoNode(tag: tag, attrs: attrs, events: events, children: children, isText: false)

proc text*(val: string): PikpoNode =
  PikpoNode(text: val, isText: true)

template toNode*(v: untyped): PikpoNode =
  when compiles(v) and not (v is void):
    when v is PikpoNode: v
    elif v is string: text(v)
    else: text($v)
  else: nil

# --- DSL Macro (Pikpo DSL) ---
macro html*(body: untyped): untyped =
  ## Transforma llamadas a procs en nodos de Pikpo.
  proc parse(n: NimNode, clist: NimNode = nil): NimNode =
    case n.kind
    of nnkCall, nnkCommand:
      let fs = n[0].repr
      if fs.startsWith("t") and fs.len > 1:
        let tag = fs[1..^1]
        var attrs = newTree(nnkPrefix, ident("@"), newTree(nnkBracket))
        var events = newTree(nnkPrefix, ident("@"), newTree(nnkBracket))

        let subList = genSym(nskVar, "children")
        var subBuild = newStmtList()
        subBuild.add(newTree(nnkVarSection, newTree(nnkIdentDefs, subList,
            newTree(nnkBracketExpr, ident("seq"), ident("PikpoNode")), newTree(
            nnkPrefix, ident("@"), newTree(nnkBracket)))))

        for i in 1 ..< n.len:
          let arg = n[i]
          if arg.kind == nnkExprEqExpr:
            let key = arg[0].repr
            let val = arg[1]
            if key.startsWith("on"):
              let k = key[2..^1]
              events[1].add(newTree(nnkTupleConstr, newLit(k), val))
            else:
              attrs[1].add(newTree(nnkTupleConstr, newLit(key), newCall(ident(
                  "$"), val)))
          elif arg.kind == nnkStmtList:
            for child in arg:
              let pChild = parse(child, subList)
              if pChild.kind != nnkEmpty: subBuild.add(pChild)
          else:
            let pChild = parse(arg, subList)
            if pChild.kind != nnkEmpty: subBuild.add(pChild)

        let nodeCall = quote do: h(`tag`, `attrs`, `events`, `subList`)
        let nodeVar = genSym(nskLet, "node")
        subBuild.add(newTree(nnkLetSection, newTree(nnkIdentDefs, nodeVar,
            newEmptyNode(), nodeCall)))

        if clist != nil:
          subBuild.add(newCall(ident("add"), clist, nodeVar))
          return subBuild
        else:
          subBuild.add(nodeVar)
          return subBuild

      if fs == "text" or fs == "toNode":
        if clist != nil: return newCall(ident("add"), clist, n)
        else: return n

      let nodeVal = newCall(ident("toNode"), n)
      if clist != nil: return newCall(ident("add"), clist, nodeVal)
      else: return nodeVal

    of nnkStrLit, nnkTripleStrLit:
      let nodeVal = newCall(ident("text"), n)
      if clist != nil: return newCall(ident("add"), clist, nodeVal)
      else: return nodeVal

    of nnkIfStmt:
      var newIf = copyNimTree(n)
      for i in 0 ..< newIf.len:
        if newIf[i].kind in {nnkElifBranch, nnkElse}:
          let branchIdx = if newIf[i].kind == nnkElifBranch: 1 else: 0
          newIf[i][branchIdx] = parse(newIf[i][branchIdx], clist)
      return newIf

    of nnkForStmt:
      var newFor = copyNimTree(n)
      newFor[2] = parse(newFor[2], clist)
      return newFor

    of nnkStmtList:
      if n.len == 1: return parse(n[0], clist)
      var list = newStmtList()
      for child in n:
        let pChild = parse(child, clist)
        if pChild.kind != nnkEmpty: list.add(pChild)
      return list

    of nnkEmpty:
      return newEmptyNode()

    else:
      let nodeVal = newCall(ident("toNode"), n)
      if clist != nil: return newCall(ident("add"), clist, nodeVal)
      else: return nodeVal

  result = parse(body)

# --- Runtime / Renderer ---

when defined(js):
  proc render*(node: PikpoNode): NativeElement =
    if node.isText:
      result = document.createElement("span")
      result.innerText = node.text
    else:
      result = document.createElement(node.tag)
      for (k, v) in node.attrs: result.setAttribute(k, v)
      for entry in node.events:
        let k = entry[0]
        let h = entry[1]
        result.addEventListener(k, proc(e: Event) =
          h(PikpEvent(native: e))
        )
      for child in node.children: result.appendChild(render(child))

  proc mount*(node: PikpoNode, id: string) =
    let container = document.getElementById(id)
    if not container.isNil:
      container.innerHTML = ""
      container.appendChild(render(node))

else:
  # --- WASM Native Bindings (Phase 14.1) ---
  # Importaciones de PikpoRuntime.js (mapeadas en loader.js)
  proc pkCreateElement(tag: cstring, len: int): NativeElement {.importc: "pkCreateElement".}
  proc pkSetAttribute(el: NativeElement, k: cstring, klen: int, v: cstring,
      vlen: int) {.importc: "pkSetAttribute".}
  proc pkAppendChild(parent, child: NativeElement) {.importc: "pkAppendChild".}
  proc pkSetTextContent(el: NativeElement, text: cstring,
      tlen: int) {.importc: "pkSetTextContent".}
  proc pkAddEventListener(el: NativeElement, name: cstring, nlen: int,
      handlerIdx: int) {.importc: "pkAddEventListener".}
  proc pkMount(el: NativeElement, container: cstring,
      clen: int) {.importc: "pkMount".}

  # Handler registry para WASM
  var wasmHandlers: seq[proc(ev: PikpEvent)] = @[]

  proc pikpo_dispatch_event(handlerIdx: int, eventId: NativeEvent) {.exportc.} =
    if handlerIdx >= 0 and handlerIdx < wasmHandlers.len:
      let pe = PikpEvent(native: eventId)
      wasmHandlers[handlerIdx](pe)

  proc render*(node: PikpoNode): NativeElement =
    if node.isText:
      # Podríamos necesitar pkCreateTextNode, pero pkCreateElement + setTextContent o similar
      # Por simplicidad, usemos spans para texto o un elemento de texto especial
      let span = pkCreateElement("span", 4)
      pkSetTextContent(span, node.text, node.text.len)
      return span

    let el = pkCreateElement(node.tag, node.tag.len)
    for entry in node.attrs:
      pkSetAttribute(el, entry[0], entry[0].len, entry[1], entry[1].len)

    for entry in node.events:
      let idx = wasmHandlers.len
      wasmHandlers.add(entry[1])
      pkAddEventListener(el, entry[0], entry[0].len, idx)

    for child in node.children:
      pkAppendChild(el, render(child))

    return el

  proc mount*(node: PikpoNode, id: string) =
    let el = render(node)
    pkMount(el, id, id.len)

# --- Component System ---
template component*(name: untyped, stateType: typedesc,
    renderProc: untyped): untyped =
  type name = ref object
    state*: stateType
    containerId: string

  proc refresh*(self: name) =
    if self.containerId != "": mount(renderProc(self), self.containerId)

  proc mount*(self: name, id: string) =
    self.containerId = id
    self.refresh()
