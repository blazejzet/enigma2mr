//
//  NowCollectionViewCell.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 27/05/2020.
//  Copyright © 2020 Blazej Zyglarski. All rights reserved.
//

import UIKit

class NowCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var poster: UIImageView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var progress: UIProgressView!

    @IBOutlet weak var duration: UILabel!
    @IBOutlet weak var time: UILabel!
    @IBOutlet weak var channnel: UIImageView!
    var sref:String = ""
    var service:Service?
    var bouquet:Service?
    var event: EpgEvent?

    override func prepareForReuse() {
        super.prepareForReuse()
        event = nil
        service = nil
        poster.cancelPicon()
        channnel.cancelPicon()
    }

    /// Channel without (loaded) EPG yet.
    func setup(service:Service, bouquet:Service){
        self.event = nil
        self.service = service
        self.bouquet = bouquet
        self.sref = service.servicereference ?? ""
        self.label.text = service.servicename
        progress.alpha = 0.0
        time.alpha = 0.0
        duration.alpha = 0.0
        showLogo(of: service)
        channnel.setPicon(for: service)
    }

    /// Channel logo (or name) on the big tile – used when there is no programme artwork.
    private func showLogo(of service: Service) {
        poster.contentMode = .scaleAspectFit
        poster.backgroundColor = UIColor(red: 0.16, green: 0.14, blue: 0.32, alpha: 1)
        poster.setPicon(for: service, padding: 0.2)
    }

    func setup(e:EpgEvent,service:Service,bouquet:Service){
        self.event = e
        self.service = service
        self.bouquet = bouquet
        self.sref = service.servicereference ?? e.sref ?? ""
        self.label.text = e.title ?? service.servicename
        poster.cancelPicon()   // a logo requested before the EPG arrived must not land on the artwork tile
        poster.image = UIImage(named: "poster_placeholder2")

        self.time.text = e.getBeginTimeString()
        self.duration.text = "\(e.durationMinutes) min."
        progress.progress = e.getProgress()

        let hasEPG = !(e.title ?? "").isEmpty && e.title != "N/A" && e.begin_timestamp != nil
        progress.alpha = hasEPG ? 1.0 : 0.0
        time.alpha = hasEPG ? 1.0 : 0.0
        duration.alpha = hasEPG ? 1.0 : 0.0
        self.poster.contentMode = .scaleAspectFill
        self.poster.backgroundColor = hasEPG ? .clear : .black

        self.channnel.setPicon(for: service)

        guard hasEPG, let title = e.title else {
            showLogo(of: service)
            return
        }
        let key = Int(e.begin_timestamp ?? 0)
        STBAPI.common()?.searchInfoWeb(title: title, duration: e.durationMinutes, eid: key) {
            image, backdrop, eid, ok in
            DispatchQueue.main.async {
                // Cells are reused – only apply artwork for the event still shown.
                guard self.event === e else { return }
                if ok, let artwork = backdrop ?? image {
                    self.poster.cancelPicon()
                    self.poster.contentMode = .scaleAspectFill
                    self.poster.backgroundColor = .clear
                    self.poster.image = artwork
                } else {
                    // TMDB has nothing for this programme – show the channel instead of an empty tile.
                    self.showLogo(of: service)
                }
            }
        }
    }
}
