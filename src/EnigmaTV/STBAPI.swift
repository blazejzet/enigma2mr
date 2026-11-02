
//
//  STBAPI.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 15.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit
import Network
import SDWebImage


extension String {

    func fromBase64() -> String? {
        guard let data = Data(base64Encoded: self) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func toBase64() -> String {
        return Data(self.utf8).base64EncodedString()
    }

    /// OpenWebif HTML-escapes EPG texts in its JSON API (`&amp;`, `&quot;`, `&#x27;` ...).
    var htmlUnescaped: String {
        guard contains("&") else { return self }
        var result = ""
        var rest = Substring(self)
        while let amp = rest.firstIndex(of: "&") {
            result += rest[..<amp]
            rest = rest[amp...]
            guard let semi = rest.firstIndex(of: ";"), rest.distance(from: amp, to: semi) <= 10 else {
                result += "&"
                rest = rest.dropFirst()
                continue
            }
            let entity = rest[rest.index(after: amp)..<semi]
            var decoded: String?
            switch entity {
            case "amp": decoded = "&"
            case "quot": decoded = "\""
            case "apos": decoded = "'"
            case "lt": decoded = "<"
            case "gt": decoded = ">"
            case "nbsp": decoded = "\u{00A0}"
            default:
                if entity.hasPrefix("#x") || entity.hasPrefix("#X"), let v = UInt32(entity.dropFirst(2), radix: 16) {
                    decoded = Unicode.Scalar(v).map { String(Character($0)) }
                } else if entity.hasPrefix("#"), let v = UInt32(entity.dropFirst()) {
                    decoded = Unicode.Scalar(v).map { String(Character($0)) }
                }
            }
            if let decoded = decoded {
                result += decoded
                rest = rest[rest.index(after: semi)...]
            } else {
                result += "&"
                rest = rest.dropFirst()
            }
        }
        return result + rest
    }
}

enum STBError: Error {
    case invalidURL
    case network(Error)
    case http(Int)
    case decoding(Error)
    case rejected(String)
}

/// `/api/powerstate?newstate=` values.
enum PowerState: Int {
    case toggleStandby = 0, deepStandby = 1, reboot = 2, restartGUI = 3, wakeUp = 4, standby = 5
}

/// Access to the receiver's OpenWebif API (`/api` = JSON, `/web` = XML) and to its streams.
///
/// Callbacks of all receiver calls are delivered on the main queue.
class STBAPI: NSObject {
    static var _stbapi:STBAPI?

    class func common()->STBAPI?{
        if (_stbapi==nil) {
            _stbapi = STBAPI();
        }
        return _stbapi;
    }
    class func restart(){
        _stbapi=nil
        DataProvider.def().invalidate()
    }

    static let defaultTmdbApiKey = "f40747d2a2888d38f5efff7d12f764b5"

    var stbAddress:String!
    /// Streaming port (8001).
    var stbPort:String!
    /// Web interface port (80).
    var stbPort2:String!
    var stbProt:String!
    var stbTranscodingPort:String?
    var tmdbApiKey:String! = STBAPI.defaultTmdbApiKey
    var timeshift:Bool!
    var zap:Bool!
    var useTranscoding:Bool!
    var username:String!
    var password:String!
    /// "api" = JSON, "web" = XML (old OpenWebif / Webinterface).
    var apitype:String! = "api"

    var timers:TimerList?

    /// Session for receiver calls. The receiver is on the LAN – fail fast.
    private let session: URLSession = {
        let conf = URLSessionConfiguration.default
        conf.timeoutIntervalForRequest = 10
        conf.timeoutIntervalForResource = 30
        conf.requestCachePolicy = .reloadIgnoringLocalCacheData
        conf.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: conf)
    }()

    /// Session for third party services (TMDB) – never gets the receiver credentials.
    private let externalSession: URLSession = {
        let conf = URLSessionConfiguration.default
        conf.timeoutIntervalForRequest = 15
        return URLSession(configuration: conf)
    }()

    // MARK: - Settings

    override init() {
        self.stbAddress = "0.0.0.0"
        self.stbPort = "8001"
        self.stbPort2 = "80"
        self.stbProt = "http"
        self.stbTranscodingPort = "8002"
        self.username = ""
        self.password = ""
        self.timeshift = true
        self.zap = false
        self.useTranscoding=false;
        super.init()
        self.loadSettings()
        ReceiverStore.syncActiveFromDefaults()
    }

    func set(address:String){
        if address != self.stbAddress {
            DataProvider.def().invalidate()
        }
        self.stbAddress = address
    }

    func set(api:String){
        print("Setting api as:\(api)")
        self.apitype = api
    }

    func getDelay() -> Double{
        if let s = UserDefaults.standard.string(forKey: "airplaydelay"), let d = Double(s) {
            return d
        }
        return 1.0
    }

    func saveSettings(){
        let uds = UserDefaults.standard
        uds.set(self.stbPort, forKey: "stbPort")
        uds.set(self.stbPort2, forKey: "stbPort2")
        uds.set(self.stbProt, forKey: "stbProt")
        uds.set(self.stbTranscodingPort, forKey: "stbTranscodingPort")
        uds.set(self.useTranscoding, forKey: "useTranscoding")
        uds.set(self.timeshift, forKey: "timeshift")
        uds.set(self.zap, forKey: "zap")
        uds.set(self.apitype=="web",forKey: "oldapi")
        uds.set(self.stbAddress, forKey: "stbAddress")
        uds.set(self.username, forKey: "username")
        uds.set(self.password, forKey: "password")
    }
    func loadSettings(){
        let uds = UserDefaults.standard
        func trimmed(_ key: String) -> String? {
            return uds.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        self.timeshift = uds.bool(forKey: "timeshift")
        self.zap = uds.bool(forKey: "zap")
        self.apitype = ((uds.bool(forKey: "oldapi")) ? "web" : "api")
        self.stbProt = trimmed("stbProt").flatMap { $0.isEmpty ? nil : $0.lowercased() } ?? "http"
        self.stbPort = trimmed("stbPort").flatMap { $0.isEmpty ? nil : $0 } ?? "8001"
        self.stbPort2 = trimmed("stbPort2").flatMap { $0.isEmpty ? nil : $0 } ?? "80"
        self.stbTranscodingPort = trimmed("stbTranscodingPort").flatMap { $0.isEmpty ? nil : $0 } ?? "8002"
        self.useTranscoding = uds.bool(forKey: "useTranscoding")
        self.username = uds.string(forKey: "username") ?? ""
        self.password = uds.string(forKey: "password") ?? ""
        self.stbAddress = trimmed("stbAddress")
        self.tmdbApiKey = STBAPI.defaultTmdbApiKey
    }

    var isConfigured: Bool {
        guard let address = stbAddress else { return false }
        return !address.isEmpty && address != "0.0.0.0"
    }

    func test(success:@escaping ((TunerInfo)->Void),failure:@escaping (()->Void)){
        let uds = UserDefaults.standard
        if uds.object(forKey: "stbAddress") == nil {
            // First run: persist sane defaults.
            self.stbAddress = "0.0.0.0"
            self.zap = true
            self.stbPort = "8001"
            self.stbPort2 = "80"
            self.stbProt = "http"
            self.username = ""
            self.apitype = "api"
            self.password = ""
            self.timeshift = true
            self.useTranscoding=false;
            self.saveSettings()
        }
        self.loadSettings()
        print("self.stbAddress \(self.stbAddress ?? "nil")")
        if !isConfigured {
            DispatchQueue.main.async(execute: failure)
        }else{
            self.getInfo(success: success, failure: failure)
        }
    }

    // MARK: - URLs

    var authorizationHeader: String? {
        guard let username = username, !username.isEmpty else { return nil }
        let login = "\(username):\(password ?? "")"
        return "Basic \(Data(login.utf8).base64EncodedString())"
    }

    /// Characters left unescaped in query values. Everything else (`&`, `+`, `=`, `"`, `#`, space,
    /// non-ASCII) is percent-encoded – service references of bouquets contain quotes and spaces,
    /// recording paths can contain `&`/`+`.
    private static let queryValueAllowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~:/")

    static func encodeQueryValue(_ value: String) -> String {
        return value.addingPercentEncoding(withAllowedCharacters: queryValueAllowed) ?? value
    }

    private func baseComponents(port: String?) -> URLComponents? {
        guard isConfigured, let host = stbAddress else { return nil }
        var c = URLComponents()
        c.scheme = stbProt ?? "http"
        c.host = host
        if let port = port, let p = Int(port) {
            let isDefault = (c.scheme == "http" && p == 80) || (c.scheme == "https" && p == 443)
            if !isDefault { c.port = p }
        }
        return c
    }

    /// Web interface URL, e.g. `http://box/api/getservices?sRef=...`.
    func webURL(path: String, query: [(String, String)] = []) -> URL? {
        guard var c = baseComponents(port: stbPort2) else { return nil }
        c.path = path.hasPrefix("/") ? path : "/" + path
        if !query.isEmpty {
            c.percentEncodedQuery = query
                .map { "\(STBAPI.encodeQueryValue($0.0))=\(STBAPI.encodeQueryValue($0.1))" }
                .joined(separator: "&")
        }
        return c.url
    }

    /// `/api/<endpoint>` or `/web/<endpoint>` depending on the configured API flavour.
    func apiURL(_ endpoint: String, _ query: [(String, String)] = []) -> URL? {
        return webURL(path: "/\(apitype ?? "api")/\(endpoint)", query: query)
    }

    /// Kept for source compatibility; prefer `apiURL`.
    var stbURL:String {
        return baseComponents(port: stbPort2)?.url?.absoluteString ?? ""
    }

    /// Live stream URL for VLC. Credentials are embedded (VLC turns them into Basic auth) because the
    /// 8001 stream server requires them when "streaming authentication" is enabled on the receiver.
    /// IPTV services are played directly from their source URL.
    func streamURL(for service: Service) -> URL? {
        guard let ref = service.reference, ref.isPlayable else { return nil }
        if let iptv = ref.iptvURL {
            return iptv
        }
        let port = (useTranscoding ?? false) ? (stbTranscodingPort ?? "8002") : (stbPort ?? "8001")
        guard var c = baseComponents(port: port) else { return nil }
        // The stream server always speaks plain HTTP.
        c.scheme = "http"
        c.port = Int(port)
        if let username = username, !username.isEmpty {
            c.user = username
            c.password = password
        }
        // Keep ':' readable; escape everything else that is not URL safe.
        c.percentEncodedPath = "/" + (ref.raw.addingPercentEncoding(withAllowedCharacters: STBAPI.queryValueAllowed) ?? ref.raw)
        return c.url
    }

    /// Kept for source compatibility.
    func urlForRef(_ ref:String)->String{
        let service = Service()
        service.servicereference = ref
        return streamURL(for: service)?.absoluteString ?? ""
    }

    /// HTTP URL of a recording (`/file?file=/media/hdd/movie/x.ts`). Seekable (range requests).
    func recordingURL(for movie: Movie) -> URL? {
        guard let sref = movie.serviceref, let path = ServiceReference(sref).path,
              let url = webURL(path: "/file", query: [("file", path)]),
              var c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        if let username = username, !username.isEmpty {
            c.user = username
            c.password = password
        }
        return c.url
    }

    /// Picon served by OpenWebif from the receiver (`/picon/1_0_19_..._0_0_0.png`).
    func piconURL(for service: Service) -> URL? {
        guard let ref = service.reference, var name = ref.piconName else { return nil }
        if ref.isIPTV {
            // OpenWebif falls back to the DVB (type 1) picon name for IPTV references.
            name = "1" + name.drop(while: { $0 != "_" })
        }
        return webURL(path: "/picon/\(name).png")
    }

    /// Picon by channel name ("SNP" packs: `TVP ABC 2` → `tvpabc2.png`, `Canal+` → `canalplus.png`).
    func piconByNameURL(for service: Service) -> URL? {
        guard let name = service.displayName else { return nil }
        var snp = name.lowercased()
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: "+", with: "plus")
            .replacingOccurrences(of: "*", with: "star")
        snp = snp.folding(options: .diacriticInsensitive, locale: nil)
        snp = String(snp.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) && $0.isASCII }.map(Character.init))
        guard !snp.isEmpty else { return nil }
        return webURL(path: "/picon/\(snp).png")
    }

    /// `/api/statusinfo` of any saved receiver (not only the active one): power, channel, recording, streams.
    static func status(of profile: ReceiverProfile, cb: @escaping ([String: Any]?) -> Void) {
        var c = URLComponents()
        c.scheme = profile.prot
        c.host = profile.address
        if let port = Int(profile.webPort), port != (profile.prot == "https" ? 443 : 80) { c.port = port }
        c.path = "/api/statusinfo"
        guard profile.apitype == "api", let url = c.url else { return DispatchQueue.main.async { cb(nil) } }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5)
        if !profile.username.isEmpty {
            let login = "\(profile.username):\(profile.password)"
            request.setValue("Basic \(Data(login.utf8).base64EncodedString())", forHTTPHeaderField: "Authorization")
        }
        URLSession.shared.dataTask(with: request) { data, _, _ in
            let json = data.flatMap { (try? JSONSerialization.jsonObject(with: $0)) as? [String: Any] }
            DispatchQueue.main.async { cb(json) }
        }.resume()
    }

    // MARK: - Transport

    private func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let auth = authorizationHeader {
            request.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        return request
    }

    /// Raw GET. Completion runs on a background queue.
    private func getData(_ url: URL, session: URLSession? = nil, authorized: Bool = true, completion: @escaping (Result<Data, STBError>) -> Void) {
        let req = authorized ? request(url) : URLRequest(url: url)
        (session ?? self.session).dataTask(with: req) { data, response, error in
            if let error = error {
                completion(.failure(.network(error)))
                return
            }
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                completion(.failure(.http(http.statusCode)))
                return
            }
            completion(.success(data ?? Data()))
        }.resume()
    }

    /// GET + decode with the configured API flavour. Completion runs on the main queue.
    func fetch<T>(_ type: T.Type, _ endpoint: String, _ query: [(String, String)] = [], completion: @escaping (Result<T, STBError>) -> Void) where T: Translateable, T: NSObject {
        guard let url = apiURL(endpoint, query) else {
            DispatchQueue.main.async { completion(.failure(.invalidURL)) }
            return
        }
        let apitype = self.apitype ?? "api"
        print("GET \(url.absoluteString)")
        getData(url) { result in
            let decoded: Result<T, STBError> = result.flatMap { data in
                do {
                    return .success(try APIDecoder(apitype).decode(type, from: data))
                } catch {
                    print("Decoding \(T.self) from \(url.absoluteString) failed: \(error)")
                    return .failure(.decoding(error))
                }
            }
            DispatchQueue.main.async { completion(decoded) }
        }
    }

    /// GET returning the body as text (empty string on any error). Completion on the main queue.
    func getContent(of address: URL, cb: @escaping ((String)->Void)){
        getData(address) { result in
            let text: String
            if case .success(let data) = result {
                text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            } else {
                text = ""
            }
            DispatchQueue.main.async { cb(text) }
        }
    }

    // MARK: - Discovery & info

    /// Scans the local /24 network for receivers answering `/api/about` (or `/web/about`).
    /// `success` is called for every receiver found, `failure` once if none was found.
    func discoverNetwork(status:@escaping ((Int)->Void),success:@escaping ((TunerInfo,String)->Void),failure:@escaping ((String)->Void), finished: (() -> Void)? = nil){
        let addresses = NetworkHelper.getNetworkIPAddresses()
        if addresses.isEmpty {
            DispatchQueue.main.async { failure(L("No network found. Please restart Your device.")) }
            return
        }

        let conf = URLSessionConfiguration.ephemeral
        conf.timeoutIntervalForRequest = 2
        conf.timeoutIntervalForResource = 4
        conf.httpMaximumConnectionsPerHost = 1
        let scanSession = URLSession(configuration: conf)

        let group = DispatchGroup()
        let limiter = DispatchSemaphore(value: 24)
        let lock = NSLock()
        var found = 0
        var checked = 0

        DispatchQueue.global(qos: .userInitiated).async {
            for address in addresses {
                limiter.wait()
                group.enter()
                self.probe(address: address, apitypes: ["api", "web"], session: scanSession) { info in
                    lock.lock()
                    checked += 1
                    let progress = checked
                    if info != nil { found += 1 }
                    lock.unlock()
                    DispatchQueue.main.async {
                        status(progress * 100 / addresses.count)
                        if let info = info { success(info, address) }
                    }
                    limiter.signal()
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                scanSession.finishTasksAndInvalidate()
                if found == 0 {
                    failure(L("No receiver found."))
                }
                finished?()
            }
        }
    }

    private func probe(address: String, apitypes: [String], session: URLSession, completion: @escaping (TunerInfo?) -> Void) {
        guard let apitype = apitypes.first, let url = URL(string: "http://\(address)/\(apitype)/about") else {
            completion(nil)
            return
        }
        getData(url, session: session, authorized: false) { result in
            if case .success(let data) = result,
               let response = try? APIDecoder(apitype).decode(TunerInfoResponse.self, from: data),
               let info = response.info {
                info.apitype = apitype
                completion(info)
            } else if case .failure(.network) = result {
                completion(nil)   // nothing listening – no need to try the XML API
            } else {
                self.probe(address: address, apitypes: Array(apitypes.dropFirst()), session: session, completion: completion)
            }
        }
    }

    func getInfo(success:@escaping ((TunerInfo)->Void),failure:@escaping (()->Void)){
        fetch(TunerInfoResponse.self, "about") { result in
            if case .success(let response) = result, let info = response.info {
                info.apitype = self.apitype
                success(info)
            } else {
                if case .failure(let error) = result { print("about failed: \(error)") }
                failure()
            }
        }
    }

    func getTunerInfo(str:String,apitype:String,cb:@escaping ((TunerInfo)->Void)){
        guard let data = str.data(using: .utf8),
              let response = try? APIDecoder(apitype).decode(TunerInfoResponse.self, from: data),
              let info = response.info else { return }
        DispatchQueue.main.async { cb(info) }
    }

    // MARK: - Bouquets & channels

    /// Bouquets (TV).
    func getServices(cb:@escaping ((Servicelist)->Void), fail:@escaping (()->Void)){
        fetch(Servicelist.self, "getservices") { result in
            switch result {
            case .success(let list): cb(list)
            case .failure: fail()
            }
        }
    }

    /// Playable channels of a bouquet: markers/separators removed, `row` = index in the list.
    func getServices(for bouquet:Service, cb:@escaping ((Servicelist)->Void),fail:@escaping (()->Void)){
        guard let bref = bouquet.servicereference else {
            DispatchQueue.main.async(execute: fail)
            return
        }
        fetch(Servicelist.self, "getservices", [("sRef", bref)]) { result in
            switch result {
            case .success(let list):
                list.bouquet = bouquet
                let services = (list.services ?? []).filter { $0.reference?.isPlayable ?? false }
                for (row, s) in services.enumerated() {
                    s.row = row
                }
                list.services = services
                cb(list)
            case .failure:
                fail()
            }
        }
    }

    func zap(for service:Service){
        guard let sref = service.servicereference else { return }
        fetch(Message.self, "zap", [("sRef", sref)]) { result in
            if case .failure(let error) = result {
                print("Zap to \(sref) failed: \(error)")
            }
        }
    }

    // MARK: - EPG

    private func unescape(_ events: [EpgEvent]) -> [EpgEvent] {
        guard apitype == "api" else { return events }
        for e in events {
            e.title = e.title?.htmlUnescaped
            e.shortdesc = e.shortdesc?.htmlUnescaped
            e.longdesc = e.longdesc?.htmlUnescaped
            e.sname = e.sname?.htmlUnescaped
        }
        return events
    }

    private func fetchEvents(_ endpoint: String, _ query: [(String, String)], cb: @escaping ([EpgEvent]) -> Void) {
        fetch(Eventlist.self, endpoint, query) { result in
            switch result {
            case .success(let list):
                cb(self.unescape(list.events ?? []))
            case .failure:
                cb([])
            }
        }
    }

    /// Programmes on all channels whose title contains `text` (`epgsearch`), oldest first.
    func searchEPG(_ text: String, cb: @escaping ([EpgEvent]) -> Void) {
        fetchEvents("epgsearch", [("search", text)]) { events in
            cb(events.sorted { ($0.begin_timestamp ?? 0) < ($1.begin_timestamp ?? 0) })
        }
    }

    /// Other broadcasts of the same programme (`epgsimilar`), e.g. repeats and further episodes.
    func similarEPG(to event: EpgEvent, cb: @escaping ([EpgEvent]) -> Void) {
        guard let sref = event.sref, let id = event.id else { return cb([]) }
        fetchEvents("epgsimilar", [("sRef", sref), ("eventid", String(id))]) { events in
            cb(events.sorted { ($0.begin_timestamp ?? 0) < ($1.begin_timestamp ?? 0) })
        }
    }

    /// Event currently running on a service (`epgservicenow`).
    func getEPG(for service:Service, from start:UInt64, to end:UInt64, cb:@escaping (([EpgEvent],Service)->Void)){
        guard let sref = service.servicereference else { return }
        fetchEvents("epgservicenow", [("sRef", sref)]) { events in
            cb(events, service)
        }
    }

    /// Events of a service starting with the one running at `start`.
    /// Note: OpenWebif's `endTime` is a duration in minutes, not a timestamp.
    func getEPGEvents(sref: String, from start: UInt64, to end: UInt64, cb: @escaping ([EpgEvent]) -> Void) {
        var query = [("sRef", sref)]
        if start > 0 {
            query.append(("time", String(start)))
        }
        if end > start {
            query.append(("endTime", String(max(1, (end - start) / 60))))
        }
        fetchEvents("epgservice", query) { events in
            // Drop the "no EPG" placeholder entry.
            cb(events.filter { $0.begin_timestamp != nil && ($0.duration_sec ?? 0) > 0 })
        }
    }

    func getFullEPG(for service:Service, from start:UInt64, to end:UInt64, cb:@escaping (([EpgEvent],Service)->Void)){
        guard let sref = service.servicereference else { return }
        getEPGEvents(sref: sref, from: start, to: end) { events in
            cb(events, service)
        }
    }

    /// Now/next events for every channel of a bouquet in a single request (`epgnownext?bRef=`).
    /// Result is keyed by service reference: (now, next). Services without EPG are omitted.
    func getBouquetNowNext(bouquet: Service, cb: @escaping ([String: (EpgEvent, EpgEvent?)]?) -> Void) {
        guard let bref = bouquet.servicereference else {
            DispatchQueue.main.async { cb(nil) }
            return
        }
        fetch(Eventlist.self, "epgnownext", [("bRef", bref)]) { result in
            guard case .success(let list) = result, let events = list.events else {
                cb(nil)
                return
            }
            var byService = [String: [EpgEvent]]()
            for e in self.unescape(events) {
                guard let sref = e.sref, e.begin_timestamp != nil, e.title != nil else { continue }
                byService[sref, default: []].append(e)
            }
            var result = [String: (EpgEvent, EpgEvent?)]()
            for (sref, list) in byService {
                let sorted = list.sorted { ($0.begin_timestamp ?? 0) < ($1.begin_timestamp ?? 0) }
                result[sref] = (sorted[0], sorted.count > 1 ? sorted[1] : nil)
            }
            cb(result)
        }
    }

    /// Now and next event of a service. `cb` is always called (with nils when there is no EPG).
    func nowPlaying(at sref:String, sname:String, cb:((EpgEvent?,EpgEvent?)->Void)?) {
        let now = UInt64(Date().timeIntervalSince1970)
        getEPGEvents(sref: sref, from: now, to: now + 6 * 60 * 60) { events in
            let current = events.first { e in
                guard let b = e.begin_timestamp, let d = e.duration_sec else { return false }
                return b <= now && now < b + d
            }
            let upcoming = events.first { ($0.begin_timestamp ?? 0) > now }
            current?.sname = current?.sname ?? sname
            cb?(current, upcoming)
        }
    }

    // MARK: - Recordings & timers

    /// Recordings from every recording location, newest first.
    /// The plain `movielist` only lists the receiver's default folder (e.g. /media/hdd/movie/), but
    /// timers without an explicit folder can end up in the mount root (openATV writes to /media/hdd/),
    /// so the configured locations and their parent folders are listed and merged.
    func getMovies(cb:@escaping ((MoviesList)->Void)){
        fetchJSON("getlocations") { json in
            var folders = [String]()
            func add(_ path: String?) {
                guard var path = path?.trimmingCharacters(in: .whitespaces), path.hasPrefix("/") else { return }
                if !path.hasSuffix("/") { path += "/" }
                if !folders.contains(path) { folders.append(path) }
            }
            let locations = (json?["locations"] as? [String] ?? []) + [json?["default"] as? String].compactMap { $0 }
            for location in locations {
                add(location)
                // Parent folder, unless it is "/" or "/media/".
                let parent = (location.hasSuffix("/") ? String(location.dropLast()) : location)
                    .components(separatedBy: "/").dropLast().joined(separator: "/")
                if parent.components(separatedBy: "/").count > 2 { add(parent) }
            }
            self.getMovies(in: folders, cb: cb)
        }
    }

    private func getMovies(in folders: [String], cb: @escaping (MoviesList) -> Void) {
        guard !folders.isEmpty else {
            // XML API or no locations: the receiver's default folder only.
            fetch(MoviesList.self, "movielist") { result in
                if case .failure(let error) = result { print("movielist failed: \(error)") }
                cb((try? result.get()) ?? MoviesList())
            }
            return
        }
        let group = DispatchGroup()
        var movies = [Movie]()
        for folder in folders {
            group.enter()
            fetch(MoviesList.self, "movielist", [("dirname", folder)]) { result in
                switch result {
                case .success(let list):
                    for case let movie? in list.movies ?? [] where !movies.contains(where: { $0.serviceref == movie.serviceref }) {
                        movies.append(movie)
                    }
                case .failure(let error):
                    print("movielist \(folder) failed: \(error)")
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            let list = MoviesList()
            list.directory = folders.first
            list.movies = movies.sorted { ($0.recordingtime ?? 0) > ($1.recordingtime ?? 0) }
            cb(list)
        }
    }

    /// Pending and running timers (ended ones are skipped), newest first.
    func getTimers(cb:@escaping ((TimerList)->Void)){
        fetch(TimerList.self, "timerlist") { result in
            switch result {
            case .success(let list):
                list.timers = (list.timers ?? []).filter { ($0.state ?? 0) < 3 }.reversed()
                self.timers = list
                cb(list)
            case .failure(let error):
                print("timerlist failed: \(error)")
                cb(TimerList())
            }
        }
    }

    /// Schedules a recording of an EPG event. `cb(success, message from the receiver)`.
    func setTimer(sref:String, eid:Int, cb:@escaping ((Bool, String?)->Void)){
        fetch(Message.self, "timeraddbyeventid", [("sRef", sref), ("eventid", String(eid))]) { result in
            switch result {
            case .success(let message):
                cb(message.result ?? false, message.message)
                self.getTimers { _ in }
            case .failure(let error):
                cb(false, "\(error)")
            }
        }
    }

    /// Records `sref` from `begin` to `end` (unix times) – "record now" for a fixed time.
    func addTimer(sref: String, begin: UInt64, end: UInt64, name: String, cb: @escaping (Bool, String?) -> Void) {
        fetch(Message.self, "timeradd", [("sRef", sref), ("begin", String(begin)), ("end", String(end)), ("name", name)]) { result in
            switch result {
            case .success(let message):
                cb(message.result ?? false, message.message)
                self.getTimers { _ in }
            case .failure(let error):
                cb(false, "\(error)")
            }
        }
    }

    /// The timer currently recording `sref`, if any (enigma2 timer state 2 = running).
    func runningRecording(sref: String, cb: @escaping (RecordingTimer?) -> Void) {
        getTimers { list in
            cb(list.timers?.first { $0.state == 2 && $0.serviceref == sref })
        }
    }

    func movieDelete(_ m:Movie, cb: ((Bool, String?) -> Void)? = nil){
        guard let sref = m.serviceref else {
            cb?(false, nil)
            return
        }
        fetch(Message.self, "moviedelete", [("sRef", sref)]) { result in
            switch result {
            case .success(let message): cb?(message.result ?? false, message.message)
            case .failure(let error): cb?(false, "\(error)")
            }
        }
    }

    func timerDelete(_ m:RecordingTimer, cb: ((Bool, String?) -> Void)? = nil){
        guard let sref = m.serviceref, let begin = m.begin, let end = m.end else {
            cb?(false, nil)
            return
        }
        fetch(Message.self, "timerdelete", [("sRef", sref), ("begin", String(begin)), ("end", String(end))]) { result in
            switch result {
            case .success(let message): cb?(message.result ?? false, message.message)
            case .failure(let error): cb?(false, "\(error)")
            }
        }
    }

    /// Tells whether tvOS blocks this app from the local network (Settings → Privacy & Security →
    /// Local Network). Connections to LAN addresses then just time out, which looks like a dead receiver.
    func checkLocalNetworkAccess(completion: @escaping (_ denied: Bool) -> Void) {
        guard let host = stbAddress, isConfigured, let port = NWEndpoint.Port(rawValue: UInt16(stbPort2 ?? "80") ?? 80) else {
            DispatchQueue.main.async { completion(false) }
            return
        }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)
        // Connection events and the timeout share one serial queue, so `answered` needs no lock.
        let queue = DispatchQueue(label: "LocalNetworkCheck")
        var answered = false
        let finish: (Bool) -> Void = { denied in
            guard !answered else { return }
            answered = true
            connection.cancel()
            DispatchQueue.main.async { completion(denied) }
        }
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                finish(false)
            case .waiting, .failed:
                let denied: Bool
                if #available(tvOS 14.0, *) {
                    denied = connection.currentPath?.unsatisfiedReason == .localNetworkDenied
                } else {
                    denied = false
                }
                print("Local network check: \(state) denied=\(denied)")
                finish(denied)
            default:
                break
            }
        }
        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + 5) { finish(false) }
    }

    // MARK: - Receiver settings & status (JSON API only)

    /// GET returning the decoded JSON object, nil on any error or with the XML API. Main queue.
    func fetchJSON(_ endpoint: String, _ query: [(String, String)] = [], completion: @escaping ([String: Any]?) -> Void) {
        guard apitype == "api", let url = apiURL(endpoint, query) else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        getData(url) { result in
            var object: [String: Any]?
            if case .success(let data) = result {
                object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            }
            DispatchQueue.main.async { completion(object) }
        }
    }

    /// Setting sections the receiver exposes (`/api/config`).
    func getConfigSections(cb: @escaping ([ReceiverConfigSection]?) -> Void) {
        fetchJSON("config") { json in
            let sections = (json?["sections"] as? [[String: Any]])?.compactMap { s -> ReceiverConfigSection? in
                guard let key = s["key"] as? String else { return nil }
                return ReceiverConfigSection(key: key, title: (s["description"] as? String)?.htmlUnescaped ?? key)
            }
            cb(sections)
        }
    }

    /// All items of one section (`/api/config/<section>`).
    func getConfig(section: String, cb: @escaping ([ReceiverConfigItem]?) -> Void) {
        // webURL() puts this into URLComponents.path, which does the percent-encoding.
        fetchJSON("config/\(section)") { json in
            cb((json?["configs"] as? [[String: Any]])?.compactMap(ReceiverConfigItem.init(json:)))
        }
    }

    /// Items by config path, loading the given sections in parallel.
    func getConfigItems(paths: [String], sections: [String], cb: @escaping ([String: ReceiverConfigItem]) -> Void) {
        let group = DispatchGroup()
        var found = [String: ReceiverConfigItem]()
        for section in sections {
            group.enter()
            getConfig(section: section) { items in
                for item in items ?? [] where paths.contains(item.path) && found[item.path] == nil {
                    found[item.path] = item
                }
                group.leave()
            }
        }
        group.notify(queue: .main) { cb(found) }
    }

    /// Changes one receiver setting (`POST /api/saveconfig`). Note: Enigma2 writes its settings file
    /// on a clean shutdown/standby cycle – a power cut right after a change can lose it.
    func saveConfig(path: String, value: String, cb: @escaping (Bool, String?) -> Void) {
        guard apitype == "api", let url = apiURL("saveconfig") else {
            DispatchQueue.main.async { cb(false, L("Requires the OpenWebif JSON API")) }
            return
        }
        var req = request(url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "key=\(STBAPI.encodeQueryValue(path))&value=\(STBAPI.encodeQueryValue(value))".data(using: .utf8)
        print("POST \(url.absoluteString) key=\(path) value=\(value)")
        session.dataTask(with: req) { data, response, error in
            var ok = false
            var message: String?
            if let error = error {
                message = error.localizedDescription
            } else if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                message = "HTTP \(http.statusCode)"
            } else if let data = data, let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                ok = json["result"] as? Bool ?? false
                message = json["message"] as? String
            }
            DispatchQueue.main.async { cb(ok, message) }
        }.resume()
    }

    struct SleepTimer {
        var enabled: Bool
        var minutes: Int
        var action: String
    }

    func getSleepTimer(cb: @escaping (SleepTimer?) -> Void) {
        fetchJSON("sleeptimer", [("cmd", "get")]) { json in
            guard let json = json else { return cb(nil) }
            cb(SleepTimer(enabled: json["enabled"] as? Bool ?? false,
                          minutes: json["minutes"] as? Int ?? 0,
                          action: json["action"] as? String ?? "standby"))
        }
    }

    /// minutes == 0 disables the sleep timer. `action`: "standby" or "shutdown".
    func setSleepTimer(minutes: Int, action: String, cb: @escaping (Bool, String?) -> Void) {
        var query = [("cmd", "set"), ("action", action), ("enabled", minutes > 0 ? "True" : "False")]
        if minutes > 0 { query.append(("time", String(minutes))) }
        fetchJSON("sleeptimer", query) { json in
            cb(json != nil, json?["message"] as? String)
        }
    }

    /// true = receiver is in standby, nil = unknown/unreachable.
    func getStandbyState(cb: @escaping (Bool?) -> Void) {
        fetchJSON("powerstate") { json in
            cb(json?["instandby"] as? Bool)
        }
    }

    /// `/api/tunersignal`: snr (%), snr_db, agc, ber, tunertype.
    func getTunerSignal(cb: @escaping ([String: Any]?) -> Void) {
        fetchJSON("tunersignal", completion: cb)
    }

    /// `/api/about` → "info" dictionary (brand, model, imagedistro, imagever, webifver, tuners, hdd, ...).
    func getAboutInfo(cb: @escaping ([String: Any]?) -> Void) {
        fetchJSON("about") { json in cb(json?["info"] as? [String: Any]) }
    }

    // MARK: - Power

    func setPowerState(_ state: PowerState, cb: ((Bool) -> Void)? = nil) {
        guard let url = apiURL("powerstate", [("newstate", String(state.rawValue))]) else {
            cb?(false)
            return
        }
        getData(url) { result in
            let ok: Bool
            if case .success = result { ok = true } else { ok = false }
            DispatchQueue.main.async { cb?(ok) }
        }
    }

    func wakeUp(){
        setPowerState(.wakeUp)
    }

    /// Puts the receiver into standby.
    func turnOff(){
        setPowerState(.standby)
    }
    func reboot(){
        setPowerState(.reboot)
    }

    // MARK: - TMDB artwork

    /// Looks up poster/backdrop for an event title on TMDB (cached in the temp directory).
    /// `cb` runs on a background queue.
    func searchInfoWeb(title:String, duration:Int, eid:Int, cb:((UIImage?,UIImage?,Int,Bool)->Void)?){
        guard let callback = cb else { return }
        // `-EnigmaBlur YES` (App Review assets): hand out blurred artwork only.
        let cb: (UIImage?,UIImage?,Int,Bool)->Void = ReviewBlur.enabled
            ? { image, backdrop, eid, ok in callback(ReviewBlur.image(image), ReviewBlur.image(backdrop), eid, ok) }
            : callback
        if title == "NO DATA" || title == "N/A" || title.isEmpty { return }
        DispatchQueue.global(qos: .utility).async {
            let key = title.toBase64().replacingOccurrences(of: "/", with: "_")
            let fm = FileManager.default
            let furl = fm.temporaryDirectory.appendingPathComponent("\(key)_fg")
            let fbgurl = fm.temporaryDirectory.appendingPathComponent("\(key)_bg")

            if let d = try? Data(contentsOf: furl) {
                let bg = (try? Data(contentsOf: fbgurl)).flatMap(UIImage.init(data:))
                cb(UIImage(data: d), bg, eid, true)
                return
            }

            // "Title - episode", "Title s.01", "Title odc.3", "Title: subtitle" -> "Title"
            var t = title.components(separatedBy: "-")[0]
            if t.contains("s.") || t.contains("odc.") {
                t = t.components(separatedBy: ".")[0]
            }
            t = t.components(separatedBy: ":")[0]
            let query = t.trimmingCharacters(in: .whitespaces)
            guard !query.isEmpty,
                  let url = URL(string: "https://api.themoviedb.org/3/search/multi?api_key=\(self.tmdbApiKey ?? STBAPI.defaultTmdbApiKey)&query=\(STBAPI.encodeQueryValue(query))") else {
                cb(nil, nil, eid, false)
                return
            }
            self.getData(url, session: self.externalSession, authorized: false) { result in
                guard case .success(let data) = result,
                      let resp = try? JSONDecoder().decode(MovieInfoList.self, from: data),
                      let m = resp.results?.first else {
                    cb(nil, nil, eid, false)
                    return
                }
                var img: UIImage?
                var img2: UIImage?
                if let path = m.poster_path, let u = URL(string: "https://image.tmdb.org/t/p/w300\(path)"),
                   let x = try? Data(contentsOf: u) {
                    try? x.write(to: furl)
                    img = UIImage(data: x)
                }
                if let path = m.backdrop_path, let u = URL(string: "https://image.tmdb.org/t/p/w1280\(path)"),
                   let x = try? Data(contentsOf: u) {
                    try? x.write(to: fbgurl)
                    img2 = UIImage(data: x)
                }
                cb(img, img2, eid, img != nil)
            }
        }
    }

}


struct ReceiverConfigSection {
    let key: String
    let title: String
}

/// One receiver setting from `/api/config/<section>`.
final class ReceiverConfigItem {
    enum Kind: String {
        case checkbox, select, number, text, other
    }

    let title: String
    let path: String
    let kind: Kind
    /// Current value as the receiver reports it, stringified ("true"/"false" for checkboxes).
    var current: String
    /// (value to save, label to show)
    let choices: [(value: String, label: String)]
    let limits: (min: Int, max: Int)?

    init?(json: [String: Any]) {
        guard let path = json["path"] as? String, let data = json["data"] as? [String: Any] else { return nil }
        self.path = path
        self.title = (json["description"] as? String ?? path).htmlUnescaped
        let type = data["type"] as? String ?? ""
        self.kind = Kind(rawValue: type) ?? .other
        self.current = ReceiverConfigItem.string(data["current"])
        self.choices = (data["choices"] as? [Any] ?? []).compactMap { choice in
            if let pair = choice as? [Any], pair.count >= 2 {
                return (ReceiverConfigItem.string(pair[0]), ReceiverConfigItem.string(pair[1]).htmlUnescaped)
            }
            let single = ReceiverConfigItem.string(choice)
            return (single, single.htmlUnescaped)
        }
        if let limits = data["limits"] as? [Any], limits.count == 2,
           let lo = Int(ReceiverConfigItem.string(limits[0])), let hi = Int(ReceiverConfigItem.string(limits[1])) {
            self.limits = (lo, hi)
        } else {
            self.limits = nil
        }
    }

    var isOn: Bool { return current == "true" }

    /// Human readable current value.
    var currentLabel: String {
        switch kind {
        case .checkbox: return isOn ? L("On") : L("Off")
        case .select: return choices.first(where: { $0.value == current })?.label ?? current.htmlUnescaped
        default: return current.htmlUnescaped
        }
    }

    var isEditable: Bool { return kind != .other }

    private static func string(_ any: Any?) -> String {
        switch any {
        case let n as NSNumber:
            // JSON booleans and numbers both arrive as NSNumber – 0/1 must stay numbers.
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return n.boolValue ? "true" : "false" }
            return n.stringValue
        case let s as String: return s
        case nil: return ""
        default: return "\(any!)"
        }
    }
}

extension UIImageView {
    private static var logoRequestKey = 0

    /// Identifies the latest logo request so late answers for reused cells are ignored.
    private var logoRequest: String? {
        get { return objc_getAssociatedObject(self, &UIImageView.logoRequestKey) as? String }
        set { objc_setAssociatedObject(self, &UIImageView.logoRequestKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Channel logo: picon installed on the receiver → tv-logo/tv-logos → rendered channel name.
    /// `padding` (fraction of the view, e.g. 0.2) insets the logo, for large tiles.
    func setPicon(for service: Service?, padding: CGFloat = 0) {
        self.sd_cancelCurrentImageLoad()
        self.image = nil
        guard let service = service else {
            logoRequest = nil
            return
        }
        let request = UUID().uuidString
        logoRequest = request
        UIImageView.loadChannelLogo(for: service) { [weak self] image in
            guard let self = self, self.logoRequest == request else { return }
            let bounds = self.bounds.size
            let aspect = bounds.height > 0 ? bounds.width / bounds.height : 0
            self.image = image.map { UIImageView.padded($0, by: padding, toAspect: aspect) }
        }
    }

    /// The logo chain of `setPicon` without a view (e.g. for Now Playing artwork). Completion on main.
    static func loadChannelLogo(for service: Service, completion: @escaping (UIImage?) -> Void) {
        let name = service.servicename ?? ""
        let load: (URL, [SDWebImageContextOption: Any]?, @escaping () -> Void) -> Void = { url, context, failed in
            SDWebImageManager.shared.loadImage(with: url, options: [], context: context, progress: nil) { image, _, _, _, _, _ in
                DispatchQueue.main.async {
                    if let image = image { completion(image) } else { failed() }
                }
            }
        }
        let showName = { completion(ChannelLogoProvider.nameImage(for: name)) }
        let tryCommunityLogo = {
            ChannelLogoProvider.shared.url(for: name) { url in
                guard let url = url else { return showName() }
                load(url, nil, showName)
            }
        }

        guard let api = STBAPI.common(), let url = api.piconURL(for: service) else {
            return tryCommunityLogo()
        }
        var context = [SDWebImageContextOption: Any]()
        // Receiver picon by reference, then by name, then the community logos.
        let tryNamePicon = {
            guard let byName = api.piconByNameURL(for: service) else { return tryCommunityLogo() }
            load(byName, context, tryCommunityLogo)
        }
        if let auth = api.authorizationHeader {
            // Only for the receiver – never send its credentials to other hosts.
            context[.downloadRequestModifier] = SDWebImageDownloaderRequestModifier { request in
                var r = request
                r.setValue(auth, forHTTPHeaderField: "Authorization")
                return r
            }
        }
        load(url, context, tryNamePicon)
    }

    /// Stops a pending `setPicon` so a late logo does not replace an image set meanwhile.
    func cancelPicon() {
        logoRequest = nil
        sd_cancelCurrentImageLoad()
    }

    /// Insets the logo by `fraction` and, when `aspect` > 0, centers it on a canvas with that
    /// width/height ratio – focus-enabled tvOS image views always aspect-fill, so this keeps wide
    /// logos (e.g. 512×100) uncropped.
    private static func padded(_ image: UIImage, by fraction: CGFloat, toAspect aspect: CGFloat) -> UIImage {
        guard fraction > 0 || aspect > 0 else { return image }
        let size = image.size
        let inner = max(0.1, 1 - 2 * fraction)
        var canvas = CGSize(width: size.width / inner, height: size.height / inner)
        if aspect > 0 {
            if canvas.width / canvas.height > aspect {
                canvas.height = canvas.width / aspect
            } else {
                canvas.width = canvas.height * aspect
            }
        }
        return UIGraphicsImageRenderer(size: canvas).image { _ in
            image.draw(in: CGRect(x: (canvas.width - size.width) / 2, y: (canvas.height - size.height) / 2,
                                  width: size.width, height: size.height))
        }
    }
}

/// Resolves channel logos from https://github.com/tv-logo/tv-logos (PNG, one folder per country).
/// The folder listing is fetched once and cached for a week; names are matched loosely
/// ("TVP ABC 2" → tvp-abc2-pl.png, "TVP3 Bydgoszcz" → tvp3-pl.png).
final class ChannelLogoProvider {
    static let shared = ChannelLogoProvider()

    private static let listingURL = "https://api.github.com/repos/tv-logo/tv-logos/contents/countries/"
    private static let cacheTTL: TimeInterval = 7 * 24 * 60 * 60

    /// normalized name → logo URL (main queue only)
    private var index: [String: String]?
    private var waiting = [() -> Void]()
    private var loading = false

    /// Countries offered in Settings → Channel logos: (tv-logos folder, region code for the name).
    static let countries: [(folder: String, region: String)] = [
        ("austria", "AT"), ("belgium", "BE"), ("croatia", "HR"), ("czech-republic", "CZ"), ("france", "FR"),
        ("germany", "DE"), ("greece", "GR"), ("hungary", "HU"), ("italy", "IT"), ("netherlands", "NL"),
        ("nordic", "SE"), ("poland", "PL"), ("portugal", "PT"), ("romania", "RO"), ("slovakia", "SK"),
        ("spain", "ES"), ("switzerland", "CH"), ("turkey", "TR"), ("ukraine", "UA"), ("united-kingdom", "GB"),
        ("united-states", "US"),
    ]

    /// Folder chosen in Settings (nil = from the Apple TV's region).
    static var chosenCountry: String? {
        get { return UserDefaults.standard.string(forKey: "logoCountry").flatMap { $0.isEmpty ? nil : $0 } }
        set {
            UserDefaults.standard.set(newValue, forKey: "logoCountry")
            shared.index = nil   // reload with the new country
        }
    }

    /// Country folder (chosen, else from the Apple TV's region), plus the international folder.
    private var folders: [String] {
        if let chosen = ChannelLogoProvider.chosenCountry { return ["international", chosen] }
        let region = Locale.current.regionCode?.uppercased() ?? ""
        let special = ["CZ": "czech-republic", "GB": "united-kingdom", "US": "united-states", "AE": "united-arab-emirates",
                       "HK": "hong-kong", "NZ": "new-zealand", "ZA": "south-africa", "CR": "costa-rica",
                       "DK": "nordic", "SE": "nordic", "NO": "nordic", "FI": "nordic", "IS": "nordic"]
        var country = special[region]
        if country == nil, let english = Locale(identifier: "en_US").localizedString(forRegionCode: region) {
            country = english.lowercased().replacingOccurrences(of: " ", with: "-")
        }
        return ["international"] + (country.map { [$0] } ?? [])
    }

    func url(for name: String, completion: @escaping (URL?) -> Void) {
        loadIndex {
            completion(self.match(name).flatMap(URL.init(string:)))
        }
    }

    static func key(_ s: String) -> String {
        let folded = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
            .replacingOccurrences(of: "&", with: "and").replacingOccurrences(of: "+", with: "plus")
        return String(folded.unicodeScalars.filter { ("a"..."z").contains($0) || ("0"..."9").contains($0) }.map(Character.init))
    }

    private func match(_ name: String) -> String? {
        guard let index = index else { return nil }
        let k = ChannelLogoProvider.key(name)
        guard k.count >= 2 else { return nil }
        if let url = index[k] { return url }
        if k.hasSuffix("hd"), let url = index[String(k.dropLast(2))] { return url }
        if let url = index[k + "hd"] { return url }
        // Regional variants: "tvp3bydgoszcz" → "tvp3".
        let prefix = index.keys.filter { $0.count >= 4 && k.hasPrefix($0) }.max { $0.count < $1.count }
        return prefix.flatMap { index[$0] }
    }

    private var cacheFile: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("tvlogos-\(folders.joined(separator: "+")).json")
    }

    private func loadIndex(_ done: @escaping () -> Void) {
        if index != nil { return done() }
        waiting.append(done)
        guard !loading else { return }
        loading = true

        if let attrs = try? FileManager.default.attributesOfItem(atPath: cacheFile.path),
           let modified = attrs[.modificationDate] as? Date, Date().timeIntervalSince(modified) < ChannelLogoProvider.cacheTTL,
           let data = try? Data(contentsOf: cacheFile),
           let cached = try? JSONDecoder().decode([String: String].self, from: data) {
            return finish(cached)
        }

        let folders = self.folders
        let group = DispatchGroup()
        var listings = [String: [[String: Any]]]()
        let lock = NSLock()
        for folder in folders {
            guard let url = URL(string: ChannelLogoProvider.listingURL + folder) else { continue }
            group.enter()
            URLSession.shared.dataTask(with: url) { data, response, _ in
                defer { group.leave() }
                guard (response as? HTTPURLResponse)?.statusCode == 200, let data = data,
                      let list = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
                    print("Logo index: no listing for \(folder)")
                    return
                }
                lock.lock()
                listings[folder] = list
                lock.unlock()
            }.resume()
        }
        group.notify(queue: .main) {
            var index = [String: String]()
            // Country specific entries win over international ones.
            for folder in folders {
                for entry in listings[folder] ?? [] {
                    guard let file = entry["name"] as? String, file.hasSuffix(".png"),
                          let url = entry["download_url"] as? String else { continue }
                    var parts = String(file.dropLast(4)).components(separatedBy: "-")
                    if parts.count > 1, let last = parts.last, last.count <= 4 {
                        parts.removeLast()   // country suffix: "-pl", "-uk", "-int"
                    }
                    let key = ChannelLogoProvider.key(parts.joined())
                    if !key.isEmpty { index[key] = url }
                }
            }
            if !index.isEmpty, let data = try? JSONEncoder().encode(index) {
                try? data.write(to: self.cacheFile)
            }
            self.finish(index)
        }
    }

    private func finish(_ index: [String: String]) {
        self.index = index
        loading = false
        let callbacks = waiting
        waiting.removeAll()
        callbacks.forEach { $0() }
    }

    private static let nameImages = NSCache<NSString, UIImage>()

    /// Channel name drawn as a logo, used when no logo image exists.
    static func nameImage(for name: String) -> UIImage? {
        let text = name.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, text != "<n/a>" else { return nil }
        if let cached = nameImages.object(forKey: text as NSString) { return cached }
        let size = CGSize(width: 480, height: 270)
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            paragraph.lineBreakMode = .byWordWrapping
            var fontSize: CGFloat = 96
            var attributes: [NSAttributedString.Key: Any] = [:]
            var bounds = CGRect.zero
            repeat {
                attributes = [.font: UIFont.systemFont(ofSize: fontSize, weight: .heavy),
                              .foregroundColor: UIColor.white, .paragraphStyle: paragraph]
                bounds = (text as NSString).boundingRect(with: CGSize(width: size.width - 40, height: .greatestFiniteMagnitude),
                                                         options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
                fontSize -= 6
            } while bounds.height > size.height - 40 && fontSize > 24
            let rect = CGRect(x: 20, y: (size.height - bounds.height) / 2, width: size.width - 40, height: bounds.height)
            (text as NSString).draw(with: rect, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
        }
        nameImages.setObject(image, forKey: text as NSString)
        return image
    }
}

// MARK: - Saved receivers

/// A receiver the user connected to.
struct ReceiverProfile: Codable, Equatable {
    var id: String
    var name: String
    var address: String
    var webPort: String
    var streamPort: String
    var prot: String
    var apitype: String
    var username: String
    var password: String
}

/// The receivers the user connected to ("multi room": living room box, bedroom box, ...).
/// The active one is mirrored into the plain UserDefaults keys that STBAPI and the tvOS Settings bundle use,
/// so switching = writing those keys + STBAPI.restart().
enum ReceiverStore {
    private static let listKey = "receivers"
    private static let activeKey = "activeReceiver"
    private static var uds: UserDefaults { return UserDefaults.standard }

    static var all: [ReceiverProfile] {
        get {
            guard let data = uds.data(forKey: listKey) else { return [] }
            return (try? JSONDecoder().decode([ReceiverProfile].self, from: data)) ?? []
        }
        set {
            uds.set(try? JSONEncoder().encode(newValue), forKey: listKey)
        }
    }

    static var activeID: String? { return uds.string(forKey: activeKey) }

    static var active: ReceiverProfile? {
        let list = all
        return list.first { $0.id == activeID } ?? list.first { $0.address == currentAddress }
    }

    private static var currentAddress: String? {
        guard let address = uds.string(forKey: "stbAddress")?.trimmingCharacters(in: .whitespacesAndNewlines),
              !address.isEmpty, address != "0.0.0.0" else { return nil }
        return address
    }

    /// The connection settings currently in the UserDefaults keys.
    private static func fromDefaults(id: String, name: String, address: String) -> ReceiverProfile {
        func value(_ key: String, _ fallback: String) -> String {
            let v = uds.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return v.isEmpty ? fallback : v
        }
        return ReceiverProfile(id: id, name: name, address: address,
                               webPort: value("stbPort2", "80"), streamPort: value("stbPort", "8001"),
                               prot: value("stbProt", "http").lowercased(), apitype: uds.bool(forKey: "oldapi") ? "web" : "api",
                               username: uds.string(forKey: "username") ?? "", password: uds.string(forKey: "password") ?? "")
    }

    /// Keeps the list in step with the UserDefaults keys: creates the first entry for a receiver configured by
    /// an older version, and takes over edits made in the Settings tab or the tvOS Settings app.
    static func syncActiveFromDefaults() {
        guard let address = currentAddress else { return }
        var list = all
        if let index = list.firstIndex(where: { $0.id == activeID }), list[index].address == address {
            list[index] = fromDefaults(id: list[index].id, name: list[index].name, address: address)
        } else if let index = list.firstIndex(where: { $0.address == address }) {
            // Address switched to another saved receiver (e.g. typed in the Settings app).
            list[index] = fromDefaults(id: list[index].id, name: list[index].name, address: address)
            uds.set(list[index].id, forKey: activeKey)
        } else if let index = list.firstIndex(where: { $0.id == activeID }) {
            // The active receiver's address was edited.
            list[index] = fromDefaults(id: list[index].id, name: list[index].name, address: address)
        } else {
            let profile = fromDefaults(id: UUID().uuidString, name: address, address: address)
            list.append(profile)
            uds.set(profile.id, forKey: activeKey)
        }
        if list != all { all = list }
    }

    /// Adds a receiver found by discovery (or refreshes its name) and returns it. Not activated.
    @discardableResult
    static func add(name: String, address: String, apitype: String) -> ReceiverProfile {
        var list = all
        if let index = list.firstIndex(where: { $0.address == address }) {
            // Keep a name the user chose; replace one that was just the address.
            if list[index].name == address, !name.isEmpty { list[index].name = name }
            list[index].apitype = apitype
            all = list
            return list[index]
        }
        let profile = ReceiverProfile(id: UUID().uuidString, name: name.isEmpty ? address : name, address: address,
                                      webPort: "80", streamPort: "8001", prot: "http", apitype: apitype,
                                      username: "", password: "")
        list.append(profile)
        all = list
        return profile
    }

    /// Makes `profile` the receiver the app talks to. Callers restart the player afterwards.
    static func activate(_ profile: ReceiverProfile) {
        let previous = active?.id
        if previous != profile.id {
            // Each receiver has its own channel list – remember the last channel per receiver.
            for key in ["lastService", "lastBouquet"] {
                if let previous = previous { uds.set(uds.string(forKey: key), forKey: "\(key).\(previous)") }
                uds.set(uds.string(forKey: "\(key).\(profile.id)"), forKey: key)
            }
        }
        uds.set(profile.address, forKey: "stbAddress")
        uds.set(profile.webPort, forKey: "stbPort2")
        uds.set(profile.streamPort, forKey: "stbPort")
        uds.set(profile.prot, forKey: "stbProt")
        uds.set(profile.apitype == "web", forKey: "oldapi")
        uds.set(profile.username, forKey: "username")
        uds.set(profile.password, forKey: "password")
        uds.set(profile.id, forKey: activeKey)
        STBAPI.restart()
    }

    static func rename(_ profile: ReceiverProfile, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        all = all.map { $0.id == profile.id ? { var p = $0; p.name = trimmed; return p }($0) : $0 }
    }

    /// Names the active receiver after its model once known, unless the user named it.
    static func adoptName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let profile = active, profile.name == profile.address else { return }
        rename(profile, to: trimmed)
    }

    static func remove(_ profile: ReceiverProfile) {
        all = all.filter { $0.id != profile.id }
    }
}
