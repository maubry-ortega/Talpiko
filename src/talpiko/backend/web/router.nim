# src/talpiko/backend/web/router.nim
## Enrutador compile-time de Talpiko con soporte RPC y Auto-Serialization.
import macros, asyncdispatch, tables, strutils
import ../core/types
import ./rpc

type
  TpRouteSegmentKind = enum
    skStatic, skDynamic

  TpRouteSegment = object
    kind:  TpRouteSegmentKind
    value: string

  TpRouteEntry = object
    methd:    TpHttpMethod
    segments: seq[TpRouteSegment]
    handler:  TpHandler

  TpRouter* = ref object
    entries:  seq[TpRouteEntry]

proc parseSegments(path: string): seq[TpRouteSegment] =
  var i = 0
  let n = path.len
  while i < n:
    while i < n and path[i] == '/': inc i
    var j = i
    while j < n and path[j] != '/': inc j
    if j > i:
      let seg = path[i ..< j]
      if seg.len > 0 and (seg[0] == ':' or (seg[0] == '{' and seg[^1] == '}')):
        let name = if seg[0] == ':': seg[1 .. ^1] else: seg[1 .. ^2]
        result.add TpRouteSegment(kind: skDynamic, value: name)
      else:
        result.add TpRouteSegment(kind: skStatic, value: seg)
    i = j

proc newTpRouter*(): TpRouter =
  new(result)
  result.entries = newSeqOfCap[TpRouteEntry](32)

proc addRoute*(router: TpRouter, methodType: TpHttpMethod, path: string, handler: TpHandler) =
  router.entries.add TpRouteEntry(
    methd:    methodType,
    segments: parseSegments(path),
    handler:  handler,
  )

type
  TpMatchResult* = object
    matched*: bool
    handler*: TpHandler
    params*:  Table[string, string]

proc matchRoute*(router: TpRouter, methodType: TpHttpMethod, path: string): TpMatchResult =
  result.matched = false
  for entry in router.entries:
    if entry.methd != methodType: continue
    var pi = 0; var si = 0; let pn = path.len; var ok = true
    var pTable = initTable[string, string](entry.segments.len * 2 + 1)
    while si < entry.segments.len and ok:
      while pi < pn and path[pi] == '/': inc pi
      if pi >= pn: (ok = false; break)
      var pj = pi
      while pj < pn and path[pj] != '/': inc pj
      let segStr = path[pi ..< pj]
      case entry.segments[si].kind
      of skStatic:
        if segStr != entry.segments[si].value: ok = false
      of skDynamic:
        pTable[entry.segments[si].value] = segStr
      pi = pj; inc si
    if ok:
      while pi < pn and path[pi] == '/': inc pi
      if pi == pn and si == entry.segments.len:
        result.matched = true; result.handler = entry.handler; result.params = pTable; return

macro tpRoute*(router: TpRouter, methodType: TpHttpMethod, path: static string, handler: typed) =
  let handlerName = handler
  let params = handler.getTypeImpl[0]
  
  # 1. Metadata Extraction
  var hType = handler.getTypeImpl
  var retTypeStr = "void"
  var discoveryCalls = newStmtList()
  
  if hType.len > 0 and hType[0].kind == nnkFormalParams:
    let formalParams = hType[0]
    if formalParams.len > 0:
      let retNode = formalParams[0]
      if retNode.kind == nnkBracketExpr and (retNode[0].repr.contains("Future")):
        if retNode.len > 1:
          retTypeStr = retNode[1].repr
          discoveryCalls.add(newCall(ident("tpDiscoverType"), retNode[1]))

  var rpcParams: seq[NimNode]
  for i in 2 ..< params.len:
    let pNode = params[i]
    let pName = pNode[0].strVal
    let pType = pNode[1]
    let pKind = if path.contains("{" & pName & "}") or path.contains(":" & pName): "path" else: "query"
    rpcParams.add(quote do: RpcParam(name: `pName`, typ: `pType`.repr, kind: `pKind`))
    discoveryCalls.add(newCall(ident("tpDiscoverType"), pType))

  # 2. Wrapper Generation
  var wrapper: NimNode
  let isSimple = params.len <= 2
  
  if isSimple and retTypeStr == "void":
    wrapper = handlerName
  else:
    let ctxNode = genSym(nskParam, "ctx")
    var wrapperBody = newStmtList()
    var callArgs = newSeq[NimNode]()
    callArgs.add(ctxNode)
    if not isSimple:
      for i in 2 ..< params.len:
        let pn = params[i][0].strVal
        let pt = params[i][1]
        let ps = genSym(nskLet, pn)
        let getCall = newCall(newDotExpr(ctxNode, ident("getParam")), newLit(pn))
        var conv: NimNode
        case pt.repr
        of "int": conv = newCall(ident("parseInt"), getCall)
        of "float": conv = newCall(ident("parseFloat"), getCall)
        of "bool": conv = newCall(ident("parseBool"), getCall)
        else: conv = getCall
        wrapperBody.add(newTree(nnkLetSection, newTree(nnkIdentDefs, ps, newEmptyNode(), conv)))
        callArgs.add(ps)
    
    let callExpr = newCall(handlerName, callArgs)
    if retTypeStr != "void":
      wrapperBody.add(quote do:
        let val = await `callExpr`
        `ctxNode`.ok(val))
    else:
      wrapperBody.add(quote do: await `callExpr`)

    wrapper = quote do:
      proc(`ctxNode`: TpContext): Future[void] {.async, gcsafe, closure.} = `wrapperBody`

  # 3. Final Codegen
  let hNameLit = newLit(handler.strVal)
  let mStrLit = newLit(methodType.repr.replace("Http", "").toUpperAscii())
  let rpcPS = newTree(nnkPrefix, ident("@"), newTree(nnkBracket, rpcParams))
  
  result = quote do:
    static:
      `discoveryCalls`
      registerRpcMetadata(RpcEndpoint(name: `hNameLit`, path: `path`, methd: `mStrLit`, params: `rpcPS`, returnTyp: `retTypeStr`))
    `router`.addRoute(`methodType`, `path`, `wrapper`)

template get*(router: TpRouter, path: static string, handler: untyped) = tpRoute(router, HttpGet, path, handler)
template post*(router: TpRouter, path: static string, handler: untyped) = tpRoute(router, HttpPost, path, handler)
template put*(router: TpRouter, path: static string, handler: untyped) = tpRoute(router, HttpPut, path, handler)
template delete*(router: TpRouter, path: static string, handler: untyped) = tpRoute(router, HttpDelete, path, handler)
template patch*(router: TpRouter, path: static string, handler: untyped) = tpRoute(router, HttpPatch, path, handler)
template options*(router: TpRouter, path: static string, handler: untyped) = tpRoute(router, HttpOptions, path, handler)
