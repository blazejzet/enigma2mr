//
//  EventDataProvider.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 25.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit

class EventDataProvider: InfoViewDataProviderDelegate {
    var event:EpgEvent?
    var nextevent:EpgEvent?
    /// Shown when the channel has no EPG.
    var serviceName:String?

    func getServiceName() -> String {
        return event?.sname ?? serviceName ?? ""
    }
    func getCurrentEvent() -> EpgEvent? {
        return event
    }
    
    func getNextEvent() -> EpgEvent? {
        return nextevent
    }
    
    func getCurrentTime() -> UInt64 {
        return UInt64(Date().timeIntervalSince1970)
    }
    
    func getRealTime() -> UInt64 {
        return UInt64(Date().timeIntervalSince1970)
    }
    
    func getTimeshiftStartTime() -> UInt64 {
        if let x = TimeShiftRecorder.common().timestart{
            return UInt64(x)
        }else{
            return UInt64(Date().timeIntervalSince1970)
        }
    }
    
    func getTimeshiftStopTime() -> UInt64 {
        return UInt64(Date().timeIntervalSince1970)
    }
    
    func shouldDisplayTimeshiftInfo() -> Bool {
        return true
    }
    func jumpTo(_ time:UInt64){
        
    }
    

}
