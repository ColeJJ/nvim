# GitLab Merge-Request-Review

`SPC g m` listet offene MRs des aktuellen Repos und öffnet Review in Neovim
statt in der GitLab-UI. `:GitLabMR` bzw. `:GitLabMR 123` geht direkt auf `!123`.

## Ablauf

1. `SPC g m` — Telescope-Liste (Filterzeile wie gewohnt)
2. `Enter` — Übersicht rechts: Beschreibung, Pipeline, Approvals, Diskussionen
3. In der Übersicht:

| Taste | Aktion |
| --- | --- |
| `d` / `Enter` | Diffview (Ziel…Quelle, nach `git fetch` des MR-Refs) |
| `c` | allgemeinen Kommentar schreiben (`C-s` sendet) |
| `R` | Diskussion unter dem Cursor beantworten |
| `e` / `gf` | zur kommentierten Datei/Zeile springen |
| `a` / `u` | Approve / Approve entfernen |
| `b` | MR im Browser |
| `r` | Übersicht neu laden |
| `q` | schließen |

Im Picker: `d` öffnet den Diff sofort, `b` den Browser.

## Token

Die API braucht ein Personal Access Token mit Scope **`api`**. Reihenfolge:

1. `GITLAB_TOKEN` oder `GITLAB_PRIVATE_TOKEN`
2. `~/.config/nvim/lua/colejj/git/review.local.lua` (nicht im Git)
3. `~/.authinfo` wie Forge, Host aus dem Git-Remote:

```
machine gitlab.guidecom.de login <user> password <token>
machine gitlab.guidecom.local login <user> password <token>
```

4. `git credential fill` (HTTPS-Remote, Keychain)

Beispiel `review.local.lua`:

```lua
return {
  token = "glpat-…",
  -- insecure = true,  -- nur wenn das Firmenzertifikat curl blockt
  -- tokens = {
  --   ["gitlab.guidecom.de"] = "glpat-…",
  --   ["gitlab.guidecom.local"] = "glpat-…",
  -- },
}
```

Host und Projekt kommen aus `origin` (`gitlab.guidecom.de` und
`gitlab.guidecom.local` werden erkannt).

## tuicr

`SPC g t` öffnet denselben MR in [tuicr](https://github.com/agavra/tuicr):
Nummer oder URL eingeben, leer lassen nimmt den MR des aktuellen Branches.
`:TuicrMR 125` geht direkt auf `!125`. Inline-Kommentare und Approve laufen
in tuicr über `:submit`. `SPC g m` bleibt die Neovim-Übersicht.

Einmalig, außerhalb von Neovim:

```bash
brew install glab tuicr
glab auth login --hostname gitlab.guidecom.de
```

tuicr speichert kein Token. Es nutzt das Konto, mit dem `glab` am Host
angemeldet ist. Für die zweite Instanz denselben Login mit
`--hostname gitlab.guidecom.local` wiederholen.
