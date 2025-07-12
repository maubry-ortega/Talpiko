# tests/frontend/dom_test.nim
import ../src/frontend/dom/core

proc testDomCreation() =
  let el = createElement("test", "Hola Talpiko")
  assert el.id == "test"
  assert el.render().contains("Hola Talpiko")

when isMainModule:
  testDomCreation()
  echo "Frontend tests passed"