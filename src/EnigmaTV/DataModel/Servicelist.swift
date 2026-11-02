//
//  Servicelist.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 15.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import Foundation
import SWXMLHash
// /api/getservices
class Servicelist:NSObject,  Translateable{
    static var translation: [String : String] = [:]
    
    var services:[Service]?
    var pos:Int?
    
    var bouquet:Service? //Bouquet
    
    required override init(){
        
    }
    
    required init(xml:XMLIndexer){
        self.services = [Service]()
        do
        {
        for xml in xml["e2servicelist"].children{
            services?.append(Service(xml: xml))
            }}catch{}
        
    }
}
