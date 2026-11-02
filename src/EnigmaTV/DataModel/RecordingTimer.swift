//
//  RecordingTimer.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 17.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import Foundation
import SWXMLHash

class RecordingTimer:NSObject, Translateable {
    var begin:UInt64?
    var end:UInt64?
    /// EPG event id; null for manual timers.
    var eit:Int?
    var serviceref:String?
    var servicename:String?
    var name:String?
    /// Formatted start ("dd.mm.yyyy HH:MM" in the JSON API).
    var realbegin:String?
    var descriptionextended:String?
    /// 0 waiting, 1 prepared, 2 running, 3 ended.
    var state:Int?
    var duration:Int?

    static var translation: [String : String] = [:]

    required override init(){

    }

    required init(xml:XMLIndexer){
        func text(_ key: String) -> String? { return xml[key].element?.text }
        self.begin = text("e2timebegin").flatMap { UInt64($0) }
        self.end = text("e2timeend").flatMap { UInt64($0) }
        self.eit = text("e2eit").flatMap { Int($0) }
        self.serviceref = text("e2servicereference")
        self.servicename = text("e2servicename")
        self.name = text("e2name")
        if let prepare = text("e2startprepare").flatMap({ Double($0) }) {
            self.realbegin = "\(Date(timeIntervalSince1970: prepare))"
        }
        self.descriptionextended = text("e2descriptionextended")
        self.state = text("e2state").flatMap { Int($0) }
        self.duration = text("e2duration").flatMap { Int($0) }
    }
}


class TimerList:NSObject, Translateable{
    var timers:[RecordingTimer]?

    static var translation: [String : String] = [:]

    required override init(){

    }

    required init(xml:XMLIndexer){
        self.timers = xml["e2timerlist"].children.map { RecordingTimer(xml: $0) }
    }
}

/// `{"result": bool, "message": "..."}` / `<e2simplexmlresult>`.
class Message:NSObject,  Translateable{
    var result:Bool?
    var message:String?

    static var translation: [String : String] = [:]

    required override init(){

    }

    required init(xml:XMLIndexer){
        let root = xml["e2simplexmlresult"]
        self.result = root["e2state"].element.flatMap { Bool($0.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) }
        self.message = root["e2statetext"].element?.text
    }
}
