# src/talpiko/backend/core/di/container.nim
## Sistema avanzado de Inyección de Dependencias (DI) para Talpiko
##
## Proporciona:
## - Contenedor DI con administración de ciclo de vida
## - Soporte para Singleton y Transient
## - Registro y resolución type-safe
## - Manejo de dependencias anidadas
## - Sistema de scopes configurables
##
## Ejemplo básico:
## runnableExamples:
##   type MyService = ref object of TpService
##     value: int
##
##   let container = newTpServiceContainer()
##   container.tpRegister(proc(c: TpServiceContainer): MyService = MyService(value: 42))
##   let service = container.tpResolve(MyService)
##   assert service.value == 42

import 
  tables, typetraits,
  macros,
  ../logging,
  ../types

type
  TpServiceLifetime* = enum
    ## Ciclo de vida de los servicios DI
    TpSingleton  ## Única instancia compartida
    TpTransient  ## Nueva instancia en cada resolución
    TpScoped     ## Instancia única por scope (no implementado aún)

  TpService* = ref object of RootObj
    ## Tipo base para todos los servicios inyectables
    discard

  TpServiceDescriptor* = ref object
    ## Descriptor de servicio para el contenedor DI
    implementation*: proc(container: TpServiceContainer): TpService {.closure.}
    lifetime*: TpServiceLifetime
    instance*: TpService  ## Cache para singletons
    logger*: TpLogger     ## Logger específico para el servicio

  TpServiceContainer* = ref object
    ## Contenedor principal de inyección de dependencias
    services*: Table[string, TpServiceDescriptor]
    parent*: TpServiceContainer  ## Contenedor padre para jerarquías
    logger*: TpLogger            ## Logger del contenedor

# Helpers de verificación de tipos
template isTpServiceType*(T: typedesc): bool =
  ## Verifica si un tipo es válido para el sistema DI
  compiles:
    var s: T
    s of TpService

proc validateServiceType*[T]() =
  ## Valida el tipo de servicio en tiempo de compilación
  when not isTpServiceType(T):
    {.error: "El tipo debe ser un ref object que herede de TpService".}

# Constructor y administración del contenedor
proc newTpServiceContainer*(
  parent: TpServiceContainer = nil,
  logger: TpLogger = getDefaultLogger()
): TpServiceContainer =
  ## Crea una nueva instancia del contenedor DI
  ## 
  ## Args:
  ##   parent: Contenedor padre para resolución jerárquica
  ##   logger: Logger personalizado para el contenedor
  ## 
  ## Returns:
  ##   Nueva instancia configurada de TpServiceContainer
  
  new(result)
  result.services = initTable[string, TpServiceDescriptor]()
  result.parent = parent
  result.logger = logger
  result.logger.tpDebug("Nuevo contenedor DI creado")

proc tpRegister*[T](
  container: TpServiceContainer,
  factory: proc(container: TpServiceContainer): T,
  lifetime: TpServiceLifetime = TpSingleton,
  logger: TpLogger = container.logger
) =
  ## Registra un servicio en el contenedor DI
  ## 
  ## Args:
  ##   container: Contenedor donde registrar el servicio
  ##   factory: Función factory que crea el servicio
  ##   lifetime: Ciclo de vida del servicio
  ##   logger: Logger personalizado para el servicio
  
  validateServiceType[T]()
  
  let typeId = name(T)
  container.logger.tpDebug(fmt"Registrando servicio: {typeId}", {
    "lifetime": $lifetime
  }.toTable)

  # Factory wrapper para conversión de tipo segura
  proc impl(container: TpServiceContainer): TpService =
    try:
      let service = factory(container)
      result = TpService(service)
    except Exception as e:
      container.logger.tpError(fmt"Error creando servicio {typeId}", {
        "error": e.msg
      }.toTable)
      raise

  container.services[typeId] = TpServiceDescriptor(
    implementation: impl,
    lifetime: lifetime,
    instance: nil,
    logger: logger
  )

proc tpTryResolve*[T](
  container: TpServiceContainer
): TpResult[T] =
  ## Intenta resolver un servicio manejando errores como TpResult
  ## 
  ## Args:
  ##   container: Contenedor donde resolver el servicio
  ## 
  ## Returns:
  ##   TpResult con el servicio o error
  
  validateServiceType[T]()
  
  let typeId = name(T)
  container.logger.tpDebug(fmt"Intentando resolver servicio: {typeId}")

  try:
    if not container.services.hasKey(typeId):
      if not container.parent.isNil:
        return container.parent.tpTryResolve[T]()
      
      let msg = fmt"Servicio no registrado: {typeId}"
      container.logger.tpError(msg)
      return tpErr[T](msg, "TP_DI_SERVICE_NOT_REGISTERED")

    let descriptor = container.services[typeId]
    var serviceInstance: TpService

    case descriptor.lifetime
    of TpSingleton:
      if descriptor.instance.isNil:
        descriptor.instance = descriptor.implementation(container)
      serviceInstance = descriptor.instance
    of TpTransient:
      serviceInstance = descriptor.implementation(container)
    of TpScoped:
      # Implementación futura para scopes
      raise newException(ValueError, "Scoped lifetime no implementado aún")

    if serviceInstance.isNil:
      let msg = fmt"Instancia nil para servicio: {typeId}"
      descriptor.logger.tpError(msg)
      return tpErr[T](msg, "TP_DI_NIL_INSTANCE")

    let result = cast[T](serviceInstance)
    if result.isNil or not (serviceInstance of T):
      let msg = fmt"Tipo de servicio no coincide: {typeId}"
      descriptor.logger.tpError(msg)
      return tpErr[T](msg, "TP_DI_TYPE_MISMATCH")

    descriptor.logger.tpDebug(fmt"Servicio resuelto exitosamente: {typeId}")
    tpOk(result)

  except Exception as e:
    container.logger.tpError(fmt"Error resolviendo servicio {typeId}", {
      "error": e.msg
    }.toTable)
    tpErr[T](e)

proc tpResolve*[T](
  container: TpServiceContainer
): T =
  ## Resuelve un servicio del contenedor DI
  ## 
  ## Args:
  ##   container: Contenedor donde resolver el servicio
  ## 
  ## Returns:
  ##   Instancia del servicio solicitado
  ## 
  ## Raises:
  ##   KeyError si el servicio no está registrado
  ##   ValueError si hay problemas con la instancia
  
  let res = container.tpTryResolve[T]()
  if res.isOk:
    res.value
  else:
    raise res.error

# Extensiones avanzadas
proc tpCreateScope*(container: TpServiceContainer): TpServiceContainer =
  ## Crea un nuevo scope de dependencias (implementación futura)
  ## 
  ## Returns:
  ##   Nuevo contenedor con scope independiente
  newTpServiceContainer(parent: container, logger: container.logger)

proc tpRegisterInstance*[T](
  container: TpServiceContainer,
  instance: T,
  logger: TpLogger = container.logger
) =
  ## Registra una instancia existente como singleton
  validateServiceType[T]()
  
  let typeId = name(T)
  container.logger.tpDebug(fmt"Registrando instancia singleton: {typeId}")

  container.services[typeId] = TpServiceDescriptor(
    implementation: proc(c: TpServiceContainer): TpService = TpService(instance),
    lifetime: TpSingleton,
    instance: TpService(instance),
    logger: logger
  )

# Soporte para resolución de secuencias
iterator tpResolveAll*[T](
  container: TpServiceContainer
): T =
  ## Resuelve todas las implementaciones registradas de un tipo
  ## 
  ## Yields:
  ##   Cada implementación registrada del tipo solicitado
  validateServiceType[T]()
  
  let typeName = name(T)
  for key, descriptor in container.services:
    if key.startsWith(typeName):
      let instance = container.tpResolve(T)
      yield instance

when isMainModule:
  # Ejemplo de uso
  type
    DatabaseService* = ref object of TpService
      url*: string
    
    AppService* = ref object of TpService
      db*: DatabaseService
  
  let container = newTpServiceContainer()
  
  # Registro de servicios
  container.tpRegister(proc(c: TpServiceContainer): DatabaseService =
    DatabaseService(url: "localhost:5432")
  )
  
  container.tpRegister(proc(c: TpServiceContainer): AppService =
    AppService(db: c.tpResolve(DatabaseService))
  )
  
  # Resolución de servicios
  let appService = container.tpResolve(AppService)
  echo "Database URL: ", appService.db.url
  
  # Ejemplo con manejo de errores
  let result = container.tpTryResolve(AppService)
  if result.isOk:
    echo "Servicio resuelto correctamente"
  else:
    echo "Error: ", result.errorMsg