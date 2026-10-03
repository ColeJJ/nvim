# Datenbank-Viewer (DBee + Dadbod)

IntelliJ-/Doom-artiger Postgres-Viewer: `nvim-dbee` stellt Verbindungs-, Schema- und
Tabellenbaum, Query-Editor sowie eine paginierte Ergebnisansicht bereit.
`vim-dadbod` bleibt für SQL aus normalen `.sql`-Dateien zuständig.

DBee verwendet einen eigenen Postgres-Treiber. `psql` wird nur für den
Verbindungscheck und Dadbod benötigt.

## Öffnen

- `SPC o d` — kompletten DB-Viewer öffnen/schließen
- `SPC f t` — Tabellen/Views der aktiven Verbindung fuzzy suchen und direkt anzeigen
- `SPC t c` — Spalte im aktuellen Resultat fuzzy suchen und zur Spalte springen
- `SPC t w` — WHERE-Bedingung wie in IntelliJ auf die aktuelle Tabelle anwenden
- `:Dbee open` / `:Dbee close` — Viewer direkt öffnen/schließen
- `:DBCheck [Profil]` — asynchron `SELECT 1` (Erreichbarkeit, User, Datenbank, `~/.pgpass`)

Der Viewer besteht aus drei Bereichen: links Verbindungen/Schemas/Tabellen,
darunter die Abfragehistorie und rechts die Tabelle über die volle Höhe.
Der DBee-Welcome-Editor ist ausgeblendet. SQL aus `.sql`-Dateien läuft weiter
über Dadbod (`SPC m s`). Beim Schließen wird das vorherige Fensterlayout restauriert.

`SPC f t` nutzt die in DBee aktive Verbindung (anfangs ENT 5432). Eine andere
Verbindung wird im Viewer mit `Enter` auf ihrem Namen aktiviert.

`SPC t c` liest die Spalten aus dem aktuellen Resultat-Grid. Die Auswahl setzt
den Cursor in diese Spalte, scrollt sie nach links und markiert sie kurz.

`SPC t w` fragt eine WHERE-Bedingung ohne das Schlüsselwort `WHERE` ab, etwa
`name LIKE '%Sach%' AND deletedateinternal IS NULL`. Leer bestätigen entfernt
den Filter wieder. Die letzte Bedingung bleibt vorausgefüllt.

## SQL aus einer .sql-Datei ausführen

1. Statement **markieren** — oder den Cursor **ins Statement** setzen
   (bis zum nächsten `;`; steht der Cursor hinter einem `;`, gilt das beendete Statement).
2. `SPC m s` oder `C-c C-c` (nur in SQL-Buffern; `SPC m` bleibt global Maven).
3. Profil wählen (zuletzt genutztes ist markiert).
4. Ergebnis erscheint im Dadbod-Preview (`dbout`). Winbar zeigt `DB: <Profil>`.

In der Ergebnisansicht:

| Taste | Aktion |
| --- | --- |
| `R` | Query erneut |
| `r` | Query zum Bearbeiten |
| `q` / `gq` | schließen |
| `<C-]>` | Foreign Key folgen (Postgres) |
| `<C-c>` | laufende Query abbrechen |

## Profile

Standardprofile (ohne Passwort) in [`lua/colejj/database/profiles.lua`](../lua/colejj/database/profiles.lua):

| Name | Port | User | Datenbank |
| --- | --- | --- | --- |
| ENT - Postgres (5432) | 5432 | ent | Entscheidungen |
| BAS - Postgres (5433) | 5433 | ent | EntscheidungenBasis |
| ENT - Kundenversion - Entscheidungen (5440) | 5440 | ent | Entscheidungen |
| ENT - Kundenversion - Basis (5440) | 5440 | ent | EntscheidungenBasis |
| Guide-Client - magellan (5432) | 5432 | sa | magellan |

Lokale Ergänzungen oder Overrides (nicht im Git):

`~/.config/nvim/lua/colejj/database/profiles.local.lua`

```lua
return {
  {
    name = "Lokal - Extra",
    user = "ent",
    host = "localhost",
    port = 5432,
    database = "Entscheidungen",
  },
}
```

## Passwörter (`~/.pgpass`)

Profile enthalten kein Passwort. DBee (lib/pq), `psql` und Dadbod lesen `~/.pgpass`:

```
localhost:5432:Entscheidungen:ent:DEIN_PW
localhost:5433:EntscheidungenBasis:ent:DEIN_PW
localhost:5440:Entscheidungen:ent:DEIN_PW
localhost:5440:EntscheidungenBasis:ent:DEIN_PW
localhost:5432:magellan:sa:DEIN_PW
```

Format: `host:port:database:user:password`. Danach:

```bash
chmod 600 ~/.pgpass
```

Ohne `0600` ignoriert libpq die Datei. Passwörter kommen nicht in Lua, Logs oder Git.

## Viewer (DBee)

- `o` — Verbindung, Schema oder Tabelle auf-/zuklappen
- `Enter` auf einer Verbindung — als aktive Verbindung setzen
- `Enter` auf einer Tabelle — Aktion auswählen, z. B. „Daten anzeigen (max. 200)“
- `r` — Baum/Metadaten aktualisieren
- `q` — gesamten Viewer schließen und altes Layout wiederherstellen
- `SPC w h/j/k/l` — zwischen Baum, Historie und Resultat wechseln

Im Resultat:

- `L` / `H` — nächste / vorherige Seite
- `F` / `E` — erste / letzte Seite
- `Enter` — Zelle bearbeiten, erneutes `Enter` speichert (`UPDATE` über Primary Key), `Esc` bricht ab. Leer oder `NULL` setzt die Spalte auf `NULL`, `''` speichert einen leeren Text.
- `dd` — aktuelle Zeile zum Löschen markieren bzw. Markierung aufheben
- visuell Zeilen wählen, dann `dd` — mehrere Zeilen zum Löschen markieren bzw. Markierungen aufheben
- `Enter` bei vorhandenen Löschmarkierungen — alle markierten Zeilen atomar über ihren Primary Key löschen
- `yy` / `yc` — Zelle unter dem Cursor kopieren (`NULL` wird leer)
- `yac` / `yaj` — aktuelle Zeile als CSV / JSON kopieren
- `yaC` / `yaJ` — alle Zeilen als CSV / JSON kopieren
- `q` — Viewer schließen

Der Viewer zeigt 200 Datensätze pro Seite. Tabellenaktionen bieten zusätzlich
Spalten, Indizes und weitere PostgreSQL-Metadaten.

## Diagnose

| Symptom | Ursache | Fix |
| --- | --- | --- |
| Warnung „psql nicht gefunden“ | nur Check/Dadbod nicht verfügbar | `brew install libpq && brew link --force libpq` |
| Warnung „Keine ~/.pgpass“ | Datei fehlt | anlegen, `chmod 600` |
| „Verbindung fehlgeschlagen“ | Port zu, falsches Profil, kein `.pgpass`-Treffer | Docker/Tunnel prüfen, Eintrag anpassen |
| Baum veraltet | Schema geändert | im Viewer `r` |
| Dadbod-Completion veraltet | Schema geändert | `:DBCompletionClearCache` |

DBee und Dadbod lesen lokale Passwörter aus `~/.pgpass`; die Connection-URLs
in der Konfiguration enthalten kein Passwort.
