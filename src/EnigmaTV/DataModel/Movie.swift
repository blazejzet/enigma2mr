//
//  Movie.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 17.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import Foundation
import SWXMLHash
class Movie:NSObject,  Translateable {
    var filename_stripped:String?
    var eventname:String?
    var recordingtime:Int64?
    var descriptionExtended:String?
    var servicename:String?
    var begintime:String?
    var filesize_readable:String?
    var serviceref:String?
    var length:String?
    
    
    static var translation: [String : String] = [:]
    
    required override init(){
        
    }
    
    required init(xml:XMLIndexer){
        self.filename_stripped = xml["e2filename"].element?.text ?? "--"
        self.eventname = xml["e2title"].element?.text ?? "--"
        self.descriptionExtended = xml["e2description"].element?.text
        self.servicename = xml["e2servicename"].element?.text
        // Same meaning as in the JSON API: recording start as unix time.
        if let t = xml["e2time"].element.flatMap({ Int64($0.text) }) {
            self.recordingtime = t
            self.begintime = "\(Date(timeIntervalSince1970: TimeInterval(t)))"
        }
        if let bytes = xml["e2filesize"].element.flatMap({ Int64($0.text) }) {
            self.filesize_readable = "\(bytes / 1024 / 1024) MB"
        }
        self.length = xml["e2length"].element?.text
        self.serviceref = xml["e2servicereference"].element?.text
    }

    /// Length in seconds parsed from `length` ("m:ss" / "h:mm:ss"); 0 when unknown ("?:??").
    var lengthSeconds: Int {
        guard let length = length else { return 0 }
        return length.split(separator: ":").reduce(0) { acc, part in acc * 60 + (Int(part) ?? 0) }
    }
}


class MoviesList:NSObject, Translateable {
    var directory:String?
    var movies:[Movie?]?
    
    static var translation: [String : String] = [:]
    
    required override init(){

    }

    private enum CodingKeys: String, CodingKey {
        case directory, movies
    }

    /// OpenWebif returns `"directory": []` (a list) when the movie directory does not exist.
    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.directory = (try? c.decodeIfPresent(String.self, forKey: .directory)) ?? nil
        self.movies = try c.decodeIfPresent([Movie?].self, forKey: .movies)
    }

    required init(xml:XMLIndexer){
        self.movies = xml["e2movielist"].children.map { Movie(xml: $0) }
    }
}
