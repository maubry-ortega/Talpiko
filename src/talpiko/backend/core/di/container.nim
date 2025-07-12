import tables, typetraits

type
  # Enumeración para el ciclo de vida del servicio
  TpServiceLifetime* = enum
    TpSingleton, TpTransient

  # Tipo base para todos los servicios de Talpiko DI
  TpService* = ref object of RootObj

  # Descriptor para almacenar la información de cada servicio registrado
  TpServiceDescriptor* = ref object
    implementation*: proc(container: TpServiceContainer): TpService
    lifetime*: TpServiceLifetime
    instance*: TpService

  # El contenedor de inyección de dependencias
  TpServiceContainer* = ref object
    services*: Table[string, TpServiceDescriptor]

# Verificación de tipo para servicios válidos
template isTpServiceType*(T: typedesc): bool =
  compiles:
    var s: T
    s of TpService

# Proceso para crear una nueva instancia del contenedor de servicios
proc newTpServiceContainer*(): TpServiceContainer =
  new result
  result.services = initTable[string, TpServiceDescriptor]()

# Proceso para registrar un servicio en el contenedor
proc tpRegister*[T](
  container: TpServiceContainer,
  lifetime: TpServiceLifetime = TpSingleton,
  factory: proc(container: TpServiceContainer): T
) =
  when not isTpServiceType(T):
    {.error: "El tipo debe ser un ref object que herede de TpService".}
  
  let typeId = name(T)
  
  # Creamos una copia de la factory para evitar captura ilegal
  let factoryCopy = factory
  
  # Implementación sin captura ilegal
  proc impl(container: TpServiceContainer): TpService =
    let service = factoryCopy(container)
    result = TpService(service)
  
  container.services[typeId] = TpServiceDescriptor(
    implementation: impl,
    lifetime: lifetime,
    instance: nil
  )

# Proceso para resolver (obtener) una instancia de un servicio del contenedor
proc tpResolve*[T](container: TpServiceContainer): T =
  when not isTpServiceType(T):
    {.error: "El tipo debe ser un ref object que herede de TpService".}
  
  let typeId = name(T)
  if not container.services.hasKey(typeId):
    raise newException(KeyError, "Servicio no registrado: " & typeId)

  let descriptor = container.services[typeId]
  var serviceInstance: TpService

  case descriptor.lifetime
  of TpSingleton:
    if descriptor.instance.isNil:
      descriptor.instance = descriptor.implementation(container)
    serviceInstance = descriptor.instance
  of TpTransient:
    serviceInstance = descriptor.implementation(container)

  # Conversión segura con verificación
  if serviceInstance.isNil:
    raise newException(ValueError, "Instancia de servicio es nil para: " & typeId)
  
  # Conversión segura con verificación de tipo
  result = cast[T](serviceInstance)
  if result.isNil or not (serviceInstance of T):
    raise newException(ValueError, "Tipo de servicio no coincide para: " & typeId)