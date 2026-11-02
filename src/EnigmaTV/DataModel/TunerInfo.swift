//
//  Service.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 15.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import Foundation
import SWXMLHash


class TunerInfo:NSObject, Translateable {
    var machinebuild:String?    // /e2abouts/e2about/e2imageversion
    var brand:String?           // /e2abouts/e2about/e2distroversion
    var boxtype:String?         // /e2abouts/e2about/e2imageversion
    var model:String?           // /e2abouts/e2about/e2model
    var ip:String?              // /e2abouts/e2about/e2lanip
    var apitype:String? = "api"
    
    
    required override init(){
        
    }
    
    required init(xml:XMLIndexer){
        
        
        do {
            if let x = xml["e2about"]["e2imageversion"].element{
                self.brand = "\(x.text) [Old API]"
            }
        }catch{}
        do{
            self.machinebuild = xml["e2about"]["e2enigmaversion"].element?.text
        }catch{}
        do{
            self.boxtype = xml["e2about"]["e2imageversion"].element?.text
        }catch{}
        do{
            self.model = xml["e2about"]["e2model"].element?.text
        }catch{}
        do{
            self.ip = xml["e2about"]["e2lanip"].element?.text
        }catch{}
        self.apitype = "web"
    }
}
