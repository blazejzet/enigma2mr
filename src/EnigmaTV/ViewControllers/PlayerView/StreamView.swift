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
              reconnectAttempts < StreamView.maxReconnectAttempts else { return }
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
        first.1.stop()
        first.1.media = nil
        hidePip()
    }

    /// Position (0...1) to seek to once the next movie starts playing ("continue watching").
    var changeToPosition:Float?

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
        onTimeshiftStatus?("LIVE")
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
            onTimeshiftStatus?("Paused")
        }
    }

    private func announceTimeshift() {
        let delay = timeshiftDelay
        if delay < TimeShiftRecorder.liveDelay + 5 {
            onTimeshiftStatus?("LIVE")
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
        onTimeshiftStatus?("Timeshift unavailable")
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
