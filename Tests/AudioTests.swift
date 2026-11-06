import AVFoundation
import Foundation

@main
struct AudioTests {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TecWisperAudioTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for channels in [AVAudioChannelCount(1), 2] {
            let url = directory.appendingPathComponent("sample-\(channels).caf")
            let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: channels)!
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48_000)!
            buffer.frameLength = 48_000
            for channel in 0..<Int(channels) {
                for index in 0..<48_000 { buffer.floatChannelData![channel][index] = Float(sin(Double(index) * 2 * .pi * 440 / 48_000)) * 0.2 }
            }
            do { let file = try AVAudioFile(forWriting: url, settings: format.settings); try file.write(from: buffer) }
            let wav = try AudioRecorder.convertRecording(at: url)
            guard abs(wav.count - 32_044) < 128 else { fatalError("Falsche PCM-Länge bei \(channels) Kanal/Kanälen: \(wav.count)") }
            guard Array(wav[22..<24]) == [1, 0], Array(wav[34..<36]) == [16, 0] else { fatalError("Kein 16-Bit-Mono") }
            guard wav.dropFirst(44).contains(where: { $0 != 0 }) else { fatalError("Ton bei Konvertierung verloren") }
            print("✓ 48-kHz-\(channels)-Kanal-Aufnahme zu 16-kHz-Mono-WAV konvertiert, Länge und Ton erhalten")
        }
        let emptyURL = directory.appendingPathComponent("empty.caf")
        do { _ = try AVAudioFile(forWriting: emptyURL, settings: AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!.settings) }
        do { _ = try AudioRecorder.convertRecording(at: emptyURL); fatalError("Leere Aufnahme akzeptiert") }
        catch AppError.emptyTranscript { print("✓ Leere Audioaufnahme abgefangen") }
        print("3 Audio-Prüfungen erfolgreich.")
    }
}
