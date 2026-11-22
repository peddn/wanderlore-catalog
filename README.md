# Wanderlore-Katalog

Ein Werkzeug für die Entwicklung von [Wanderlore](https://github.com/peddn/wanderlore): Es zeigt alle Monster und Tiere aus bestehenden Luanti-Mods in einem Fenster, mit Texturen und Animationen, damit man daraus auswählen kann.

Der Katalog ist kein Teil des Spiels. Die fremden Mods werden nicht in dieses Repository kopiert. `sources.toml` nennt Quelle, feste Version und Lizenz jeder Quelle, ein Skript holt sie.

## Was man braucht

- Luanti 5.18
- Git und Bash

## Einrichten und starten

```
scripts/setup.sh
scripts/run.sh
```

`setup.sh` legt alles im Ordner `.dev/` an: Minetest Game, die Quellen, den Katalog-Mod und eine flache Welt. Die eigenen Luanti-Welten bleiben unberührt. Das Skript lässt sich beliebig oft wiederholen.

Ist Luanti nicht unter dem Namen `luanti` erreichbar, nennt man das Programm so: `LUANTI=/pfad/zu/luanti scripts/run.sh`.

## Bedienen

Nach dem Start öffnet sich der Katalog von selbst. Später öffnet ihn der Befehl `/katalog` oder das Buch im Inventar.

- **Links** steht die Liste aller Wesen. Jedes hat eine Nummer aus Buchstabe und Zahl, zum Beispiel `N26`. Der Buchstabe steht für die Quelle. Darüber lässt sich die Liste auf eine Quelle einschränken.
- **In der Mitte** steht das Modell. Mit der Maus lässt es sich drehen. Die Knöpfe darunter spielen die Animationen ab, die der Mod angibt.
- **Rechts** stehen Quelle, Art, Leben, Schaden, technischer Name und Lizenz. Darunter wechselt man die Textur, wenn es mehrere gibt.
- **In die Welt stellen** setzt das Modell vor die eigene Figur, in seiner echten Größe. Es bewegt sich nicht vom Fleck und greift nicht an. Ein Schlag entfernt es wieder.

## Quellen

| Buchstabe | Quelle | Wesen |
| --- | --- | --- |
| M | Mobs Monster | 11 |
| A | Mobs Animal | 24 |
| N | Not So Simple Mobs | 68 |
| D | dmobs | 35 |
| G | Goblins | 12 |
| R | Draconis | 13 |
| L | Animalia | 18 |
| P | Paleotest | 19 |

Zusammen 200. Lizenzen und feste Versionen stehen in `sources.toml`.

Eine Quelle auslassen: `WL_CATALOG_SKIP="paleotest mob_core" scripts/setup.sh`

Eine Quelle hinzufügen: einen Abschnitt in `sources.toml` ergänzen und `scripts/setup.sh` erneut ausführen.

## Übersichtsbilder

`scripts/shots.sh` nimmt von jedem Wesen ein Bild auf und setzt sie zu Übersichten in `.dev/sheets/` zusammen. Das läuft auf einem unsichtbaren Bildschirm und braucht Xvfb, ImageMagick und Python 3 mit Pillow.

## Grenzen

- **Die Zahl 200 enthält Doppelte.** Farbvarianten und Altersstufen sind bei manchen Mods eigene Einträge, etwa die Schafe in Mobs Animal.
- **Die Art ist nicht immer bekannt.** Nur Mods auf Basis von Mobs Redo sagen, ob etwas Monster oder Tier ist. Bei Draconis, Animalia und Paleotest steht „unbekannt“.
- **Im Fenster stehen manche Modelle schief**, vor allem aus Not So Simple Mobs. Das Fenster zeigt das Modell so, wie es gespeichert ist. „In die Welt stellen“ zeigt es so, wie Luanti es im Spiel darstellt.
- **Der Katalog zeigt nur das Modell.** Verhalten, Geräusche, Angriffe und Geschosse der Wesen zeigt er nicht.
- **Alte Mods laufen nur mit Nachhilfe.** `mods/wl_catalog/compat.lua` gleicht aus, was aktuelles Luanti ablehnt. Das reicht zum Anzeigen, nicht zum Spielen.

## Aufbau

```
sources.toml             Quellen mit fester Version und Lizenz
scripts/setup.sh         holt die Quellen, legt die Welt an
scripts/run.sh           startet den Katalog
scripts/shots.sh         nimmt Bilder aller Wesen auf
scripts/sheets.py        setzt die Bilder zu Übersichten zusammen
mods/wl_catalog/         der Katalog-Mod
```
