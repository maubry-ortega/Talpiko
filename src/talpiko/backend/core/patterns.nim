# src/talpiko/backend/core/patterns.nim
## Sistema avanzado de patrones para Talpiko Framework
## Proporciona un motor de coincidencia de patrones eficiente con soporte para:
## - Grupos de caracteres
## - Cuantificadores
## - Modo case-sensitive/insensitive
## - Patrones precompilados para mejor rendimiento

import strutils, tables

type
  TpPattern* = ref object
    ## Patrón compilado para búsqueda optimizada
    originalPattern: string
    compiledPattern: string
    caseSensitive: bool
    charGroups: Table[int, set[char]]  # Cache para grupos de caracteres
    isPrecompiled: bool

const
  SpecialChars = {'[', ']', '?', '*', '.'}
  DefaultCaseSensitive = false

proc initTpPattern(): TpPattern =
  ## Inicializa un nuevo patrón con valores por defecto
  new(result)
  result.charGroups = initTable[int, set[char]]()
  result.isPrecompiled = false

proc normalizePattern(pattern: string, caseSensitive: bool): string =
  ## Normaliza el patrón según configuración de case sensitivity
  if caseSensitive:
    pattern
  else:
    pattern.toLowerAscii()

proc compileCharGroup(pattern: string, startPos: int): (set[char], int) =
  ## Compila un grupo de caracteres [abc] a un conjunto eficiente
  var charSet: set[char] = {}
  var pos = startPos + 1  # Saltar el '['
  
  while pos < pattern.len and pattern[pos] != ']':
    if pattern[pos] == '\\' and pos + 1 < pattern.len:
      # Carácter escapado
      inc(pos)
      charSet.incl(pattern[pos])
    else:
      charSet.incl(pattern[pos])
    inc(pos)
  
  if pos >= pattern.len:
    raise newException(ValueError, "Grupo de caracteres no cerrado")
  
  (charSet, pos + 1)  # Retorna el set y posición después del ']'

proc tpCompilePattern*(pattern: string, caseSensitive = DefaultCaseSensitive): TpPattern =
  ## Compila un patrón optimizado para búsquedas repetidas
  ## Args:
  ##   pattern: String con el patrón a compilar
  ##   caseSensitive: Si la coincidencia debe ser sensible a mayúsculas
  result = initTpPattern()
  result.originalPattern = pattern
  result.caseSensitive = caseSensitive
  result.compiledPattern = normalizePattern(pattern, caseSensitive)
  
  # Precompilar grupos de caracteres para mejor rendimiento
  var pos = 0
  var groupIndex = 0
  while pos < pattern.len:
    if pattern[pos] == '[':
      let (charSet, newPos) = compileCharGroup(pattern, pos)
      result.charGroups[groupIndex] = charSet
      pos = newPos
      inc(groupIndex)
    else:
      inc(pos)
  
  result.isPrecompiled = true

proc matchChar(c: char, patternChar: char, caseSensitive: bool): bool =
  ## Comparación de caracteres con manejo de case sensitivity
  if caseSensitive:
    c == patternChar
  else:
    c.toLowerAscii() == patternChar.toLowerAscii()

proc matchStar(
  input: string, 
  pattern: TpPattern, 
  inputPos: int, 
  patternPos: int
): (bool, int) =
  ## Maneja el cuantificador * (0 o más caracteres)
  var currentInputPos = inputPos
  
  if patternPos >= pattern.compiledPattern.len:
    return (true, input.len)  # Coincide con cualquier cosa al final
  
  let nextPatternPos = patternPos + 1
  let nextPatternChar = pattern.compiledPattern[nextPatternPos]
  
  while currentInputPos < input.len:
    let (matched, newPos) = tpMatchImpl(input, pattern, currentInputPos, nextPatternPos)
    if matched:
      return (true, newPos)
    inc(currentInputPos)
  
  (false, inputPos)

proc tpMatchImpl(
  input: string,
  pattern: TpPattern,
  inputPos: int,
  patternPos: int
): (bool, int) =
  ## Implementación recursiva de la coincidencia de patrones
  var i = inputPos
  var p = patternPos
  var groupIndex = 0
  
  while i < input.len and p < pattern.compiledPattern.len:
    let patternChar = pattern.compiledPattern[p]
    
    case patternChar
    of '[':
      # Grupo de caracteres precompilado
      if groupIndex in pattern.charGroups:
        let charSet = pattern.charGroups[groupIndex]
        if input[i] notin charSet:
          return (false, i)
        inc(groupIndex)
      else:
        # Fallback para grupos no precompilados
        var found = false
        inc(p)  # Saltar '['
        while p < pattern.compiledPattern.len and pattern.compiledPattern[p] != ']':
          if matchChar(input[i], pattern.compiledPattern[p], pattern.caseSensitive):
            found = true
          inc(p)
        if not found:
          return (false, i)
      inc(i)
      inc(p)  # Saltar ']'
    
    of '?':
      # Carácter opcional (0 o 1)
      inc(i)
      inc(p)
    
    of '*':
      # Cuantificador 0 o más
      let (matched, newPos) = matchStar(input, pattern, i, p)
      if not matched:
        return (false, i)
      i = newPos
      inc(p)
    
    of '.':
      # Cualquier carácter
      inc(i)
      inc(p)
    
    else:
      # Carácter literal
      if not matchChar(input[i], patternChar, pattern.caseSensitive):
        return (false, i)
      inc(i)
      inc(p)
  
  # Verificar si coincidió todo el patrón
  if p == pattern.compiledPattern.len:
    (true, i)
  else:
    (false, i)

proc tpMatch*(input: string, pattern: TpPattern): bool =
  ## Verifica si el input coincide completamente con el patrón
  let normalizedInput = if pattern.caseSensitive: input else: input.toLowerAscii()
  let (matched, pos) = tpMatchImpl(normalizedInput, pattern, 0, 0)
  matched and pos == normalizedInput.len

proc tpPartialMatch*(input: string, pattern: TpPattern): bool =
  ## Verifica si el input contiene el patrón en cualquier posición
  let normalizedInput = if pattern.caseSensitive: input else: input.toLowerAscii()
  for i in 0..(normalizedInput.len - 1):
    let (matched, _) = tpMatchImpl(normalizedInput, pattern, i, 0)
    if matched:
      return true
  false

proc tpStartsWith*(input: string, pattern: TpPattern): bool =
  ## Verifica si el input comienza con el patrón
  let normalizedInput = if pattern.caseSensitive: input else: input.toLowerAscii()
  let (matched, _) = tpMatchImpl(normalizedInput, pattern, 0, 0)
  matched

proc tpEndsWith*(input: string, pattern: TpPattern): bool =
  ## Verifica si el input termina con el patrón
  let normalizedInput = if pattern.caseSensitive: input else: input.toLowerAscii()
  for i in countdown(normalizedInput.len - 1, 0):
    let (matched, pos) = tpMatchImpl(normalizedInput, pattern, i, 0)
    if matched and pos == normalizedInput.len:
      return true
  false

when isMainModule:
  # Tests básicos
  let emailPattern = tpCompilePattern("*@*.*")
  assert "user@domain.com".tpMatch(emailPattern)
  assert not "invalid.email".tpMatch(emailPattern)
  
  let casePattern = tpCompilePattern("Test", true)
  assert "Test".tpMatch(casePattern)
  assert not "test".tpMatch(casePattern)
  
  echo "Todos los tests de patrones pasaron correctamente"