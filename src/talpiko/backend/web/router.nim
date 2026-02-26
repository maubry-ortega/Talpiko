# src/talpiko/backend/web/router.nim
## Enrutador del servidor de Talpiko.
## Permite registrar y emparejar rutas dinámicas y estáticas.

import strutils, tables, macros, sugar, asyncdispatch
import ../core/types

type
  TpRouteNode = ref object
    ## Un nodo en el árbol de rutas (Radix Tree o Tree básico)
    handler: TpHandler
    staticChildren: Table[string, TpRouteNode]
    dynamicChild: TpRouteNode  # Nodo para :param o {param}
    paramName: string          # Nombre del parámetro capturado

  TpRouter* = ref object
    ## Enrutador principal que contiene los árboles para cada método HTTP
    trees: Table[TpHttpMethod, TpRouteNode]

proc newTpRouter*(): TpRouter =
  ## Instancia un enrutador nuevo
  new(result)
  result.trees = initTable[TpHttpMethod, TpRouteNode]()

proc newRouteNode(): TpRouteNode =
  new(result)
  result.staticChildren = initTable[string, TpRouteNode]()
  result.dynamicChild = nil

proc addRoute*(router: TpRouter, methodType: TpHttpMethod, path: string, handler: TpHandler) =
  ## Añade una ruta al enrutador. 
  ## Soporta rutas estáticas (/api/v1/users) y dinámicas (/api/v1/users/:id)
  
  if not router.trees.hasKey(methodType):
    router.trees[methodType] = newRouteNode()
  
  var current = router.trees[methodType]
  let parts = path.strip(chars = {'/'}).split('/')

  for part in parts:
    if part == "": continue # Ignorar doble slash
    
    if part.startsWith(":") or (part.startsWith("{") and part.endsWith("}")):
      # Es un segmento dinámico
      if current.dynamicChild == nil:
        current.dynamicChild = newRouteNode()
        current.paramName = part.replace(":", "").replace("{", "").replace("}", "")
      current = current.dynamicChild
    else:
      # Segmento estático
      if not current.staticChildren.hasKey(part):
        current.staticChildren[part] = newRouteNode()
      current = current.staticChildren[part]
      
  current.handler = handler


# --- Typed Routing Macros ---

macro tpRoute*(router: TpRouter, methodType: TpHttpMethod, path: static string, handler: typed) =
  ## Macro central para registrar rutas con inyección automática de parámetros.
  ## Soporta: proc(ctx: TpContext, [param: Type]* )
  
  let handlerName = handler
  let params = handler.getTypeImpl[0] # FormalParams
  
  # Si solo tiene un parámetro (TpContext), registrar directamente
  if params.len <= 2: # [ResultType, TpContext]
    return quote do:
      `router`.addRoute(`methodType`, `path`, `handlerName`)

  # Si tiene más parámetros, generar un wrapper
  let ctxNode = genSym(nskParam, "ctx")
  var wrapperBody = newStmtList()
  var callArgs = newSeq[NimNode]()
  callArgs.add(ctxNode)

  for i in 2..<params.len: # Omitir ResultType y TpContext
    let param = params[i]
    let pName = param[0].strVal
    let pType = param[1]
    
    let extracted = genSym(nskLet, pName)
    let pNameLit = newLit(pName)
    
    # Lógica de conversión basada en tipo
    var conversion: NimNode
    case pType.repr
    of "int":
      conversion = quote do: parseInt(`ctxNode`.getParam(`pNameLit`))
    of "float":
      conversion = quote do: parseFloat(`ctxNode`.getParam(`pNameLit`))
    of "bool":
      conversion = quote do: parseBool(`ctxNode`.getParam(`pNameLit`))
    else: # Por defecto asume string
      conversion = quote do: `ctxNode`.getParam(`pNameLit`)
    
    wrapperBody.add(quote do:
      let `extracted` = `conversion`
    )
    callArgs.add(extracted)

  let callExpr = newCall(handlerName, callArgs)
  wrapperBody.add(quote do:
    await `callExpr`
  )

  let wrapper = quote do:
    proc(`ctxNode`: TpContext): Future[void] {.async, gcsafe.} =
      `wrapperBody`

  result = quote do:
    `router`.addRoute(`methodType`, `path`, `wrapper`)

template get*(router: TpRouter, path: static string, handler: untyped) =
  tpRoute(router, HttpGet, path, handler)

template post*(router: TpRouter, path: static string, handler: untyped) =
  tpRoute(router, HttpPost, path, handler)

template put*(router: TpRouter, path: static string, handler: untyped) =
  tpRoute(router, HttpPut, path, handler)

template delete*(router: TpRouter, path: static string, handler: untyped) =
  tpRoute(router, HttpDelete, path, handler)

proc matchRoute*(router: TpRouter, methodType: TpHttpMethod, path: string): tuple[matched: bool, handler: TpHandler, params: Table[string, string]] =
  ## Intenta emparejar una ruta y extraer los parámetros dinámicos
  result.matched = false
  result.params = initTable[string, string]()
  
  if not router.trees.hasKey(methodType): return
  
  var current = router.trees[methodType]
  let parts = path.strip(chars = {'/'}).split('/')
  
  for part in parts:
    if part == "": continue
    
    if current.staticChildren.hasKey(part):
      current = current.staticChildren[part]
    elif current.dynamicChild != nil:
      result.params[current.paramName] = part
      current = current.dynamicChild
    else:
      return # Ruta no encontrada
      
  if current.handler != nil:
    result.matched = true
    result.handler = current.handler
