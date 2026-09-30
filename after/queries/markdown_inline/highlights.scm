; extends

; Normale Shortcut-Links behalten versteckte Klammern.
; [!] und [B] sind Checkboxen und bleiben ausgespart, sonst wird das [
; als Link kursiv und unterstrichen.
(shortcut_link
  "[" @markup.link
  (link_text) @_text
  (#not-eq? @_text "!")
  (#not-eq? @_text "B")
  (#not-eq? @_text "b")
  (#set! @markup.link conceal ""))

(shortcut_link
  (link_text) @_text
  (#not-eq? @_text "!")
  (#not-eq? @_text "B")
  (#not-eq? @_text "b")
  "]" @markup.link
  (#set! @markup.link conceal ""))
