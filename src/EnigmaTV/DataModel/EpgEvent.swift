//
//  Event.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 15.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import Foundation
import SWXMLHash

class EpgEvent:NSObject ,Translateable{
    var id:Int?
    var begin_timestamp:UInt64?
    var duration_sec:UInt64?
    /// Receiver time of the response. `/api/epgservice` always sends 0 here.
    var now_timestamp:UInt64?
    var remaining:UInt64?
    var title:String?
    var shortdesc:String?
    var longdesc:String?
    var sref:String?
    var sname:String?
    var end_timestamp:UInt64?{
        (begin_timestamp ?? 0) + (duration_sec ?? 0)
    }

    var timer:RecordingTimer? //MOJE

    private static let timeFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.setLocalizedDateFormatFromTemplate("HH:mm")
        return dateFormatter
    }()

    /// false for the placeholder OpenWebif returns when the receiver has no EPG ("N/A", no times).
    var hasData: Bool {
        guard let title = title?.trimmingCharacters(in: .whitespaces), !title.isEmpty, title != "N/A" else { return false }
        return (begin_timestamp ?? 0) > 0
    }

    func getBeginTimeString()->String{
        guard let ts = self.begin_timestamp else {return "?"}
        return EpgEvent.timeFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }

    var durationMinutes: Int {
        return Int((duration_sec ?? 0) / 60)
    }

    static var translation: [String : String] = [:]

    override init() {

    }

    /// 0...1, based on the receiver's time when known, otherwise on the local clock.
    func getProgress()->Float{
        guard let b = begin_timestamp, let d = duration_sec, d > 0 else { return 0 }
        let n = (now_timestamp ?? 0) > 0 ? now_timestamp! : UInt64(Date().timeIntervalSince1970)
        guard n > b else { return 0 }
        return min(1, Float(n - b) / Float(d))
    }


    required init(xml:XMLIndexer){
        self.id = xml["e2eventid"].element.flatMap { Int($0.text) }
        self.begin_timestamp = xml["e2eventstart"].element.flatMap { UInt64($0.text) }
        self.duration_sec = xml["e2eventduration"].element.flatMap { UInt64($0.text) }
        self.now_timestamp = xml["e2eventcurrenttime"].element.flatMap { UInt64($0.text) }
        if let now = now_timestamp, let begin = begin_timestamp, let duration = duration_sec {
            if now > begin {
                self.remaining = now - begin < duration ? duration - (now - begin) : 0
            } else {
                self.remaining = duration
            }
        }
        self.title = xml["e2eventtitle"].element?.text
        self.shortdesc = xml["e2eventdescription"].element?.text
        self.longdesc = xml["e2eventdescriptionextended"].element?.text
        self.sname = xml["e2eventservicename"].element?.text
        self.sref = xml["e2eventservicereference"].element?.text
    }
}
