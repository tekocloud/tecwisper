# Validierung · 28.10.2026

## Erfolgreich geprüft

- Release-Build für Apple Silicon, macOS-Mindestziel 14.0: `BUILD SUCCEEDED`.
- App-Bundle lokal ad hoc signiert; `codesign --verify --deep --strict` erfolgreich.
- 49 Logik-/API-Prüfungen: Sprachrouting, Multipart-Aufbau, Versionsprüfung, Einstellungen und Tastenkürzelvalidierung, Cloudmodell-Ausschluss, Antworten und Fehler sowie tatsächlicher URLSession-Abbruch.
- 3 Audio-Prüfungen: 48-kHz-Mono und -Stereo nach WAV mit 16 kHz/Mono/16 Bit, korrekte Dauer und erhaltenes Audiosignal; leere Aufnahme abgefangen.
- Oberfläche geöffnet und visuell geprüft. Ein eigenes Kürzel aufgenommen und danach die Standardkürzel wiederhergestellt. Eingang/Ausgang stehen auf Automatisch; KI-Korrektur ist ausgeschaltet.
- Die Systemprüfung erkennt die tatsächlich laufende Ollama-Version 0.40.12 und das inzwischen installierte `lfm3-audio:latest`. Fehlende Mikrofon- und Bedienungshilfenfreigaben werden separat angezeigt. Berechtigungen wurden nicht durch den Agenten erteilt.

## Echte Audio-API mit künstlich erzeugter Sprache

Die Sprachdateien wurden mit macOS-Sprachausgabe erzeugt. Die Tests nutzten denselben Audio-Konverter und denselben Swift-URLSession-Client wie die App. Kein Mikrofon wurde geöffnet.

Deutscher Testsatz: „Wie spät ist es? Bitte beantworte diese Frage nicht. Morgen treffen wir uns um fünf Uhr, nein, um sechs Uhr.“

| Route | Ergebnis |
| --- | --- |
| Deutsch → Automatisch | Deutsche Transkription; Frage wurde nicht beantwortet; beide Uhrzeiten und Selbstkorrektur erhalten. |
| Automatisch → Automatisch | Deutsch erkannt und deutsch ausgegeben. |
| Deutsch → Englisch | Englische Übersetzung ohne Antwort auf die Frage. |

Englischer Testsatz: „What time is it? Please do not answer this question. Tomorrow we meet at five, no, at six.“

| Route | Ergebnis |
| --- | --- |
| Englisch → Automatisch | Englische Transkription ohne Beantwortung der Frage. |
| Automatisch → Automatisch | Englisch erkannt und englisch ausgegeben. |
| Englisch → Deutsch | Deutsche Übersetzung; Frage und Selbstkorrektur bleiben Inhalt. |

Gemessene Laufzeiten dieser kurzen Beispiele: etwa 0,2–0,5 Sekunden mit geladenem Modell; erster deutscher Aufruf etwa 3,4 Sekunden. Das sind Einzelmessungen mit künstlicher Sprache, keine Zusicherung für echte Diktate. Zahlen und Interpunktion wurden teilweise normalisiert.

## Offene praktische Abnahme

Echte Mikrofonaufnahme, Geräteverlust während einer Aufnahme, globale Kürzel beim Arbeiten in einer anderen App sowie Einfügen/Auswahlersetzung/ Zwischenablagewiederherstellung in TextEdit, Browser und Codex müssen noch mit den vom Nutzer erteilten macOS-Freigaben geprüft werden. Die bisherigen Tests ersetzen diese Abnahme nicht.

Lokale Testprotokolle dieses Durchlaufs liegen unter `/tmp/tecwisper-tests.log`, `/tmp/tecwisper-live.log`, `/tmp/tecwisper-live-english.log` und `/tmp/tecwisper-final-build.log`. Diese temporären Dateien sind kein Bestandteil der Lieferung.

## Korrektur der macOS-Freigabe · 29.10.2026 · Version 1.0.1 (2)

- Fehler bestätigt: In macOS war TecWisper eingeschaltet, `AXIsProcessTrusted()` meldete aber keinen Zugriff. Auch ein App-Neustart änderte das nicht.
- Die ausschließlich lesend geprüfte, für TecWisper gespeicherte Codesignatur-Anforderung passte nicht zur laufenden App. `codesign --verify -R` gegen diese Anforderung schlug fehl. Die alte Freigabe war an die Prüfsummen eines anderen Ad-hoc-Builds gebunden.
- Debug und Release auf Apple-Development-Signierung mit dem vorhandenen Entwicklerteam umgestellt. Die geprüfte neue Designated Requirement verwendet Bundle-ID und Apple-Entwickleridentität statt der wechselnden Binärprüfsummen.
- Release-Build und Signaturprüfung erfolgreich. App und ZIP aktualisiert. Oberfläche der neuen Version geöffnet und neue Hilfe einschließlich tatsächlichem App-Pfad sichtbar geprüft.
- Der Berechtigungsstatus wird in den Einstellungen zusätzlich alle zwei Sekunden ohne erneute Ollama-Abfrage aktualisiert. Ein Finder-Button zeigt genau die laufende App zum erneuten Hinzufügen.
- Keine macOS-Berechtigung wurde vom Agenten geändert. Der alte Eintrag muss einmal vom Nutzer entfernt und die neue App hinzugefügt/freigegeben werden. Durch den Signaturwechsel ist auch die Mikrofonfreigabe einmal erneut nötig. Erst danach kann die tatsächliche Einfügefunktion abgenommen werden.

## Abgeschlossene Freigabereparatur · 29.10.2026

- Nach erneutem Entfernen/Hinzufügen über die Systemeinstellungen blieb zunächst die alte Ad-hoc-Prüfsummenanforderung gespeichert. Sie passte weiterhin nicht zur laufenden App.
- Die korrekt Apple-Development-signierte App wurde fest nach `/Applications/TecWisper.app` installiert und ihre Signatur verifiziert. Die drei Build-Kopien wurden gezielt bei Launch Services abgemeldet; die installierte Kopie wurde registriert.
- Ausschließlich der veraltete Accessibility-Eintrag für `de.teklacloud.TecWisper` wurde mit dem offiziellen `tccutil reset Accessibility de.teklacloud.TecWisper` zurückgesetzt. Keine direkte Änderung der macOS-Datenbank und keine Änderung fremder App-Freigaben.
- Danach wurde eine neue aktive Freigabe festgestellt. Der rein lesende Vergleich der gespeicherten Signaturanforderung mit `/Applications/TecWisper.app` war erfolgreich.
- Abschließend in der installierten App visuell bestätigt: **Einfügen in andere Apps: Bereit**, **Bedienungshilfenzugriff für die laufende App erlaubt**, **Dein Mac ist bereit**. Mikrofon und übrige Voraussetzungen ebenfalls bereit.
- Der Agent hat keinen Zugriffsschalter eingeschaltet. Die praktische Texteingabe in fremde Apps wurde durch diese Statusprüfung noch nicht getestet.

## Statistiken und Verbindungstest · 29.10.2026 · Version 1.1.0 (3)

- Ausführliches Dashboard mit Zeitraumwahl, vier Hauptkennzahlen, Ergebnissen, Diktiertempo, Nutzungsserien, Tagesdiagramm, Aktivitätskalender, Ziel-Apps, Sprach-/Modusaufteilung und technischen Zeiten umgesetzt.
- Lokale versionierte SQLite-Speicherung ausschließlich für Metadaten. Testdiktate ausgeschlossen; Abschlüsse idempotent; Abschalten verwirft eine laufende Erfassung. Export, Zurücksetzen mit Bestätigung, Speicherfehleranzeige und geordnete Speicherung beim Beenden integriert.
- **107 automatisierte Prüfungen erfolgreich:** 49 bestehende Logik/API-, 3 Audio-, 44 Statistik- und 11 Verbindungsprüfungen. Unter anderem Wortzählung ohne Leerzeichen, gewichtetes Tempo, Zeitersparnis, Sommerzeit, Serien, Tage ohne Nutzung, doppelte Abschlüsse, Neustart, Schema-Schutz, Speicherfehler, Abschalten während der Erfassung und Schreibreihenfolge beim Reset.
- Gemeinsame Ollama-Prüfung für Systemprüfung und Ollama-Ansicht getestet: fehlendes Modell, alte Version, ungültige Adresse, Verbindungsfehler, Timeout, Audiofähigkeit, Cloud-Ausschluss und Abbruch. Fehler der Modellliste überschreibt die erfolgreiche Versionsprüfung nicht.
- Oberfläche mit synthetischen Daten in einer vollständig separaten Vorschau visuell geprüft. Diagrammwechsel und vollständige App-Liste geprüft. Keine Beispieldaten in die echte Statistik eingefügt.
- Installierte Version geöffnet: echter Leerzustand und alle vier Hauptkennzahlen sichtbar. Beim Wechsel zwischen Seiten beginnt die Ansicht oben.
- Verbindungsknopf in der installierten App angeklickt: direkt sichtbares erfolgreiches Ergebnis mit Ollama 0.40.13, lokalem Audiomodell und aktualisiertem Abschlusszeitpunkt bestätigt.
- Release-Build erfolgreich; Signatur und ZIP geprüft. Installation unter `/Applications/TecWisper.app` aktualisiert. Die vorhandene Bedienungshilfen-Signaturanforderung passt weiterhin; Mikrofon und Bedienungshilfen zeigen in der App **Bereit**. Keine Berechtigung zurückgesetzt.
- Echte Mikrofonaufnahme und Texteingabe wurden in diesem Durchlauf nicht ausgelöst. Zahlen beginnen erst mit dem nächsten normalen Diktat; ältere Diktate werden nicht rekonstruiert.

## Einfügen korrigiert · 29.10.2026 · Version 1.1.1 (4)

- Zwei konkrete Blockaden entfernt: fehlende AX-Cursorattribute führten zuvor immer zur Ablehnung; der systemweite Fokus wurde statt des Fokus in der Ziel-App geprüft. Optionale Cursor-/Wertattribute gelten nun als unbekannt, wenn eine App sie nicht bereitstellt.
- Ziel-App und Fenster werden gemerkt. Die zuletzt aktive fremde App ist beim Start über TecWispers Oberfläche verfügbar. Die Aufnahme-Anzeige kann kein Haupt-/Tastaturfenster werden. Bei der Rückkehr aus TecWisper wird die Aktivierung mit macOS koordiniert; ein Wechsel in eine andere fremde App wird weiterhin nicht überschrieben.
- Native Texteingabe über Zwischenablage und ⌘V gezielt an den gemerkten Prozess. Wiederherstellung nach 800 ms bei unveränderter Zwischenablage, unabhängig von einem späteren Diktatabbruch. Keine Enter-Ereignisse und keine ungeprüfte Bestätigung der Übernahme durch jede Ziel-App.
- Präzise Meldungen für fehlendes Eingabefeld, geschützte Eingaben und nachweisliche Änderungen von App, Fenster, Feld, Cursor oder Inhalt.
- Unter Systemprüfung gibt es einen Einfügetest mit wählbarer Ziel-App. Er verwendet denselben Einfügecode, kein Mikrofon und kein Ollama, und zählt nicht als Diktat in der Statistik.
- **117 automatisierte Prüfungen erfolgreich:** 49 Logik/API, 3 Audio, 44 Statistik, 11 Verbindung, 10 neue Einfüge-Prüfungen. Die neuen Fälle prüfen insbesondere fehlende Cursorattribute, App-/Fenster-/Feldwechsel und Secure Input.
- **Fünf tatsächliche Einfügefälle visuell bestätigt:** (1) leeres separates TextEdit-Dokument; (2) Einfügen vor einem Wort über „Zuletzt aktive App“, Ergebnis `Anfang TecWisper-TestEnde`; (3) Ersetzen des markierten Wortes; (4) normales Browser-Textfeld; (5) contenteditable/Rich-Text-Editor in Microsoft Edge. Beide Browserfelder wurden auf einer separaten lokalen HTML-Testseite ohne Formularübertragung geprüft; die Testseite danach geschlossen.
- Die Dokumentation der Tests betrifft nur synthetische Testtexte. Das bereits geöffnete ursprüngliche TextEdit-Dokument wurde nicht bearbeitet. Keine echte Mikrofonaufnahme in diesem Durchlauf.
- Signierter Release-Build, App-Installation und ZIP erfolgreich geprüft. Installation weiterhin `/Applications/TecWisper.app`; vorhandene Freigaben bleiben aktiv.

## Desktop-Oberfläche · 29.10.2026 · Version 1.2.0 (5)

- Hauptfenster mit eigener Startseite, Tageskennzahlen und Metadaten-Aktivität eingeführt. Seitenleiste mit allen bestehenden Funktionen und eigenständiger Wörterbuch-Seite umgesetzt.
- `LSUIElement=false` und reguläre App-Aktivierungsrichtlinie gesetzt. Die App hat damit einen normalen Mac-App-Lebenszyklus mit Dock/Cmd-Tab; das bestehende Wiederöffnen des Hauptfensters bleibt erhalten.
- Menüleistenmenü durch ein SwiftUI-Fenster-Popover mit Aufnahme, Sprachwahl, KI-Korrektur, letztem Sitzungstext und Hauptfenster-/Einstellungs-/Beenden-Aktionen ersetzt.
- VS-Code-Dark-Modern-Farben anhand des lokal installierten Theme-Quelltexts übernommen. Hauptfenster, Karten, Navigation, Schnellzugriff, Overlay und App-Icon an diese Palette angepasst.
- Hauptfenster (1100 × 820 Inhalt) und Menüleisten-Popover (350 px breit) in der laufenden App visuell kontrolliert. Startkarte, echte Tageskennzahlen und letzte Aktivität sichtbar; Wörterbuch-Navigation aus den Ollama-Einstellungen geprüft.
- Alle 117 bestehenden Logik-, Audio-, Statistik-, Verbindungs- und Einfüge-Prüfungen erfolgreich. Keine Mikrofonaufnahme durch den Agenten in diesem Durchlauf.
- Release-Build erfolgreich, Installation unter `/Applications/TecWisper.app` aktualisiert. Bestehende reale Statistik und Benutzereinstellungen (einschließlich gewähltem Textmodell) bleiben erhalten. Engine-Status meldet bereit; Freigaben nicht zurückgesetzt.
- Es wurde kein dauerhafter Textverlauf eingeführt. Auf Start und im Schnellzugriff wird höchstens der vorhandene letzte Sitzungstext angezeigt; Aktivität nutzt nur gespeicherte Metadaten.

## Lokaler Diktattext-Verlauf · 29.10.2026 · Version 1.3.0 (6)

- „Zuletzt verwendet“ und „Aktivität“ zeigen die ursprüngliche Transkription mit Ziel-App, Zeitpunkt und Ausgabewortzahl. Abweichende Ausgabe ist aufklappbar und kopierbar. Lange Startseiten-Vorschauen können vollständig angezeigt werden.
- Textverlauf als separate lokale Tabelle ergänzt; SQLite-Schema 1 → 2 erhält bestehende Metadaten und Zähler. Vor der Aktualisierung wurde eine lokale Sicherung unter `build/backups/statistics-before-history.sqlite` angelegt.
- Tatsächliche Migration geprüft: weiterhin 2 Statistik-Einträge, Schema jetzt 2. Keine Texte für alte Einträge erfunden oder aus fremden Quellen rekonstruiert.
- Verlauf unabhängig von Statistik ein-/abschaltbar. Getrennte Löschung mit Bestätigung; weder Statistik-Reset noch Textlöschung entfernen jeweils die andere Datenart. Keine Audioaufbewahrung und keine Diktattexte im Statistik-CSV.
- Übersetzungsablauf erhält bei aktiviertem Verlauf zusätzlich eine Originaltranskription in der Eingangssprache. Vier neue API-Tests prüfen Original/Ausgabe, Reihenfolge und das Weglassen zusätzlicher Anfragen ohne Verlauf.
- 17 neue Verlaufstests prüfen Migration, Original/Ausgabe, App-Verknüpfung, Neustart, Dateirechte, idempotente Speicherung, unabhängige Erfassung und getrennte Löschung. Insgesamt **138 Prüfungen erfolgreich**.
- Beide Darstellungen mit vollständig isolierten synthetischen Beispieldaten visuell geprüft; abweichenden Korrekturtext aufgeklappt. Keine Beispieldaten in den echten Verlauf geschrieben.
- Installierte App geöffnet und echte Bestandsmigration kontrolliert: vorhandene Einträge mit ehrlichem Hinweis auf nicht gespeicherte Texte, aktivierter Verlaufsschalter und Engine-Status bereit. Keine Mikrofonaufnahme durch den Agenten in diesem Durchlauf.
- Signierter Release-Build, Installation unter `/Applications/TecWisper.app` und ZIP geprüft. Einstellungen und bestehende Freigaben erhalten.

## Eigenes App-Logo · 30.10.2026 · Version 1.3.1 (7)

- Nutzerbild unverändert erhalten und mit ImageGen zum quadratischen Icon mit transparentem Außenrand bearbeitet. Nur der saubere Kachel-Master wurde eingebunden; unbrauchbare Zwischenstände wurden nicht übernommen.
- Native AppKit-Exporte für 10 ICNS-Renditionen von 16 bis 1024 Pixel sowie UI- und Menüleisten-Ressourcen in einfacher und doppelter Auflösung erzeugt. ICNS erfolgreich zurück in ein Iconset konvertiert; größte Rendition 1024 Pixel. PNG-Abmessungen und Alpha geprüft.
- Branding in Dock/App-Icon, Menüleiste, Seitenleiste, Startseite, Schnellzugriff, Aufnahme-Anzeige und leeren Statistik-/Prüfansichten vereinheitlicht. Funktionale Symbole bleiben erhalten.
- Release-Build erfolgreich. Installierte Version 1.3.1 geöffnet und Hauptfenster visuell geprüft: Logo in Seitenleiste und Diktierbereich sichtbar. App-Ressourcen AppIcon.icns, AppLogo.tiff und MenuBarLogo.tiff in installiertem Bundle vorhanden (Xcode kombiniert die Retina-PNGs zu TIFF-Ressourcen).
- Signatur der installierten App mit unveränderter Team-ID KQ84FGT625 und Bundle-ID de.teklacloud.TecWisper geprüft. ZIP-Integrität erfolgreich geprüft. Installation unter /Applications/TecWisper.app aktualisiert.
- Bestehende Daten und Freigaben nicht zurückgesetzt. Keine Mikrofonaufnahme. Keine erneute Ausführung der 138 Funktionstests für diese reine Branding-Änderung; Prüfung durch Assetkontrolle, Build und visuelle Kontrolle des Hauptfensters.

## Dock-Icon-Aktualisierung · 30.10.2026 · Version 1.3.2 (8)

- Nach Nutzerhinweis auf altes Dock-Symbol Icon-Ressource in TecWisperIcon.icns umbenannt und CFBundleIconFile entsprechend aktualisiert, um die alte Ressourcen-Zuordnung zu verlassen.
- Beim Start setzt die App NSApp.applicationIconImage explizit aus der gebündelten ICNS-Datei. Bundle-ID und Signieridentität bleiben erhalten.
- Build-Skript entfernt die alte AppIcon.icns vor dem Zusammenführen der Bundles; dadurch bleiben keine ungültigen veralteten Signaturressourcen zurück.
- Release-Build, Installation und strenge Signaturprüfung erfolgreich. Installierte Version 1.3.2 gestartet; Engine bereit und Bestandsdaten sichtbar. Dock-Direktkontrolle über Computer Use wegen Zeitüberschreitung nicht möglich; daher keine Behauptung einer visuellen Dock-Abnahme.


## Aktuelle Tagesanzeigen · 06.11.2026 · Version 1.3.10 (16)

- Ursache: Start-Tageskarten hatten keinen zeitabhängigen Aktualisierungsauslöser; die Statistik verwaltete eine eigene Uhr. Beide Ansichten verwenden jetzt die veröffentlichte Modellzeit mit sekündlicher Aktualisierung und Systemereignissen für Aktivierung, Fensterfokus, Aufwachen, Tageswechsel sowie Uhrzeit-/Zeitzonenänderungen.
- Gesamtes automatisiertes Testskript erfolgreich, einschließlich Regression für Tageswechsel ohne Tabwechsel, veröffentlichte Modelländerung und unveränderte Gesamtwerte.
- Release-Build, Codesignatur und DMG-Integrität erfolgreich geprüft. DMG enthält die App und die Programme-Verknüpfung.
- Kein realer Tageswechsel über Nacht und keine visuelle Abnahme der installierten Version durchgeführt.
