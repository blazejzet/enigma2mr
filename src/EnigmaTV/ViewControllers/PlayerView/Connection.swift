//
//  Connection.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 23.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//  https://stackoverflow.com/questions/24028995/toll-free-bridging-and-pointer-access-in-swift
//

import UIKit

extension OutputStream {
    func write(data: Data) -> Int {
        return data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> Int in
            guard let base = buffer.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return write(base, maxLength: buffer.count)
        }
    }
}

extension InputStream {
    func read(data: inout Data) -> Int {
        var d = data;
        return d.withUnsafeMutableBytes { read($0, maxLength: data.count) }
    }
}


class Connection: NSObject, StreamDelegate {
    
    private var inputStream: InputStream!
    private var outputStream: OutputStream!
    private var readStream: Unmanaged<CFReadStream>?
    var connected = false
    
    func connect(stream: String) {
        
        let str: NSString = NSString(string: stream)
        let url = CFURLCreateWithString(kCFAllocatorDefault, str, nil)
        let urlRequest = CFHTTPMessageCreateRequest(kCFAllocatorDefault, NSString(string:"GET"),
                                                    url!, kCFHTTPVersion1_1)
        
        print (urlRequest)
        
        readStream = CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, urlRequest.takeRetainedValue())
        CFReadStreamOpen(readStream?.takeRetainedValue())
        self.inputStream = readStream!.takeRetainedValue()
        inputStream.delegate = self
        
    }
    
    
    func record(to:URL){
        #if swift(>=4.2)
        inputStream.schedule(in: RunLoop.current, forMode: RunLoop.Mode.default)
        #else
        inputStream.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
        #endif
        inputStream.open()
        
        //DispatchQueue.global(qos: .background).async {
        let os = OutputStream(url: to, append: false)
        os?.open()
        let bufferSize = 1024
        var data  = Data(capacity: bufferSize)
            while (true){
             // let  err =   CFReadStreamGetError(self.readStream?.takeRetainedValue())
              //  print ("available \(self.inputStream.hasBytesAvailable)")
                if self.inputStream.hasBytesAvailable {
                    let read = self.inputStream.read(data: &data)
                    let write =  os?.write(data: data)
                    print("[WR] Did write (\(write))")
                }
            }
            
        //}
    }
    
    private func addHeader(urlRequest: Unmanaged<CFHTTPMessage>,key: String, val: String) {
        let nsKey: NSString = NSString(string:key)
        let nsVal: NSString = NSString(string:val)
        CFHTTPMessageSetHeaderFieldValue(urlRequest.takeUnretainedValue(),
                                         nsKey,
                                         nsVal)
    }
    
    func stream(aStream: Stream, handleEvent eventCode: Stream.Event) {
        switch (eventCode){
        case Stream.Event.openCompleted:
            NSLog("Stream opened")
            break
        case Stream.Event.hasBytesAvailable:
            NSLog("HasBytesAvailable")
            break
        case Stream.Event.errorOccurred:
            NSLog("ErrorOccurred")
            break
        case Stream.Event.endEncountered:
            NSLog("EndEncountered")
            break
        default:
            NSLog("unknown.")
        }
    }

    
    
}
