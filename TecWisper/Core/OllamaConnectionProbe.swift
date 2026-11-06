import Foundation

struct OllamaConnectionReport {
    var checks: [CheckItem]
    var models: [OllamaModel] = []
}

/// One source for the Ollama tab and the system check; transport can be simulated in tests.
struct OllamaConnectionProbe {
    var session: URLSession = .shared
    func check(address: String, audioModel: String = "lfm3-audio", cleanupModel: String?) async throws -> OllamaConnectionReport {
        var report = OllamaConnectionReport(checks: [
            .init(id: "ollama", title: "Ollama-Verbindung / Version", status: .unchecked, detail: "Noch nicht geprüft."),
            .init(id: "audio", title: "Audiomodell", status: .unchecked, detail: "Ollama-Verbindung und Mindestversion zuerst herstellen.")
        ])
        if cleanupModel != nil { report.checks.append(.init(id: "cleanup", title: "Textmodell", status: .unchecked, detail: "Ollama-Verbindung und Mindestversion zuerst herstellen.")) }
        func status(for error: Error) -> Readiness {
            if case AppError.version = error { return .missing }
            if case AppError.invalidURL = error { return .missing }
            return .unreachable
        }
        let client: OllamaClient
        do {
            client = try OllamaClient(address: address, session: session)
            let version = try await client.version()
            guard let parsed = SemanticVersion(version), parsed >= .minimum else { throw AppError.version(version) }
            report.checks[0].status = .ready; report.checks[0].detail = "Version \(version) · lokale Verbindung erreichbar."
        } catch {
            try Task.checkCancellation()
            if error is CancellationError { throw error }
            report.checks[0].status = status(for: error); report.checks[0].detail = error.localizedDescription
            return report
        }
        do { report.models = try await client.models() }
        catch {
            try Task.checkCancellation()
            if error is CancellationError { throw error }
            for index in report.checks.indices where index > 0 {
                report.checks[index].status = .unreachable
                report.checks[index].detail = "Die Modellliste konnte nicht geladen werden. \(error.localizedDescription)"
            }
            return report
        }
        for index in report.checks.indices where index > 0 {
            let audio = report.checks[index].id == "audio"
            let name = audio ? audioModel : cleanupModel!
            let installed = report.models.contains { ($0.name == name || $0.name == name + ":latest") && $0.isLocal }
            guard installed else {
                report.checks[index].status = .missing
                report.checks[index].detail = audio ? "Das gewählte lokale Audiomodell „\(name)“ ist nicht installiert." : "Das gewählte lokale Textmodell ist nicht installiert."
                continue
            }
            do {
                let info = try await client.show(name)
                let valid = info.isLocal && info.capabilities?.contains(audio ? "audio" : "completion") == true
                report.checks[index].status = valid ? .ready : .missing
                report.checks[index].detail = valid
                    ? (audio ? "\(name) ist lokal installiert; Audiofähigkeit bestätigt. Verarbeitung noch nicht getestet." : "\(name) ist lokal verfügbar.")
                    : "Das Modell ist nicht lokal oder unterstützt die benötigte \(audio ? "Audioeingabe" : "Textausgabe") nicht."
            } catch {
                try Task.checkCancellation()
                if error is CancellationError { throw error }
                report.checks[index].status = .unreachable; report.checks[index].detail = error.localizedDescription
            }
        }
        return report
    }
}
