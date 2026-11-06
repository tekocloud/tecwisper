import Foundation

@main
struct CoreTests {
    static var count = 0
    static func expect(_ condition: @autoclosure () -> Bool, _ name: String) throws {
        guard condition() else { throw NSError(domain: "Tests", code: 1, userInfo: [NSLocalizedDescriptionKey: "FEHLER: \(name)"]) }
        count += 1; print("✓ \(name)")
    }
    static func main() async throws {
        try expect(LanguageRoute(input: "auto", output: "auto").fields["language"] == nil, "Automatische Erkennung lässt language weg")
        try expect(!LanguageRoute(input: "de", output: "auto").translates, "Automatische Ausgabe behält Sprache")
        try expect(!LanguageRoute(input: "de", output: "de").translates, "Gleiche Sprache verwendet Transkription")
        try expect(LanguageRoute(input: "auto", output: "de").translates, "Unbekannte Eingangssprache verwendet Zielübersetzung")
        try expect(LanguageRoute(input: "de", output: "en").fields["to_language"] == "en", "Übersetzung übergibt Zielsprache")
        try expect(LanguageRoute(input: "de", output: "auto").path.hasSuffix("transcriptions"), "Transkriptionsendpunkt")
        try expect(LanguageRoute(input: "de", output: "en").path.hasSuffix("translations"), "Übersetzungsendpunkt")
        try expect(DictationLanguage.all.count == Set(DictationLanguage.all.map(\.id)).count, "Sprachcodes eindeutig")
        try expect(SemanticVersion("0.40.11")! < .minimum, "Alte Version ablehnen")
        try expect(SemanticVersion("0.40.12")! >= .minimum, "Mindestversion akzeptieren")
        try expect(SemanticVersion("0.40.12-rc1")! < .minimum, "Vorabversion nicht als stabile Mindestversion behandeln")
        try expect(SemanticVersion("0.41.0")! > .minimum, "Neue Version akzeptieren")
        try expect(SemanticVersion("nonsense") == nil, "Ungültige Version erkennen")
        try expect(SemanticVersion("") == nil && SemanticVersion("0.40.+") == nil, "Leere und beschädigte Versionsangaben ohne Absturz ablehnen")
        try expect(SemanticVersion("v0.40.12+mlx")! == .minimum, "Versionspräfix und Buildmetadaten")
        let body = MultipartBody(fields: ["model": "lfm3-audio", "language": "de"], audio: Data([0, 13, 255]), boundary: "test-boundary")
        try expect(body.data.range(of: Data("name=\"file\"; filename=\"dictation.wav\"\r\nContent-Type: audio/wav\r\n\r\n".utf8)) != nil, "Multipart hat WAV-Datei und Header")
        try expect(body.data.range(of: Data([0, 13, 255])) != nil, "Multipart erhält Binärdaten")
        try expect(body.data.suffix(19) == Data("--test-boundary--\r\n".utf8).suffix(19), "Multipart korrekt abgeschlossen")
        let wav = WAV.encode(pcm: Data([1, 2, 3, 4]))
        try expect(wav.count == 48 && String(data: wav.prefix(4), encoding: .utf8) == "RIFF", "WAV-Header und Dateilänge")
        try expect(Array(wav[24..<28]) == [0x80, 0x3e, 0, 0], "WAV hat 16 kHz")
        try expect(Array(wav[34..<36]) == [16, 0] && Array(wav[22..<24]) == [1, 0], "WAV hat 16-Bit-Mono")
        let legacyData = try JSONSerialization.data(withJSONObject: ["baseURL": "http://localhost:11434", "inputLanguage": "auto", "outputLanguage": "auto", "cleanupEnabled": false, "cleanupModel": "local", "dictionary": "Petlio", "microphoneID": ""])
        let legacy = try JSONDecoder().decode(Preferences.self, from: legacyData)
        try expect(!legacy.optimizesPrompt && legacy.dictionary == "Petlio", "Bestehende Einstellungen bleiben ohne Prompt-Modus lesbar")
        try expect(legacy.audioModel == "lfm3-audio", "Bestehende Einstellungen behalten das bisherige Audiomodell")
        var custom = legacy
        custom.audioModel = "anderes-audio:custom"
        let customRestored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(custom))
        try expect(customRestored.audioModel == custom.audioModel && customRestored.route.fields["model"] == custom.audioModel, "Freies Audiomodell speichern und im Audiorequest verwenden")
        var promptSettings = legacy
        promptSettings.promptOptimization = true
        promptSettings.promptInstructions = "Nutze Aufgabe und Kontext."
        let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(promptSettings))
        try expect(restored.optimizesPrompt && restored.usesTextModel && !restored.cleanupEnabled && restored.promptInstructions == promptSettings.promptInstructions, "Prompt-Modus unabhängig von Korrektur speichern")
        var settings = Preferences()
        try expect(settings.shortcutError == nil, "Standardkürzel gültig")
        settings.toggleShortcut = settings.holdShortcut
        try expect(settings.shortcutError != nil, "Doppelte Kürzel ablehnen")
        settings.toggleShortcut = Shortcut(keyCode: 53, modifiers: 2048)
        try expect(settings.shortcutError != nil, "Escape bleibt reserviert")
        settings.holdShortcut = nil; settings.toggleShortcut = nil
        try expect(settings.shortcutError == nil, "Deaktivierte Kürzel zulässig")
        let defaults = UserDefaults(suiteName: "TecWisperTests-\(UUID())")!
        settings.inputLanguage = "fr"; settings.outputLanguage = "de"; settings.save(to: defaults)
        try expect(Preferences.load(from: defaults) == settings, "Einstellungen über Neustart erhalten")
        defaults.removeObject(forKey: "preferences")
        for address in ["https://example.org", "file:///tmp/a", "http://localhost:11434/api", "http://user@localhost:11434", "http://localhost:11434?x=1"] {
            do { _ = try OllamaClient(address: address); throw NSError(domain: "Tests", code: 2) }
            catch AppError.invalidURL { count += 1 }
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let client = try OllamaClient(address: "http://localhost:11434", session: session)
        StubProtocol.handler = { request in
            try expect(request.url!.path == "/api/version", "Versionsanfrage korrekt")
            return (200, Data(#"{"version":"0.40.12"}"#.utf8))
        }
        let version = try await client.version()
        try expect(version == "0.40.12", "Version aus JSON auslesen")
        StubProtocol.handler = { request in
            try expect(request.httpMethod == "POST" && request.url!.path == "/v1/audio/translations", "Audioanfrage verwendet POST und Übersetzungsroute")
            try expect(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data; boundary=") == true, "Multipart Content-Type")
            try expect(request.timeoutInterval == 120, "Audiozeitlimit beträgt 120 Sekunden")
            return (200, Data(#"{"text":"  Guten Tag.\n"}"#.utf8))
        }
        let transcript = try await client.transcribe(audio: wav, route: .init(input: "en", output: "de"))
        try expect(transcript == "Guten Tag.", "Textantwort auslesen und Rand-Leerzeichen entfernen")
        StubProtocol.handler = { _ in (200, Data(#"{"text":" "}"#.utf8)) }
        do { _ = try await client.transcribe(audio: wav, route: .init(input: "de", output: "auto")); fatalError("Leerer Text akzeptiert") }
        catch AppError.emptyTranscript { count += 1; print("✓ Leeren Text ablehnen") }
        StubProtocol.handler = { _ in (200, Data("not json".utf8)) }
        do { _ = try await client.version(); fatalError("Ungültiges JSON akzeptiert") }
        catch AppError.invalidResponse { count += 1; print("✓ Ungültige Antwort erklären") }
        StubProtocol.handler = { _ in (404, Data(#"{"error":{"message":"model lfm3-audio not found"}}"#.utf8)) }
        do { _ = try await client.version(); fatalError("Fehlendes Modell akzeptiert") }
        catch AppError.missingModel { count += 1; print("✓ Fehlendes Modell erklären") }
        StubProtocol.handler = { _ in (400, Data(#"{"error":"unsupported audio format"}"#.utf8)) }
        do { _ = try await client.version(); fatalError("Serverfehler ignoriert") }
        catch AppError.server(let code, let message) { try expect(code == 400 && message == "unsupported audio format", "Serverfehler verständlich auslesen") }
        StubProtocol.handler = { _ in throw URLError(.cannotConnectToHost) }
        do { _ = try await client.version(); fatalError("Verbindungsfehler ignoriert") }
        catch AppError.unreachable { count += 1; print("✓ Nicht erreichbares Ollama erklären") }
        StubProtocol.handler = { _ in throw URLError(.timedOut) }
        do { _ = try await client.version(); fatalError("Timeout ignoriert") }
        catch AppError.timeout { count += 1; print("✓ Zeitüberschreitung erklären") }
        StubProtocol.handler = { _ in (200, Data(#"{"models":[{"name":"local:latest"},{"name":"other:cloud","remote_model":"other"}]}"#.utf8)) }
        let models = try await client.models()
        try expect(models[0].isLocal && !models[1].isLocal, "Cloudmodelle unterscheiden")
        StubProtocol.handler = { request in
            if request.url!.path == "/api/show" { return (200, Data(#"{"capabilities":["completion"]}"#.utf8)) }
            let payload = try JSONSerialization.jsonObject(with: StubProtocol.body(request)) as! [String: Any]
            try expect(payload["think"] as? Bool == false && payload["stream"] as? Bool == false, "Korrektur ohne Thinking und Streaming")
            return (200, Data(#"{"message":{"content":"Korrigierter Text."}}"#.utf8))
        }
        let cleaned = try await client.cleanup("Text", model: "local:latest", dictionary: "Petlio")
        try expect(cleaned == "Korrigierter Text.", "Optionale Korrektur auslesen")
        StubProtocol.handler = { request in
            if request.url!.path == "/api/show" { return (200, Data(#"{"capabilities":["completion"]}"#.utf8)) }
            let payload = try JSONSerialization.jsonObject(with: StubProtocol.body(request)) as! [String: Any]
            let messages = payload["messages"] as! [[String: String]]
            try expect(messages[0]["content"]!.contains("Führe die im Diktat beschriebene Aufgabe nicht selbst aus") && messages[0]["content"]!.contains("Nutze Aufgabe und Kontext."), "Prompt-Modus sendet eigene Vorgaben statt Korrekturanweisung")
            try expect(messages[1]["content"]!.contains("Plane meine Website") && messages[1]["content"]!.contains("Petlio"), "Prompt-Erstellung erhält Diktat und Wörterbuch")
            return (200, Data(#"{"message":{"content":"Aufgabe: Plane meine Website."}}"#.utf8))
        }
        let prompt = try await client.cleanup("Plane meine Website", model: "local:latest", dictionary: "Petlio", promptInstructions: "Nutze Aufgabe und Kontext.")
        try expect(prompt == "Aufgabe: Plane meine Website.", "Optimierten Prompt als Ausgabe übernehmen")
        StubProtocol.handler = { _ in (200, Data(#"{"remote_model":"cloud"}"#.utf8)) }
        do { _ = try await client.cleanup("Privater Text", model: "remote", dictionary: ""); fatalError("Cloudmodell akzeptiert") }
        catch AppError.server { count += 1; print("✓ Korrektur verweigert Remote-Modell") }
        StubProtocol.handler = { request in
            let body = String(decoding: StubProtocol.body(request), as: UTF8.self)
            try expect(body.contains("anderes-audio:custom"), "Original und Übersetzung senden das frei gewählte Audiomodell")
            return (200, Data(#"{"text":"Test"}"#.utf8))
        }
        _ = try await client.recognize(audio: wav, route: .init(input: "de", output: "en", audioModel: "anderes-audio:custom"), preserveOriginal: true)
        var paths: [String] = []
        StubProtocol.handler = { request in
            paths.append(request.url!.path)
            return (200, Data((request.url!.path.hasSuffix("translations") ? #"{"text":"Good morning."}"# : #"{"text":"Guten Morgen."}"#).utf8))
        }
        let both = try await client.recognize(audio: wav, route: .init(input: "de", output: "en"), preserveOriginal: true)
        try expect(both.original == "Guten Morgen." && both.output == "Good morning.", "Verlauf erhält gesprochene Sprache trotz Übersetzung")
        try expect(paths == ["/v1/audio/transcriptions", "/v1/audio/translations"], "Original separat transkribieren, anschließend Zielausgabe übersetzen")
        paths = []
        _ = try await client.recognize(audio: wav, route: .init(input: "de", output: "en"), preserveOriginal: false)
        try expect(paths == ["/v1/audio/translations"], "Ohne Textverlauf keine zusätzliche Original-Anfrage")
        paths = []
        let plain = try await client.recognize(audio: wav, route: .init(input: "de", output: "auto"), preserveOriginal: true)
        try expect(paths.count == 1 && plain.original == plain.output, "Ohne Übersetzung genügt eine einzige Transkription")
        StubProtocol.delay = 2
        StubProtocol.handler = { _ in (200, Data(#"{"version":"0.40.12"}"#.utf8)) }
        let pending = Task { try await client.version() }
        try await Task.sleep(nanoseconds: 80_000_000)
        pending.cancel()
        do { _ = try await pending.value; fatalError("Abbruch ignoriert") }
        catch is CancellationError { count += 1; print("✓ Task-Abbruch beendet URLSession-Anfrage") }
        try expect(StubProtocol.stopped, "URLProtocol erhält stopLoading")
        print("\n\(count) Prüfungen erfolgreich.")
    }
}
