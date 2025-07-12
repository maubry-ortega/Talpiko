# src/talpiko/backend/core/patterns.nim
## Sistema de patrones y expresiones regulares minimalista para Talpiko

import strutils  # Necesario para toLower

type
  TpPattern* = ref object
    ## Patrón compilado para búsqueda
    pattern: string
    caseSensitive: bool

proc tpCompilePattern*(pattern: string, caseSensitive = false): TpPattern =
  ## Compila un patrón simple
  new(result)
  result.pattern = pattern
  result.caseSensitive = caseSensitive

proc tpMatch*(input: string, pattern: TpPattern): bool =
  ## Verifica si el input coincide con el patrón
  let str = if pattern.caseSensitive: input else: input.toLower
  let pat = if pattern.caseSensitive: pattern.pattern else: pattern.pattern.toLower

  var i = 0
  var p = 0

  while i < str.len and p < pat.len:
    case pat[p]
    of '[':
      # Grupo de caracteres [abc]
      inc(p)
      var matched = false
      while p < pat.len and pat[p] != ']':
        if pat[p] == str[i]:
          matched = true
        inc(p)
      if not matched:
        return false
      inc(i)
      inc(p) # Saltar el ']'
    of '?':
      # Opcional (0 o 1)
      inc(i)
      inc(p)
    of '*':
      # 0 o más caracteres
      if p == pat.len - 1:
        return true # Coincide con cualquier cosa al final
      inc(p)
      let nextPat = pat[p]
      while i < str.len:
        if tpMatch(str.substr(i), tpCompilePattern(pat.substr(p))):
          return true
        inc(i)
      return false
    of '.':
      # Cualquier carácter
      inc(i)
      inc(p)
    else:
      # Carácter literal
      if str[i] != pat[p]:
        return false
      inc(i)
      inc(p)

  result = i == str.len and p == pat.len