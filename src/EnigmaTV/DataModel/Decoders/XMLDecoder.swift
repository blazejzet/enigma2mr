//
//  XMLDecoder.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 18.06.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import Foundation
import SWXMLHash
protocol OptionalProtocol {
    static var wrappedType: Any.Type { get }
}
extension Optional : OptionalProtocol {
    static var wrappedType: Any.Type { return Wrapped.self }
}


protocol Translateable : NSObjectProtocol, Codable {
    init(xml:XMLIndexer)
    
}

extension Translateable{
    //func set(value:Any,for key:String){
      
    //}
}

class XMLDecoder: NSObject {

    open func decodeData<T>(_ type: T.Type, fromData data: Data) throws -> T where T:Translateable, T:NSObject{
        
        let xmlIndexer = SWXMLHash.parse(data)
        return try self.decode(type, fromXML: xmlIndexer)
        
    }
    open func decode<T>(_ type: T.Type, fromXML xmlInd: XMLIndexer) throws -> T where T:Translateable, T:NSObject{
        
        return type.init(xml:xmlInd)
        //self.propagate(&x, from: xmlInd)
        //return x
    }
    
    
    
}
