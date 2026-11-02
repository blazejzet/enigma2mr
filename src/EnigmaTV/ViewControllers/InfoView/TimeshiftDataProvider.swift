//
//  TimeshiftDataProvider.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 25.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit

/// Info overlay data while watching a live channel through the timeshift buffer.
/// All times are wall-clock unix times; "current" is the moment currently on screen.
class TimeshiftDataProvider: InfoViewDataProviderDelegate {

    weak var sv : StreamView?
    weak var mp : VLCMediaPlayer?
    var ct:UInt64 = UInt64(Date().timeIntervalSince1970)
    var event:EpgEvent?
    var nextevent:EpgEvent?

    private var recorder: TimeShiftRecorder { return TimeShiftRecorder.common() }

    public func refresh(){
        let now = Date().timeIntervalSince1970
        ct = UInt64(sv?.timeshiftPlaybackTime ?? now)
        let events = recorder.events ?? []
        event = events.first { e in
            guard let b = e.begin_timestamp, let d = e.duration_sec else { return false }
            return b <= ct && ct < b + d
        }
        nextevent = events.first { ($0.begin_timestamp ?? 0) > ct }
        if event == nil || nextevent == nil {
            // Buffered past the known EPG (long session) – fetch again for the next refresh.
            recorder.reloadEvents()
        }
    }

    func getServiceName() -> String {
        return event?.sname ?? recorder.service?.servicename ?? ""
    }
    func getCurrentEvent() -> EpgEvent? {
        return event
    }

    func getNextEvent() -> EpgEvent? {
        return nextevent
    }

    func getCurrentTime() -> UInt64 {
        return ct
    }

    func getRealTime() -> UInt64 {
        return UInt64(Date().timeIntervalSince1970)
    }

    /// Oldest moment still in the buffer.
    func getTimeshiftStartTime() -> UInt64 {
        return UInt64(recorder.window?.start ?? Date().timeIntervalSince1970)
    }

    /// Newest moment in the buffer (≈ live).
    func getTimeshiftStopTime() -> UInt64 {
        return UInt64(recorder.window?.end ?? Date().timeIntervalSince1970)
    }

    func shouldDisplayTimeshiftInfo() -> Bool {
        return true
    }

    /// Scrubbing to the right end of the bar returns to live.
    func jumpTo(_ time:UInt64){
        sv?.seekTimeshift(to: TimeInterval(time))
        ct = UInt64(sv?.timeshiftPlaybackTime ?? TimeInterval(time))
    }

}
