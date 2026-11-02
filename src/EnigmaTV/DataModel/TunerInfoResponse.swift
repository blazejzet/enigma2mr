//
//  Service.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 15.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import Foundation
import SWXMLHash
class TunerInfoResponse:NSObject, Translateable{
    var info:TunerInfo?
    
    static var translation: [String : String] = [
        "info" :"/e2abouts"
    ]
    
    required override init(){
        
    }
    
    required init(xml:XMLIndexer){
        // Any web server answers /web/about with something – only an <e2abouts><e2about> document is a receiver.
        if xml["e2abouts"]["e2about"].element != nil {
            self.info = TunerInfo(xml:xml["e2abouts"])
        }
    }
}
