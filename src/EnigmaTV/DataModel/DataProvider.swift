//
//  DataProvider.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 09/05/2019.
//  Copyright © 2019 Blazej Zyglarski. All rights reserved.
//

import Foundation

/// In-memory cache in front of STBAPI for data that rarely changes while the app runs
/// (bouquets and their channel lists). EPG is always fetched fresh.
/// All callbacks are delivered on the main queue; the cache is only touched from main.
class DataProvider: NSObject {
    private static let instance = DataProvider()

    class func def() -> DataProvider{
        return DataProvider.instance
    }

    private var bouquets: [Service]?
    private var servicesByBouquet = [String: [Service]]()
    /// Bumped by invalidate(); answers to requests started before that are not cached.
    private var generation = 0

    /// Drop everything, e.g. after the receiver or its settings changed.
    func invalidate() {
        generation += 1
        bouquets = nil
        servicesByBouquet.removeAll()
    }

    // MARK: - EPG

    func getEpgForService(sref:String,begin:Int64,end:Int64,cb:@escaping ([EpgEvent])->Void){
        guard let api = STBAPI.common() else {
            cb([])
            return
        }
        api.getEPGEvents(sref: sref, from: UInt64(max(begin, 0)), to: UInt64(max(end, 0)), cb: cb)
    }

    // MARK: - Bouquets

    func getBouquets( cb:@escaping ([Service])->Void){
        if let bouquets = bouquets {
            cb(bouquets)
            return
        }
        guard let api = STBAPI.common() else {
            cb([])
            return
        }
        let generation = self.generation
        api.getServices(cb: { list in
            let bouquets = list.services ?? []
            if generation == self.generation {
                self.bouquets = bouquets
            }
            cb(bouquets)
        }, fail: {
            cb([])
        })
    }

    func getBouquet(bref:String, cb:@escaping ((Service?)->Void)){
        getBouquets { bouquets in
            if let bouquet = bouquets.first(where: { $0.servicereference == bref }) {
                cb(bouquet)
            } else if bouquets.isEmpty {
                // Receiver unreachable or the list failed – still allow resuming by reference.
                let bouquet = Service()
                bouquet.servicereference = bref
                cb(bouquet)
            } else {
                cb(nil)
            }
        }
    }

    // MARK: - Channels

    /// Playable channels of a bouquet (markers removed), `row` set to the index in the returned list.
    func getServices(bref:String,  cb:@escaping (([Service])->Void)){
        if let services = servicesByBouquet[bref] {
            cb(services)
            return
        }
        guard let api = STBAPI.common() else {
            cb([])
            return
        }
        let bouquet = Service()
        bouquet.servicereference = bref
        let generation = self.generation
        api.getServices(for: bouquet, cb: { list in
            let services = list.services ?? []
            if generation == self.generation {
                self.servicesByBouquet[bref] = services
            }
            cb(services)
        }, fail: {
            cb([])
        })
    }

    func getService(bref:String,sref:String,  cb:@escaping ((Service?)->Void)){
        getServices(bref: bref) { services in
            cb(services.first(where: { $0.servicereference == sref }))
        }
    }

    /// First bouquet (in list order) containing `sref`, with the channel from it. Uses the cached lists.
    func findService(sref: String, cb: @escaping (Service?, Service?) -> Void) {
        getBouquets { bouquets in
            func check(_ index: Int) {
                guard index < bouquets.count, let bref = bouquets[index].servicereference else { return cb(nil, nil) }
                self.getServices(bref: bref) { services in
                    if let service = services.first(where: { $0.servicereference == sref }) {
                        cb(service, bouquets[index])
                    } else {
                        check(index + 1)
                    }
                }
            }
            check(0)
        }
    }

    /// Neighbour of `service` in its bouquet, wrapping around. `offset` -1 = previous, +1 = next.
    func neighbour(of service: Service, in services: [Service], offset: Int) -> Service? {
        guard !services.isEmpty else { return nil }
        let index = services.firstIndex(where: { $0.servicereference == service.servicereference }) ?? service.row ?? 0
        let count = services.count
        return services[((index + offset) % count + count) % count]
    }
}
