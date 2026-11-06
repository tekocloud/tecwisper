import Foundation

/// Explicit integration test. Uses synthetic speech, never records the microphone.
@main
struct LiveAudioTest {
    static func main() async throws {
        guard CommandLine.arguments.count >= 2 else { fatalError("WAV-/AIFF-Datei als Argument erforderlich") }
        let audio = try AudioRecorder.convertRecording(at: URL(fileURLWithPath: CommandLine.arguments[1]))
        guard String(data: audio.prefix(4), encoding: .utf8) == "RIFF", audio.count > 44 else { fatalError("Keine WAV-Datei erzeugt") }
        print("Audio-Konvertierung: \(audio.count) Bytes, WAV 16 kHz / Mono / 16 Bit")
        let client = try OllamaClient(address: "http://localhost:11434")
        let input = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "de"
        let output = input == "de" ? "en" : "de"
        for route in [LanguageRoute(input: input, output: "auto"), .init(input: "auto", output: "auto"), .init(input: input, output: output)] {
            let start = Date()
            let text = try await client.transcribe(audio: audio, route: route)
            print("\(route.input) → \(route.output) [\(String(format: "%.1f", Date().timeIntervalSince(start))) s]: \(text)")
        }
    }
}
