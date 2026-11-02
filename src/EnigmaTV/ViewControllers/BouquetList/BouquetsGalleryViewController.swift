//
//  BouquetsGalleryViewController.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 26/05/2020.
//  Copyright © 2020 Blazej Zyglarski. All rights reserved.
//

import UIKit

class BouquetsGalleryViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    static let sectionHeaderElementKind = "section-header-element-kind"
    var servicelist:Servicelist?
    var servicechannels = [String:Servicelist]()
    /// Currently running event per service reference.
    var events = [String:EpgEvent]()
    /// Bouquets whose receiver does not support `epgnownext` – EPG is then loaded per channel.
    private var perChannelEPG = Set<String>()
    private var requestedEPG = Set<String>()

    @IBOutlet weak var bg: UIImageView!
    @IBOutlet weak var cv: UICollectionView!

    private func bouquet(at section: Int) -> Service? {
        guard let services = servicelist?.services, section < services.count else { return nil }
        return services[section]
    }

    private func channels(of bouquet: Service?) -> [Service] {
        guard let ref = bouquet?.servicereference else { return [] }
        return servicechannels[ref]?.services ?? []
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return channels(of: bouquet(at: section)).count
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let indexPath = cv.indexPathsForSelectedItems?.first,
              let c = cv.cellForItem(at: indexPath) as? NowCollectionViewCell,
              let ds = segue.destination as? TVEventViewController,
              let s = c.service, let b = c.bouquet else { return }
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "bouquetPrepared"), object: ["service":s, "bouquet": b], userInfo: ["direction":0])
        let event = c.event ?? EpgEvent()
        event.sref = event.sref ?? s.servicereference
        ds.configure(s: s, b: b, e: event)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let x = collectionView.dequeueReusableCell(withReuseIdentifier: "movieCell", for: indexPath) as! NowCollectionViewCell
        let b = bouquet(at: indexPath.section)
        let list = channels(of: b)
        guard let bouquet = b, indexPath.row < list.count else { return x }
        let chan = list[indexPath.row]

        if let sref = chan.servicereference, let event = events[sref] {
            x.setup(e: event, service: chan, bouquet: bouquet)
        } else {
            x.setup(service: chan, bouquet: bouquet)
            loadEPGIfNeeded(for: chan, in: bouquet)
        }
        return x
    }

    /// Fallback for receivers without `epgnownext`: one request per channel, once.
    private func loadEPGIfNeeded(for service: Service, in bouquet: Service) {
        guard let bref = bouquet.servicereference, perChannelEPG.contains(bref),
              let sref = service.servicereference, !requestedEPG.contains(sref) else { return }
        requestedEPG.insert(sref)
        STBAPI.common()?.getEPG(for: service, from: 0, to: 0) { [weak self] events, _ in
            guard let self = self, let now = events.first else { return }
            self.events[sref] = now
            self.reload(service: sref, in: bouquet)
        }
    }

    private func loadBouquetEPG(_ bouquet: Service) {
        guard let bref = bouquet.servicereference else { return }
        STBAPI.common()?.getBouquetNowNext(bouquet: bouquet) { [weak self] nowNext in
            guard let self = self else { return }
            guard let nowNext = nowNext else {
                self.perChannelEPG.insert(bref)
                self.reloadSection(of: bouquet)
                return
            }
            for (sref, pair) in nowNext {
                self.events[sref] = pair.0
            }
            self.reloadSection(of: bouquet)
        }
    }

    private func section(of bouquet: Service) -> Int? {
        return servicelist?.services?.firstIndex(where: { $0.servicereference == bouquet.servicereference })
    }

    private func reloadSection(of bouquet: Service) {
        guard let section = section(of: bouquet), section < cv.numberOfSections else {
            cv.reloadData()
            return
        }
        cv.reloadSections(IndexSet(integer: section))
    }

    private func reload(service sref: String, in bouquet: Service) {
        guard let section = section(of: bouquet),
              let row = channels(of: bouquet).firstIndex(where: { $0.servicereference == sref }),
              section < cv.numberOfSections, row < cv.numberOfItems(inSection: section) else { return }
        cv.reloadItems(at: [IndexPath(row: row, section: section)])
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return servicelist?.services?.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let x = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath) as! HeaderView
        x.label.text = bouquet(at: indexPath.section)?.servicename ?? "Bukiet"
        return x
    }

    func collectionView(_ collectionView: UICollectionView, canFocusItemAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        cv.register(
            HeaderView.self,
            forSupplementaryViewOfKind: BouquetsGalleryViewController.sectionHeaderElementKind,
            withReuseIdentifier: HeaderView.reuseIdentifier)

        cv.collectionViewLayout = ScrollableSectionCollectionViewLayout.create()
        STBAPI.common()?.getServices(cb: { [weak self] slist in
            guard let self = self else { return }
            self.servicelist = slist
            self.cv.reloadData()
            for s in slist.services ?? [] {
                guard let bref = s.servicereference else { continue }
                STBAPI.common()?.getServices(for: s, cb: { [weak self] channelslist in
                    guard let self = self else { return }
                    self.servicechannels[bref] = channelslist
                    self.reloadSection(of: s)
                    self.loadBouquetEPG(s)
                }, fail: {
                    print("Could not load channels of \(s.servicename ?? bref)")
                })
            }
        }, fail: {
            print("Could not load bouquets")
        })
    }

}
