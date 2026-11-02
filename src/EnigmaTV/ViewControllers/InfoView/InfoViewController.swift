//
//  InfoViewController.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 18.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit
import SDWebImage

/// Info overlay over the player: a Liquid Glass card with channel, programme, timeline and next
/// programme, plus a clock pill. Swiping left/right on the remote scrubs within the timeshift buffer.
class InfoViewController: UIViewController {

    // Storyboard outlets of the previous layout. The storyboard still connects them; the views are
    // replaced by the code-built layout below and these stay unused.
    @IBOutlet weak var day: UILabel!
    @IBOutlet weak var month: UILabel!
    @IBOutlet weak var year: UILabel!
    @IBOutlet weak var hour: UILabel!
    @IBOutlet weak var top: NSLayoutConstraint!
    @IBOutlet weak var bottom: UIView!
    @IBOutlet weak var picon: UIImageView!
    @IBOutlet weak var pvrInfo: UILabel!
    @IBOutlet weak var serviceName: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var current_time: UILabel!
    @IBOutlet weak var nowHourLabel: UILabel!
    @IBOutlet weak var nowNameLabel: UILabel!
    @IBOutlet weak var nextHourLabel: UILabel!
    @IBOutlet weak var nextNameLabel: UILabel!
    @IBOutlet weak var recordingTimeBar: UIImageView!
    @IBOutlet weak var currentBar: UIImageView!
    @IBOutlet weak var currenttimeIndicator: UIImageView!
    @IBOutlet weak var nextBar: UIImageView!
    @IBOutlet var textslabels: [UILabel]!

    var delegate:ViewController?
    var edp:InfoViewDataProviderDelegate?{
        didSet{
            self.configure()
        }
    }

    var movie:Movie?
    /// Live channel being shown (for the logo); nil for recordings.
    var service:Service?

    private static var autoHide: TimeInterval {
        #if DEBUG
        let override = UserDefaults.standard.double(forKey: "EnigmaOverlaySeconds")
        if override > 0 { return override }
        #endif
        return 6
    }

    // MARK: Views

    private let card = Glass.panel()
    private let clockPill = Glass.panel(cornerRadius: 34)
    private let logo = UIImageView()
    private let channelLabel = Glass.label(.headline, weight: .semibold, color: Glass.secondaryText)
    private let badge = PaddedLabel()
    private let titleLabel = Glass.label(.title2, weight: .semibold)
    private let timesLabel = Glass.label(.callout, color: Glass.secondaryText)
    private let nextLabel = Glass.label(.callout, color: Glass.secondaryText)
    private let clockLabel = Glass.label(.title3, weight: .semibold)
    private let dateTextLabel = Glass.label(.callout, color: Glass.secondaryText)
    private let timeline = TimelineView()

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        // Drop the storyboard layout (gesture recognizers on `view` stay connected).
        view.subviews.forEach { $0.removeFromSuperview() }
        view.backgroundColor = .clear
        buildLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateClock()
        card.alpha = 0
        card.transform = CGAffineTransform(translationX: 0, y: 60)
        clockPill.alpha = 0
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        configure()
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0, options: [], animations: {
            self.card.alpha = 1
            self.card.transform = .identity
            self.clockPill.alpha = 1
        })
        scheduleHide()
    }

    private func scheduleHide() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hide), object: nil)
        perform(#selector(hide), with: nil, afterDelay: InfoViewController.autoHide)
    }

    @objc func hide(){
        UIView.animate(withDuration: 0.25, animations: {
            self.card.alpha = 0
            self.card.transform = CGAffineTransform(translationX: 0, y: 40)
            self.clockPill.alpha = 0
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
        })
    }

    // MARK: Layout

    private func buildLayout() {
        let scrim = GradientView(colors: [.clear, UIColor(white: 0, alpha: 0.55)])
        scrim.translatesAutoresizingMaskIntoConstraints = false
        scrim.isUserInteractionEnabled = false
        view.addSubview(scrim)
        view.addSubview(card)
        view.addSubview(clockPill)

        logo.translatesAutoresizingMaskIntoConstraints = false
        logo.contentMode = .scaleAspectFit
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        badge.textColor = .white
        badge.layer.cornerRadius = 10
        badge.layer.cornerCurve = .continuous
        badge.clipsToBounds = true
        titleLabel.lineBreakMode = .byTruncatingTail
        timesLabel.textAlignment = .right
        timesLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        timeline.translatesAutoresizingMaskIntoConstraints = false

        let channelRow = UIStackView(arrangedSubviews: [channelLabel, badge, UIView()])
        channelRow.spacing = 18
        channelRow.alignment = .center
        let titleRow = UIStackView(arrangedSubviews: [titleLabel, timesLabel])
        titleRow.spacing = 30
        titleRow.alignment = .lastBaseline
        let text = UIStackView(arrangedSubviews: [channelRow, titleRow])
        text.axis = .vertical
        text.spacing = 6
        let header = UIStackView(arrangedSubviews: [logo, text])
        header.spacing = 36
        header.alignment = .center
        let content = UIStackView(arrangedSubviews: [header, timeline, nextLabel])
        content.axis = .vertical
        content.spacing = 22
        content.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(content)

        let clock = UIStackView(arrangedSubviews: [clockLabel, dateTextLabel])
        clock.spacing = 16
        clock.alignment = .firstBaseline
        clock.translatesAutoresizingMaskIntoConstraints = false
        clockPill.contentView.addSubview(clock)

        NSLayoutConstraint.activate([
            scrim.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrim.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrim.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrim.heightAnchor.constraint(equalToConstant: 520),

            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Glass.margin),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Glass.margin),
            card.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -60),
            content.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 36),
            content.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -34),
            content.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 44),
            content.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -44),
            logo.widthAnchor.constraint(equalToConstant: 200),
            logo.heightAnchor.constraint(equalToConstant: 112),
            timeline.heightAnchor.constraint(equalToConstant: 64),

            clockPill.topAnchor.constraint(equalTo: view.topAnchor, constant: 60),
            clockPill.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Glass.margin),
            clock.topAnchor.constraint(equalTo: clockPill.contentView.topAnchor, constant: 16),
            clock.bottomAnchor.constraint(equalTo: clockPill.contentView.bottomAnchor, constant: -16),
            clock.leadingAnchor.constraint(equalTo: clockPill.contentView.leadingAnchor, constant: 32),
            clock.trailingAnchor.constraint(equalTo: clockPill.contentView.trailingAnchor, constant: -32),
        ])
    }

    private func updateClock() {
        let now = Date()
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("HH:mm")
        clockLabel.text = formatter.string(from: now)
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMM")
        dateTextLabel.text = formatter.string(from: now)
    }

    // MARK: Content

    private var isRecording: Bool { return edp is MovieDataProvider }

    /// Timeline range: the running programme, else the timeshift buffer / recording length.
    private var range: (start: UInt64, end: UInt64)? {
        guard let edp = edp else { return nil }
        if let event = edp.getCurrentEvent(), let begin = event.begin_timestamp, let duration = event.duration_sec, duration > 0 {
            return (begin, begin + duration)
        }
        let start = edp.getTimeshiftStartTime(), end = edp.getTimeshiftStopTime()
        return end > start ? (start, end) : nil
    }

    func configure(){
        DispatchQueue.main.async {
            guard self.isViewLoaded, let edp = self.edp else { return }
            // The timeshift position (and with it the programme) changes while the overlay is up.
            (edp as? TimeshiftDataProvider)?.refresh()
            let event = edp.getCurrentEvent()
            let recording = (edp as? MovieDataProvider)?.movie

            let name = edp.getServiceName()
            self.channelLabel.text = name.isEmpty ? (self.service?.displayName ?? "") : name
            self.titleLabel.text = event?.title ?? recording?.eventname ?? self.service?.displayName ?? name

            if let event = event, let begin = event.begin_timestamp {
                let end = EpgEvent()
                end.begin_timestamp = begin + (event.duration_sec ?? 0)
                self.timesLabel.text = "\(event.getBeginTimeString()) – \(end.getBeginTimeString()) · " + L("%d min", event.durationMinutes)
            } else if let recording = recording {
                self.timesLabel.text = recording.length.map { L("%@ min", $0) }
            } else {
                self.timesLabel.text = nil
            }

            if let next = edp.getNextEvent(), let title = next.title {
                self.nextLabel.text = L("Next   %@  %@", next.getBeginTimeString(), title)
            } else {
                self.nextLabel.text = nil
            }

            if let service = self.service {
                self.logo.setPicon(for: service)
            } else if !name.isEmpty {
                let byName = Service()
                byName.servicename = name
                self.logo.setPicon(for: byName)
            } else {
                self.logo.image = nil
            }
            self.updateTimeline()
        }
    }

    private func updateTimeline(position: UInt64? = nil) {
        guard let edp = edp, let range = range else {
            timeline.isHidden = true
            badge.isHidden = true
            return
        }
        timeline.isHidden = false
        let span = Double(range.end - range.start)
        func fraction(_ t: UInt64) -> CGFloat {
            return CGFloat(min(max((Double(t) - Double(range.start)) / span, 0), 1))
        }
        let current = position ?? edp.getCurrentTime()
        let real = edp.getRealTime()
        timeline.played = fraction(current)
        if edp.shouldDisplayTimeshiftInfo() {
            timeline.buffered = (fraction(edp.getTimeshiftStartTime()), fraction(isRecording ? range.end : edp.getTimeshiftStopTime()))
        } else {
            timeline.buffered = nil
        }
        timeline.positionText = isRecording ? InfoViewController.duration(current) : InfoViewController.clock(current)

        if isRecording {
            badge.isHidden = true
        } else {
            let delay = real > current ? real - current : 0
            badge.isHidden = false
            if delay < 8 {
                badge.text = L("LIVE")
                badge.backgroundColor = UIColor.systemRed
            } else {
                badge.text = "−" + InfoViewController.duration(delay)
                badge.backgroundColor = UIColor(white: 1, alpha: 0.22)
            }
        }
    }

    private static func clock(_ time: UInt64) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("HH:mm")
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(time)))
    }

    private static func duration(_ seconds: UInt64) -> String {
        let s = Int(seconds)
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: Remote

    @IBAction func tapPLay(_ sender: Any) {
        delegate?.playPausePressed(sender)
        scheduleHide()
    }
    @IBAction func tapLeft(_ sender: Any) {
        delegate?.tapLeft(sender)
    }

    @IBAction func tapRight(_ sender: Any) {
        delegate?.tapRight(sender)
    }

    func piconSetup(name:String){
        configure()
    }

    // Scrubbing: horizontal swipes on the touch surface move the position within the range.
    private var scrubStart: CGFloat?
    private var scrubTouchX: CGFloat?
    private var scrubTime: UInt64?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let edp = edp, edp.shouldDisplayTimeshiftInfo(), let touch = touches.first else { return }
        scrubStart = timeline.played
        scrubTouchX = touch.location(in: view).x
        scrubTime = nil
        scheduleHide()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let edp = edp, let range = range, let start = scrubStart, let x0 = scrubTouchX, let touch = touches.first else { return }
        // A full swipe across the touch surface (~1920 pt) moves a third of the range.
        let delta = (touch.location(in: view).x - x0) / view.bounds.width / 3
        var target = min(max(start + delta, 0), 1)
        if let window = timeline.buffered {
            target = min(max(target, window.start), window.end)
        }
        let time = range.start + UInt64(Double(target) * Double(range.end - range.start))
        scrubTime = time
        updateTimeline(position: min(time, edp.getRealTime()))
        scheduleHide()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer {
            scrubStart = nil
            scrubTouchX = nil
            scrubTime = nil
        }
        guard let edp = edp, let time = scrubTime else { return }
        edp.jumpTo(time)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.configure() }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        scrubStart = nil
        scrubTouchX = nil
        scrubTime = nil
        updateTimeline()
    }
}

/// Progress track with optional buffered range, played part and a position knob with time label.
private final class TimelineView: UIView {
    var played: CGFloat = 0 { didSet { setNeedsLayout() } }
    var buffered: (start: CGFloat, end: CGFloat)? { didSet { setNeedsLayout() } }
    var positionText: String? {
        get { return timeLabel.text }
        set { timeLabel.text = newValue }
    }

    private let track = UIView()
    private let bufferedView = UIView()
    private let playedView = UIView()
    private let knob = UIView()
    private let timeLabel = Glass.label(.caption1, weight: .semibold)
    private let trackHeight: CGFloat = 10

    override init(frame: CGRect) {
        super.init(frame: frame)
        track.backgroundColor = UIColor(white: 1, alpha: 0.18)
        bufferedView.backgroundColor = UIColor(white: 1, alpha: 0.32)
        playedView.backgroundColor = .white
        knob.backgroundColor = .white
        knob.layer.shadowColor = UIColor.black.cgColor
        knob.layer.shadowOpacity = 0.35
        knob.layer.shadowRadius = 8
        knob.layer.shadowOffset = .zero
        for v in [track, bufferedView, playedView] {
            v.layer.cornerRadius = trackHeight / 2
            addSubview(v)
        }
        knob.layer.cornerRadius = 14
        addSubview(knob)
        timeLabel.translatesAutoresizingMaskIntoConstraints = true
        timeLabel.textAlignment = .center
        addSubview(timeLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let y = bounds.height - trackHeight - 8
        let width = bounds.width
        track.frame = CGRect(x: 0, y: y, width: width, height: trackHeight)
        if let buffered = buffered {
            bufferedView.isHidden = false
            bufferedView.frame = CGRect(x: width * buffered.start, y: y, width: width * max(buffered.end - buffered.start, 0), height: trackHeight)
        } else {
            bufferedView.isHidden = true
        }
        playedView.frame = CGRect(x: 0, y: y, width: width * played, height: trackHeight)
        knob.frame = CGRect(x: width * played - 14, y: y + trackHeight / 2 - 14, width: 28, height: 28)
        timeLabel.sizeToFit()
        let labelWidth = timeLabel.bounds.width + 8
        let x = min(max(width * played - labelWidth / 2, 0), width - labelWidth)
        timeLabel.frame = CGRect(x: x, y: 0, width: labelWidth, height: timeLabel.bounds.height)
    }
}

/// Label with padding, used for the LIVE / −mm:ss badge.
private final class PaddedLabel: UILabel {
    private let insets = UIEdgeInsets(top: 4, left: 14, bottom: 4, right: 14)

    override func drawText(in rect: CGRect) {
        super.drawText(in: CGRect(x: rect.minX + insets.left, y: rect.minY + insets.top,
                                  width: rect.width - insets.left - insets.right,
                                  height: rect.height - insets.top - insets.bottom))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom)
    }
}

/// Vertical gradient (top → bottom) used as a scrim behind overlay content.
private final class GradientView: UIView {
    override class var layerClass: AnyClass { return CAGradientLayer.self }

    init(colors: [UIColor]) {
        super.init(frame: .zero)
        (layer as? CAGradientLayer)?.colors = colors.map { $0.cgColor }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
