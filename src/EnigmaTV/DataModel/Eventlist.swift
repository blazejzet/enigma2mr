//
//  Eventlist.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 16.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import Foundation
import SWXMLHash

class Eventlist:NSObject,  Translateable {
    
    var events:[EpgEvent]?
    var result:Bool?
    static var translation: [String : String] = [:]
    
    required override init(){
        
    }
    
    required init(xml:XMLIndexer){
        self.events = [EpgEvent]()
        do{
        for xml in xml["e2eventlist"].children{
            events?.append(EpgEvent(xml: xml))
        }
        }catch{}
        
    }
}
