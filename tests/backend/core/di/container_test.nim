import unittest, tables
import ../../../../src/talpiko/backend/core/di/container

type
  # Servicios de prueba que heredan de TpService
  TestService = ref object of TpService
    value*: int
  TestService2 = ref object of TpService
    value*: string

suite "Pruebas del Contenedor DI de Talpiko":
  test "Registro básico y resolución":
    let container = newTpServiceContainer()
    
    # Función factory sin pragma
    proc factory(c: TpServiceContainer): TestService = 
      TestService(value: 42)
    
    tpRegister[TestService](container, factory = factory)
    
    let service = tpResolve[TestService](container)
    check service.value == 42

  test "Singleton funciona correctamente":
    let container = newTpServiceContainer()
    
    proc factory(c: TpServiceContainer): TestService = 
      TestService(value: 0)
    
    tpRegister[TestService](container, TpSingleton, factory)
    
    let s1 = tpResolve[TestService](container)
    let s2 = tpResolve[TestService](container)
    s1.value = 100
    check s2.value == 100
    check s1 == s2

  test "Transient crea nuevas instancias":
    let container = newTpServiceContainer()
    
    proc factory(c: TpServiceContainer): TestService = 
      TestService(value: 0)
    
    tpRegister[TestService](container, TpTransient, factory)
    
    let s1 = tpResolve[TestService](container)
    let s2 = tpResolve[TestService](container)
    s1.value = 200
    check s2.value == 0
    check s1 != s2

  test "Múltiples servicios coexisten":
    let container = newTpServiceContainer()
    
    proc factory1(c: TpServiceContainer): TestService = 
      TestService(value: 1)
    
    proc factory2(c: TpServiceContainer): TestService2 = 
      TestService2(value: "test")
    
    tpRegister[TestService](container, factory = factory1)
    tpRegister[TestService2](container, factory = factory2)
    
    let s1 = tpResolve[TestService](container)
    let s2 = tpResolve[TestService2](container)
    check s1.value == 1
    check s2.value == "test"

  test "Error al resolver servicio no registrado":
    let container = newTpServiceContainer()
    expect KeyError:
      discard tpResolve[TestService](container)