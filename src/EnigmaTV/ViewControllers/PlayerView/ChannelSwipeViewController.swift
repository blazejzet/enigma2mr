//
//  ChannelSwipeViewController.swift
//  EnigmaTV
//
//  Created by Damian Skarżyński on 13/01/2020.
//  Copyright © 2020 Blazej Zyglarski. All rights reserved.
//

import UIKit

/// Previous / next channel over the player: two Liquid Glass capsules with a round chevron button
/// and a preview of the neighbouring channel (logo, name, programme now on air).
class ChannelSwipeViewController: UIViewController{


    @IBOutlet weak var arrowLeft: UIButton!
    @IBOutlet weak var arrowRight: UIButton!

    // Storyboard logo views of the previous layout – replaced by the previews below.
    @IBOutlet weak var piconRight: UIImageView!
    @IBOutlet weak var piconLeft: UIImageView!


    var initialDirection: Direction?
    var service: Service?
    var bouquet: Service?
    var services = [Service]()

    private let leftPanel = Glass.panel(cornerRadius: 100)
    private let rightPanel = Glass.panel(cornerRadius: 100)
    private let leftPreview = ChannelPreview()
    private let rightPreview = ChannelPreview()

    private static let panelSize = CGSize(width: 620, height: 200)
    private static let arrowSize: CGFloat = 104


    override func viewDidLoad() {
        super.viewDidLoad()

        piconLeft.isHidden = true
        piconRight.isHidden = true
        for (panel, preview) in [(leftPanel, leftPreview), (rightPanel, rightPreview)] {
            panel.translatesAutoresizingMaskIntoConstraints = true
            panel.isUserInteractionEnabled = false
            panel.contentView.addSubview(preview)
            // Just above the full-screen backdrop image, below both arrows.
            view.insertSubview(panel, at: min(1, view.subviews.count))
        }
        style(arrowLeft, symbol: "chevron.left")
        style(arrowRight, symbol: "chevron.right")

        switch initialDirection{
        case .Left:
            arrowRight.isEnabled = false

        case .Right:
            arrowLeft.isEnabled = false

        default:
            break

        }

        if let bref = bouquet?.servicereference {
            DataProvider.def().getServices(bref: bref){ list in
                self.services = list
                self.setIcons()
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = ChannelSwipeViewController.panelSize
        let arrow = ChannelSwipeViewController.arrowSize
        let y = (view.bounds.height - size.height) / 2
        let inset: CGFloat = 48

        leftPanel.frame = CGRect(x: Glass.margin, y: y, width: size.width, height: size.height)
        rightPanel.frame = CGRect(x: view.bounds.width - Glass.margin - size.width, y: y, width: size.width, height: size.height)

        // Arrows sit on the outer side of each capsule.
        arrowLeft.translatesAutoresizingMaskIntoConstraints = true
        arrowRight.translatesAutoresizingMaskIntoConstraints = true
        arrowLeft.frame = CGRect(x: leftPanel.frame.minX + inset, y: leftPanel.frame.midY - arrow / 2, width: arrow, height: arrow)
        arrowRight.frame = CGRect(x: rightPanel.frame.maxX - inset - arrow, y: rightPanel.frame.midY - arrow / 2, width: arrow, height: arrow)

        let previewWidth = size.width - inset - arrow - 32 - inset
        leftPreview.frame = CGRect(x: inset + arrow + 32, y: 0, width: previewWidth, height: size.height)
        rightPreview.frame = CGRect(x: inset, y: 0, width: previewWidth, height: size.height)
    }

    /// Round chevron button: translucent normally, white with a dark chevron when focused (tvOS style).
    private func style(_ button: UIButton, symbol: String) {
        button.clipsToBounds = false
        button.layer.cornerRadius = ChannelSwipeViewController.arrowSize / 2
        button.setTitle(nil, for: .normal)
        var configuration = UIButton.Configuration.filled()
        configuration.cornerStyle = .capsule
        configuration.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 34, weight: .bold))
        button.configuration = configuration
        button.configurationUpdateHandler = { button in
            var configuration = button.configuration
            let focused = button.isFocused
            configuration?.baseBackgroundColor = focused ? .white : UIColor(white: 1, alpha: 0.16)
            configuration?.baseForegroundColor = focused ? UIColor(white: 0.08, alpha: 1) : .white
            button.configuration = configuration
            button.alpha = button.isEnabled ? 1 : 0.35
        }
        button.setNeedsUpdateConfiguration()
    }

    func setIcons(){
        guard let service = service else { return }
        let provider = DataProvider.def()
        leftPreview.show(provider.neighbour(of: service, in: services, offset: -1))
        rightPreview.show(provider.neighbour(of: service, in: services, offset: 1))
    }

    private func switchChannel(offset: Int) {
        guard let current = service, let bouquet = bouquet,
              let next = DataProvider.def().neighbour(of: current, in: services, offset: offset) else { return }
        self.service = next
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "setMainPlayer"), object: nil, userInfo: ["service": next, "bouquet": bouquet, "direction": offset])
        setIcons()
    }

    @IBAction func leftArrowClicked(_ sender: Any){
        switchChannel(offset: -1)
    }

    @IBAction func rightArrowClicked(_ sender: Any){
        switchChannel(offset: 1)
    }

    @IBAction func swipeRight(_ sender: Any){
        arrowRight.isEnabled = true
        arrowLeft.isEnabled = true
    }

    @IBAction func swipeLeft(_ sender: Any){
        arrowLeft.isEnabled = true
        arrowRight.isEnabled = true
    }

}

/// Logo, name and current programme of a neighbouring channel.
private final class ChannelPreview: UIView {
    private let logo = UIImageView()
    private let name = Glass.label(.callout, weight: .semibold)
    private let now = Glass.label(.caption1, color: Glass.secondaryText)
    private var shownReference: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        logo.contentMode = .scaleAspectFit
        logo.translatesAutoresizingMaskIntoConstraints = false
        for label in [name, now] {
            label.textAlignment = .center
            label.lineBreakMode = .byTruncatingTail
        }
        let stack = UIStackView(arrangedSubviews: [logo, name, now])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 6
        stack.setCustomSpacing(12, after: logo)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            logo.heightAnchor.constraint(equalToConstant: 80),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func show(_ service: Service?) {
        shownReference = service?.servicereference
        logo.setPicon(for: service)
        name.text = service.map { $0.displayName ?? L("Unnamed channel") }
        now.text = nil
        guard let service = service, let reference = service.servicereference else { return }
        STBAPI.common()?.getEPG(for: service, from: 0, to: 0) { [weak self] events, _ in
            guard let self = self, self.shownReference == reference,
                  let title = events.first?.title, title != "N/A", !title.isEmpty else { return }
            self.now.text = title
        }
    }
}
