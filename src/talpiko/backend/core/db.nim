# src/talpiko/backend/core/db.nim
import macros, asyncdispatch, tables, strutils, options
import ./types

type
  TpDbDriver* = ref object of RootObj
    ## Interfaz base para drivers de base de datos.

  MockDriver* = ref object of TpDbDriver
    ## Driver de ejemplo/test.
    data*: Table[string, seq[seq[string]]] # table -> rows -> columns

  TpDb* = ref object
    driver*: TpDbDriver

proc newTpDb*(driver: TpDbDriver): TpDb =
  new(result)
  result.driver = driver

macro tpDbGet*(db: TpDb, T: typedesc, id: int): untyped =
  ## Obtiene un objeto de tipo T por ID de forma tipada usando el driver.
  let tName = T.repr
  let table = tName.toLowerAscii & "s"

  proc getObjNode(n: NimNode): NimNode =
    var curr = n
    for _ in 0..10:
      case curr.kind
      of nnkSym: curr = curr.getTypeImpl
      of nnkTypeDef: curr = curr[2]
      of nnkRefTy: curr = curr[0]
      of nnkObjectTy: return curr
      of nnkBracketExpr: curr = curr[curr.len - 1] # Handle Future[T] or other wrappers
      else: break
    return nil

  let objTypeNode = getObjNode(T)

  var fields = newSeq[string]()
  if objTypeNode != nil:
    let body = objTypeNode[2] # RecList
    for i in 0 ..< body.len:
      fields.add(body[i][0].strVal)
  else:
    error("tpDbGet: No se pudo resolver la estructura de objeto para " & tName, T)

  result = newStmtList()
  let rowSym = genSym(nskLet, "row")
  let objSym = genSym(nskVar, "obj")

  var mapping = newStmtList()
  if objTypeNode != nil:
    let body = objTypeNode[2]
    for i in 0 ..< body.len:
      let fieldNode = body[i][0]
      let fieldType = body[i][1]
      let idx = i
      var conv: NimNode
      case fieldType.repr
      of "int": conv = newCall(ident("parseInt"), newTree(nnkBracketExpr,
          rowSym, newLit(idx)))
      of "float": conv = newCall(ident("parseFloat"), newTree(nnkBracketExpr,
          rowSym, newLit(idx)))
      of "bool": conv = newCall(ident("parseBool"), newTree(nnkBracketExpr,
          rowSym, newLit(idx)))
      else: conv = newTree(nnkBracketExpr, rowSym, newLit(idx))
      mapping.add(newAssignment(newDotExpr(objSym, fieldNode), conv))

  result = quote do:
    # Simulación de obtención de fila desde el driver
    # En un driver real esto sería: await db.driver.getRow(...)
    let `rowSym` = if `db`.driver of MockDriver:
        let m = MockDriver(`db`.driver)
        if m.data.hasKey(`table`) and `id` < m.data[`table`].len:
          m.data[`table`][`id`]
        else: @[""]
      else: @[""]

    if `rowSym`.len == 0 or `rowSym`[0] == "":
      default(`T`)
    else:
      var `objSym`: `T`
      `mapping`
      `objSym`
