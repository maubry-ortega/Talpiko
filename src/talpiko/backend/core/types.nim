# src/talpiko/backend/core/types.nim
## Sistema de tipos avanzado para Talpiko Framework
##
## Proporciona:
## - Monad TpResult para manejo funcional de errores
## - Operaciones monádicas para composición segura
## - Conversión automática de excepciones
## - Tipos de error especializados
## - Operadores para programación fluida
##
## Ejemplo básico:
## runnableExamples:
##   let res = tpOk(42)
##            >>= func(x: int): TpResult[int] = tpOk(x + 1)
##            >>= func(x: int): TpResult[string] = tpOk($x)
##   assert res == tpOk("43")

import 
  macros,
  std/[strformat, strutils]

type
  TpResult*[T] = object
    ## Monad Result para manejo funcional de errores.
    ## 
    ## Args:
    ##   T: Tipo del valor contenido
    case isOk*: bool
    of true:
      value*: T       ## Valor contenido en caso de éxito
    of false:
      error*: ref TpResultError  ## Error en caso de fallo
      errorMsg*: string          ## Mensaje de error legible
      errorCode*: string         ## Código de error estandarizado
      errorContext*: Table[string, string]  ## Contexto adicional
  
  TpResultError* = ref object of CatchableError
    ## Error especializado para TpResult
    code*: string                 ## Código de error estandarizado
    context*: Table[string, string] ## Contexto adicional del error
    exception*: ref Exception      ## Excepción original (si aplica)

const
  DefaultErrorCode* = "TP_UNKNOWN" ## Código de error por defecto
  InternalErrorCode* = "TP_INTERNAL" ## Código para errores internos

# Constructores básicos
proc tpOk*[T](value: T): TpResult[T] =
  ## Crea un resultado exitoso con un valor.
  ## 
  ## Args:
  ##   value: Valor a encapsular
  ## 
  ## Returns:
  ##   TpResult[T] en estado exitoso
  runnableExamples:
    let res = tpOk(42)
    assert res.isOk
    assert res.value == 42
  
  TpResult[T](isOk: true, value: value)

proc tpErr*[T](
  error: string, 
  code: string = DefaultErrorCode,
  context: Table[string, string] = initTable[string, string]()
): TpResult[T] =
  ## Crea un resultado de error con mensaje personalizado.
  ## 
  ## Args:
  ##   error: Mensaje descriptivo del error
  ##   code: Código de error estandarizado
  ##   context: Contexto adicional del error
  ## 
  ## Returns:
  ##   TpResult[T] en estado de error
  runnableExamples:
    let err = tpErr[int]("Invalid input", "TP_INVALID_INPUT")
    assert err.isError
    assert err.errorMsg == "Invalid input"
  
  TpResult[T](
    isOk: false,
    error: TpResultError(
      msg: error,
      code: code,
      context: context
    ),
    errorMsg: error,
    errorCode: code,
    errorContext: context
  )

proc tpErr*[T](
  error: ref Exception, 
  code: string = DefaultErrorCode,
  context: Table[string, string] = initTable[string, string]()
): TpResult[T] =
  ## Crea un resultado de error a partir de una excepción.
  ## 
  ## Args:
  ##   error: Excepción a convertir
  ##   code: Código de error estandarizado
  ##   context: Contexto adicional del error
  ## 
  ## Returns:
  ##   TpResult[T] en estado de error
  let errMsg = if error.msg.isNilOrWhitespace: "Unknown error" else: error.msg
  TpResult[T](
    isOk: false,
    error: TpResultError(
      msg: errMsg,
      code: code,
      context: context,
      exception: error
    ),
    errorMsg: errMsg,
    errorCode: code,
    errorContext: context
  )

# Operaciones de consulta
proc tpIsError*[T](res: TpResult[T]): bool {.inline.} =
  ## Verifica si el resultado es un error.
  ## 
  ## Returns:
  ##   true si es un error, false en caso contrario
  not res.isOk

proc tpErrorCode*[T](res: TpResult[T]): string {.inline.} =
  ## Obtiene el código de error del resultado.
  ## 
  ## Returns:
  ##   Código de error o string vacío si es éxito
  if res.isOk: "" else: res.errorCode

proc tpErrorMsg*[T](res: TpResult[T]): string {.inline.} =
  ## Obtiene el mensaje de error del resultado.
  ## 
  ## Returns:
  ##   Mensaje de error o string vacío si es éxito
  if res.isOk: "" else: res.errorMsg

# Operadores y operaciones monádicas
proc `>>=`*[T, R](
  res: TpResult[T], 
  op: proc(x: T): TpResult[R]
): TpResult[R] {.inline.} =
  ## Operador bind para composición monádica.
  ## 
  ## Args:
  ##   res: Resultado inicial
  ##   op: Función a aplicar si res es éxito
  ## 
  ## Returns:
  ##   Nuevo resultado de la operación
  runnableExamples:
    proc double(x: int): TpResult[int] = tpOk(x * 2)
    let res = tpOk(21) >>= double
    assert res.value == 42
  
  if res.isOk: 
    try:
      op(res.value)
    except CatchableError as e:
      tpErr[R](e)
  else:
    tpErr[R](res.errorMsg, res.errorCode, res.errorContext)

proc tpMap*[T, R](
  res: TpResult[T], 
  op: proc(x: T): R
): TpResult[R] {.inline.} =
  ## Transforma el valor contenido usando op si es éxito.
  ## 
  ## Args:
  ##   res: Resultado a transformar
  ##   op: Función de transformación
  ## 
  ## Returns:
  ##   Nuevo resultado con valor transformado o mismo error
  if res.isOk: 
    try:
      tpOk(op(res.value))
    except CatchableError as e:
      tpErr[R](e)
  else:
    tpErr[R](res.errorMsg, res.errorCode, res.errorContext)

proc tpFlatMap*[T, R](
  res: TpResult[T], 
  op: proc(x: T): TpResult[R]
): TpResult[R] {.inline.} =
  ## Alias para operador bind (>>=)
  res >>= op

proc `?`*[T](res: TpResult[T]): T =
  ## Operador de propagación de error (similar a Rust).
  ## 
  ## Returns:
  ##   Valor contenido o levanta excepción si es error
  runnableExamples:
    let val = tpOk(42).?
    assert val == 42
    
    doAssertRaises(TpResultError):
      discard tpErr[int]("test").?
  
  if res.isOk: res.value
  else: raise res.error

# Manejo de errores
proc tpRecover*[T](
  res: TpResult[T],
  op: proc(err: ref TpResultError): T
): T {.inline.} =
  ## Maneja un error transformándolo a un valor válido.
  ## 
  ## Args:
  ##   res: Resultado a recuperar
  ##   op: Función de recuperación
  ## 
  ## Returns:
  ##   Valor original o resultado de la recuperación
  if res.isOk: res.value else: op(res.error)

proc tpOrElse*[T](
  res: TpResult[T], 
  op: proc(): TpResult[T]
): TpResult[T] {.inline.} =
  ## Ejecuta op si res es error.
  ## 
  ## Args:
  ##   res: Resultado inicial
  ##   op: Función alternativa
  ## 
  ## Returns:
  ##   res si es éxito, resultado de op en caso contrario
  if res.isOk: res else: op()

proc tpGetOrDefault*[T](
  res: TpResult[T], 
  default: T
): T {.inline.} =
  ## Obtiene el valor o un default si es error.
  ## 
  ## Args:
  ##   res: Resultado a evaluar
  ##   default: Valor por defecto
  ## 
  ## Returns:
  ##   Valor contenido o default
  if res.isOk: res.value else: default

# Conversión de excepciones
template tpTry*[T](body: untyped): TpResult[T] =
  ## Ejecuta body capturando cualquier excepción.
  ## 
  ## Returns:
  ##   TpResult con el valor o error capturado
  runnableExamples:
    let res = tpTry:
      if true: 42
      else: raise newException(ValueError, "error")
    assert res == tpOk(42)
  
  try:
    tpOk(body)
  except CatchableError as e:
    tpErr[T](e)

template tpTryOr*[T](
  body: untyped,
  errorHandler: untyped
): TpResult[T] =
  ## Ejecuta body con manejo personalizado de errores.
  ## 
  ## Args:
  ##   body: Código a ejecutar
  ##   errorHandler: Manejador de excepciones
  ## 
  ## Returns:
  ##   TpResult con el valor o error procesado
  try:
    tpOk(body)
  except CatchableError as e:
    errorHandler(e)

# Operaciones de colección
iterator tpResults*[T](results: seq[TpResult[T]]): T =
  ## Itera sobre resultados exitosos.
  ## 
  ## Yields:
  ##   Valores de resultados exitosos
  for res in results:
    if res.isOk:
      yield res.value

proc tpCollect*[T](results: seq[TpResult[T]]): TpResult[seq[T]] =
  ## Combina múltiples resultados en uno solo.
  ## 
  ## Returns:
  ##   Seq de valores si todos son éxito, primer error encontrado
  var collected: seq[T] = @[]
  for res in results:
    if res.isError:
      return tpErr[seq[T]](res.errorMsg, res.errorCode, res.errorContext)
    collected.add(res.value)
  tpOk(collected)

# Extensiones avanzadas
proc tpTap*[T](
  res: TpResult[T],
  op: proc(x: T)
): TpResult[T] {.inline.} =
  ## Ejecuta op con el valor si es éxito (para side-effects).
  ## 
  ## Returns:
  ##   El mismo resultado sin modificar
  if res.isOk:
    op(res.value)
  res

proc tpTapError*[T](
  res: TpResult[T],
  op: proc(err: ref TpResultError)
): TpResult[T] {.inline.} =
  ## Ejecuta op con el error si es fallo (para side-effects).
  ## 
  ## Returns:
  ##   El mismo resultado sin modificar
  if res.isError:
    op(res.error)
  res

when isMainModule:
  # Ejemplos de uso
  let success = tpOk(42)
  let failure = tpErr[int]("Division by zero", "TP_DIV_ZERO")
  
  echo "Success: ", success
  echo "Failure: ", failure
  
  let mapped = success >>= proc(x: int): TpResult[int] = tpOk(x * 2)
  echo "Mapped success: ", mapped
  
  let recovered = failure.tpRecover(proc(e: ref TpResultError): int = 0)
  echo "Recovered value: ", recovered