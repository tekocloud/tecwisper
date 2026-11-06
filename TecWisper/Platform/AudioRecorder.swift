import AVFoundation
import CoreAudio
import Foundation

struct Microphone: Identifiable, Hashable { let id: String; let name: String; let deviceID: AudioDeviceID }

final class AudioRecorder {
    private var engine: AVAudioEngine?
    private var file: AVAudioFile?
    private var url: URL?
    private let lock = NSLock()
    private var writeError: Error?
    var onLevel: ((Float) -> Void)?
    var onFailure: ((String) -> Void)?
    private var observer: NSObjectProtocol?

    static var microphones: [Microphone] {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone], mediaType: .audio, position: .unspecified).devices.compactMap { device in
            var deviceID = AudioDeviceID(0)
            var uid = device.uniqueID as CFString
            withUnsafeMutablePointer(to: &uid) { pointer in
                withUnsafeMutablePointer(to: &deviceID) { outputPointer in
                    var translation = AudioValueTranslation(mInputData: UnsafeMutableRawPointer(pointer), mInputDataSize: UInt32(MemoryLayout<CFString>.size), mOutputData: UnsafeMutableRawPointer(outputPointer), mOutputDataSize: UInt32(MemoryLayout<AudioDeviceID>.size))
                    var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyTranslateUIDToDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
                    var size = UInt32(MemoryLayout<AudioValueTranslation>.size)
                    _ = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &translation)
                }
            }
            return Microphone(id: device.uniqueID, name: device.localizedName, deviceID: deviceID)
        }
    }

    func start(microphoneID: String) throws {
        discard()
        let engine = AVAudioEngine()
        let input = engine.inputNode
        if !microphoneID.isEmpty {
            guard let microphone = Self.microphones.first(where: { $0.id == microphoneID }), microphone.deviceID != 0,
                  let unit = input.audioUnit else { throw AppError.microphone("Das ausgewählte Mikrofon ist nicht mehr verfügbar. Wähle ein anderes in den Einstellungen.") }
            var id = microphone.deviceID
            let status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &id, UInt32(MemoryLayout<AudioDeviceID>.size))
            guard status == noErr else { throw AppError.microphone("Das ausgewählte Mikrofon konnte nicht geöffnet werden (\(status)).") }
        }
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw AppError.microphone("Kein betriebsbereites Mikrofon gefunden.") }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("TecWisper-\(UUID().uuidString).caf")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        self.engine = engine; self.file = file; self.url = url; self.writeError = nil
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.lock.lock()
            do { try self.file?.write(from: buffer) } catch { self.writeError = error }
            self.lock.unlock()
            if let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 {
                var energy: Float = 0
                for index in 0..<Int(buffer.frameLength) { energy += samples[index] * samples[index] }
                self.onLevel?(min(1, sqrt(energy / Float(buffer.frameLength)) * 5))
            }
        }
        observer = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            self?.onFailure?("Das Mikrofon wurde getrennt oder seine Konfiguration geändert. Prüfe das Aufnahmegerät und starte erneut.")
        }
        do { try engine.start() } catch { discard(); throw AppError.microphone("Die Mikrofonaufnahme konnte nicht gestartet werden: \(error.localizedDescription)") }
    }

    func finish() throws -> Data {
        stopEngine()
        lock.lock(); let error = writeError; file = nil; lock.unlock()
        defer { discard() }
        if let error { throw AppError.microphone("Die Aufnahme konnte nicht gespeichert werden: \(error.localizedDescription)") }
        guard let url else { throw AppError.microphone("Es liegt keine Aufnahme vor.") }
        return try Self.convertRecording(at: url)
    }
    static func convertRecording(at url: URL) throws -> Data {
        let source = try AVAudioFile(forReading: url)
        guard source.length > 0 else { throw AppError.emptyTranscript }
        guard let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true),
              let converter = AVAudioConverter(from: source.processingFormat, to: outputFormat) else { throw AppError.microphone("Das Audioformat konnte nicht umgewandelt werden.") }
        var pcm = Data()
        var reachedEnd = false
        while true {
            guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: 16_000) else { throw AppError.invalidResponse }
            var conversionError: NSError?
            var readError: Error?
            let status = converter.convert(to: output, error: &conversionError) { requested, inputStatus in
                if reachedEnd || source.framePosition >= source.length { reachedEnd = true; inputStatus.pointee = .endOfStream; return nil }
                guard let buffer = AVAudioPCMBuffer(pcmFormat: source.processingFormat, frameCapacity: max(requested, 4096)) else {
                    inputStatus.pointee = .endOfStream; return nil
                }
                do { try source.read(into: buffer, frameCount: AVAudioFrameCount(min(AVAudioFramePosition(buffer.frameCapacity), source.length - source.framePosition))) } catch {
                    readError = error; inputStatus.pointee = .endOfStream; return nil
                }
                if buffer.frameLength == 0 { reachedEnd = true; inputStatus.pointee = .endOfStream; return nil }
                inputStatus.pointee = .haveData; return buffer
            }
            if let readError { throw readError }
            if let conversionError { throw AppError.microphone("Audio-Konvertierung fehlgeschlagen: \(conversionError.localizedDescription)") }
            let audioBuffer = output.audioBufferList.pointee.mBuffers
            if let bytes = audioBuffer.mData, audioBuffer.mDataByteSize > 0 { pcm.append(bytes.assumingMemoryBound(to: UInt8.self), count: Int(audioBuffer.mDataByteSize)) }
            if status == .endOfStream { break }
            if status == .error { throw AppError.microphone("Audio-Konvertierung fehlgeschlagen.") }
        }
        guard !pcm.isEmpty else { throw AppError.emptyTranscript }
        return WAV.encode(pcm: pcm)
    }
    private func stopEngine() {
        if let observer { NotificationCenter.default.removeObserver(observer); self.observer = nil }
        engine?.stop()
        if engine != nil { engine?.inputNode.removeTap(onBus: 0) }
        engine = nil
    }
    func discard() {
        stopEngine()
        lock.lock(); file = nil; writeError = nil; lock.unlock()
        if let url { try? FileManager.default.removeItem(at: url) }
        url = nil
    }
    deinit { discard() }
}
