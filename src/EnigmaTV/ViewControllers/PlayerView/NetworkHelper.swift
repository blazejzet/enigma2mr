//
//  NetworkHelper.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 12.04.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit

struct Platform {
    static let isSimulator: Bool = {
        #if targetEnvironment(simulator)
            return true
        #else
            return false
        #endif
    }()
}

class NetworkHelper: NSObject {

    /// All host addresses of the local /24 network the Apple TV is in (excluding itself).
    class func getNetworkIPAddresses() -> [String] {
        // The simulator shares the Mac's interfaces, so en0/en1 detection works there as well;
        // fall back to the common home subnet only when nothing was found.
        guard let myAddr = NetworkHelper.getIPAddress() else {
            return Platform.isSimulator ? self.subnetAddresses(prefix: "192.168.1", excluding: nil) : []
        }
        print("Address found: \(myAddr)")
        let comp = myAddr.components(separatedBy: ".")
        guard comp.count == 4 else { return [] }
        return subnetAddresses(prefix: "\(comp[0]).\(comp[1]).\(comp[2])", excluding: myAddr)
    }

    private class func subnetAddresses(prefix: String, excluding own: String?) -> [String] {
        return (1...254).map { "\(prefix).\($0)" }.filter { $0 != own }
    }

    /// IPv4 address of the wired (en0) or wireless (en1) interface. Wired wins when both are up.
    class func getIPAddress() -> String? {
        var found = [String: String]()
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while let interface = ptr?.pointee {
            defer { ptr = interface.ifa_next }
            guard let addr = interface.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: interface.ifa_name)
            guard name == "en0" || name == "en1" else { continue }
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                found[name] = String(cString: hostname)
            }
        }
        return found["en0"] ?? found["en1"]
    }
}
