# tests/backend/core/logging_test.nim
## Pruebas exhaustivas para el sistema de logging de Talpiko Framework
##
## Cubre:
## - Creación y configuración de loggers
## - Filtrado por niveles de log
## - Handlers personalizados
## - Contexto de logging
## - Comportamiento thread-safe
## - Rotación de archivos (cuando está habilitado)

import 
  unittest, 
  tables,
  os,
  strutils,
  times,
  ../../../src/talpiko/backend/core/logging,
  ../../../src/talpiko/backend/core/types

suite "Pruebas del Sistema de Logging":
  setup:
    # Logger temporal para pruebas
    let testLogger = newTpLogger("test-logger", TP_DEBUG)
    var loggedMessages: seq[tuple[level: TpLogLevel, msg: string, ctx: TpLogContext]] = @[]
    
    # Handler de prueba que captura mensajes
    proc testHandler(
      level: TpLogLevel, 
      msg: string, 
      ctx: TpLogContext, 
      timestamp: string,
      loggerName: string
    ) =
      loggedMessages.add((level, msg, ctx))
    
    testLogger.tpAddHandler(testHandler)

  teardown:
    # Limpiar archivos de prueba
    if fileExists("test.log"):
      removeFile("test.log")
    if fileExists("test.log.bak"):
      removeFile("test.log.bak")

  test "Creación básica de logger":
    check testLogger.name == "test-logger"
    check testLogger.level == TP_DEBUG
    check testLogger.handlers.len == 1
    check testLogger.context.len == 0

  test "Filtrado por nivel de log":
    let infoLogger = newTpLogger("info-logger", TP_INFO)
    var infoMessages: seq[string] = @[]
    
    infoLogger.tpAddHandler proc(
      level: TpLogLevel, 
      msg: string, 
      ctx: TpLogContext, 
      timestamp: string,
      loggerName: string
    ) =
      infoMessages.add(msg)
    
    infoLogger.tpDebug("No debería aparecer")
    infoLogger.tpInfo("Mensaje informativo")
    infoLogger.tpWarn("Advertencia importante")
    
    check infoMessages.len == 2
    check "Mensaje informativo" in infoMessages
    check "Advertencia importante" in infoMessages
    check "No debería aparecer" notin infoMessages

  test "Logging con contexto":
    const testCtx = {"user": "test-user", "action": "login"}.toTable
    testLogger.tpInfo("Acción de usuario", testCtx)
    
    check loggedMessages.len == 1
    check loggedMessages[0].msg == "Acción de usuario"
    check loggedMessages[0].ctx["user"] == "test-user"
    check loggedMessages[0].ctx["action"] == "login"

  test "Logger por defecto":
    let defaultLogger = getDefaultLogger()
    check defaultLogger != nil
    when defined(release):
      check defaultLogger.level == TP_INFO
    else:
      check defaultLogger.level == TP_DEBUG
    check defaultLogger.handlers.len >= 1  # Tiene al menos el handler de consola

  test "Manejo seguro de handlers":
    var handlerCalled = false
    proc tempHandler(
      level: TpLogLevel, 
      msg: string, 
      ctx: TpLogContext, 
      timestamp: string,
      loggerName: string
    ) =
      handlerCalled = true
    
    testLogger.tpAddHandler(tempHandler)
    testLogger.tpInfo("Test handler")
    check handlerCalled
    
    testLogger.tpRemoveHandler(tempHandler)
    handlerCalled = false
    testLogger.tpInfo("Test handler removido")
    check not handlerCalled

  when defined(useFileLogging):
    test "Logging a archivo con rotación":
      const testFile = "test.log"
      let fileLogger = newTpLogger("file-logger")
      
      # Crear archivo de log grande para probar rotación
      if fileExists(testFile):
        removeFile(testFile)
      
      let fileHandler = tpFileHandler(testFile, maxSize = 100)  # 100 bytes máximo
      fileLogger.tpAddHandler(fileHandler)
      
      # Llenar el archivo
      for i in 1..20:
        fileLogger.tpInfo(fmt"Mensaje de prueba {i}")
      
      # Verificar rotación
      check fileExists(testFile)
      let backupFiles = toSeq(walkFiles(testFile & "*"))
      check backupFiles.len >= 1  # Puede haber archivos rotados
      
      # Verificar contenido
      let content = readFile(testFile)
      check "Mensaje de prueba" in content

    test "Manejo de errores en file handler":
      var consoleOutput: seq[string] = @[]
      proc consoleCapture(
        level: TpLogLevel, 
        msg: string, 
        ctx: TpLogContext, 
        timestamp: string,
        loggerName: string
      ) =
        consoleOutput.add(msg)
      
      let errorLogger = newTpLogger("error-logger")
      errorLogger.tpAddHandler(consoleCapture)
      errorLogger.tpAddHandler(tpFileHandler("/ruta/invalida/test.log"))
      
      errorLogger.tpError("Mensaje de error")
      
      check consoleOutput.len == 1
      check "Mensaje de error" in consoleOutput[0]
      check "Error escribiendo log" in consoleOutput[0]  # Mensaje de error del handler

  test "Comportamiento thread-safe":
    var threadMessages: seq[string] = @[]
    let threadLogger = newTpLogger("thread-logger")
    
    proc threadHandler(
      level: TpLogLevel, 
      msg: string, 
      ctx: TpLogContext, 
      timestamp: string,
      loggerName: string
    ) =
      threadMessages.add(msg)
    
    threadLogger.tpAddHandler(threadHandler)
    
    # Simular acceso concurrente
    proc logFromThread(msg: string) =
      threadLogger.tpInfo(msg)
    
    let threads = [
      spawn logFromThread("Hilo 1"),
      spawn logFromThread("Hilo 2"),
      spawn logFromThread("Hilo 3")
    ]
    
    for t in threads:
      sync(t)
    
    check threadMessages.len == 3
    check "Hilo 1" in threadMessages
    check "Hilo 2" in threadMessages
    check "Hilo 3" in threadMessages

  test "Formateo personalizado de mensajes":
    var formattedMessage: string
    proc formatHandler(
      level: TpLogLevel, 
      msg: string, 
      ctx: TpLogContext, 
      timestamp: string,
      loggerName: string
    ) =
      formattedMessage = tpFormatMessage(level, msg, ctx, timestamp, loggerName, "[$level] $message")
    
    let formatLogger = newTpLogger("format-logger")
    formatLogger.tpAddHandler(formatHandler)
    formatLogger.tpWarn("Mensaje con formato")
    
    check formattedMessage.startsWith("[WARN]")
    check "Mensaje con formato" in formattedMessage
    check "$level" notin formattedMessage  # Verificar que se reemplazó

  test "Contexto global del logger":
    let ctxLogger = newTpLogger("ctx-logger", initialContext = {"app": "tests", "version": "1.0.0"}.toTable)
    var capturedCtx: TpLogContext
    
    proc ctxHandler(
      level: TpLogLevel, 
      msg: string, 
      ctx: TpLogContext, 
      timestamp: string,
      loggerName: string
    ) =
      capturedCtx = ctx
    
    ctxLogger.tpAddHandler(ctxHandler)
    ctxLogger.tpInfo("Mensaje con contexto global")
    
    check capturedCtx["app"] == "tests"
    check capturedCtx["version"] == "1.0.0"
    
    # Contexto específico sobrescribe global
    ctxLogger.tpInfo("Mensaje con contexto específico", {"version": "1.0.1"}.toTable)
    check capturedCtx["version"] == "1.0.1"