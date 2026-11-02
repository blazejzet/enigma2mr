//
//  StreamView.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 15.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit

import Pods_EnigmaTV
import CloudKit
import AVFoundation
import CoreFoundation
import MediaPlayer

class StreamView: UIView, VLCMediaPlayerDelegate, TimeShiftRecorderDelegate {

    static let pipFrame = CGRect(x: 60, y: 60, width: 480, height: 270)

    var url:URL?
    var nexturl:URL?
    var v1:UIView!
    var v2:UIView!

    /// (drawable, player) of the full-screen player and of the PiP / pre-buffer player.
    /// They are swapped when a prepared PiP stream is promoted to full screen.
    var first : (UIView,VLCMediaPlayer)!
    var second : (UIView,VLCMediaPlayer)!

    /// The player currently shown full screen. Always follows `first`, also after a PiP swap.
    var mp: VLCMediaPlayer! { return first?.1 }

    // Live-stream reconnect state.
    private static let maxReconnectAttempts = 5
    private var reconnectAttempts = 0
    private var userStopped = false

    /// Direct receiver URL of the current live service (fallback when timeshift fails).
    private var liveURL: URL?

    // MARK: Timeshift state
    /// true while the main player plays from the local timeshift buffer.
    private(set) var timeshift = false
    /// Short user feedback ("LIVE", "−02:15", "Paused") – shown by ViewController.
    var onTimeshiftStatus: ((String) -> Void)?
    /// true from starting a stream until VLC shows a picture (or gives up) – drives the loading spinner.
    var onLoading: ((Bool) -> Void)?
    /// Wall-clock time of the first byte of the currently opened buffer URL.
    private var tsAnchorTime: TimeInterval = 0
    /// Opened before the first byte arrived: tsAnchorTime is just "now" and is corrected on .playing.
    private var tsAnchorProvisional = false
    /// VLC time (ms) when that first byte started playing.
    private var tsVlcStart: Int32?
    /// Position at which the user paused.
    private var tsPausedAt: TimeInterval?
    /// Invalidates pending timeshift starts when the channel changes.
    private var tsGeneration = 0
    /// VLC reported "paused" (its `state` property flips to buffering afterwards, so remember the event).
    private var vlcPaused = false

    func mediaPlayerStateChanged(_ aNotification: Notification) {
        guard let player = aNotification.object as? VLCMediaPlayer, player === first.1 else { return }
        if player.state != .buffering {   // VLC reports buffering progress many times a second
            print("[STATE] \(VLCMediaPlayerStateToString(player.state) as String) \(player.media?.url?.absoluteString ?? "-")")
        }

        switch player.state {
        case .paused:
            vlcPaused = true
        case .opening, .stopped, .ended, .error:
            vlcPaused = false
        default:
            break
        }

        switch player.state {
        case .playing:
            vlcPaused = false
            reconnectAttempts = 0
            onLoading?(false)
            if let position = changeToPosition {
                changeToPosition = nil
                player.position = position
            }
            if timeshift && tsVlcStart == nil {
                tsVlcStart = player.time.intValue
                // Playback started at the first buffered byte – use when it really arrived.
                if tsAnchorProvisional, let start = TimeShiftRecorder.common().window?.start {
                    tsAnchorTime = start
                    tsAnchorProvisional = false
                }
            }
        case .error, .ended:
            scheduleReconnectIfNeeded()
        default:
            break
        }
    }

    /// A live TS stream should never "end"; when it does (network hiccup, receiver re-tuning after zap)
    /// reopen it with a short back-off. With timeshift, reopen the buffer where playback was.
    private func scheduleReconnectIfNeeded() {
        guard mode == .service, !userStopped, let media = first.1.media,
              reconnectAttempts < StreamView.maxReconnectAttempts else {
            onLoading?(false)
            return
        }
        reconnectAttempts += 1
        let delay = Double(reconnectAttempts) * 1.5
        print("[STATE] reconnect #\(reconnectAttempts) in \(delay)s")
        let player = first.1
        let resumeAt = timeshift ? timeshiftPlaybackTime : nil
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, !self.userStopped, self.first.1 === player, player.media === media else { return }
            if self.timeshift {
                if !self.openTimeshift(at: resumeAt) {
                    self.timeshiftFailed()
                }
            } else if let url = media.url {
                player.media = StreamView.makeMedia(url: url)
                player.play()
            }
        }
    }

    static func makeMedia(url: URL) -> VLCMedia {
        let media = VLCMedia(url: url)
        if url.host == "127.0.0.1" {
            // Timeshift buffer on the loopback interface – little caching needed.
            media.addOption(":network-caching=500")
        }
        // Tuning for receiver streams goes here once tested with a real receiver
        // (e.g. ":network-caching=1500").
        return media
    }

    var timer:Timer?
    var timerVA:Timer?
    var cdelay = 0
    init() {
        super.init(frame:CGRect(x: 0, y: 0, width: 1920 , height: 1080));
        v1 = VideoDrawableView(frame: self.frame)
        v2 = VideoDrawableView(frame: StreamView.pipFrame)
        self.addSubview(v1)
        self.addSubview(v2)

        let main = VLCMediaPlayer()
        main.drawable = v1
        main.delegate = self
        let pip = VLCMediaPlayer()
        pip.drawable = v2

        first = (v1!,main)
        second = (v2!,pip)
    }

    func getLastService(cb:@escaping (Service?,Service?)->Void){
        getLastStream(cb: cb)
    }

    func stop(){
        userStopped = true
        stopTimeshift()
        // iOS reclaims listening sockets of suspended apps – restart the server on next use.
        TimeshiftServer.shared.shutdown()
        print("Stopping stream")
        onLoading?(false)
        first.1.stop()
        first.1.media = nil
        hidePip()
    }

    /// Position (0...1) to seek to once the next movie starts playing ("continue watching").
    var changeToPosition:Float?

    /// Paused by the user (timeshift pause or a paused recording / live stream).
    var isPaused: Bool {
        if timeshift { return tsPausedAt != nil }
        return first.1.media != nil && !first.1.isPlaying
    }

    // MARK: - Play / pause

    func stTogglePause(){
        if timeshift {
            toggleTimeshiftPause()
            return
        }
        if (first.1.isPlaying){
            self.stpause()
        }else{
            self.stplay()
        }
    }
    func stpause(){
        first.1.pause()
    }
    func stplay()
    {
        first.1.play()
    }

    func playLiveStream(){
        guard let url = url else { return }
        userStopped = false
        reconnectAttempts = 0
        if (second.1.media?.url == url){
            // The stream was already pre-buffered in the PiP player – promote it.
            (first,second)=(second,first)
            first.1.delegate = self
            second.1.delegate = nil
            first.1.audio?.volume = 100
            second.1.audio?.volume = 0

            UIView.animate(withDuration: 0.3){
                self.first.0.frame = self.frame
                self.second.0.frame = StreamView.pipFrame
            }
            self.insertSubview(self.second.0, aboveSubview: self.first.0)

            // Forget the old stream, otherwise switching back to it would "promote" this stopped player.
            second.1.stop()
            second.1.media = nil
            onLoading?(!first.1.isPlaying)

        }else{
            first.1.media = StreamView.makeMedia(url: url)
            first.1.drawable = first.0
            first.1.play();
        }

    }

    var mode = viewingMode.service

    func prepare(_ service:Service, inBouquet bouquet:Service){
        guard let next = STBAPI.common()?.streamURL(for: service) else { return }
        nexturl = next
        self.prepareLiveStream()
    }

    func play(_ service:Service, inBouquet bouquet:Service){
        guard let api = STBAPI.common(), let streamURL = api.streamURL(for: service) else {
            print("No stream URL for \(service.servicereference ?? "?")")
            return
        }
        mode = viewingMode.service
        userStopped = false
        changeToPosition = nil
        onLoading?(true)
        self.saveLast(service: service, bouquet: bouquet)

        if api.zap {
            api.zap(for: service)
        }
        liveURL = streamURL
        self.isUserInteractionEnabled = true

        // The recorder buffers one MPEG-TS stream from the receiver; IPTV sources (often HLS playlists) play directly.
        guard api.timeshift, service.reference?.iptvURL == nil else {
            stopTimeshift()
            url = streamURL
            playLiveStream()
            return
        }

        // Timeshift: the recorder is the only connection to the receiver; VLC plays its buffer.
        stopTimeshift()
        if second.1.media?.url == streamURL {
            hidePip()
        }
        first.1.stop()
        let gen = tsGeneration
        let recorder = TimeShiftRecorder.common()
        recorder.delegate = self
        recorder.startTimeShift(for: streamURL, service: service, inBouquet: bouquet) { [weak self] ok in
            guard let self = self, gen == self.tsGeneration, !self.userStopped else { return }
            if !ok || !self.openTimeshift(at: nil) {
                print("Timeshift unavailable – playing live directly")
                self.timeshiftFailed()
            }
        }
    }

    func skipto(p:Float){
        self.first.1.position=p
    }

    func play(_ movie:Movie){
        guard let urlb = STBAPI.common()?.recordingURL(for: movie) else {
            print("No recording URL for \(movie.serviceref ?? "?")")
            return
        }
        stopTimeshift()
        mode = .movie
        onLoading?(true)

        if let serviceref = movie.serviceref, let privateCloudDatabase = CloudSync.database {
            let movieInfo = CKRecord(recordType: "MovieInfo", recordID: CKRecord.ID(recordName: serviceref))
            movieInfo["ind"] = NSNumber(integerLiteral: 0)
            movieInfo["watched"] = NSNumber(integerLiteral: 0)
            privateCloudDatabase.save(movieInfo, completionHandler: {ckrek,_ in
                print(ckrek as Any)
            })
        }

        url = urlb
        self.isUserInteractionEnabled = true
        self.playLiveStream()
    }

    // MARK: - Timeshift

    /// Wall-clock time of the picture currently shown (== now - delay).
    var timeshiftPlaybackTime: TimeInterval {
        let now = Date().timeIntervalSince1970
        guard timeshift else { return now }
        if let paused = tsPausedAt { return paused }
        guard let start = tsVlcStart else { return tsAnchorTime }
        let elapsed = Double(max(0, Int(first.1.time.intValue) - Int(start))) / 1000
        let end = TimeShiftRecorder.common().window?.end ?? now
        return min(tsAnchorTime + elapsed, end)
    }

    /// Seconds behind live (0 when not timeshifting).
    var timeshiftDelay: TimeInterval {
        guard timeshift else { return 0 }
        let end = TimeShiftRecorder.common().window?.end ?? Date().timeIntervalSince1970
        return max(0, end - timeshiftPlaybackTime)
    }

    /// Opens the buffer at wall-clock `time` (nil = live edge).
    @discardableResult
    private func openTimeshift(at time: TimeInterval?) -> Bool {
        let empty = TimeShiftRecorder.common().window == nil
        guard let position = TimeShiftRecorder.common().playbackURL(at: time) else { return false }
        tsAnchorProvisional = empty
        timeshift = true
        mode = .service
        userStopped = false
        tsPausedAt = nil
        tsVlcStart = nil
        tsAnchorTime = position.start
        first.1.media = StreamView.makeMedia(url: position.url)
        first.1.drawable = first.0
        first.1.play()
        return true
    }

    /// Jump to a wall-clock time inside the buffer; times at/after the live edge go live.
    func seekTimeshift(to time: TimeInterval) {
        guard timeshift, let window = TimeShiftRecorder.common().window else { return }
        let liveEdge = window.end - TimeShiftRecorder.liveDelay
        if time >= liveEdge - 2 {
            goLive()
            return
        }
        openTimeshift(at: max(time, window.start))
        announceTimeshift()
    }

    /// Relative jump, e.g. -30 / +30 seconds.
    func seekTimeshift(by seconds: TimeInterval) {
        seekTimeshift(to: timeshiftPlaybackTime + seconds)
    }

    func goLive() {
        guard timeshift else { return }
        openTimeshift(at: nil)
        onTimeshiftStatus?(L("LIVE"))
    }

    private func toggleTimeshiftPause() {
        if let pausedAt = tsPausedAt {
            let window = TimeShiftRecorder.common().window
            if let window = window, pausedAt < window.start + 2 {
                // Paused longer than the buffer holds – continue from the oldest available moment.
                openTimeshift(at: window.start + 2)
            } else if vlcPaused {
                // The loopback connection was held open (TCP back-pressure) – just continue.
                tsPausedAt = nil
                first.1.play()
            } else {
                // VLC stopped the input instead of pausing – reopen where we were.
                openTimeshift(at: pausedAt)
            }
            announceTimeshift()
        } else {
            let position = timeshiftPlaybackTime
            first.1.pause()
            tsPausedAt = position
            onTimeshiftStatus?(L("Paused"))
        }
    }

    private func announceTimeshift() {
        let delay = timeshiftDelay
        if delay < TimeShiftRecorder.liveDelay + 5 {
            onTimeshiftStatus?(L("LIVE"))
            return
        }
        let total = Int(delay)
        let text = total >= 3600
            ? String(format: "−%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
            : String(format: "−%02d:%02d", total / 60, total % 60)
        onTimeshiftStatus?(text)
    }

    private func stopTimeshift() {
        tsGeneration += 1
        timeshift = false
        tsPausedAt = nil
        tsVlcStart = nil
        TimeShiftRecorder.common().stop()
    }

    /// Recorder gave up (receiver unreachable, disk full) – watch the receiver stream directly.
    func timeshiftFailed() {
        guard !userStopped, mode == .service, let liveURL = liveURL else { return }
        stopTimeshift()
        url = liveURL
        playLiveStream()
        onTimeshiftStatus?(L("Timeshift unavailable"))
    }

    // MARK: - PiP

    func prepareLiveStream(){
        guard let nexturl = nexturl else { return }
        second.0.frame = StreamView.pipFrame   // hidePip() collapsed it
        second.1.media = StreamView.makeMedia(url: nexturl)
        second.1.play();
        second.1.audio?.volume = 0
    }

    func hidePip(){
        second.1.stop();
        second.1.media = nil
        second.0.frame = .zero
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder);
    }


    private func saveLast(service:Service, bouquet:Service){
        guard let sref = service.servicereference, let bref = bouquet.servicereference else { return }
        UserDefaults.standard.set(sref, forKey: "lastService");
        UserDefaults.standard.set(bref, forKey: "lastBouquet");
    }

    /// Resolves the last watched (service, bouquet) pair from the receiver.
    private func getLastStream(cb:@escaping (Service?,Service?)->Void){
        guard let bref = UserDefaults.standard.string(forKey: "lastBouquet"),
              let sref = UserDefaults.standard.string(forKey: "lastService") else {
            cb(nil,nil)
            return
        }
        DataProvider.def().getBouquet(bref: bref){ bouquet in
            guard let bouquet = bouquet else {
                cb(nil,nil)
                return
            }
            DataProvider.def().getService(bref: bref, sref: sref){ service in
                cb(service, service == nil ? nil : bouquet)
            }
        }
    }

}


enum viewingMode{
    case movie,service
}


/// "Continue watching" positions in the user's private iCloud database. nil when the build has no
/// iCloud entitlement (CKContainer would raise an exception) – the feature is then simply off.
enum CloudSync {
    static let database: CKDatabase? = {
        guard hasICloudEntitlement else {
            print("CloudKit off: this build has no iCloud entitlement")
            return nil
        }
        return EnigmaDefaultCloudContainer()?.privateCloudDatabase
    }()

    /// CloudKit raises an uncatchable exception (inside dispatch_once) without the entitlement, so
    /// look for it in the signed executable (entitlements are embedded in the code signature).
    private static var hasICloudEntitlement: Bool {
        guard let url = Bundle.main.executableURL,
              let binary = try? Data(contentsOf: url, options: .alwaysMapped) else { return false }
        return binary.range(of: Data("com.apple.developer.icloud-services".utf8)) != nil
    }
}


/// tvOS "Now Playing": programme / recording info for Control Center, the Apple TV Remote on iPhone and Siri,
/// and their play/pause/skip commands.
final class NowPlaying {
    private weak var sv: StreamView?
    private var service: Service?
    private var bouquet: Service?
    private var movie: Movie?
    /// Last state written for the other Apple TVs, and when.
    private var sharedSession: WatchSession?
    private var event: EpgEvent?
    private var events = [EpgEvent]()
    private var artwork: UIImage?
    private var timer: Timer?
    /// Invalidates EPG / artwork answers that belong to a previous channel or recording.
    private var generation = 0
    /// The Siri Remote's play/pause button may arrive both as a press and as a remote command.
    private var lastLocalToggle = Date.distantPast
    private static let skipInterval = 15.0

    init(streamView: StreamView) {
        sv = streamView
        let commands = MPRemoteCommandCenter.shared()
        commands.togglePlayPauseCommand.addTarget { [weak self] _ in self?.togglePause() ?? .commandFailed }
        commands.playCommand.addTarget { [weak self] _ in self?.setPaused(false) ?? .commandFailed }
        commands.pauseCommand.addTarget { [weak self] _ in self?.setPaused(true) ?? .commandFailed }
        commands.skipForwardCommand.preferredIntervals = [NSNumber(value: NowPlaying.skipInterval)]
        commands.skipBackwardCommand.preferredIntervals = [NSNumber(value: NowPlaying.skipInterval)]
        commands.skipForwardCommand.addTarget { [weak self] event in
            self?.skip(by: (event as? MPSkipIntervalCommandEvent)?.interval ?? NowPlaying.skipInterval) ?? .commandFailed
        }
        commands.skipBackwardCommand.addTarget { [weak self] event in
            self?.skip(by: -((event as? MPSkipIntervalCommandEvent)?.interval ?? NowPlaying.skipInterval)) ?? .commandFailed
        }
        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            return self?.seek(to: event.positionTime) ?? .commandFailed
        }
    }

    /// The programme on screen (live / timeshift), if the EPG has it.
    var currentProgramme: EpgEvent? { return event }

    // MARK: What is playing

    func watching(_ service: Service, in bouquet: Service?) {
        reset()
        self.service = service
        self.bouquet = bouquet
        loadEvents()
        loadArtwork()
        publish()
    }

    func watching(_ movie: Movie) {
        reset()
        self.movie = movie
        loadArtwork()
        publish()
    }

    func stop() {
        shareSession()   // last recording position
        reset()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        RoomSync.markStopped()
    }

    /// The play/pause press was handled by the player screen itself.
    func noteLocalToggle() {
        lastLocalToggle = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.publish() }
    }

    private func reset() {
        generation += 1
        service = nil
        bouquet = nil
        movie = nil
        event = nil
        events = []
        artwork = nil
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in self?.tick() }
    }

    /// Follows the picture on screen (also when timeshift lags behind live) into the next programme.
    private func tick() {
        guard service != nil || movie != nil else { return }
        if service != nil {
            let shown = currentEvent()
            if shown !== event {
                event = shown
                artwork = nil
                loadArtwork()
            }
            if shown == nil && !events.isEmpty { loadEvents() }
        }
        publish()
    }

    private var playbackTime: TimeInterval {
        return sv?.timeshiftPlaybackTime ?? Date().timeIntervalSince1970
    }

    private func currentEvent() -> EpgEvent? {
        let t = UInt64(playbackTime)
        return events.first { e in
            guard e.hasData, let b = e.begin_timestamp, let d = e.duration_sec else { return false }
            return b <= t && t < b + d
        }
    }

    private func loadEvents() {
        guard let sref = service?.servicereference else { return }
        let gen = generation
        let now = Int64(Date().timeIntervalSince1970)
        // From 4 h back: the timeshift buffer can show an earlier programme.
        DataProvider.def().getEpgForService(sref: sref, begin: now - 4 * 60 * 60, end: now + 6 * 60 * 60) { [weak self] events in
            guard let self = self, gen == self.generation else { return }
            self.events = events
            self.event = self.currentEvent()
            self.loadArtwork()
            self.publish()
        }
    }

    /// Programme artwork from TMDB when known, else the channel logo.
    private func loadArtwork() {
        let gen = generation
        let apply: (UIImage?) -> Void = { [weak self] image in
            DispatchQueue.main.async {
                guard let self = self, gen == self.generation, let image = image else { return }
                self.artwork = image
                self.publish()
            }
        }
        let title = movie?.eventname ?? event?.title
        let minutes = movie.map { $0.lengthSeconds / 60 } ?? event?.durationMinutes ?? 0
        let logo = { [weak self] in
            guard let service = self?.service else { return }
            UIImageView.loadChannelLogo(for: service, completion: apply)
        }
        guard let name = title, !name.isEmpty, let api = STBAPI.common() else { return logo() }
        api.searchInfoWeb(title: name, duration: minutes, eid: Int(event?.begin_timestamp ?? 0)) { image, backdrop, _, ok in
            if ok, let art = backdrop ?? image { apply(art) } else { DispatchQueue.main.async(execute: logo) }
        }
    }

    private func publish() {
        guard let sv = sv, service != nil || movie != nil else { return }
        var info = [String: Any]()
        if let movie = movie {
            info[MPMediaItemPropertyTitle] = movie.eventname ?? ""
            if let channel = movie.servicename { info[MPMediaItemPropertyArtist] = channel }
            if movie.lengthSeconds > 0 { info[MPMediaItemPropertyPlaybackDuration] = Double(movie.lengthSeconds) }
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(sv.mp.time.intValue) / 1000
        } else if let service = service {
            let channel = service.displayName ?? ""
            if let event = event, let begin = event.begin_timestamp, let duration = event.duration_sec, duration > 0 {
                info[MPMediaItemPropertyTitle] = event.title ?? channel
                info[MPMediaItemPropertyArtist] = channel
                info[MPMediaItemPropertyPlaybackDuration] = Double(duration)
                info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = max(0, playbackTime - Double(begin))
            } else {
                info[MPMediaItemPropertyTitle] = channel
            }
            info[MPNowPlayingInfoPropertyIsLiveStream] = sv.timeshiftDelay < 5
        }
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.video.rawValue
        info[MPNowPlayingInfoPropertyPlaybackRate] = sv.isPaused ? 0.0 : 1.0
        if let artwork = artwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        shareSession()

        let commands = MPRemoteCommandCenter.shared()
        let seekable = movie != nil || sv.timeshift
        commands.skipForwardCommand.isEnabled = seekable
        commands.skipBackwardCommand.isEnabled = seekable
        commands.changePlaybackPositionCommand.isEnabled = movie != nil
    }

    /// Tells the other Apple TVs what plays here. Written on changes, and once a minute for a recording's position.
    private func shareSession() {
        guard let sv = sv, let receiver = ReceiverStore.active else { return }
        var session: WatchSession
        if let movie = movie, let sref = movie.serviceref {
            // While a resume seek is pending, the target is the real position.
            let position = Double(sv.changeToPosition ?? sv.mp.position)
            session = WatchSession(device: RoomSync.deviceID, room: RoomSync.roomName, receiverAddress: receiver.address,
                                   receiverName: receiver.name, kind: "recording", sref: sref, bref: nil,
                                   title: movie.eventname ?? "", programme: movie.servicename,
                                   position: position > 0 ? position : sharedSession?.position, updated: 0, active: true)
        } else if let service = service, let sref = service.servicereference {
            session = WatchSession(device: RoomSync.deviceID, room: RoomSync.roomName, receiverAddress: receiver.address,
                                   receiverName: receiver.name, kind: "live", sref: sref, bref: bouquet?.servicereference,
                                   title: service.displayName ?? "", programme: event?.title, position: nil, updated: 0, active: true)
        } else {
            return
        }
        let now = Date().timeIntervalSince1970
        var previous = sharedSession
        previous?.updated = 0
        let changed = previous.map { p -> Bool in
            var a = p, b = session
            a.position = nil
            b.position = nil
            return a != b
        } ?? true
        let positionMoved = abs((session.position ?? 0) - (previous?.position ?? 0)) > 0.005
        guard changed || (positionMoved && now - (sharedSession?.updated ?? 0) > 60) else { return }
        session.updated = now
        sharedSession = session
        RoomSync.publish(session)
    }

    // MARK: Commands

    private func togglePause() -> MPRemoteCommandHandlerStatus {
        guard let sv = sv, service != nil || movie != nil else { return .noActionableNowPlayingItem }
        guard Date().timeIntervalSince(lastLocalToggle) > 0.5 else { return .success }
        sv.stTogglePause()
        noteLocalToggle()
        return .success
    }

    private func setPaused(_ paused: Bool) -> MPRemoteCommandHandlerStatus {
        guard let sv = sv, service != nil || movie != nil else { return .noActionableNowPlayingItem }
        if sv.isPaused != paused { return togglePause() }
        return .success
    }

    private func skip(by seconds: TimeInterval) -> MPRemoteCommandHandlerStatus {
        guard let sv = sv else { return .commandFailed }
        if sv.timeshift {
            sv.seekTimeshift(by: seconds)
        } else if movie != nil {
            let step = Int32(abs(seconds))
            if seconds > 0 { sv.mp.jumpForward(step) } else { sv.mp.jumpBackward(step) }
        } else {
            return .commandFailed
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.publish() }
        return .success
    }

    private func seek(to position: TimeInterval) -> MPRemoteCommandHandlerStatus {
        guard let sv = sv, movie != nil else { return .commandFailed }
        sv.mp.time = VLCTime(int: Int32(position * 1000))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.publish() }
        return .success
    }
}

// MARK: - Multi room

/// What one Apple TV watches, shared with the user's other Apple TVs through iCloud key-value storage.
struct WatchSession: Codable, Equatable {
    var device: String
    var room: String
    var receiverAddress: String
    var receiverName: String
    /// "live" or "recording".
    var kind: String
    /// Service reference of the channel, or of the recording.
    var sref: String
    var bref: String?
    var title: String
    var programme: String?
    /// Recordings: how far it was watched (0...1).
    var position: Double?
    var updated: TimeInterval
    /// false once this Apple TV stopped (went to sleep, app closed).
    var active: Bool
}

/// Sessions of all Apple TVs on the iCloud account. Each device writes only its own key.
enum RoomSync {
    private static let prefix = "room."
    private static var store: NSUbiquitousKeyValueStore { return NSUbiquitousKeyValueStore.default }
    static let changed = NSNotification.Name("RoomSync.changed")
    private static var observing = false

    static var deviceID: String {
        if let id = UserDefaults.standard.string(forKey: "deviceID") { return id }
        let id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(id, forKey: "deviceID")
        return id
    }

    /// Shown to the other Apple TVs ("Living room"). Editable in Settings.
    static var roomName: String {
        get {
            let name = UserDefaults.standard.string(forKey: "roomName")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return name.isEmpty ? UIDevice.current.name : name
        }
        set { UserDefaults.standard.set(newValue, forKey: "roomName") }
    }

    static func start() {
        guard !observing else { return }
        observing = true
        NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                               object: store, queue: .main) { _ in
            NotificationCenter.default.post(name: changed, object: nil)
        }
        store.synchronize()
    }

    static var mine: WatchSession? { return session(forKey: prefix + deviceID) }

    /// The other Apple TVs, most recent first; sessions older than two days are dropped.
    static var others: [WatchSession] {
        let cutoff = Date().timeIntervalSince1970 - 2 * 24 * 60 * 60
        return store.dictionaryRepresentation.keys
            .filter { $0.hasPrefix(prefix) && $0 != prefix + deviceID }
            .compactMap(session(forKey:))
            .filter { $0.updated > cutoff }
            .sorted { $0.updated > $1.updated }
    }

    private static func session(forKey key: String) -> WatchSession? {
        guard let data = store.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WatchSession.self, from: data)
    }

    static func publish(_ session: WatchSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        store.set(data, forKey: prefix + deviceID)
        store.synchronize()
    }

    static func markStopped() {
        guard var session = mine, session.active else { return }
        session.active = false
        session.updated = Date().timeIntervalSince1970
        publish(session)
    }
}
