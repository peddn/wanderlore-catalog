# Wanderlore-Katalog

Ein Werkzeug für die Entwicklung von [Wanderlore](https://github.com/peddn/wanderlore): Es zeigt, was bestehende Luanti-Mods mitbringen, damit man daraus auswählen kann. Es gibt zwei Welten:

- **Wesen:** alle Monster und Tiere in einem Fenster, mit Texturen und Animationen.
- **Pflanzen:** alle Stämme, Blätter, Setzlinge, Blumen, Gräser, Pilze und Bodenblöcke als Tafeln mit Nummern, und alle Bäume einzeln in Reihen auf einer flachen, kahlen Welt.

Der Katalog ist kein Teil des Spiels. Die fremden Mods werden nicht in dieses Repository kopiert. `sources.toml` nennt Quelle, feste Version und Lizenz jeder Quelle, ein Skript holt sie.

## Was man braucht

- Luanti 5.18
- Git und Bash

## Einrichten und starten

```
scripts/setup.sh
scripts/run.sh
```

`scripts/run.sh` startet die Wesen, `scripts/run.sh plants` die Pflanzen.

`setup.sh` legt alles im Ordner `.dev/` an: Minetest Game, die Quellen, den Katalog-Mod und die beiden Welten. Die eigenen Luanti-Welten bleiben unberührt. Das Skript lässt sich beliebig oft wiederholen.

Ist Luanti nicht unter dem Namen `luanti` erreichbar, nennt man das Programm so: `LUANTI=/pfad/zu/luanti scripts/run.sh`.

## Bedienen

Nach dem Start öffnet sich der Katalog von selbst. Später öffnet ihn der Befehl `/katalog` oder das Buch im Inventar.

- **Links** steht die Liste aller Wesen. Jedes hat eine Nummer aus Buchstabe und Zahl, zum Beispiel `N26`. Der Buchstabe steht für die Quelle. Darüber lässt sich die Liste auf eine Quelle einschränken.
- **In der Mitte** steht das Modell. Mit der Maus lässt es sich drehen. Die Knöpfe darunter spielen die Animationen ab, die der Mod angibt.
- **Rechts** stehen Quelle, Art, Leben, Schaden, technischer Name und Lizenz. Darunter wechselt man die Textur, wenn es mehrere gibt.
- **In die Welt stellen** setzt das Modell vor die eigene Figur, in seiner echten Größe. Es bewegt sich nicht vom Fleck und greift nicht an. Ein Schlag entfernt es wieder.

## Pflanzen bedienen

Die Welt der Pflanzen ist flach und kahl. Ihr Boden ist ein eigener Block mit einem Raster: jede Linie ein Block. Die Generatoren der Quellen laufen nicht, und nichts wächst, breitet sich aus oder zerfällt.

- **`/pflanzen`** oder das Buch im Inventar öffnet die Tafeln der Blöcke. Jeder Block hat eine Nummer aus den Buchstaben der Quelle und einer Zahl, zum Beispiel `EB12`. Die Farbe des Feldes zeigt die Art: Stamm, Bretter, Laub, Setzling, Blume, Pilz, Pflanze, Wasserpflanze, Boden. Ein Klick legt den Block ins Inventar und nennt seinen technischen Namen.
- **`/quellen`** oder der Kristall im Inventar öffnet die Liste der Quellen. Je Quelle springt ein Knopf zu ihrem ersten Baum und einer an den Anfang ihres Gangs der Beete.
- **`/arten`** oder der Diamant im Inventar öffnet die Liste der Baumarten. Jeder Baum steht ein zweites Mal in Reihen nach Art, weit hinter den Beeten: erst die Familien, etwa alle Birken aller Quellen, dann die Bäume ohne bekannten Namen je Quelle, dann Büsche, Stämme und Stümpfe, Pflanzengruppen sowie Strukturen und Gebäude. In einer Reihe stehen die Bäume mit demselben Stamm-Block nebeneinander. Die Familie ist aus dem Namen geraten und trifft nicht immer.
- **`/auswahl`** springt zur Auswahl für Wanderlore; die Listen von `/arten` und `/quellen` haben dafür oben rechts einen grünen Knopf. Dort steht jede gewählte Form zweimal nebeneinander: wie gewählt und mit Hängelaub, einem Block des Katalogs aus demselben Laub in Strähnen. `mods/wl_catalog/selection.lua` nennt je Baumart einen Stamm, ein Laub und die gewählten Formen; der Katalog stellt jede Form noch einmal auf, umgeschrieben auf diese beiden Blöcke. Eine Form lässt sich dort auch vergrößern. Nach einer Änderung der Datei `scripts/setup.sh` ausführen. `scripts/shots.sh plants "" selection` macht daraus die Tafel `selection_<Art>_<Seite>.jpg`.
- **Die Bodenpflanzen** stehen als Beete von 5 × 5 in der Welt, weit weg von den Bäumen. Jede Quelle hat einen eigenen Gang: einen hellen Weg mit ihren Beeten links und rechts, am Anfang steht ihr Name. `/beet EB` springt an den Anfang des Gangs von Extra Biomes, `/beet EB12` vor ein Beet.
- **Die Bäume** stehen in Reihen, eine Reihe je Quelle. Jeder Baum hat eine Nummer mit `-T`, zum Beispiel `MT-T13`; sie schwebt über dem Baum. `/baum` listet die Reihen, `/baum MT-T13` springt vor den Baum.
- Fliegen mit `K`, schnell mit `J`.

Woher die Bäume kommen: Der Katalog liest, was die Quellen für ihre eigenen Generatoren angemeldet haben, sucht in ihren Ordnern nach weiteren Baumdateien und lässt die Bäume von More Trees nach deren Regeln wachsen. Aufgenommen wird, was Stamm, Laub oder Pflanzen enthält; so stehen dort auch Büsche, liegende Stämme und manche Bauwerke mit Bewuchs.

## Quellen der Wesen

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

Eine Quelle hinzufügen: einen Abschnitt in `sources.toml` ergänzen und `scripts/setup.sh` erneut ausführen. Mit `set = "plants"` gehört sie zur Welt der Pflanzen. Ein Modpack braucht keinen Eintrag `mod`; seine Mods werden gefunden.

## Quellen der Pflanzen

| Buchstaben | Quelle | Blöcke | Bäume |
| --- | --- | --- | --- |
| MG | Minetest Game | 73 | 30 |
| MT | More Trees | 82 | 15 |
| PL | Plantlife | 69 | 0 |
| EB | Extra Biomes | 164 | 55 |
| ET | Ethereal NG | 139 | 24 |
| EV | Everness | 226 | 59 |
| NB | Wilhelmines Natural Biomes | 152 | 53 |
| LJ | Wilhelmines Living Jungle | 19 | 10 |
| LD | Wilhelmines Living Desert | 50 | 25 |
| LF | Wilhelmines Living Floatlands | 69 | 35 |
| AO | Aotearoa | 138 | 64 |
| BB | Better Biomes | 20 | 44 |
| SW | Swamp Biome | 11 | 7 |
| RP | Giant Mushrooms | 9 | 0 |
| SU | Swamps | 12 | 0 |
| SB | Sunset Biomes | 10 | 11 |
| FT | Fruit Trees | 30 | 19 |
| MA | Maple Tree | 4 | 1 |
| CO | Coconut Trees | 2 | 1 |
| XF | X Farming | 58 | 10 |
| BF | Beautiful Flowers | 105 | 0 |
| HB | Herbs | 21 | 0 |
| EF | Elysflowers | 45 | 0 |
| NF | New Flowers | 14 | 0 |
| MF | Moonflowers | 1 | 0 |
| DS | Decorations Sea | 20 | 24 |

Zusammen 1543 Blöcke und 487 Einträge unter den Bäumen; 707 der Blöcke sind Bodenpflanzen und stehen als Beet in der Welt. Dazu kommen die Bibliotheken XCompat und Biome Lib. Gesucht wurden die Quellen am 23.11.2026 auf ContentDB. Australia war zuerst dabei und ist gestrichen.

## Übersichtsbilder

`scripts/shots.sh` nimmt von jedem Wesen ein Bild auf und setzt sie zu Übersichten in `.dev/sheets/` zusammen. Das läuft auf einem unsichtbaren Bildschirm und braucht Xvfb, ImageMagick und Python 3 mit Pillow.

`scripts/shots.sh plants` macht dasselbe für die Pflanzen, nach `.dev/sheets-plants/`: die Tafeln der Blöcke als `blocks_<Quelle>_<Seite>.png`, die Bäume als `trees_<Quelle>_<Seite>.jpg`, die Beete als `beds_<Quelle>_<Seite>.jpg`, die Bäume nach Art als `kinds_<Nummer>_<Art>_<Seite>.jpg`, mit dem Namen des Stamm-Blocks unter jedem Baum. Stämme, Bretter und Laub aller Quellen stehen zusätzlich nebeneinander auf `blocks_TRUNK_…`, `blocks_PLANKS_…` und `blocks_LEAVES_…`. Unter jedem Baum stehen Nummer, Name und Breite mal Höhe in Blöcken. Mit `scripts/shots.sh plants "MT EB"` nur für einzelne Quellen, mit einem dritten Wort nur für eine Art von Bildern: `scripts/shots.sh plants "" beds`. Alles zusammen dauert auf einem Bildschirm ohne Grafikkarte gut eine Stunde.

## Grenzen

- **Die Zahl 200 enthält Doppelte.** Farbvarianten und Altersstufen sind bei manchen Mods eigene Einträge, etwa die Schafe in Mobs Animal.
- **Die Art ist nicht immer bekannt.** Nur Mods auf Basis von Mobs Redo sagen, ob etwas Monster oder Tier ist. Bei Draconis, Animalia und Paleotest steht „unbekannt“.
- **Im Fenster stehen manche Modelle schief**, vor allem aus Not So Simple Mobs. Das Fenster zeigt das Modell so, wie es gespeichert ist. „In die Welt stellen“ zeigt es so, wie Luanti es im Spiel darstellt.
- **Der Katalog zeigt nur das Modell.** Verhalten, Geräusche, Angriffe und Geschosse der Wesen zeigt er nicht.
- **Die Tafeln der Blöcke lassen Wachstumsstufen aus.** Gezeigt wird, was die Quelle im Kreativ-Inventar anbietet. Abgeleitete Formen wie Treppen, Platten und Zäune fehlen ebenfalls.
- **Nicht jeder Baum ist ein Baum.** Der Katalog erkennt Bäume daran, dass eine Baudatei Stamm, Laub oder Pflanzen enthält.
- **Bäume, die nur aus eigenem Code wachsen, fehlen,** außer denen von More Trees. Das betrifft etwa die Riesenpilze.
- **Pflanzen aus zwei Blöcken zeigen im Beet nur den unteren,** und Ranken liegen am Boden statt zu hängen.
- **Die Lizenzen in `sources.toml` gelten für die Quelle als Ganzes,** wie ContentDB sie nennt. Einzelne Dateien können abweichen und sind vor einer Übernahme zu prüfen.
- **Alte Mods laufen nur mit Nachhilfe.** `mods/wl_catalog/compat.lua` gleicht aus, was aktuelles Luanti ablehnt. Das reicht zum Anzeigen, nicht zum Spielen.

## Aufbau

```
sources.toml             Quellen mit fester Version und Lizenz
scripts/setup.sh         holt die Quellen, legt die Welt an
scripts/run.sh           startet den Katalog, mit "plants" die Pflanzen
scripts/shots.sh         nimmt Bilder aller Wesen auf, mit "plants" der Pflanzen
scripts/shots_plants.sh  der Teil für die Pflanzen
scripts/sheets.py        setzt die Bilder der Wesen zu Übersichten zusammen
scripts/sheets_plants.py dasselbe für die Bäume
mods/wl_catalog/         der Katalog-Mod; plants.lua ist der Teil für die Pflanzen
```
