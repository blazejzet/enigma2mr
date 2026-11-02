//
//  MovieInfo.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 19.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import Foundation
import SWXMLHash


class MovieInfo:NSObject, Translateable {
    static var translation: [String : String] = [:]
    
    var vote_average: Double?
    var title: String?
    var poster_path: String?
    var release_date:String?
    var backdrop_path:String?
    
    required override init(){
        
    }
    
    required init(xml:XMLIndexer){
        
    }
}

class MovieInfoList:NSObject, Translateable  {
    
    
    var total_results:Int?
    var results:[MovieInfo]?
    static var translation: [String : String] = [:]
    
    required override init(){
        
    }
    
    required init(xml:XMLIndexer){
        
    }
}

