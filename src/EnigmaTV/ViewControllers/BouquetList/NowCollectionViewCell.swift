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

    override func awakeFromNib() {
        super.awakeFromNib()
        // The system focus effect only enlarges the image – invisible on logo tiles (padded logo on a coloured
        // background), so the tiles looked dead. Lift the whole tile instead.
        poster.adjustsImageWhenAncestorFocused = false
        poster.layer.cornerRadius = 12
        poster.layer.cornerCurve = .continuous
        poster.clipsToBounds = true
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 18)
        layer.shadowRadius = 24
        layer.shadowOpacity = 0
        clipsToBounds = false
        applyFocus(false)
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations({ self.applyFocus(self.isFocused) }, completion: nil)
    }

    private func applyFocus(_ focused: Bool) {
        transform = focused ? CGAffineTransform(scaleX: 1.08, y: 1.08) : .identity
        layer.shadowOpacity = focused ? 0.6 : 0
        layer.zPosition = focused ? 1 : 0
        label.textColor = focused ? .white : UIColor(white: 1, alpha: 0.7)
    }

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
        self.label.text = service.displayName ?? ""
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
        // Without EPG OpenWebif sends "N/A" – show the channel name rather than that.
        self.label.text = e.hasData ? e.title : service.displayName ?? ""
        poster.cancelPicon()   // a logo requested before the EPG arrived must not land on the artwork tile
        poster.image = UIImage(named: "poster_placeholder2")

        self.time.text = e.getBeginTimeString()
        self.duration.text = L("%d min", e.durationMinutes)
        progress.progress = e.getProgress()

        let hasEPG = e.hasData
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
