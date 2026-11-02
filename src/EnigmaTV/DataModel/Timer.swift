//
//  Timer.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 17.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit
import SWXMLHash

class RecordingTimer:NSObject, Translateable {
    var begin:UInt64?
    var end:UInt64?
    var eit:Int?
    var serviceref:String?
    var servicename:String?
    var name:String?
    var realbegin:String?
    var descriptionextended:String?
    var state:Int?
    var duration:Int?
    
    static var translation: [String : String] = [:]
    
    required override init(){
        
    }
    
    required init(xml:XMLIndexer){
        print("--\n");
        print("--\n");
        print(xml);
        print("--\n");
        
        self.begin = UInt64(xml["e2timebegin"].element!.text)
         self.end = UInt64(xml["e2timeend"].element!.text)
         self.eit = Int(xml["e2eit"].element!.text)
        self.serviceref = xml["e2servicereference"].element!.text
        self.servicename = xml["e2servicename"].element!.text
        self.name = xml["e2name"].element!.text
        let d = Date(timeIntervalSince1970: TimeInterval(Int(Double(xml["e2startprepare"].element!.text)!)))
        
        self.realbegin = "\(d)"
        self.descriptionextended = xml["e2descriptionextended"].element!.text
        self.state = Int(xml["e2state"].element!.text)
        self.duration = Int(xml["e2duration"].element!.text)
    }
}


class TimerList:NSObject, Translateable{
    var timers:[Timer]?
    
    static var translation: [String : String] = [:]
    
    required override init(){
        
    }
    
    required init(xml:XMLIndexer){
        self.timers = [Timer]()
        for xml in xml["e2timerlist"].children{
            timers?.append(Timer(xml: xml))
        }
    }
}

class Message:NSObject,  Translateable{
    var result:Bool?
    var message:String?
    
    static var translation: [String : String] = [:]
    
    required override init(){
        
    }
    
    required init(xml:XMLIndexer){
        self.result = Bool(xml["e2simplexmlresult"]["e2state"].element!.text.lowercased())
        self.message = xml["e2simplexmlresult"]["e2statetext"].element!.text
    }
}
