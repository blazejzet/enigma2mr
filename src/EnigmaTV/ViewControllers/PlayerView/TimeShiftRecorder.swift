//
//  TimeShiftRecorder.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 22.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//
//  Timeshift = one connection to the receiver whose TS stream is written into a disk buffer
//  (TimeshiftBuffer) + a loopback HTTP server (TimeshiftServer) from which VLC plays at any
//  position of that buffer. "Live" is simply the buffer played a few seconds behind its end.
//

import UIKit
import Network

// MARK: - Buffer

/// Segmented, size/time limited on-disk buffer of a live TS stream with a time → byte index.
/// Thread safe: appended from the download queue, read from the server queue.
final class TimeshiftBuffer {

    enum ReadResult {
        case data(Data, offset: Int64)
        /// Nothing new yet – use `whenDataAvailable`.
        case wait
        case closed
    }

    private struct Sample {
        let time: TimeInterval
        let offset: Int64
    }

    static let packetSize: Int64 = 188

    let generation: Int
    let directory: URL
    let maxBytes: Int64
    let maxDuration: TimeInterval
    /// Called (on the download queue) once when the disk refused a write.
    var onWriteFailure: (() -> Void)?

    private let segmentSize: Int64 = 32 * 1024 * 1024
    private let lock = NSLock()
    private var startOffset: Int64 = 0
    private var endOffset: Int64 = 0
    /// Arrival time of the byte at `offset`, sampled twice a second.
    private var samples = [Sample]()
    private var lastAppend: TimeInterval = 0
    /// Offsets where a new HTTP connection started (TS packet alignment restarts there).
    private var discontinuities: [Int64] = [0]
    private var writer: FileHandle?
    private var writerSegment: Int64 = -1
    private var waiters = [() -> Void]()
    private var closed = false
    private var writeFailed = false

    // TS index: where a decoder can start (PAT → PMT → video keyframe), filled while recording.
    private var scanCarry = Data()
    private var scanOffset: Int64 = 0
    private var pcrPid: Int?
    private var pmtPids = Set<Int>()
    private var patOffsets = [Int64]()
    private var pmtOffsets = [Int64]()
    private var keyframeOffsets = [Int64]()

    init?(generation: Int, maxBytes: Int64, maxDuration: TimeInterval) {
        self.generation = generation
        self.maxBytes = maxBytes
        self.maxDuration = maxDuration
        self.directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("timeshift-\(generation)", isDirectory: true)
        do {
            try? FileManager.default.removeItem(at: directory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            print("Timeshift buffer: cannot create \(directory.path): \(error)")
            return nil
        }
    }

    /// Removes buffers left behind by a previous run (crash, kill while suspended).
    static func removeStaleBuffers() {
        let tmp = FileManager.default.temporaryDirectory
        let items = (try? FileManager.default.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil)) ?? []
        for item in items where item.lastPathComponent.hasPrefix("timeshift") {
            try? FileManager.default.removeItem(at: item)
        }
    }

    private func segmentURL(_ index: Int64) -> URL {
        return directory.appendingPathComponent(String(format: "%06lld.ts", index))
    }

    // MARK: Writing

    /// Call before appending data of a new connection to the source.
    func markDiscontinuity() {
        lock.lock()
        if discontinuities.last != endOffset {
            discontinuities.append(endOffset)
        }
        scanCarry.removeAll()
        lock.unlock()
    }

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        guard !closed, !writeFailed else {
            lock.unlock()
            return
        }
        let now = Date().timeIntervalSince1970
        if samples.isEmpty || now - samples[samples.count - 1].time >= 0.5 {
            samples.append(Sample(time: now, offset: endOffset))
        }

        indexPackets(data, at: endOffset)

        var index = data.startIndex
        var failed = false
        while index < data.endIndex {
            let segment = endOffset / segmentSize
            if segment != writerSegment {
                try? writer?.close()
                let url = segmentURL(segment)
                FileManager.default.createFile(atPath: url.path, contents: nil)
                writer = try? FileHandle(forWritingTo: url)
                writerSegment = segment
            }
            let room = Int(segmentSize - endOffset % segmentSize)
            let end = min(data.endIndex, index + room)
            do {
                guard let writer = writer else { throw CocoaError(.fileWriteUnknown) }
                try writer.write(contentsOf: data[index..<end])
            } catch {
                print("Timeshift buffer: write failed: \(error)")
                writeFailed = true
                failed = true
                break
            }
            endOffset += Int64(end - index)
            index = end
        }
        lastAppend = now
        prune(now: now)
        let toWake = waiters
        waiters.removeAll()
        lock.unlock()

        toWake.forEach { $0() }
        if failed {
            onWriteFailure?()
        }
    }

    /// Drops whole segments from the start while the buffer exceeds its size or duration.
    private func prune(now: TimeInterval) {
        while true {
            let tooBig = endOffset - startOffset > maxBytes
            let tooOld = (samples.first.map { now - $0.time > maxDuration }) ?? false
            let first = startOffset / segmentSize
            guard tooBig || tooOld, first < writerSegment else { return }
            try? FileManager.default.removeItem(at: segmentURL(first))
            startOffset = (first + 1) * segmentSize
            // Keep the last sample at/before the new start for interpolation.
            if let i = samples.lastIndex(where: { $0.offset <= startOffset }), i > 0 {
                samples.removeFirst(i)
            }
            if let i = discontinuities.lastIndex(where: { $0 <= startOffset }), i > 0 {
                discontinuities.removeFirst(i)
            }
            for keyPath in [\TimeshiftBuffer.patOffsets, \TimeshiftBuffer.pmtOffsets, \TimeshiftBuffer.keyframeOffsets] {
                let stale = self[keyPath: keyPath].firstIndex(where: { $0 >= startOffset }) ?? self[keyPath: keyPath].count
                self[keyPath: keyPath].removeFirst(stale)
            }
        }
    }

    /// Stops accepting data, wakes readers (they get `.closed`) and deletes the files.
    func close() {
        lock.lock()
        closed = true
        try? writer?.close()
        writer = nil
        let toWake = waiters
        waiters.removeAll()
        lock.unlock()
        toWake.forEach { $0() }
        let directory = self.directory
        DispatchQueue.global(qos: .utility).async {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    // MARK: Reading

    func read(from offset: Int64, maxLength: Int) -> ReadResult {
        lock.lock()
        if closed {
            lock.unlock()
            return .closed
        }
        // Data that was pruned meanwhile is skipped – continue at the oldest byte still present.
        let start = max(offset, startOffset)
        guard start < endOffset else {
            lock.unlock()
            return .wait
        }
        let segment = start / segmentSize
        let available = min(endOffset, (segment + 1) * segmentSize) - start
        let length = Int(min(Int64(maxLength), available))
        let url = segmentURL(segment)
        lock.unlock()

        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            try handle.seek(toOffset: UInt64(start - segment * segmentSize))
            if let data = try handle.read(upToCount: length), !data.isEmpty {
                return .data(data, offset: start)
            }
        } catch {
            // The segment was pruned between unlock and open – retry at the new start.
            lock.lock()
            let moved = startOffset > start
            lock.unlock()
            if moved {
                return read(from: start, maxLength: maxLength)
            }
            print("Timeshift buffer: read failed at \(start): \(error)")
        }
        return .closed
    }

    /// Calls `block` (on an arbitrary queue) as soon as there is data after `offset` or the buffer closed.
    func whenDataAvailable(after offset: Int64, _ block: @escaping () -> Void) {
        lock.lock()
        if closed || endOffset > max(offset, startOffset) {
            lock.unlock()
            block()
            return
        }
        waiters.append(block)
        lock.unlock()
    }

    // MARK: Time ↔ position

    /// Wall-clock range currently in the buffer (oldest byte, newest byte).
    var window: (start: TimeInterval, end: TimeInterval)? {
        lock.lock()
        defer { lock.unlock() }
        guard !samples.isEmpty, endOffset > startOffset else { return nil }
        return (timeLocked(startOffset), lastAppend)
    }

    /// Byte offset to start playback at for wall-clock `time`, aligned to a TS packet,
    /// and the arrival time of that byte (the time playback will actually start at).
    func playbackPosition(for time: TimeInterval) -> (offset: Int64, time: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        guard !samples.isEmpty else {
            return (endOffset, Date().timeIntervalSince1970)
        }
        let target = offsetLocked(for: time)
        let offset = randomAccessPointLocked(atOrBefore: target) ?? alignedLocked(target)
        return (offset, timeLocked(offset))
    }

    private func timeLocked(_ offset: Int64) -> TimeInterval {
        guard let first = samples.first else { return lastAppend }
        if offset <= first.offset { return first.time }
        var lo = 0, hi = samples.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if samples[mid].offset <= offset { lo = mid } else { hi = mid - 1 }
        }
        let a = samples[lo]
        let (bTime, bOffset) = lo + 1 < samples.count ? (samples[lo + 1].time, samples[lo + 1].offset) : (lastAppend, endOffset)
        guard bOffset > a.offset else { return a.time }
        return a.time + (bTime - a.time) * Double(min(offset, bOffset) - a.offset) / Double(bOffset - a.offset)
    }

    private func offsetLocked(for time: TimeInterval) -> Int64 {
        guard let first = samples.first else { return endOffset }
        if time <= first.time { return startOffset }
        if time >= lastAppend { return endOffset }
        var lo = 0, hi = samples.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if samples[mid].time <= time { lo = mid } else { hi = mid - 1 }
        }
        let a = samples[lo]
        let (bTime, bOffset) = lo + 1 < samples.count ? (samples[lo + 1].time, samples[lo + 1].offset) : (lastAppend, endOffset)
        var offset = a.offset
        if bTime > a.time {
            offset += Int64(Double(bOffset - a.offset) * (time - a.time) / (bTime - a.time))
        }
        return min(max(offset, startOffset), endOffset)
    }

    /// Offset from which a decoder can start immediately: the PAT preceding the PMT preceding a
    /// video keyframe (random_access_indicator on the PCR/video PID). The last such point at or
    /// before `offset`; right after a recording started (none yet) the first one after it.
    private func randomAccessPointLocked(atOrBefore offset: Int64) -> Int64? {
        func entry(forKeyframe k: Int64) -> Int64? {
            guard let p = TimeshiftBuffer.last(in: pmtOffsets, atOrBefore: k), p >= startOffset,
                  let a = TimeshiftBuffer.last(in: patOffsets, atOrBefore: p), a >= startOffset else { return nil }
            return a
        }
        if let k = TimeshiftBuffer.last(in: keyframeOffsets, atOrBefore: offset), k >= startOffset, let a = entry(forKeyframe: k) {
            return a
        }
        for k in keyframeOffsets where k > offset {
            if let a = entry(forKeyframe: k) { return a }
        }
        return nil
    }

    private static func last(in sorted: [Int64], atOrBefore value: Int64) -> Int64? {
        var lo = 0, hi = sorted.count - 1, found: Int64?
        while lo <= hi {
            let mid = (lo + hi) / 2
            if sorted[mid] <= value { found = sorted[mid]; lo = mid + 1 } else { hi = mid - 1 }
        }
        return found
    }

    /// Scans complete 188-byte TS packets of the incoming data (lock held).
    private func indexPackets(_ data: Data, at offset: Int64) {
        if scanCarry.isEmpty { scanOffset = offset }
        scanCarry.append(data)
        let base = scanOffset
        var consumed = 0
        scanCarry.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let b = raw.bindMemory(to: UInt8.self)
            let count = b.count
            var i = 0
            while i + 188 <= count {
                // Sync byte, confirmed by the next packet's sync byte when available.
                guard b[i] == 0x47, i + 188 == count || b[i + 188] == 0x47 else {
                    i += 1
                    continue
                }
                let pid = (Int(b[i + 1] & 0x1f) << 8) | Int(b[i + 2])
                let unitStart = b[i + 1] & 0x40 != 0
                let control = (b[i + 3] >> 4) & 3
                let position = base + Int64(i)
                var payload = i + 4
                if control & 2 != 0 {
                    let length = Int(b[i + 4])
                    if length > 0 {
                        let flags = b[i + 5]
                        if flags & 0x10 != 0 && pcrPid == nil { pcrPid = pid }
                        if flags & 0x40 != 0 && pid == pcrPid { keyframeOffsets.append(position) }
                    }
                    payload = i + 5 + length
                }
                if pid == 0 && unitStart {
                    patOffsets.append(position)
                    // Program map PIDs from the PAT section (single-packet PATs).
                    if control & 1 != 0, payload < i + 188 {
                        let section = payload + 1 + Int(b[payload])
                        if section + 8 <= i + 188 {
                            let length = (Int(b[section + 1] & 0x0f) << 8) | Int(b[section + 2])
                            let end = min(section + 3 + length - 4, i + 188)
                            var j = section + 8
                            while j + 4 <= end {
                                let program = (Int(b[j]) << 8) | Int(b[j + 1])
                                if program != 0 { pmtPids.insert((Int(b[j + 2] & 0x1f) << 8) | Int(b[j + 3])) }
                                j += 4
                            }
                        }
                    }
                } else if unitStart && pmtPids.contains(pid) {
                    pmtOffsets.append(position)
                }
                i += 188
            }
            consumed = i
        }
        scanCarry.removeFirst(consumed)
        scanOffset += Int64(consumed)
    }

    private func alignedLocked(_ offset: Int64) -> Int64 {
        let base = discontinuities.last(where: { $0 <= offset }) ?? 0
        var aligned = base + (offset - base) / TimeshiftBuffer.packetSize * TimeshiftBuffer.packetSize
        while aligned < startOffset {
            aligned += TimeshiftBuffer.packetSize
        }
        return aligned
    }
}

// MARK: - Loopback HTTP server

/// Serves the timeshift buffer to VLC: `GET /ts?g=<generation>&o=<byte offset>` streams from that
/// offset and, at the end of the buffer, waits for new data – to VLC it looks like a live stream.
/// TCP back-pressure makes VLC's pause hold the position.
final class TimeshiftServer {
    static let shared = TimeshiftServer()

    private let queue = DispatchQueue(label: "timeshift.server")
    private var listener: NWListener?
    private var readyCallbacks = [(Bool) -> Void]()
    private var clients = [ObjectIdentifier: NWConnection]()
    private var buffer: TimeshiftBuffer?

    private let portLock = NSLock()
    private var _port: UInt16?
    var port: UInt16? {
        portLock.lock()
        defer { portLock.unlock() }
        return _port
    }
    private func setPort(_ port: UInt16?) {
        portLock.lock()
        _port = port
        portLock.unlock()
    }

    /// Buffer to serve; drops clients of the previous one.
    func serve(_ buffer: TimeshiftBuffer?) {
        queue.async {
            self.buffer = buffer
            self.dropClients()
        }
    }

    /// Starts listening on the loopback interface if needed. `completion` on the main queue.
    func start(completion: @escaping (Bool) -> Void) {
        queue.async {
            if self.listener != nil, self.port != nil {
                DispatchQueue.main.async { completion(true) }
                return
            }
            self.readyCallbacks.append(completion)
            guard self.listener == nil else { return }
            do {
                let params = NWParameters.tcp
                params.requiredInterfaceType = .loopback
                params.allowLocalEndpointReuse = true
                let listener = try NWListener(using: params)
                // The server is a process-wide singleton, so capturing it strongly is fine.
                listener.newConnectionHandler = { connection in
                    self.accept(connection)
                }
                listener.stateUpdateHandler = { [weak listener] state in
                    guard let listener = listener else { return }
                    self.listenerStateChanged(state, listener)
                }
                self.listener = listener
                listener.start(queue: self.queue)
            } catch {
                print("Timeshift server: cannot listen: \(error)")
                self.finishStart(false)
            }
        }
    }

    /// Closes the listener (e.g. app going to background – iOS reclaims sockets of suspended apps).
    func shutdown() {
        queue.async {
            self.dropClients()
            self.buffer = nil
            self.listener?.cancel()
            self.listener = nil
            self.setPort(nil)
        }
    }

    private func listenerStateChanged(_ state: NWListener.State, _ listener: NWListener) {
        switch state {
        case .ready:
            setPort(listener.port?.rawValue)
            print("Timeshift server listening on 127.0.0.1:\(port ?? 0)")
            finishStart(true)
        case .failed(let error):
            print("Timeshift server failed: \(error)")
            listener.cancel()
            if self.listener === listener {
                self.listener = nil
                setPort(nil)
            }
            finishStart(false)
        case .cancelled:
            if self.listener === listener {
                self.listener = nil
                setPort(nil)
            }
        default:
            break
        }
    }

    private func finishStart(_ ok: Bool) {
        let callbacks = readyCallbacks
        readyCallbacks.removeAll()
        DispatchQueue.main.async { callbacks.forEach { $0(ok) } }
    }

    private func dropClients() {
        clients.values.forEach { $0.cancel() }
        clients.removeAll()
    }

    // MARK: Connections

    private func accept(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        clients[id] = connection
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                self?.clients[id] = nil
            default:
                break
            }
        }
        connection.start(queue: queue)
        receiveRequest(connection, Data())
    }

    private func receiveRequest(_ connection: NWConnection, _ received: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            var request = received
            if let data = data { request.append(data) }
            if let end = request.range(of: Data("\r\n\r\n".utf8)) {
                self.handle(connection, head: String(decoding: request[..<end.lowerBound], as: UTF8.self))
            } else if error != nil || isComplete || request.count > 16 * 1024 {
                connection.cancel()
            } else {
                self.receiveRequest(connection, request)
            }
        }
    }

    private func handle(_ connection: NWConnection, head: String) {
        let requestLine = head.components(separatedBy: "\r\n").first?.components(separatedBy: " ") ?? []
        guard requestLine.count >= 2, requestLine[0] == "GET" || requestLine[0] == "HEAD",
              let components = URLComponents(string: requestLine[1]), components.path == "/ts",
              let buffer = buffer else {
            respond(connection, status: "404 Not Found")
            return
        }
        let query = components.queryItems ?? []
        let generation = query.first(where: { $0.name == "g" })?.value.flatMap { Int($0) }
        let offset = query.first(where: { $0.name == "o" })?.value.flatMap { Int64($0) } ?? 0
        guard generation == buffer.generation else {
            respond(connection, status: "410 Gone")
            return
        }
        let isGet = requestLine[0] == "GET"
        let header = "HTTP/1.1 200 OK\r\nContent-Type: video/mp2t\r\nCache-Control: no-cache\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(header.utf8), completion: .contentProcessed { [weak self] error in
            guard error == nil, isGet else {
                connection.cancel()
                return
            }
            self?.pump(connection, buffer, from: max(0, offset))
        })
    }

    private func respond(_ connection: NWConnection, status: String) {
        let response = "HTTP/1.1 \(status)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    /// Sends the buffer from `offset` on; the next chunk is read only after the previous one was
    /// taken by the socket, so a paused/slow VLC naturally holds the position.
    private func pump(_ connection: NWConnection, _ buffer: TimeshiftBuffer, from offset: Int64) {
        guard clients[ObjectIdentifier(connection)] != nil, self.buffer === buffer else {
            connection.cancel()
            return
        }
        switch buffer.read(from: offset, maxLength: Int(TimeshiftBuffer.packetSize) * 1024) {
        case .data(let data, let at):
            connection.send(content: data, completion: .contentProcessed { [weak self] error in
                if error != nil {
                    connection.cancel()
                    return
                }
                self?.pump(connection, buffer, from: at + Int64(data.count))
            })
        case .wait:
            buffer.whenDataAvailable(after: offset) { [weak self] in
                self?.queue.async { self?.pump(connection, buffer, from: offset) }
            }
        case .closed:
            connection.cancel()
        }
    }
}

// MARK: - Recorder

protocol TimeShiftRecorderDelegate: AnyObject {
    /// Timeshift cannot continue (source lost for good, disk full) – fall back to direct live playback.
    func timeshiftFailed()
}

class TimeShiftRecorder: NSObject {
    static var _tsr:TimeShiftRecorder?
    weak var delegate:TimeShiftRecorderDelegate?

    class func common() -> TimeShiftRecorder{
        if let tsr = TimeShiftRecorder._tsr{
            return tsr
        }else{
            TimeshiftBuffer.removeStaleBuffers()
            TimeShiftRecorder._tsr = TimeShiftRecorder()
            return TimeShiftRecorder._tsr!
        }
    }

    /// How far behind the newest byte "live" playback starts (lets VLC start on buffered data).
    static let liveDelay: TimeInterval = 3
    private static let maxReconnectAttempts = 8

    private(set) var buffer: TimeshiftBuffer?
    var conn2:URLConnection?
    var timestart:TimeInterval?
    var service:Service?
    var bouquet:Service?
    var events:[EpgEvent]?
    private(set) var generation = 0
    private var sourceURL: URL?
    private var reconnectAttempts = 0
    private var loadingEvents = false

    var isActive: Bool { return buffer != nil }
    var window: (start: TimeInterval, end: TimeInterval)? { return buffer?.window }

    public func stop(){
        generation += 1
        conn2?.stop()
        conn2 = nil
        buffer?.close()
        buffer = nil
        TimeshiftServer.shared.serve(nil)
        sourceURL = nil
        timestart = nil
    }

    /// Starts buffering `url`. `ready(true)` (main queue) once the local server can serve it.
    public func startTimeShift(for url:URL, service:Service, inBouquet bouquet:Service, ready: @escaping (Bool) -> Void){
        stop()
        let gen = generation
        let minutes = UserDefaults.standard.integer(forKey: "timeshiftMinutes")
        let duration = TimeInterval(minutes > 0 ? minutes : 60) * 60
        guard let buffer = TimeshiftBuffer(generation: gen, maxBytes: TimeShiftRecorder.byteBudget(), maxDuration: duration) else {
            ready(false)
            return
        }
        buffer.onWriteFailure = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self, self.generation == gen else { return }
                self.delegate?.timeshiftFailed()
            }
        }
        self.buffer = buffer
        self.service = service
        self.bouquet = bouquet
        self.events = nil
        self.sourceURL = url
        self.reconnectAttempts = 0
        self.timestart = Date().timeIntervalSince1970

        TimeshiftServer.shared.serve(buffer)
        connect()
        reloadEvents()
        TimeshiftServer.shared.start { [weak self] ok in
            guard let self = self, self.generation == gen else { return }
            ready(ok)
        }
    }

    private func connect() {
        guard let url = sourceURL, let buffer = buffer else { return }
        let gen = generation
        let connection = URLConnection()
        connection.onData = { [weak self] in
            self?.reconnectAttempts = 0
        }
        connection.onFinish = { [weak self] _ in
            self?.sourceEnded(generation: gen)
        }
        buffer.markDiscontinuity()
        print("Timeshift: recording \(url.absoluteString)")
        connection.connect(url: url, into: buffer)
        conn2 = connection
    }

    /// The receiver closed the stream (zap on a busy tuner, network hiccup): reconnect with back-off,
    /// appending to the same buffer so already buffered content stays watchable.
    private func sourceEnded(generation gen: Int) {
        guard gen == generation, buffer != nil else { return }
        conn2?.stop()
        conn2 = nil
        reconnectAttempts += 1
        guard reconnectAttempts <= TimeShiftRecorder.maxReconnectAttempts else {
            print("Timeshift: source lost, giving up")
            delegate?.timeshiftFailed()
            return
        }
        let delay = min(Double(reconnectAttempts) * 1.5, 10)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.generation == gen, self.buffer != nil, self.conn2 == nil else { return }
            self.connect()
        }
    }

    /// Local URL for VLC starting at wall-clock `time` (nil = live) and the time playback really starts at.
    func playbackURL(at time: TimeInterval?) -> (url: URL, start: TimeInterval)? {
        guard let buffer = buffer, let port = TimeshiftServer.shared.port else { return nil }
        let target = time ?? ((buffer.window?.end ?? Date().timeIntervalSince1970) - TimeShiftRecorder.liveDelay)
        let position = buffer.playbackPosition(for: target)
        guard let url = URL(string: "http://127.0.0.1:\(port)/ts?g=\(buffer.generation)&o=\(position.offset)") else { return nil }
        return (url, position.time)
    }

    /// EPG of the recorded service; reloaded when the buffered time runs past the known events.
    func reloadEvents() {
        guard !loadingEvents, let service = service, let sref = service.servicereference else { return }
        loadingEvents = true
        let from = Int64(timestart ?? Date().timeIntervalSince1970) - 4 * 60 * 60
        let to = Int64(Date().timeIntervalSince1970) + 6 * 60 * 60
        DataProvider.def().getEpgForService(sref: sref, begin: max(from, 0), end: to){ [weak self] events in
            guard let self = self else { return }
            self.loadingEvents = false
            guard self.service === service else { return }
            self.events = events
        }
    }

    /// Disk budget: at most 4 GB and at most half of the free space (min. 256 MB).
    static func byteBudget() -> Int64 {
        let maxBytes: Int64 = 4 * 1024 * 1024 * 1024
        let minBytes: Int64 = 256 * 1024 * 1024
        guard let values = try? FileManager.default.temporaryDirectory.resourceValues(forKeys: [.volumeAvailableCapacityKey]),
              let available = values.volumeAvailableCapacity else { return minBytes * 4 }
        return max(minBytes, min(maxBytes, Int64(available) / 2))
    }

}
