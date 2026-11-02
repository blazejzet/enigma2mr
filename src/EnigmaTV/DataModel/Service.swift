//
//  Service.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 15.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import Foundation
import SWXMLHash

class Service:NSObject,  Translateable {
    var servicereference:String?
    var servicename:String?
    var program:Int?
    var pos:Int?

    //dodatkowe moje
    var row:Int?

    static var translation: [String : String] = [:]

    /// Name to show; nil for services the receiver has no name for ("<n/a>").
    var displayName: String? {
        guard let name = servicename?.trimmingCharacters(in: .whitespaces), !name.isEmpty, name != "<n/a>" else { return nil }
        return name
    }

    var reference: ServiceReference? {
        return servicereference.map(ServiceReference.init)
    }

    required override init(){

    }

    required init(xml:XMLIndexer){
        self.servicereference = xml["e2servicereference"].element?.text
        self.servicename = xml["e2servicename"].element?.text
    }
}

/// Enigma2 service reference: `type:flags:stype:sid:tsid:onid:ns:psid:ptype:pvid:path:name`.
struct ServiceReference {
    let raw: String
    let fields: [String]

    init(_ raw: String) {
        self.raw = raw
        self.fields = raw.components(separatedBy: ":")
    }

    var type: Int { return Int(fields.first ?? "") ?? 0 }
    var flags: Int { return fields.count > 1 ? Int(fields[1]) ?? 0 : 0 }

    // eServiceReference flags
    private static let isDirectory = 1
    private static let isMarker = 64
    private static let isInvisible = 512

    var isMarker: Bool { return flags & ServiceReference.isMarker != 0 }
    var isDirectory: Bool { return flags & ServiceReference.isDirectory != 0 }
    var isInvisible: Bool { return flags & ServiceReference.isInvisible != 0 }

    /// Something the user can actually watch (not a bouquet, separator or hidden entry).
    var isPlayable: Bool { return !isMarker && !isDirectory && !isInvisible && fields.count >= 10 }

    /// Path part (11th field). For recordings it is the file name – everything after the 10th ':', so a
    /// path containing ':' survives. For IPTV services it is the escaped stream URL (its ':' are written
    /// as %3a) and everything after it is the channel name, which may itself contain ':'.
    var path: String? {
        guard fields.count > 10 else { return nil }
        let joined = isIPTV ? fields[10] : fields[10...].joined(separator: ":")
        return joined.isEmpty ? nil : joined
    }

    /// 4097 = gstreamer, 5001/5002 = exteplayer3/serviceapp, 8193 = DVB over IP.
    var isIPTV: Bool { return [4097, 5001, 5002, 8193].contains(type) }

    /// For IPTV services: the URL the receiver itself would open.
    var iptvURL: URL? {
        guard isIPTV, let path = path else { return nil }
        let decoded = path.removingPercentEncoding ?? path
        guard decoded.hasPrefix("http://") || decoded.hasPrefix("https://") else { return nil }
        return URL(string: decoded) ?? URL(string: decoded.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? decoded)
    }

    /// File name OpenWebif uses for picons: fields 1-10 joined with '_' (`1_0_19_1F4_1C37_17B8_FFFF0000_0_0_0`).
    var piconName: String? {
        guard fields.count >= 10 else { return nil }
        return fields[0..<10].joined(separator: "_")
    }
}
