//
//  MenuTabBarController.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 06/11/2019.
//  Copyright © 2019 Blazej Zyglarski. All rights reserved.
//

import UIKit

class MenuTabBarController: UITabBarController {

    /// Receiver discovery (from the storyboard). Shown as the Settings tab only when no receiver
    /// is configured; otherwise it is opened from Settings → "Search for receivers…".
    private var discovery: SettingsViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        guard var controllers = viewControllers else { return }

        if let index = controllers.firstIndex(where: { $0 is SettingsViewController }) {
            discovery = controllers[index] as? SettingsViewController
            if STBAPI.common()?.isConfigured == true {
                let settings = ReceiverSettingsViewController()
                settings.onSearch = { [weak self] in self?.showDiscovery() }
                let navigation = UINavigationController(rootViewController: settings)
                controllers[index] = navigation
            }
        }

        // Titles by content (the storyboard order is EPG, Settings, Recordings).
        for controller in controllers {
            let content = (controller as? UINavigationController)?.viewControllers.first ?? controller
            switch content {
            case is BouquetsGalleryViewController: controller.tabBarItem.title = "EPG"
            case is Movies2ViewController: controller.tabBarItem.title = L("Recordings")
            case is SettingsViewController, is ReceiverSettingsViewController: controller.tabBarItem.title = L("Settings")
            default: break
            }
        }
        if STBAPI.common()?.isConfigured == true {
            controllers.append(EPGSearchResultsViewController.makeTab())
            controllers.append(RoomsViewController.makeTab())
        }
        // EPG, Recordings, Search, Rooms, Settings – as in the tvOS apps.
        let order: (UIViewController) -> Int = { controller in
            let content = (controller as? UINavigationController)?.viewControllers.first ?? controller
            switch content {
            case is BouquetsGalleryViewController: return 0
            case is Movies2ViewController: return 1
            case is UISearchContainerViewController: return 2
            case is RoomsViewController: return 3
            default: return 4
            }
        }
        controllers.sort { order($0) < order($1) }
        setViewControllers(controllers, animated: false)
    }

    #if DEBUG
    /// Screenshot helper: move focus from the tab bar into the selected screen.
    var debugFocusContent = false

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if debugFocusContent, let content = selectedViewController {
            return [content]
        }
        return super.preferredFocusEnvironments
    }

    func debugFocusIntoContent() {
        debugFocusContent = true
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
        debugFocusContent = false
    }
    #endif

    private func showDiscovery() {
        guard let discovery = discovery else { return }
        discovery.modalPresentationStyle = .overFullScreen
        present(discovery, animated: true)
    }

}

// MARK: - Rooms tab

/// Carries a WatchSession through NotificationCenter (which wants an object).
final class WatchSessionBox: NSObject {
    let session: WatchSession
    init(_ session: WatchSession) { self.session = session }
}

/// Multi room overview: what the other Apple TVs watch, and the state of every saved receiver.
final class RoomsViewController: UITableViewController {
    private var statuses = [String: [String: Any]]()
    private var timer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "row")
        tableView.backgroundColor = .clear
        tableView.rowHeight = 124
        NotificationCenter.default.addObserver(self, selector: #selector(sessionsChanged), name: RoomSync.changed, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        RoomSync.start()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in self?.refresh() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
    }

    @objc private func sessionsChanged() {
        tableView.reloadData()
    }

    private func refresh() {
        for profile in ReceiverStore.all {
            STBAPI.status(of: profile) { [weak self] status in
                self?.statuses[profile.id] = status ?? ["unreachable": true]
                self?.tableView.reloadData()
            }
        }
        tableView.reloadData()
    }

    private var sessions: [WatchSession] { return RoomSync.others }
    private var receivers: [ReceiverProfile] { return ReceiverStore.all }

    override func numberOfSections(in tableView: UITableView) -> Int { return 3 }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return L("This Apple TV")
        case 1: return L("Other Apple TVs")
        default: return L("Receivers")
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == 1, sessions.isEmpty else { return nil }
        return L("Apple TVs signed in to the same iCloud account appear here once they play something with this app.")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1
        case 1: return sessions.count
        default: return receivers.count
        }
    }

    /// "Live · TVP1 · Teleexpress" / "Recording · Film · 42%".
    private func describe(_ session: WatchSession) -> String {
        if session.kind == "recording" {
            return [L("Recording (playing)"), session.title, session.position.map { "\(Int($0 * 100))%" }].compactMap { $0 }.joined(separator: " · ")
        }
        return [L("Live"), session.title, session.programme].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func ago(_ time: TimeInterval) -> String {
        let minutes = Int((Date().timeIntervalSince1970 - time) / 60)
        if minutes < 1 { return L("now") }
        if minutes < 60 { return L("%d min ago", minutes) }
        if minutes < 24 * 60 { return L("%d h ago", minutes / 60) }
        return L("%d d ago", minutes / 1440)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath)
        var content = UIListContentConfiguration.subtitleCell()
        cell.accessoryType = .none
        switch indexPath.section {
        case 0:
            content.text = RoomSync.roomName
            content.secondaryText = RoomSync.mine.map { "\(describe($0)) · \($0.receiverName)" } ?? L("Nothing playing")
        case 1:
            let session = sessions[indexPath.row]
            // Still playing: active and heard from within the last few minutes.
            let live = session.active && Date().timeIntervalSince1970 - session.updated < 5 * 60
            content.text = (live ? "● " : "") + session.room
            content.secondaryText = [describe(session), session.receiverName, live ? nil : ago(session.updated)]
                .compactMap { $0 }.joined(separator: " · ")
        default:
            let profile = receivers[indexPath.row]
            content.text = profile.name
            content.secondaryText = describe(statuses[profile.id], address: profile.address)
            if profile.id == ReceiverStore.active?.id { cell.accessoryType = .checkmark }
        }
        cell.contentConfiguration = content
        return cell
    }

    private func describe(_ status: [String: Any]?, address: String) -> String {
        guard let status = status else { return "\(address) · " + L("Checking…") }
        if status["unreachable"] != nil { return "\(address) · " + L("Not reachable") }
        if (status["inStandby"] as? String) == "true" { return L("status.standby") }
        var parts = [L("status.on")]
        if let station = status["currservice_station"] as? String, !station.isEmpty {
            let programme = (status["currservice_name"] as? String).flatMap { $0 == "N/A" || $0.isEmpty ? nil : $0 }
            parts.append([station, programme].compactMap { $0 }.joined(separator: " – "))
        }
        if (status["isRecording"] as? String) == "true" { parts.append(L("● Recording")) }
        let streams = (status["Streaming_list"] as? String)?.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count ?? 0
        if streams > 0 { parts.append(streams == 1 ? L("1 stream") : L("%d streams", streams)) }
        return parts.joined(separator: " · ")
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            let alert = UIAlertController(title: L("Room name"), message: L("How this Apple TV is shown on your other Apple TVs."), preferredStyle: .alert)
            alert.addTextField { $0.text = RoomSync.roomName }
            alert.addAction(UIAlertAction(title: L("Save"), style: .default) { [weak self] _ in
                RoomSync.roomName = alert.textFields?.first?.text ?? ""
                if var mine = RoomSync.mine {
                    mine.room = RoomSync.roomName
                    RoomSync.publish(mine)
                }
                self?.tableView.reloadData()
            })
            alert.addAction(UIAlertAction(title: L("Cancel"), style: .cancel))
            present(alert, animated: true)
        case 1:
            let session = sessions[indexPath.row]
            let sheet = UIAlertController(title: session.room, message: describe(session), preferredStyle: .actionSheet)
            sheet.addAction(UIAlertAction(title: L("Watch here"), style: .default) { _ in
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "roomContinue"), object: WatchSessionBox(session))
            })
            sheet.addAction(UIAlertAction(title: L("Cancel"), style: .cancel))
            present(sheet, animated: true)
        default:
            let profile = receivers[indexPath.row]
            guard profile.id != ReceiverStore.active?.id else { return }
            let sheet = UIAlertController(title: profile.name, message: profile.address, preferredStyle: .actionSheet)
            sheet.addAction(UIAlertAction(title: L("Watch from this receiver"), style: .default) { _ in
                ReceiverStore.activate(profile)
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "tuner.setupready"), object: nil)
            })
            sheet.addAction(UIAlertAction(title: L("Cancel"), style: .cancel))
            present(sheet, animated: true)
        }
    }

    static func makeTab() -> UIViewController {
        let navigation = UINavigationController(rootViewController: RoomsViewController(style: .grouped))
        navigation.tabBarItem.title = L("Rooms")
        return navigation
    }
}
