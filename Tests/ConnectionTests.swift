import Foundation

@main
struct ConnectionTests {
    static var count = 0
    static func expect(_ value: @autoclosure () -> Bool, _ title: String) throws {
        guard value() else { throw NSError(domain: "ConnectionTests", code: 1, userInfo: [NSLocalizedDescriptionKey: title]) }
        count += 1; print("✓ \(title)")
    }
    static func main() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let probe = OllamaConnectionProbe(session: session)
        let address = "http://localhost:11434"
        func configure(version: String = "0.40.12", models: String = #"{"models":[{"name":"lfm3-audio:latest"},{"name":"text:latest"}]}"#, capability: String = "audio") {
            StubProtocol.handler = { request in
                switch request.url!.path {
                case "/api/version": return (200, Data("{\"version\":\"\(version)\"}".utf8))
                case "/api/tags": return (200, Data(models.utf8))
                default:
                    let payload = try JSONSerialization.jsonObject(with: StubProtocol.body(request)) as! [String: String]
                    return (200, Data("{\"capabilities\":[\"\(payload["model"] == "lfm3-audio" ? capability : "completion")\"]}".utf8))
                }
            }
        }
        configure()
        let ready = try await probe.check(address: address, cleanupModel: "text:latest")
        try expect(ready.checks.count == 3 && ready.checks.allSatisfy { $0.status == .ready }, "Verbindung, Audiomodell und Textmodell erfolgreich")
        configure(models: #"{"models":[]}"#)
        let missing = try await probe.check(address: address, cleanupModel: nil)
        try expect(missing.checks[0].status == .ready && missing.checks[1].status == .missing, "Erreichbares Ollama mit fehlendem Modell getrennt dargestellt")
        try expect(missing.checks[1].detail.contains("lfm3-audio"), "Fehlendes Modell zeigt Installationshilfe")
        configure(version: "0.40.11")
        let old = try await probe.check(address: address, cleanupModel: nil)
        try expect(old.checks[0].status == .missing && old.checks[1].status == .unchecked, "Alte Version erklärt und Modellprüfung übersprungen")
        let invalid = try await probe.check(address: "https://example.org", cleanupModel: nil)
        try expect(invalid.checks[0].status == .missing && invalid.checks[0].detail.contains("Adresse"), "Ungültige Adresse wird direkt erklärt")
        StubProtocol.handler = { _ in throw URLError(.cannotConnectToHost) }
        let offline = try await probe.check(address: address, cleanupModel: nil)
        try expect(offline.checks[0].status == .unreachable && offline.checks[0].detail.contains("nicht erreichbar"), "Nicht erreichbares Ollama wird sichtbar gemeldet")
        StubProtocol.handler = { _ in throw URLError(.timedOut) }
        let timeout = try await probe.check(address: address, cleanupModel: nil)
        try expect(timeout.checks[0].status == .unreachable && timeout.checks[0].detail.contains("zu lange"), "Zeitüberschreitung hat verständliches Ergebnis")
        configure(models: #"{"models":[{"name":"anderes-audio:custom"}]}"#)
        let customHandler = StubProtocol.handler!
        StubProtocol.handler = { request in
            if request.url!.path == "/api/show" {
                let payload = try JSONSerialization.jsonObject(with: StubProtocol.body(request)) as! [String: String]
                try expect(payload["model"] == "anderes-audio:custom", "Systemprüfung verwendet das frei gewählte Modell")
                return (200, Data(#"{"capabilities":["audio"]}"#.utf8))
            }
            return try customHandler(request)
        }
        let custom = try await probe.check(address: address, audioModel: "anderes-audio:custom", cleanupModel: nil)
        try expect(custom.checks.allSatisfy { $0.status == .ready }, "Alternatives Audiomodell ohne lfm3-audio akzeptieren")
        configure(capability: "completion")
        let wrong = try await probe.check(address: address, cleanupModel: nil)
        try expect(wrong.checks[1].status == .missing && wrong.checks[1].detail.contains("Audioeingabe"), "Fehlende Audiofähigkeit wird erkannt")
        configure(models: #"{"models":[{"name":"lfm3-audio:latest","remote_model":"remote"}]}"#)
        let cloud = try await probe.check(address: address, cleanupModel: nil)
        try expect(cloud.checks[1].status == .missing, "Cloud-Audiomodell nicht als lokal bereit ausgegeben")
        configure()
        let prior = StubProtocol.handler!
        StubProtocol.handler = { request in
            if request.url!.path == "/api/tags" { return (500, Data(#"{"error":"unavailable"}"#.utf8)) }
            return try prior(request)
        }
        let tagsError = try await probe.check(address: address, cleanupModel: nil)
        try expect(tagsError.checks[0].status == .ready && tagsError.checks[1].status == .unreachable, "Fehler der Modellliste überschreibt erfolgreiche Verbindung nicht")
        configure(); StubProtocol.delay = 1
        let task = Task { try await probe.check(address: address, cleanupModel: nil) }
        try await Task.sleep(nanoseconds: 50_000_000); task.cancel()
        do { _ = try await task.value; throw NSError(domain: "NoCancel", code: 1) }
        catch is CancellationError { count += 1; print("✓ Abbruch veröffentlicht keinen irreführenden Fehlerbericht") }
        print("\n\(count) Verbindungstest-Prüfungen erfolgreich.")
    }
}
