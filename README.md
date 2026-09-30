# Neovim als Java-/Spring-IDE

Lua-Konfiguration mit **lazy.nvim**, nativem Neovim-0.11-LSP, **nvim-java** und
einer Kompatibilitätsschicht zu den Maven-Reactor- und IntelliJ-Run-Workflows
der Doom-Emacs-Konfiguration.

## Voraussetzungen

- Neovim **0.11.5+** (offiziell von nvim-java). `0.11.0` läuft mit einem
  `cmd`-Wrapper und einer deaktivierten harten Versionsprüfung; ein Upgrade
  bleibt empfohlen (`brew upgrade neovim`).
- JDK **21** für JDT.LS, projektbezogen zusätzlich JDK **17**
- `git`, `fd`, `ripgrep`, `make`
- Maven (`mvn` oder `./mvnw`) bzw. Gradle-Wrapper
- Optional: `lazygit`, `lazydocker`, `podman` (Compose-Provider: `docker-compose` oder `podman-compose`), `delta`, Node für PHP/JS-Debugger, `psql` (`libpq`) für die Datenbank-UI

JDK-Suche (ohne hart codierte Einzelpfade):

- `/Library/Java/JavaVirtualMachines/{temurin,jdk,openjdk,zulu}-VERSION.jdk`
- `/opt/homebrew/opt/openjdk@VERSION`
- `JAVA_HOME`

## Installation

```bash
# Plugins und Mason-Tools
nvim --headless "+Lazy! sync" +qa

# In Neovim
:checkhealth
:Mason
```

Der bisherige Packer-Stack ist entfernt. `lazy-lock.json` versioniert die Plugin-Stände.

## Architektur

```
init.lua
lua/colejj/
  set.lua remap.lua project.lua lazy.lua
  plugins/          lazy.nvim-Specs
  java/             JDT.LS, Run/Debug, Maven, IntelliJ-Parser
  database/         Postgres-Profile, Dadbod, SQL am Cursor
  snippets/         IntelliJ Live Templates (LuaSnip)
lua/overseer/template/user/maven.lua
formatter/gc-eclipse-format.xml
formatter/gcIntellijCodeStyle.xml
```

JDT.LS bekommt **pro Projekt** einen gehashten Workspace unter
`~/.local/share/nvim/jdtls-workspace/`. `.project` verkleinert die Wurzel nicht;
gesucht wird Git-Root bzw. das **oberste** `pom.xml` (Reactor).

## Keymaps

Leader ist `Space`.

| Taste | Aktion |
| --- | --- |
| `<leader>fs` / `⌘S` | Datei speichern (`:w`) |
| `<leader>C` | Cursor: Insert schmal ↔ Block mit Farbwechsel |

### Navigation / LSP

| Taste | Aktion |
| --- | --- |
| `gd` | Definition |
| `gD` | Implementierung |
| `gy` | Typ-Definition |
| `gh` | Hover |
| `gf` | Referenzen |
| `gn` / `<leader>cr` | Rename |
| `<leader>ca` | Code Action |
| `]e` `[e` | nächster / vorheriger Fehler |
| `]w` `[w` | nächste / vorherige Warnung |
| `<leader>sc` | Go to Class (fd) |
| `<leader>sC` | Workspace-Symbole (LSP) |
| `<leader>si` | Datei-Symbole |
| `<leader>fm` | Methoden im Projekt |
| `<leader>sw` | Wort unter Cursor in dieser Datei |
| `/` / `<leader>ss` / `<leader>sp` / `<leader>gr` (visuell) | Auswahl als Suchtext |

### Java (`<leader>j`)

| Taste | Aktion |
| --- | --- |
| `jo` | Imports ordnen |
| `jf` | Format (Profil `gcIntellijCodeStyle`) |
| `ju` | Maven/Gradle neu importieren |
| `jn` | Neuer Typ (Class/Interface/Enum/Record) |
| `jI` | Interface ↔ Impl |
| `ji` | Super-Methode |
| `jg` `js` `je` `jv` | Generate Getter / toString / equals / Override |
| `jB` | Build Project (ganzer Reactor) |
| `jb` | Modul + Dependents |
| `jh` / `jW` | JDT.LS Health / Workspace-Reset |

### Maven (`<leader>m`)

| Taste | Aktion |
| --- | --- |
| `mm` | Overseer-Task-Picker |
| `mc` | compile (Reactor) |
| `mb` | Rebuild (`clean install -DskipTests`) |
| `mt` | freies Goal |
| `mT` | test (Modul + Upstream) |
| `mi` | install `-DskipTests` |
| `md` | `dependency:tree` |
| `mu` | Reimport |
| `mr` / `rr` | IntelliJ-Run-Config: Build im unteren Terminal, danach DAP-Konsole |
| `mR` | Fallback `mvn exec:java` |
| `mk` `me` `ma` `mh` | Stop / Rerun / Attach :5005 / HotSwap |

### Tests (`<leader>rt`)

| Taste | Aktion |
| --- | --- |
| `rtt` | Test unter Cursor |
| `rta` | alle Tests der aktuellen Klasse |
| `rtd` / `rtD` | Debug (Methode / Datei) |
| `rtl` | letzten Test wiederholen |
| `rto` / `rts` | Output / Übersicht |
| `rtS` | Tests stoppen |

Der Klassenlauf nutzt einen gecachten Maven-Test-Classpath und den direkten
JUnit-Console-Runner. Vollständige XML-Reports beenden die Anzeige zuverlässig;
nach 120 Sekunden wird ein tatsächlich hängender Lauf abgebrochen.
Fehlgeschlagene Tests zeigen Erwartung, Ist-Wert und relevante Stackframes
direkt an; `e` auf einem Fehler öffnet den vollständigen Fehler in einem großen Fenster.

### Debug (`<leader>d`)

| Taste | Aktion |
| --- | --- |
| `dd` / `F5` | Continue |
| `db` `dc` `dl` | Breakpoint / Bedingung / Logpoint |
| `dn` `di` `do` / `F8` `F7` | Step Over / Into / Out |
| `de` `dE` `dw` `dr` | Evaluate / Watch / REPL |
| `du` `dU` | DAP-UI / Layout reset |
| `da` | Attach :5005 |
| `dQ` | Alles stoppen |

### Buffer (`<leader>b`)

| Taste | Aktion |
| --- | --- |
| `bl` | offene Buffer; `d` / `x` / `<C-d>` schließt den ausgewählten |

`<leader>d` ist nicht mehr „löschen ohne Yank“ — das liegt jetzt auf `<leader>D`.
Wort ersetzen ist `<leader>R`. Dateibaum ist `<leader>e`. Fenster: `wh/j/k/l` springen,
Pfeiltasten nach `SPC w` schieben die Größe.

### Öffnen (`<leader>o`)

| Taste | Aktion |
| --- | --- |
| `ob` | aktuelle Datei im Standard-Browser öffnen (wie Doom `SPC o b`) |
| `oc` | Compose-Picker, dann LazyDocker für den gewählten Stack (`lazydocker.yml`) |
| `oC` | LazyDocker direkt: alle Container, Images, Volumes |
| `od` | DB-Viewer: Verbindungen, Schemas, Tabellen und paginierte Daten |

### Datenbank

Postgres-Viewer über DBee; SQL-Dateien über Dadbod. Details:
[docs/datenbank.md](docs/datenbank.md).

| Taste | Aktion |
| --- | --- |
| `ft` | Tabelle/View der aktiven DB fuzzy finden und Daten anzeigen |
| `tc` | Spalte im aktuellen Resultat fuzzy finden und dorthin springen |
| `tw` | WHERE-Filter wie in IntelliJ auf die aktuelle Tabelle |
| `ms` / `C-c C-c` (in `.sql`) | Statement oder Auswahl ausführen |

### Git

| Taste | Aktion |
| --- | --- |
| `gg` / `gs` | LazyGit / aktuelle Datei |
| `gm` | GitLab-MRs: Übersicht, Diff, Kommentare, Approve ([docs/review.md](docs/review.md)) |
| `fc` | Commit suchen; Enter öffnet Details im vertikalen Buffer (`q` zu, `c` Checkout) |
| `gb` | Inline-Blame |
| `gd` / `gD` | Datei-Diff vs HEAD / vs Abzweigpunkt (readonly, `e` sprung, `d` verwerfen) |
| `gh` | Datei-Historie |
| `gc` | Merge-Konflikte |

## Spring

nvim-java startet die Spring Boot Tools:

- Completion in `application.yml` / `application.properties`
- Bean- und Endpoint-Symbole (`<leader>sb`)
- Annotation-Hinweise und Code Actions
- Built-in Runner von nvim-java (`:JavaRunnerRunMain`)

## Doom-Kompatibilität

Nur wenn das Projekt erkannt wird (`ent-dev` in der POM, `ent.application.properties`
oder Projektname `entscheidungen`):

- Maven-Profil `-Pent-dev`
- SSL/Wagon-Flags für Nexus mit selbstsigniertem Zertifikat
- Spiegeln von `src/test/resources/conf` nach `target/classes` vor DAP-Starts
- Build-before-run: `mvn -pl <modul> -am compile` bzw. `install` für den Maven-Fallback

Allgemeine Spring-Boot-Projekte bleiben davon unberührt.

IntelliJ-`Application`-Configs kommen aus `.idea/runConfigurations/*.xml`
(Main-Klasse, Modul, VM-Args, Env, Working Directory).

## Formatierung

`SPC c f` formatiert Java über JDT.LS mit dem Eclipse-Profil
[`formatter/gc-eclipse-format.xml`](formatter/gc-eclipse-format.xml) (`gcIntellijCodeStyle`),
abgeleitet aus dem IntelliJ-Schema
[`formatter/gcIntellijCodeStyle.xml`](formatter/gcIntellijCodeStyle.xml).

Kernregeln: 2 Spaces, Continuation 4, Zeilenbreite 100, Import-Reihenfolge
`static / java / javax / org / com / Rest`, keine Star-Imports.

Kotlin nutzt ktlint (Official Style). Imports werden **nicht** automatisch beim
Speichern umgeschrieben (`<leader>jo`).

JDT.LS muss nach dem Profilwechsel neu starten (`:e` auf einer Java-Datei oder
`<leader>jW`).

## Optionale Folgephasen

Nicht Teil dieser Umstellung, aber später sinnvoll:

- REST-Client
- Profiler / Flamegraph

## Abnahme

1. `nvim --version` ≥ 0.11.5
2. `:Lazy` ohne Packer-/lsp-zero-Reste
3. `:checkhealth lazy`, Mason, LSP, Treesitter, neotest
4. Spring-Boot-Projekt: Completion, Format, Reimport, Tests, Run/Debug
5. Maven-Reactor mit `.idea/runConfigurations`: Picker, Build-before-run, Attach, Rerun, Stop
6. Bestehende Lua/Go/JS/PHP-LSPs und Debugger unverändert
