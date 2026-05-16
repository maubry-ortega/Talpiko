# src/talpiko/backend/web/rpc.nim
import macros, strutils, tables
import ../core/types

type
  RpcParam* = object
    name*: string
    typ*: string
    kind*: string # "path", "query", "body"

  RpcEndpoint* = object
    name*: string
    path*: string
    methd*: string
    params*: seq[RpcParam]
    returnTyp*: string

  DiscoveryType* = object
    name*: string
    fields*: seq[tuple[name: string, typ: string]]

var gRpcMetadata {.compileTime.}: seq[RpcEndpoint]
var gRpcTypes {.compileTime.}: Table[string, DiscoveryType]

proc registerRpcMetadata*(endpoint: RpcEndpoint) {.compileTime.} =
  gRpcMetadata.add(endpoint)

macro tpDiscoverType*(T: untyped) =
  let tTyped = T.getType
  let impl = tTyped.getTypeImpl
  let name = T.repr
  if gRpcTypes.hasKey(name): return
  if impl.kind == nnkBracketExpr: return # handled by Future[T] logic in router
  if impl.kind == nnkObjectTy:
    var disc = DiscoveryType(name: name)
    let body = impl[2] # RecList
    for i in 0 ..< body.len:
      let field = body[i]
      disc.fields.add (field[0].strVal, field[1].repr)
    gRpcTypes[name] = disc

proc nimToTsType(nimType: string): string =
  case nimType
  of "int", "int8", "int16", "int32", "int64", "uint", "uint8", "uint16",
      "uint32", "uint64", "float", "float32", "float64": "number"
  of "string": "string"
  of "bool": "boolean"
  of "void": "void"
  else:
    if nimType.startsWith("seq[") or nimType.startsWith("openArray["):
      let inner = nimType[nimType.find("[")+1 .. ^2]
      return nimToTsType(inner) & "[]"
    else: return nimType

proc generateTsInterfaces*(): string =
  result = ""
  for name, disc in gRpcTypes:
    result.add "export interface " & name & " {\n"
    for f in disc.fields:
      result.add "  " & f.name & ": " & nimToTsType(f.typ) & ";\n"
    result.add "}\n\n"

proc generateTsSdkCode*(): string =
  result = "/* Talpiko Generated SDK */\n\nexport type TpStatus = \"success\" | \"error\";\n\n"
  result.add "export interface TpErrorResponse {\n  code: string;\n  message: string;\n  status: \"error\";\n}\n\n"
  result.add "export type TpResult<T> = \n  | { isOk: true; value: T; status: \"success\" }\n  | { isOk: false; error: TpErrorResponse; status: \"error\" };\n\n"
  result.add generateTsInterfaces()
  result.add "\nexport class TalpikoClient {\n  constructor(private baseUrl: string = 'http://localhost:8080') {}\n\n"
  for ep in gRpcMetadata:
    let tsReturn = nimToTsType(ep.returnTyp)
    var tsArgs = newSeq[string](); var urlP = ep.path
    for p in ep.params:
      tsArgs.add p.name & ": " & nimToTsType(p.typ)
      if p.kind == "path": urlP = urlP.replace("{" & p.name & "}", "${" &
          p.name & "}").replace(":" & p.name, "${" & p.name & "}")
    let argS = tsArgs.join(", ")
    result.add "  async " & ep.name & "(" & argS & "): Promise<" & tsReturn & "> {\n"
    result.add "    const url = `${this.baseUrl}" & urlP & "`;\n"
    result.add "    const res = await fetch(url, { method: '" & ep.methd & "' });\n"
    result.add "    if (!res.ok) throw new Error(`RPC Failed: ${res.statusText}`);\n"
    result.add "    return await res.json() as " & tsReturn & ";\n  }\n\n"
  result.add "}\n"

proc generateNimClientCode*(): string =
  result = "# Talpiko Generated Nim Client\n"
  result.add "when defined(js):\n"
  result.add "  import std/[jsfetch, asyncjs, json, strutils]\n"
  result.add "else:\n"
  result.add "  import httpclient, asyncdispatch, json, tables, strutils\n"
  result.add "import ../src/talpiko/backend/core/types\n"
  result.add "export types\n\n"
  result.add "type TalpikoClient* = ref object\n  endpoint*: string\n\n"

  for ep in gRpcMetadata:
    var nimArgs = newSeq[string](); var urlP = ep.path
    for p in ep.params:
      nimArgs.add p.name & ": " & p.typ
      if p.kind == "path": urlP = urlP.replace("{" & p.name & "}", "\" & $" &
          p.name & " & \"").replace(":" & p.name, "\" & $" & p.name & " & \"")
    let argS = if nimArgs.len > 0: ", " & nimArgs.join(", ") else: ""

    result.add "proc " & ep.name & "*(c: TalpikoClient" & argS & "): Future[" &
        ep.returnTyp & "] {.async.} =\n"
    result.add "  let url = c.endpoint & \"" & urlP & "\"\n"
    result.add "  when defined(js):\n"
    result.add "    let res = await fetch(url.cstring, FetchOptions(metod: \"" &
        ep.methd & "\".cstring))\n"
    result.add "    let text = await res.text()\n"
    if ep.returnTyp != "void":
      result.add "    if ($text).len > 0: result = parseJson($text).to(" &
          ep.returnTyp & ")\n"
    else:
      result.add "    discard\n"
    result.add "  else:\n"
    result.add "    let client = newHttpClient()\n"
    result.add "    let res = client.request(url, httpMethod = Http" &
        ep.methd.capitalizeAscii() & ")\n"
    result.add "    let body = res.body\n"
    if ep.returnTyp != "void":
      result.add "    if body.len > 0: result = parseJson(body).to(" &
          ep.returnTyp & ")\n\n"
    else:
      result.add "    discard\n\n"

macro generateSdk*(path: static string) =
  let tsCode = generateTsSdkCode()
  writeFile(path, tsCode)
  echo "[RPC] TypeScript SDK generated at: ", path

macro generateNimClient*(path: static string) =
  let code = generateNimClientCode()
  writeFile(path, code)
  echo "[RPC] Nim Client generated at: ", path
