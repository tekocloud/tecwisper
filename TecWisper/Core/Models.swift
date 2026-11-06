import Foundation

struct DictationLanguage: Identifiable, Hashable {
    let id: String
    let name: String
    static let all: [Self] = [
        .init(id: "auto", name: "Automatisch"), .init(id: "de", name: "Deutsch"),
        .init(id: "en", name: "Englisch"), .init(id: "ar", name: "Arabisch"),
        .init(id: "zh", name: "Chinesisch"), .init(id: "da", name: "Dänisch"),
        .init(id: "fi", name: "Finnisch"), .init(id: "fr", name: "Französisch"),
        .init(id: "el", name: "Griechisch"), .init(id: "he", name: "Hebräisch"),
        .init(id: "it", name: "Italienisch"), .init(id: "ja", name: "Japanisch"),
        .init(id: "ko", name: "Koreanisch"), .init(id: "nl", name: "Niederländisch"),
        .init(id: "pl", name: "Polnisch"), .init(id: "pt", name: "Portugiesisch"),
        .init(id: "sv", name: "Schwedisch"), .init(id: "es", name: "Spanisch"),
        .init(id: "tr", name: "Türkisch")
    ]
}

struct LanguageRoute: Equatable {
    let input: String
    let output: String
    var audioModel = "lfm3-audio"
    var translates: Bool { output != "auto" && output != input }
    var path: String { translates ? "v1/audio/translations" : "v1/audio/transcriptions" }
    var fields: [String: String] {
        var fields = ["model": audioModel, "response_format": "json", "temperature": "0", "stream": "false"]
        if input != "auto" { fields["language"] = input }
        if translates { fields["to_language"] = output }
        return fields
    }
}

struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    // Carbon modifier flags, independent of the current keyboard layout.
    static let holdDefault = Shortcut(keyCode: 49, modifiers: 2048)
    static let toggleDefault = Shortcut(keyCode: 49, modifiers: 2048 | 512)
    var isValid: Bool { keyCode != 53 && modifiers & (256 | 512 | 2048 | 4096) != 0 }
}

struct Preferences: Codable, Equatable {
    var baseURL = "http://localhost:11434"
    var selectedAudioModel: String?
    var audioModel: String {
        get { (selectedAudioModel ?? "lfm3-audio").trimmingCharacters(in: .whitespacesAndNewlines) }
        set { selectedAudioModel = newValue }
    }
    var inputLanguage = "auto"
    var outputLanguage = "auto"
    var holdShortcut: Shortcut? = .holdDefault
    var toggleShortcut: Shortcut? = .toggleDefault
    var cleanupEnabled = false
    var cleanupModel = "qwen3.8:27b-mlx"
    var dictionary = ""
    // Optional stored values keep preferences from earlier versions decodable.
    var promptOptimization: Bool?
    var promptInstructions: String?
    var optimizesPrompt: Bool { promptOptimization ?? false }
    var usesTextModel: Bool { cleanupEnabled || optimizesPrompt }
    static let defaultPromptInstructions = "Formuliere einen klaren, direkt verwendbaren Prompt. Strukturiere bei Bedarf nach Aufgabe, Kontext, Anforderungen und gewünschtem Ausgabeformat. Bewahre meine Absicht und alle genannten Details. Erfinde keine Fakten oder Anforderungen. Kennzeichne notwendige fehlende Angaben als Platzhalter. Gib ausschließlich den fertigen Prompt aus."
    var microphoneID = ""
    var route: LanguageRoute { .init(input: inputLanguage, output: outputLanguage, audioModel: audioModel) }
    var shortcutError: String? {
        if let holdShortcut, !holdShortcut.isValid { return "Wähle eine Taste mit ⌘, ⌥, ⌃ oder ⇧. Escape ist für Abbrechen reserviert." }
        if let toggleShortcut, !toggleShortcut.isValid { return "Wähle eine Taste mit ⌘, ⌥, ⌃ oder ⇧. Escape ist für Abbrechen reserviert." }
        if let holdShortcut, holdShortcut == toggleShortcut { return "Die beiden Aktionen benötigen unterschiedliche Tastenkürzel." }
        return nil
    }
    static func load(from defaults: UserDefaults = .standard) -> Self {
        guard let data = defaults.data(forKey: "preferences"), let value = try? JSONDecoder().decode(Self.self, from: data) else { return .init() }
        return value
    }
    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: "preferences") }
    }
}

struct SemanticVersion: Comparable {
    let major: Int; let minor: Int; let patch: Int
    let prerelease: Bool
    init?(_ text: String) {
        let clean = text.hasPrefix("v") ? String(text.dropFirst()) : text
        let pieces = clean.split(separator: "-", maxSplits: 1)
        guard let release = pieces.first else { return nil }
        let numbers = release.split(separator: ".", omittingEmptySubsequences: false)
        guard numbers.count == 3, let patchPart = numbers[2].split(separator: "+").first,
              let a = Int(numbers[0]), let b = Int(numbers[1]),
              let c = Int(patchPart), a >= 0, b >= 0, c >= 0 else { return nil }
        major = a; minor = b; patch = c; prerelease = pieces.count > 1
    }
    static func < (lhs: Self, rhs: Self) -> Bool {
        let a = [lhs.major, lhs.minor, lhs.patch], b = [rhs.major, rhs.minor, rhs.patch]
        if a != b { return a.lexicographicallyPrecedes(b) }
        return lhs.prerelease && !rhs.prerelease
    }
    static let minimum = SemanticVersion("0.40.12")!
}

enum Readiness: String { case ready = "Bereit", missing = "Fehlt", unreachable = "Nicht erreichbar", checking = "Prüfung läuft", unchecked = "Noch nicht geprüft" }
struct CheckItem: Identifiable {
    let id: String
    let title: String
    var status: Readiness
    var detail: String
}

struct OllamaModel: Decodable, Identifiable {
    let name: String
    let remoteModel: String?
    let remoteHost: String?
    let capabilities: [String]?
    var id: String { name }
    var isLocal: Bool { remoteModel == nil && remoteHost == nil && !name.hasSuffix(":cloud") }
    enum CodingKeys: String, CodingKey { case name, capabilities; case remoteModel = "remote_model", remoteHost = "remote_host" }
}
struct ModelInfo: Decodable {
    let capabilities: [String]?
    let remoteModel: String?
    let remoteHost: String?
    var isLocal: Bool { remoteModel == nil && remoteHost == nil }
    enum CodingKeys: String, CodingKey { case capabilities; case remoteModel = "remote_model", remoteHost = "remote_host" }
}

enum AppError: LocalizedError {
    case invalidURL, unreachable, version(String), missingModel(String), microphone(String), server(Int, String), invalidResponse, emptyTranscript, timeout, noTarget
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Die Ollama-Adresse ist ungültig. Verwende eine lokale HTTP-Adresse, zum Beispiel http://localhost:11434."
        case .unreachable: return "Ollama ist nicht erreichbar. Starte Ollama oder prüfe die eingestellte Adresse."
        case .version(let version): return "Ollama \(version) wird nicht unterstützt. Für Audio ist Version 0.40.12 oder neuer erforderlich."
        case .missingModel(let name): return "Das Modell \(name) ist nicht verfügbar. Installiere es in Ollama und prüfe erneut."
        case .microphone(let detail): return detail
        case .server(let code, let detail): return "Ollama meldet einen Fehler (\(code)): \(detail)"
        case .invalidResponse: return "Ollama hat eine ungültige Antwort gesendet. Prüfe Version und Audiomodell."
        case .emptyTranscript: return "Es wurde kein Text erkannt. Sprich etwas näher am Mikrofon und versuche es erneut."
        case .timeout: return "Die Verarbeitung hat zu lange gedauert. Prüfe Ollama und versuche es erneut."
        case .noTarget: return "Kein eindeutiges, beschreibbares Textfeld gefunden. Der Text bleibt zum Kopieren verfügbar."
        }
    }
}

struct MultipartBody {
    let boundary: String
    let data: Data
    init(fields: [String: String], audio: Data, boundary: String = "TecWisper-\(UUID().uuidString)") {
        self.boundary = boundary
        var body = Data()
        func append(_ string: String) { body.append(Data(string.utf8)) }
        for key in fields.keys.sorted() {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n\r\n\(fields[key]!)\r\n")
        }
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"dictation.wav\"\r\nContent-Type: audio/wav\r\n\r\n")
        body.append(audio)
        append("\r\n--\(boundary)--\r\n")
        data = body
    }
}
