//
//  URLConnection.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 23.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit

/// Downloads the receiver's (never ending) live TS stream into a `TimeshiftBuffer`.
/// This is the only connection to the receiver while timeshift is on – VLC reads from the buffer.
class URLConnection: NSObject, URLSessionDataDelegate{

    private var session:URLSession?
    private var dataTask:URLSessionDataTask?
    private var buffer:TimeshiftBuffer?
    private var receivedData = false

    /// Called on the main queue when the first bytes arrived.
    var onData: (() -> Void)?
    /// Called on the main queue when the stream ended or failed (not after `stop()`).
    var onFinish: ((Error?) -> Void)?

    /// Serial delegate queue: all buffer appends happen here, in order.
    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        q.name = "timeshift.download"
        return q
    }()

    func connect(url:URL, into buffer:TimeshiftBuffer){
        self.buffer = buffer
        overallcount = 0
        receivedData = false

        let conf = URLSessionConfiguration.default
        conf.timeoutIntervalForRequest = 15
        conf.timeoutIntervalForResource = .greatestFiniteMagnitude
        conf.requestCachePolicy = .reloadIgnoringLocalCacheData
        if let auth = STBAPI.common()?.authorizationHeader {
            conf.httpAdditionalHeaders = ["Authorization" : auth]
        }
        // The session retains its delegate until invalidated – see stop().
        session = URLSession(configuration: conf, delegate: self, delegateQueue: queue)
        dataTask = session?.dataTask(with: url)
        dataTask?.resume()
    }

    func stop(){
        onData = nil
        onFinish = nil
        dataTask?.cancel()
        dataTask = nil
        session?.invalidateAndCancel()
        session = nil
    }

    private(set) var overallcount:Int=0

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            print("Timeshift source answered HTTP \(http.statusCode)")
            completionHandler(.cancel)
            let error = NSError(domain: "EnigmaTV.timeshift", code: http.statusCode,
                                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
            DispatchQueue.main.async { self.onFinish?(error) }
            return
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer?.append(data)
        overallcount += data.count
        if !receivedData {
            receivedData = true
            DispatchQueue.main.async { self.onData?() }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error as NSError?, error.code == NSURLErrorCancelled {
            return
        }
        print("Timeshift source ended: \(error?.localizedDescription ?? "closed by receiver")")
        DispatchQueue.main.async { self.onFinish?(error) }
    }

    func getDataSize()->Int{
        return overallcount
    }

}
