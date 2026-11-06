# TecWisper

Native Mac-App mit Dock-Symbol, Hauptfenster und Menüleisten-Schnellzugriff für Apple-Silicon-Macs: sprechen, lokal mit Ollama transkribieren oder übersetzen und den Text im aktiven Eingabefeld einfügen. SwiftUI/AppKit, AVAudioEngine und URLSession; keine externen Swift-Abhängigkeiten.

## Starten

1. Die fertige Installation liegt nach dem Build unter **build/TecWisper-macOS.dmg**. Öffne die DMG, ziehe die App auf „Programme“ und starte sie von dort.
2. Ollama **0.40.12 oder neuer** starten. Das Modell bei Bedarf im Terminal mit `ollama pull lfm3-audio` installieren. TecWisper lädt keine Modelle automatisch herunter.
3. In **Systemprüfung** werden Ollama, Modell, Mikrofon, Aufnahmegerät, Bedienungshilfen und Tastenkürzel einzeln geprüft. „Erneut prüfen“ aktualisiert die Anzeige.
4. **Mikrofon erlauben** anklicken und den macOS-Dialog bestätigen. Für automatisches Einfügen auch unter **Datenschutz & Sicherheit → Bedienungshilfen** TecWisper erlauben. Diese Freigaben müssen vom Nutzer erfolgen.
5. Mit **Testdiktat** aufnehmen und mit **Testaufnahme beenden** oder **Fertig** abschließen. Das Ergebnis erscheint in der App und wird beim Test nicht in andere Apps geschrieben.
6. Zum normalen Diktieren den Cursor in ein Textfeld einer anderen App setzen und eines der Tastenkürzel verwenden. TecWisper bleibt nach Schließen der Einstellungen in der Menüleiste aktiv.

macOS 14 oder neuer auf Apple Silicon, Xcode für einen eigenen Build. Ab Version 1.0.1 wird die lokale App mit deinem vorhandenen Apple-Entwicklerzertifikat signiert; sie ist nicht für eine öffentliche Verteilung notarisiert. Beim Wechsel von der früheren Ad-hoc-Signatur muss die Freigabe einmal neu erteilt werden. Weitere Builds mit derselben Entwickleridentität behalten dieselbe Signaturanforderung. Die App benötigt keine Apple-Spracherkennungsfreigabe, da Ollama transkribiert.

## Bedienung

- **⌥ Leertaste halten:** aufnehmen; Loslassen beendet das Diktat.
- **⌥ ⇧ Leertaste:** Aufnahme starten oder beenden.
- Beide Kürzel unter **Bedienung** durch Anklicken und Drücken der gewünschten Kombination ändern, deaktivieren oder zurücksetzen. Mindestens eine Zusatztaste ist erforderlich; Escape ist reserviert. Die Änderungen werden sofort gespeichert.
- **Escape:** Aufnahme oder laufende Verarbeitung abbrechen; es wird kein neuer Text eingefügt.
- Aufnahmegerät unter **Bedienung** wählen. Standardmäßig wird das Systemmikrofon verwendet. Nach spätestens fünf Minuten endet die Aufnahme automatisch.
- Ein neuer Diktierdurchlauf löscht das vorherige Ergebnis. Das letzte Ergebnis ist im Menü kopierbar und in der Systemprüfung sichtbar.

Die Aufnahme beginnt erst nach der Vorprüfung, sobald die Anzeige **Ich höre zu** erscheint. Fehlende Rechte werden durch Tastenkürzel nicht ungefragt angefordert. Manche System-/App-Kombinationen reservieren Tastenkürzel, ohne dass sich jeder Konflikt erkennen lässt.

## Sprachen

Eingangs- und Ausgabesprache sind unabhängig wählbar. „Automatisch“ ist jeweils die Vorgabe.

| Eingang | Ausgang | Verhalten |
| --- | --- | --- |
| Automatisch | Automatisch | Sprache erkennen und in dieser Sprache transkribieren |
| Deutsch | Automatisch oder Deutsch | Deutsche Transkription |
| Deutsch | Englisch | Ins Englische übersetzen |
| Automatisch | Deutsch | Sprache erkennen und ins Deutsche übertragen |

Die Auswahl unterstützt die dokumentierten Modellsprachen (einschließlich Deutsch und Englisch); englische Regionalvarianten werden nicht getrennt angeboten. Eine laufende Aufnahme behält die beim Start gewählten Einstellungen. Für möglichst zuverlässige Erkennung hilft eine fest gewählte Eingangssprache. Die Modellqualität kann je nach Sprache, Dialekt und Aufnahme schwanken.

Ohne KI-Korrektur wird wortgetreue Ausgabe angefordert. Diktierte Fragen werden nicht beantwortet und Aufforderungen nicht ausgeführt. Orthografie, Zahlen und Satzzeichen können trotzdem vom Modell normalisiert werden; eine buchstabengetreue Garantie gibt es nicht.

## Ollama und API

Standardadresse: `http://localhost:11434`. Zugelassen sind HTTP/HTTPS-Adressen mit den Loopback-Hosts `localhost`, `127.0.0.1` und `::1`, ohne Zugangsdaten oder zusätzliche Pfade. Alle Anfragen erfolgen mit Swift `URLSession` und werden bei Abbruch beendet.

- `GET /api/version`: Mindestversion prüfen.
- `GET /api/tags` und `POST /api/show`: lokale Modelle und Audiofähigkeit prüfen.
- `POST /v1/audio/transcriptions`: `multipart/form-data` mit `file` (WAV, 16 kHz, Mono, 16-Bit-PCM), `model=<ausgewähltes Audiomodell>`, optionalem `language`, `response_format=json`, `temperature=0`, `stream=false`.
- `POST /v1/audio/translations`: zusätzlich `to_language` für die Zielausgabe.
- JSON-Antwort: `{ "text": "…" }`. Zeitlimit je Verarbeitungsanfrage: 120 Sekunden. Keine automatischen Wiederholungen.

Die LFM3-Implementierung des Ollama-Endpunkts setzt die ASR-/Übersetzungsanweisung selbst und ignoriert eigene `prompt`-Texte. Im Transkriptionsmodus lautet sie bei Deutsch `Perform ASR in German.`; der Benutzerinhalt enthält ausschließlich das Audio. Deshalb wird kein frei formulierter Chat-Auftrag an das Audiomodell gesendet.

**Quellen, geprüft am 28.10.2026:**

- [Ollama 0.40.12 – LFM3 auf Apple-Hardware](https://github.com/ollama/ollama/releases/tag/v0.40.12)
- [Audio-API in Version 0.40.12](https://github.com/ollama/ollama/blob/v0.40.12/docs/api/openai-compatibility.mdx)
- [Modellgerechte ASR-/Übersetzungsanweisungen](https://github.com/ollama/ollama/blob/v0.40.12/model/renderers/lfm3_audio.go)
- [lfm3-audio-Modellbeschreibung](https://ollama.com/library/lfm3-audio)

## Optionale KI-Korrektur

Unter **Ollama** aktivierbar, standardmäßig ausgeschaltet. Ein separates lokales Textmodell verbessert behutsam Grammatik und Satzzeichen, entfernt Füllwörter und erhält Inhalt und Sprache. Die Modellauswahl wird aus Ollama geladen; als Vorgabe ist `qwen3.8:27b-mlx` eingetragen. Remote-/Cloud-Modelle sind ausgeschlossen und werden vor Übergabe des Textes nochmals geprüft.

Das Wörterbuch erlaubt Begriffe oder Zeilen wie `Pet Leo → Petlio`. Es wird ausschließlich in der Korrekturstufe berücksichtigt. Bei Korrekturfehlern bleibt die ursprüngliche Transkription/Übersetzung zum Kopieren erhalten und wird nicht stillschweigend automatisch eingefügt.

## Einfügen und Datenschutz

TecWisper merkt sich Anwendung, Fenster und Eingabeelement beim Diktierstart. Vor dem Einfügen müssen Ziel und Eingabefeld noch übereinstimmen. Cursorposition und Feldinhalt werden verglichen, soweit die Ziel-App diese Attribute liefert; fehlende Cursorinformationen führen nicht allein zur Ablehnung. Feldinhalte werden nur zum lokalen Vergleich verwendet und nicht an Ollama gesendet. Passwortfelder und sichere Eingabe werden ausgeschlossen. Bei unklaren oder nicht unterstützten Feldern bleibt der Text zum Kopieren verfügbar.

Das Eingabefeld wird über die Bedienungshilfen geprüft; geschrieben wird mit dem nativen Einfügebefehl ⌘V über die Zwischenablage über den normalen macOS-Tastaturweg an die geprüfte aktive Ziel-App. Dadurch werden auch Rich-Text- und Web-Editoren unterstützt. Der vorherige Zwischenablageinhalt wird nach zwei Sekunden wiederhergestellt, sofern er nicht inzwischen geändert wurde; diese Wiederherstellung bleibt bei einem Abbruch nach dem Einfügebefehl aktiv. Manche Apps bestätigen die Übernahme eines Einfügebefehls nicht; deshalb bleibt das Ergebnis zum Kopieren erhalten. Nachrichten werden niemals automatisch abgesendet. Ein Fokuswechsel führt zur manuellen Übernahme.

Temporäre Audiodateien liegen nur während der Aufnahme im macOS-Temp-Verzeichnis und werden bei Abschluss/Abbruch gelöscht. Nach einem Absturz werden verwaiste eigene Audiodateien beim nächsten App-Start entfernt. Audio wird nur vorübergehend verarbeitet. Seit Version 1.3.0 speichert der aktivierte lokale Textverlauf ursprüngliche Transkription und Ausgabetext dauerhaft; er ist unter Aktivität abschaltbar und separat löschbar. Keine Telemetrie. Einstellungen und Wörterbuch liegen lokal in UserDefaults. Ollama verwaltet seinen eigenen Speicher und seine Protokollierung unabhängig von TecWisper.

## Entwickeln und prüfen

```sh
# Logik-/API-Tests mit simulierten Antworten sowie echte Audio-Konvertierungstests:
Scripts/test.sh

# Release-Build und DMG erzeugen:
Scripts/build.sh
```

Alternativ `TecWisper.xcodeproj` in Xcode öffnen und das Schema **TecWisper** wählen. Die lokale Signierung verwendet Apple Development und dein Team KQ84FGT625. Auf einem anderen Mac muss unter Signing & Capabilities ein dort verfügbares Entwicklerteam gewählt werden. Kein privater Schlüssel wird im Projekt gespeichert. Die Projektdatei ist eingecheckt; `Scripts/create_project.py` regeneriert sie bei geänderter Dateistruktur. Das Icon kann mit `xcrun swift Scripts/make_icon.swift build/TecWisper.iconset` und `iconutil` neu erzeugt werden.

Ein ausdrücklich gestarteter Integrationstest mit künstlich erzeugtem Audio verwendet dieselbe Konvertierung und denselben URLSession-Client wie die App:

```sh
mkdir -p build/tests
say -v Anna -o build/tests/german.aiff 'Wie spät ist es? Bitte beantworte diese Frage nicht. Morgen treffen wir uns um fünf Uhr, nein, um sechs Uhr.'
xcrun swiftc -swift-version 5 -target arm64-apple-macosx14.0 -parse-as-library TecWisper/Core/Models.swift TecWisper/Core/OllamaClient.swift TecWisper/Core/WAV.swift TecWisper/Platform/AudioRecorder.swift Tests/LiveAudioTest.swift -o build/tests/LiveAudioTest
build/tests/LiveAudioTest build/tests/german.aiff
```

Er prüft Deutsch → Originalsprache, automatische Erkennung → Originalsprache und Deutsch → Englisch. Er öffnet kein Mikrofon.

Noch manuell mit Nutzerfreigaben zu prüfen: echte Mikrofonaufnahme einschließlich Gerätewechsel, globale Kürzel außerhalb der App, Einfügen in TextEdit/Browser/Codex, Auswahlersetzung und Zwischenablagewiederherstellung. Modellinstallation wird nicht automatisch durchgeführt; Einstellungen und Systemprüfung zeigen bei fehlenden Voraussetzungen die nötigen Schritte an.

## Schalter an, aber Einfügen weiterhin „Fehlt“

Eine frühere Ad-hoc-Signatur konnte die macOS-Freigabe an die Prüfsumme einer bestimmten App-Version binden. Dann bleibt der Schalter eingeschaltet, obwohl die aktuelle Datei nicht mehr zur Freigabe passt. TecWisper zeigt weiterhin den echten Status von `AXIsProcessTrusted()` und nimmt keine pauschale Freigabe aufgrund des Schalters an.

1. In der Systemprüfung **Laufende App im Finder zeigen** wählen.
2. In macOS unter **Datenschutz & Sicherheit → Gerätesteuerung und Datenzugriff** (je nach macOS-Version **Bedienungshilfen**) den alten TecWisper-Eintrag entfernen.
3. Mit **+** genau die im Finder gezeigte App erneut hinzufügen und einschalten.
4. Zur App zurückkehren. Der Status wird alle zwei Sekunden sowie beim Aktivieren aktualisiert. Falls nötig TecWisper beenden und neu öffnen.

Die App verändert die macOS-Freigaben nicht selbst. Ab Version 1.0.1 ist die Codesignatur mit dem vorhandenen Apple-Entwicklerzertifikat stabilisiert.

## Statistiken ab Version 1.1.0

**Statistiken** in der Seitenleiste oder **Statistiken öffnen** im Menü zeigt Diktate, erzeugte Wörter, Aufnahmedauer und geschätzte Zeitersparnis. Dazu kommen Ergebniszahlen, durchschnittliche Diktatlänge, Diktiertempo, aktive Tage, Nutzungsserien, Tagesdiagramm, Aktivitätskalender, Ziel-Apps, Sprachen und technische Verarbeitungszeiten.

- Zeiträume: Heute, letzte 7/30 Tage, dieser Kalendermonat, insgesamt. Diagramm und Kalender sind auf zwölf Monate begrenzt; Gesamtkennzahlen behalten alle Daten.
- Eine Nutzung zählt ab Beginn einer echten Aufnahme. Vorprüfungsfehler und Testdiktate werden nicht erfasst. Abbruch/Fehler zählen keine Wörter; ein Korrekturfehler erhält die Wörter des verfügbaren Ausgangstexts.
- Erzeugte Wörter beziehen sich auf den verfügbaren Endtext einschließlich Übersetzung/Korrektur. `NLTokenizer` zählt auch Sprachen ohne Leerzeichen. Zahlen und Interpunktion können vom Modell normalisiert werden.
- Das Diktiertempo verwendet die unkorrigierte Wortzahl erfolgreicher, nicht übersetzter Transkriptionen und die gesamte Aufnahmedauer einschließlich Pausen. Die Gewichtung erfolgt nach Dauer.
- Geschätzte Ersparnis pro erfolgreichem Diktat: `max(0, Wörter / Tippwörter-pro-Minute × 60 − Aufnahmezeit − Verarbeitungszeit)`. Vorgabe 40 Wörter/Minute; Änderungen unter Statistik-Einstellungen berechnen ältere Schätzungen neu. Das ist keine Messung tatsächlich gesparter Arbeitszeit.
- Aktive Tage und Serien beziehen sich auf erfolgreiche Diktate im gewählten Zeitraum. Eine aktuelle Serie kann bis gestern reichen. Die ursprüngliche lokale Tageszuordnung bleibt bei Zeitzonenwechseln erhalten.
- Ziel-Apps werden beim Start zugeordnet. Diese Zahl ist kein Nachweis einer erfolgreichen Texteingabe in die App. Bei unbestätigtem Einfügeversuch wird kein bestätigter Einfügeerfolg als Statistik gespeichert.
- Die dauerhafte Erfassung beginnt erst mit Installation dieser Version. Frühere Diktate lassen sich nicht rekonstruieren.

Die versionierte SQLite-Datei liegt unter `~/Library/Application Support/TecWisper/statistics.sqlite`. Die Statistiktabelle enthält Zählwerte, Zeiten, Einstellungen, App-Namen/-Kennungen und technische Ergebniskategorien. Seit Version 1.3.0 enthält eine getrennte Verlaufstabelle bei aktivierter Textspeicherung zusätzlich die ursprüngliche Transkription und den fertigen Ausgabetext. Audio, Fenstertitel, URLs und vollständige Fehlermeldungen werden nicht gespeichert. Alle Daten bleiben lokal.

Die Aufzeichnung ist standardmäßig an und abschaltbar. Abschalten verwirft eine laufende Erfassung, erhält aber bisherige Zahlen. **CSV exportieren** exportiert alle gespeicherten Metadaten unabhängig vom Zeitraum. **Statistik zurücksetzen** löscht nach Bestätigung die Statistik und beginnt die Erfassung neu; andere Einstellungen bleiben erhalten. Speicherfehler werden angezeigt und stoppen das Diktieren nicht.

**Verbindung prüfen** zeigt in der Ollama-Ansicht jetzt direkt Fortschritt, getrennte Ergebnisse für Verbindung/Version und Modelle sowie den Zeitpunkt des Abschlusses. Änderungen der Adresse verwerfen alte Ergebnisse. Die Prüfung startet kein Diktat und wird nicht als Nutzung gezählt.

Für die visuelle Prüfung mit isolierten Beispieldaten gibt es `Scripts/preview_statistics.sh`. Die Vorschau verwendet ausschließlich synthetische Metadaten unter `build/preview` und berührt die echte Statistik nicht.

Das Build-Skript aktualisiert eine vorhandene Installation unter `/Applications/TecWisper.app` und registriert diese als maßgebliche App-Kopie. Beende TecWisper vor dem Update. Die Signierung bleibt auf demselben Apple-Entwicklerzertifikat; Freigaben werden nicht zurückgesetzt.

## Einfügen ab Version 1.1.1

Die Aufnahme-Anzeige kann den Tastaturfokus nicht übernehmen. Start oder Ende über TecWispers eigene Oberfläche kann zur vorherigen Ziel-App zurückkehren. Wechselst du während der Verarbeitung zu einer anderen fremden App, wird nicht automatisch dorthin geschrieben. Bei einer nachweislichen Änderung von Fenster, Eingabefeld, Cursor oder Feldinhalt bleibt der Text zum Kopieren verfügbar.

Unter **Systemprüfung → Einfügen in andere Apps → Testziel** kannst du eine laufende App wählen. **Einfügen testen** schreibt `TecWisper-Test` in deren aktives Textfeld und aktiviert die gewählte App ausdrücklich. Verwende dafür ein leeres Testdokument. Mit **Zuletzt aktive App** wird die normale automatische Zielzuordnung geprüft. Dieser Test benötigt weder Mikrofon noch Ollama und zählt nicht zur Statistik. Eine Meldung „Einfügebefehl gesendet“ ist allein noch kein Nachweis, dass jede Ziel-App den Text angenommen hat; prüfe das Ergebnis im Textfeld.

## Desktop-Oberfläche ab Version 1.2.0

TecWisper läuft als reguläre Mac-Anwendung mit Dock-Symbol, Cmd-Tab und eigenem Hauptfenster. Beim Start öffnet sich **Start** mit Diktierkarte, deinen tatsächlichen Tastenkürzeln, Tageskennzahlen und letzter Aktivität. Das Schließen des Fensters beendet die App nicht; das Dock-Symbol öffnet das Fenster erneut. Zum Beenden den normalen macOS-App-Befehl oder den Ausschalter im Schnellzugriff verwenden.

Die Seitenleiste führt zu **Start**, **Aktivität**, **Statistiken**, **Wörterbuch**, **Bedienung**, **Sprache**, **Ollama** und **Systemprüfung**. Das Wörterbuch ist direkt bearbeitbar; die Wörter werden weiterhin nur bei aktivierter KI-Korrektur berücksichtigt.

Der Klick auf das Menüleistensymbol öffnet jetzt ein kompaktes Popover mit Aufnahme, KI-Korrektur, Eingangs-/Ausgabesprache, letztem Sitzungstext zum Kopieren und Zugriff auf das Hauptfenster. Ab Version 1.3.0 enthält die Aktivität zusätzlich einen separat verwalteten lokalen Textverlauf.

Der Aufbau orientiert sich am bereitgestellten Screenshot und an [Sinthex Flow](https://sinthex.de/flow/). Die Farbgrundlage ist **VS Code Dark Modern**, aus dem lokal installierten Theme abgeleitet:

| Bereich | Farbe |
| --- | --- |
| Hintergrund | `#1F1F1F` |
| Seitenleiste | `#181818` |
| Karten | `#252526` |
| Rahmen | `#333333` |
| Text | `#CCCCCC` |
| Blauer Akzent | `#0078D4` |

Die App stellt ihre Oberfläche unabhängig vom macOS-Hellmodus dunkel dar. App-Icon, Schnellzugriff und Aufnahme-Anzeige verwenden dieselbe blaue Gestaltung.

## Diktattexte mit Ziel-App ab Version 1.3.0

**Zuletzt verwendet** und **Aktivität** zeigen bei neuen normalen Diktaten die ursprüngliche Transkription direkt im Eintrag. Darunter stehen Ziel-App, Zeitpunkt und die Wortanzahl der Ausgabe. Abweichende Texte nach KI-Korrektur oder Übersetzung lassen sich über **Ausgabe nach Übersetzung / KI-Korrektur** aufklappen; das Kopiersymbol übernimmt den fertigen Ausgabetext. Lange Vorschauen auf Start sind aufklappbar.

Die ursprüngliche Transkription ist der vom Audiomodell erkannte Text; Satzzeichen und Zahlen können bereits durch die Erkennung normalisiert sein. Bei einer Übersetzung und aktiviertem Verlauf wird das Audio zusätzlich lokal in seiner Eingangssprache transkribiert, damit das Gesprochene erhalten bleibt. Ohne Textverlauf entfällt diese zusätzliche Anfrage. Audio wird weiterhin nicht dauerhaft gespeichert.

Unter **Aktivität → Diktattexte lokal speichern** ist die Speicherung standardmäßig eingeschaltet. Abschalten erhält bisherige Texte und verhindert die Speicherung des laufenden und weiterer Diktate. **Diktattexte löschen** entfernt die Texte nach Bestätigung und erhält die Nutzungsstatistik. Umgekehrt löscht ein Statistik-Reset keine separat gespeicherten Diktattexte. Beide Aufzeichnungen sind unabhängig voneinander abschaltbar. Abgebrochene Aufnahmen, fehlgeschlagene Erkennung und Testdiktate speichern keine Texte.

Die SQLite-Datenbank wird verlustfrei auf Schema 2 erweitert. Bestehende Metadaten und Zähler bleiben erhalten; ältere Einträge zeigen ausdrücklich an, dass für sie kein Text gespeichert wurde. Alte Diktate lassen sich nicht nachträglich aus Zählwerten rekonstruieren. Die ursprüngliche Ziel-App ist eine Zielzuordnung und keine technische Bestätigung, dass jedes Zielprogramm den Einfügebefehl angenommen hat.

`Scripts/preview_history.sh` zeigt beide Listen mit isolierten synthetischen Beispieldaten, einschließlich abweichender Ausgabe. Der Test berührt den echten Verlauf nicht. Der Statistik-CSV-Export enthält weiterhin keine Diktattexte.

## App-Logo

Seit Version 1.3.1 verwendet TecWisper das Motiv „Sprachwelle trifft Textstriche“ für App-/Dock-Icon, Menüleiste, Seitenleiste, Startseite, Schnellzugriff und Aufnahme-Anzeige. Das Originalbild bleibt unverändert erhalten. Der bearbeitete Master mit transparentem Außenrand liegt unter `_branding/tecwisper-icon-master.png`, ein wiederverwendbarer 1024-Pixel-Export unter `_branding/TecWisper-Icon-1024.png`. Bearbeitungsprompt und Dateizuordnung stehen in `_branding/EDIT_PROMPT.md`.

Technische Größen erneut erzeugen: `swift Scripts/make_icon.swift`, danach `iconutil -c icns build/TecWisper.iconset -o TecWisper/Resources/TecWisperIcon.icns`. `Scripts/create_project.py` berücksichtigt die Logo-Ressourcen automatisch. Funktionssymbole wie Mikrofon, Kopieren und Statistiken bleiben ihrer jeweiligen Funktion zugeordnet.

Beim Einfügen wartet TecWisper kurz auf das Loslassen der Zusatztasten des Diktierkürzels und auf die Fokusübergabe. Für Chromium-/Electron-Apps wird der Bedienungshilfen-Baum angefordert. Der Fokus wird direkt vor dem Tastaturbefehl nochmals geprüft. Ein unbestätigter Einfügebefehl wird nicht automatisch wiederholt, damit kein doppelter Text entsteht.

Die Zielerkennung prüft zusätzlich den systemweiten Bedienungshilfen-Fokus (mit Prozessprüfung), das aktive Fenster und darin ausdrücklich als fokussiert markierte Textfelder. Es wird kein beliebiges Textfeld als Ziel ausgewählt, wenn eine App ihren Fokus nicht meldet.

Die Aufnahme-Anzeige verschwindet automatisch, sobald der Feldinhalt nach dem Einfügen exakt der erwarteten Ersetzung an der ursprünglichen Cursorposition entspricht. Ein gesendeter Einfügebefehl allein reicht dafür nicht. Wenn die Ziel-App Feldinhalt oder Cursorposition nicht bereitstellt, bleibt die Kopierhilfe verfügbar. Bei abgebrochenem Einfügen, Fehlern und Testdiktaten bleibt die Kopierhilfe vorübergehend sichtbar und lässt sich mit dem Schließen-Knopf ausblenden. Der Sitzungstext bleibt im Menüleisten-Schnellzugriff und bei aktiviertem Textverlauf in der Aktivität verfügbar.

## Version 1.3.4 (Build 10)

Die Bestätigung einer Textübernahme unterstützt auch Editoren ohne auslesbare Cursorposition, sofern sich der neue Inhalt exakt aus dem alten Inhalt und dem eingefügten Text ergibt. Neu erzeugte Eingabeelemente im gleichen Fenster sowie geschützte Leerzeichen werden berücksichtigt. Für den Feldinhalt wird zusätzlich die macOS-Textbereichsabfrage verwendet. Fehlende oder unveränderte Feldinhalte gelten weiterhin nicht als Erfolg.

## Version 1.3.5 (Build 11)

Nach einem gesendeten Einfügebefehl wird die schwebende Kopierhilfe ausgeblendet, auch wenn die Ziel-App keine auslesbare Bestätigung liefert. Ein fehlender Nachweis wird damit nicht als Erfolg gewertet: Die Meldung zur unbestätigten Übernahme bleibt in TecWisper verfügbar. Bei einem Abbruch vor dem Einfügebefehl bleibt die Kopierhilfe sichtbar. Text ist weiterhin über die Menüleiste und den aktivierten Verlauf erreichbar. Diese Regel ersetzt das in 1.3.4 eingeführte Offenhalten bei fehlender Bestätigung.

## Version 1.3.6 (Build 12)

Die Verlaufstexte unter „Zuletzt verwendet“ und „Aktivität“ verwenden normale SwiftUI-Textdarstellung, um die vertikal gespiegelte Darstellung auswählbarer Texte in macOS-Verlaufszeilen zu vermeiden. Direktes Markieren ist dort deaktiviert; der Kopierknopf für den Ausgabetext bleibt verfügbar.

## Version 1.3.7 (Build 13)

Der Release-Build erzeugt `build/TecWisper-macOS.dmg`. Die DMG per Doppelklick öffnen und `TecWisper.app` auf die Verknüpfung „Programme“ ziehen. Eine laufende alte Fassung vorher beenden. Danach die App aus „Programme“ starten und das Installationslaufwerk auswerfen.

Die DMG wird auch bei laufender App erzeugt. Das Build-Skript installiert die App nicht automatisch. Eine vorhandene signierte App lässt sich separat mit `Scripts/package_dmg.sh /Pfad/zu/TecWisper.app` verpacken.

## Version 1.3.8 (Build 14)

Die DMG ist das verbindliche Installationsformat. Der Build erzeugt keine zusätzliche ZIP-Datei oder separate App-Kopie und überschreibt keine installierte App.

## Vollständiges Backup und Restore

Unter **Einstellungen → Backup & Restore** speicherst du alle App-Einstellungen, Wörterbuch und Prompt-Vorgaben einschließlich Diktattexten und Statistiken in einer `.tecwisperbackup`-Datei. Die Datei ist unverschlüsselt und sollte geschützt aufbewahrt werden. Temporäre Audiodateien und Sitzungsergebnisse gehören nicht zur Sicherung.

**Backup wiederherstellen …** zeigt Datum, Quellversion und Umfang an und ersetzt nach Bestätigung den aktuellen Stand vollständig. Vorher wird automatisch eine vollständige Sicherheitssicherung unter `~/Library/Application Support/TecWisper/Backups` erstellt. Über **Sicherheitssicherung im Finder zeigen** erreichst du diese Datei; sie lässt sich mit derselben Funktion wieder einspielen. Scheitert die Sicherheitssicherung, wird die Wiederherstellung abgebrochen.

Während der Sicherung oder Wiederherstellung sind Diktate und Änderungen gesperrt. Die übernommenen Einstellungen gelten sofort. macOS-Berechtigungen und installierte Ollama-Modelle werden nicht übertragen; Modellnamen, Mikrofonwahl und Verbindungsadresse bleiben enthalten. Prüfe nach einem Umzug auf einen anderen Mac die Systemprüfung und wähle bei Bedarf ein verfügbares Mikrofon.


## Version 1.3.10 (Build 16)

Startseite und Statistik verwenden eine gemeinsame, sekündlich aktualisierte Zeitbasis. Tageswerte wechseln dadurch ohne Tabwechsel auf den neuen Tag. Beim Aktivieren der App, Öffnen des Fensters, Aufwachen des Macs sowie bei Tages-, Uhrzeit- und Zeitzonenänderungen wird die Zeit zusätzlich aktualisiert. Gespeicherte Diktate und Gesamtwerte bleiben erhalten.

## Version 1.3.11 (Build 17)

Unter Ollama lässt sich das Audiomodell aus installierten lokalen Modellen wählen oder als Modellname inklusive Tag frei eingeben. Die Auswahl bleibt nach Neustarts und in Backups erhalten und gilt auch für Übersetzungen und die Systemprüfung. Bestehende Einstellungen verwenden weiterhin lfm3-audio. Das gewählte Modell muss lokale Audioeingabe über die Ollama-Audioschnittstelle unterstützen; ein Testdiktat bestätigt die tatsächliche Verarbeitung.
