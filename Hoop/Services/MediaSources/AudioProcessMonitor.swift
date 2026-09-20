// Hoop/Services/MediaSources/AudioProcessMonitor.swift
import CoreAudio
import Foundation
import os.log

private let log = Logger(subsystem: "com.hoops.hoop", category: "AudioProcessMonitor")

/// Reports which processes (by bundle ID) are currently outputting audio,
/// using CoreAudio process objects. Generic: no app list required.
final class AudioProcessMonitor {

    struct Snapshot: Equatable {
        let outputting: Set<String>
        let timestamp: Date
    }

    static var isSupported: Bool {
        if #available(macOS 14.2, *) { return true }
        return false
    }

    /// Delivered on the main queue, only when the set of outputting bundle IDs changes.
    var onSnapshot: ((Snapshot) -> Void)?

    private let queue = DispatchQueue(label: "com.hoops.hoop.audioprocess", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var last: Set<String>?
    private let selfBundleID = Bundle.main.bundleIdentifier

    func start() {
        guard Self.isSupported, timer == nil else { return }
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 0.5, repeating: 1.0)
        t.setEventHandler { [weak self] in self?.poll() }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
        last = nil
    }

    private func poll() {
        guard #available(macOS 14.2, *) else { return }
        let current = Self.outputtingBundleIDs().subtracting([selfBundleID].compactMap { $0 })
        guard current != last else { return }
        last = current
        let snap = Snapshot(outputting: current, timestamp: Date())
        DispatchQueue.main.async { [weak self] in self?.onSnapshot?(snap) }
    }

    @available(macOS 14.2, *)
    private static func outputtingBundleIDs() -> Set<String> {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var listAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &listAddr, 0, nil, &size) == noErr, size > 0 else {
            return []
        }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &listAddr, 0, nil, &size, &ids) == noErr else {
            log.error("process list read failed")
            return []
        }

        var result = Set<String>()
        for id in ids {
            var runAddr = AudioObjectPropertyAddress(
                mSelector: kAudioProcessPropertyIsRunningOutput,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            var running: UInt32 = 0
            var runSize = UInt32(MemoryLayout<UInt32>.size)
            guard AudioObjectGetPropertyData(id, &runAddr, 0, nil, &runSize, &running) == noErr,
                  running != 0 else { continue }

            var bidAddr = AudioObjectPropertyAddress(
                mSelector: kAudioProcessPropertyBundleID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            var bundle: CFString? = nil
            var bidSize = UInt32(MemoryLayout<CFString?>.size)
            let status = withUnsafeMutablePointer(to: &bundle) { ptr in
                AudioObjectGetPropertyData(id, &bidAddr, 0, nil, &bidSize, ptr)
            }
            guard status == noErr, let cf = bundle else { continue }
            let s = cf as String
            if !s.isEmpty { result.insert(s) }
        }
        return result
    }
}
