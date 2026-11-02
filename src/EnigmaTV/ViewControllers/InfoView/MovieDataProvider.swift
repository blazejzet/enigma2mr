//
//  EventDataProvider.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 25.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit

class MovieDataProvider: InfoViewDataProviderDelegate {
    
    weak var mp : VLCMediaPlayer?
    var movie:Movie?
    
    public func refresh(){
        
        // position zmienia się?... zostaje stałe przy pauzie, mimo, że zmienia się czas nagrania... aha... to trzeba obejść jakoś...
        
        
    }
    
    func getServiceName() -> String {
        return movie?.servicename ?? ""
    }
    /// Recording length in seconds.
    func getRecordingTimeX(movie:Movie)->Int{
        return movie.lengthSeconds
    }
    func getCurrentEvent() -> EpgEvent? {
       
        return nil// movie.getEvent()
    }
    
    func getNextEvent() -> EpgEvent? {
        //self.refresh()
        return nil
    }
    
    func getCurrentTime() -> UInt64 {
        //self.refresh()
        //czas aktualnego oglądania...
        guard let movie = movie, let mp = mp else { return 0 }
        return UInt64(max(0, mp.position) * Float(getRecordingTimeX(movie: movie)))
    }
    
    func getRealTime() -> UInt64 {
        //self.refresh()
        return UInt64(Date().timeIntervalSince1970)
    }
    
    func getTimeshiftStartTime() -> UInt64 {
        //self.refresh()
        return 0
    }
    
    func getTimeshiftStopTime() -> UInt64 {
        //self.refresh()
        guard let movie = movie else { return 0 }
        return UInt64(getRecordingTimeX(movie: movie))
    }
    
    func shouldDisplayTimeshiftInfo() -> Bool {
        //self.refresh()
        return true
    }
    
    func jumpTo(_ time:UInt64){
        guard let movie = movie, mp != nil else { return }
        let duration = UInt64(getRecordingTimeX(movie: movie))
        guard duration > 0 else { return }
        let new_mptime = time
        
        var procent = Float(new_mptime) / Float(duration)
        
        if procent>0.98{
            procent = 0.98
        }
        if procent<0.001{
            procent = 0.001
        }
        
        mp?.position=procent
        
        
        
    }
    
}


