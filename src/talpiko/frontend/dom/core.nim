# src/frontend/dom/core.nim
type
  Element* = ref object
    id*: string
    content*: string

proc createElement*(id: string, content: string = ""): Element =
  ## Factory para crear elementos del DOM
  Element(id: id, content: content)

proc render*(self: Element): string =
  ## Renderiza el elemento como HTML
  "<div id=\"$1\">$2</div>" % [self.id, self.content]