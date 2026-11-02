//
//  SettingsViewController.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 12.04.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit
import Reachability

class SettingsViewController: UIViewController, UITableViewDelegate,UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    
    var tuners = [TunerInfo]()
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tuners.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var x = tableView.dequeueReusableCell(withIdentifier: "tunercell")! as? TunerCell
        x?.configure(serv: tuners[indexPath.row])
        
        
        return x!
    }
    
    
    
    
    
    
    
    @IBOutlet weak var cbutton: UIButton!
    var f=false;
    @IBOutlet weak var info: UILabel!
    @IBAction func cbuttonCLicked(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    @IBOutlet weak var whe: UIActivityIndicatorView!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.whe.startAnimating()
        STBAPI.common()?.discoverNetwork(status: { _ in }, success: { dat,address in
            print("Discovering successfull: \(address):")
            self.info.text = "Receiver found."
            /*self.f=true
            //self.cbutton.setTitle("OK", for: UIControlState.focused)
            self.cbutton.setTitle("OK", for: .focused)
            self.cbutton.setTitle("OK", for: .normal)
            //self.tapMenu(self)
            self.whe.alpha=0.0
            //self.perform(#selector(ViewController.tapMenu(_:)), with: self, afterDelay: 1.0)
            */
            dat.ip = address;
            self.tuners.append(dat)
            self.tableView.reloadData()
            // Focus the found receiver – one click selects it.
            self.setNeedsFocusUpdate()
            self.updateFocusIfNeeded()
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "EnigmaDemo"), self.tuners.count == 1 {
                // Demo recording: select the receiver like a user would.
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.tableView(self.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
                }
            }
            #endif
            
        }, failure: { st in
            self.info.text = "Failed finding a device..."
            self.reachability?.stopNotifier()
            self.reachability = try? Reachability()
            let reachability = self.reachability
            // The notifier is owned by this screen – capture it weakly or the two keep each other alive.
            reachability?.whenReachable = { [weak self] reachability in
                DispatchQueue.main.async {
                    self?.info.text = "No supported device in Your Network. Check  Your STB."
                }
            }
            reachability?.whenUnreachable = { [weak self] reachability in
                DispatchQueue.main.async {
                    self?.info.text = "Network not found..."
                }
            }
            do
            {
                try reachability?.startNotifier()
            }catch{
                self.info.text = "General network error"
            }
        }, finished: { [weak self] in
            self?.whe.stopAnimating()
            self?.whe.isHidden = true
        })
    }

    /// Kept alive while the screen is shown (a local instance would stop notifying immediately).
    private var reachability: Reachability?

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        reachability?.stopNotifier()
        reachability = nil
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if !tuners.isEmpty, let table = tableView { return [table] }
        return super.preferredFocusEnvironments
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBOutlet weak var manual: UIButton!
    @IBAction func mbuttonClicked(_ sender: Any) {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "tuner.manualsetup"), object: nil)
        #if swift(>=4.2)
        let settingsURL = UIApplication.openSettingsURLString
        #else
        let settingsURL = UIApplicationOpenSettingsURLString
        #endif
        UIApplication.shared.open(URL(string: settingsURL)!)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var tc = tuners[indexPath.row]
        STBAPI.common()?.set(address:tc.ip!)
        if let apitype = tc.apitype{
            STBAPI.common()?.set(api:tc.apitype!)
        }else{
            STBAPI.common()?.set(api:"api")
        }
        STBAPI.common()?.saveSettings()
        
        
        let receiver = [tc.brand, tc.model].compactMap { $0 }.joined(separator: " ")
        let alert = UIAlertController(title: "Connected to \(receiver.isEmpty ? tc.ip ?? "receiver" : receiver)",
                                      message: "EnigmaTV will now load your channel lists and TV guide from \(tc.ip ?? "the receiver").",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Continue", style: .default){ a in
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "tuner.setupready"), object: nil)
        })
        self.present(alert, animated: true, completion: {})
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "EnigmaDemo") {
            // Demo recording: "press" Continue after a moment.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                alert.dismiss(animated: true) {
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "tuner.setupready"), object: nil)
                }
            }
        }
        #endif
        
        
      
    }

    
    
}

// MARK: - Receiver settings (Settings tab when a receiver is configured)

/// Settings of the connected receiver and of this app. Discovery is only offered as an action.
final class ReceiverSettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private enum Row {
        case power, sleepTimer, restartGUI, reboot
        case timeshift, timeshiftBuffer, zap, transcoding
        case config(String)
        case allSettings, address, credentials, search
    }

    private struct Section {
        let title: String
        let footer: String?
        let rows: [Row]
    }

    /// Curated receiver settings: (section title, footer, config paths, OpenWebif sections to load).
    private static let curated: [(title: String, footer: String?, paths: [String])] = [
        ("Streaming", "With authentication on, set the receiver's user name and password under Connection.",
         ["config.streaming.authentication", "config.streaming.descramble", "config.usage.http_startdelay", "config.usage.frontend_priority"]),
        ("Recording", nil,
         ["config.recording.margin_before", "config.recording.margin_after", "config.recording.default_afterevent", "config.recording.keep_timers"]),
        ("System", "Enigma2 stores changed settings when it goes to standby or restarts.",
         ["config.timezone.area", "config.timezone.val", "config.misc.SyncTimeUsing", "config.usage.boot_action",
          "config.usage.shutdownNOK_action", "config.workaround.wakeuptime"]),
    ]
    private static let curatedSections = ["Usage", "Recording", "Time"]

    var onSearch: (() -> Void)?

    private var items = [String: ReceiverConfigItem]()
    private var inStandby: Bool?
    private var sleepTimer: STBAPI.SleepTimer?
    private var about: [String: Any]?
    private var signal: [String: Any]?
    private var reachable: Bool?
    private var refreshTimer: Timer?

    private let table = UITableView(frame: .zero, style: .grouped)
    private let card = Glass.panel()
    private let modelLabel = Glass.label(.title2, weight: .semibold)
    private let imageLabel = Glass.label(.callout, color: Glass.secondaryText)
    private let addressLabel = Glass.label(.callout, color: Glass.secondaryText)
    private let statusLabel = Glass.label(.headline, weight: .medium)
    private let signalLabel = Glass.label(.callout, color: Glass.secondaryText)
    private let signalBar = UIProgressView(progressViewStyle: .default)

    private var api: STBAPI? { return STBAPI.common() }

    // MARK: Layout

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        buildCard()

        table.translatesAutoresizingMaskIntoConstraints = false
        table.dataSource = self
        table.delegate = self
        table.backgroundColor = .clear
        table.remembersLastFocusedIndexPath = true
        view.addSubview(table)
        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: view.topAnchor, constant: 140),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            table.leadingAnchor.constraint(equalTo: card.trailingAnchor, constant: 60),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Glass.margin),
        ])
    }

    private func buildCard() {
        view.addSubview(card)
        let logo = UIImageView(image: UIImage(named: "logo"))
        logo.contentMode = .scaleAspectFit
        logo.translatesAutoresizingMaskIntoConstraints = false
        signalBar.translatesAutoresizingMaskIntoConstraints = false
        signalBar.progressTintColor = Glass.accent
        for label in [modelLabel, imageLabel, addressLabel, statusLabel, signalLabel] {
            label.numberOfLines = 2
        }
        let stack = UIStackView(arrangedSubviews: [logo, modelLabel, imageLabel, addressLabel, statusLabel, signalLabel, signalBar])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 14
        stack.setCustomSpacing(36, after: logo)
        stack.setCustomSpacing(30, after: addressLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: view.topAnchor, constant: 160),
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Glass.margin),
            card.widthAnchor.constraint(equalToConstant: 600),
            logo.heightAnchor.constraint(equalToConstant: 120),
            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 44),
            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 44),
            stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -44),
            stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -44),
        ])
        updateCard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        reload()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.refreshStatus() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: Data

    private func reload() {
        guard let api = api else { return }
        api.getAboutInfo { [weak self] info in
            self?.about = info
            self?.reachable = info != nil
            self?.updateCard()
        }
        refreshStatus()
        api.getSleepTimer { [weak self] timer in
            self?.sleepTimer = timer
            self?.table.reloadData()
        }
        reloadItems()
    }

    private func reloadItems() {
        let paths = ReceiverSettingsViewController.curated.flatMap { $0.paths }
        api?.getConfigItems(paths: paths, sections: ReceiverSettingsViewController.curatedSections) { [weak self] found in
            self?.items = found
            self?.table.reloadData()
        }
    }

    private func refreshStatus() {
        api?.getStandbyState { [weak self] standby in
            self?.inStandby = standby
            self?.reachable = standby != nil
            self?.updateCard()
            self?.table.reloadData()
        }
        api?.getTunerSignal { [weak self] signal in
            self?.signal = signal
            self?.updateCard()
        }
    }

    private func updateCard() {
        let brand = about?["brand"] as? String ?? ""
        let model = about?["model"] as? String ?? ""
        modelLabel.text = "\(brand) \(model)".trimmingCharacters(in: .whitespaces).isEmpty ? "Receiver" : "\(brand) \(model)"
        let distro = (about?["friendlyimagedistro"] as? String) ?? (about?["imagedistro"] as? String) ?? ""
        let version = about?["imagever"] as? String ?? ""
        let webif = about?["webifver"] as? String ?? ""
        imageLabel.text = [distro + (version.isEmpty ? "" : " " + version), webif].filter { !$0.isEmpty }.joined(separator: "\n")
        addressLabel.text = api?.stbAddress
        switch (reachable, inStandby) {
        case (false?, _):
            statusLabel.text = "● Not reachable"
            statusLabel.textColor = .systemRed
        case (_, true?):
            statusLabel.text = "● Standby"
            statusLabel.textColor = .systemOrange
        case (_, false?):
            statusLabel.text = "● On"
            statusLabel.textColor = .systemGreen
        default:
            statusLabel.text = "Connecting…"
            statusLabel.textColor = Glass.secondaryText
        }
        if let snr = signal?["snr"] as? Int {
            let db = signal?["snr_db"] as? String
            let type = signal?["tunertype"] as? String
            signalLabel.text = ["Signal \(snr)%", db.map { "\($0) dB" }, type].compactMap { $0 }.joined(separator: " · ")
            signalBar.progress = Float(snr) / 100
            signalBar.isHidden = false
        } else {
            signalLabel.text = nil
            signalBar.isHidden = true
        }
        transcodingSupported = about?["transcoding"] as? Bool ?? false
    }
    private var transcodingSupported = false

    private var sections: [Section] {
        var result = [
            Section(title: "Receiver", footer: nil, rows: [.power, .sleepTimer, .restartGUI, .reboot]),
            Section(title: "Watching on Apple TV", footer: nil, rows: [.timeshift, .timeshiftBuffer, .zap, .transcoding]),
        ]
        for group in ReceiverSettingsViewController.curated {
            let rows = group.paths.filter { items[$0] != nil }.map { Row.config($0) }
            if !rows.isEmpty {
                result.append(Section(title: group.title, footer: group.footer, rows: rows))
            }
        }
        result.append(Section(title: "Connection", footer: nil, rows: [.allSettings, .address, .credentials, .search]))
        return result
    }

    // MARK: Table

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section].footer
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "row") ?? UITableViewCell(style: .value1, reuseIdentifier: "row")
        let row = sections[indexPath.section].rows[indexPath.row]
        let (title, value, pushes) = describe(row)
        var content = UIListContentConfiguration.valueCell()
        content.text = title
        content.secondaryText = value
        cell.contentConfiguration = content
        cell.accessoryType = pushes ? .disclosureIndicator : .none
        return cell
    }

    private func onOff(_ value: Bool) -> String { return value ? "On" : "Off" }

    private func describe(_ row: Row) -> (String, String?, Bool) {
        let uds = UserDefaults.standard
        switch row {
        case .power:
            return (inStandby == true ? "Wake up receiver" : "Put receiver in standby", nil, false)
        case .sleepTimer:
            guard let timer = sleepTimer else { return ("Sleep timer", "…", true) }
            return ("Sleep timer", timer.enabled ? "\(timer.minutes) min · \(timer.action == "shutdown" ? "Deep standby" : "Standby")" : "Off", true)
        case .restartGUI:
            return ("Restart Enigma2", nil, false)
        case .reboot:
            return ("Reboot receiver", nil, false)
        case .timeshift:
            return ("Timeshift", onOff(uds.bool(forKey: "timeshift")), false)
        case .timeshiftBuffer:
            let minutes = uds.integer(forKey: "timeshiftMinutes")
            return ("Timeshift buffer", minutes >= 60 ? "\(minutes / 60) h" : "\(max(minutes, 30)) min", true)
        case .zap:
            return ("Switch receiver to watched channel", onOff(uds.bool(forKey: "zap")), false)
        case .transcoding:
            return ("Use transcoding port", transcodingSupported ? onOff(uds.bool(forKey: "useTranscoding")) : "Not supported", false)
        case .config(let path):
            let item = items[path]
            return (item?.title ?? path, item?.currentLabel, item?.kind == .select)
        case .allSettings:
            return ("All receiver settings", nil, true)
        case .address:
            return ("Receiver address", api?.stbAddress, false)
        case .credentials:
            let user = api?.username ?? ""
            return ("User name & password", user.isEmpty ? "None" : user, false)
        case .search:
            return ("Search for receivers…", nil, false)
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = sections[indexPath.section].rows[indexPath.row]
        let uds = UserDefaults.standard
        switch row {
        case .power:
            api?.setPowerState(inStandby == true ? .wakeUp : .standby) { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self?.refreshStatus() }
            }
        case .sleepTimer:
            let options = [0, 15, 30, 45, 60, 90, 120].map { ($0 == 0 ? "0" : String($0), $0 == 0 ? "Off" : "\($0) minutes") }
            let current = sleepTimer?.enabled == true ? String(sleepTimer?.minutes ?? 0) : "0"
            pushChoices("Sleep timer", options, selected: current) { [weak self] value in
                self?.api?.setSleepTimer(minutes: Int(value) ?? 0, action: self?.sleepTimer?.action ?? "standby") { ok, message in
                    if !ok { self?.showError(message) }
                    self?.api?.getSleepTimer { timer in
                        self?.sleepTimer = timer
                        self?.table.reloadData()
                    }
                }
            }
        case .restartGUI:
            confirm("Restart Enigma2?", "The receiver's interface restarts. Live TV stops for a moment.", action: "Restart") { [weak self] in
                self?.api?.setPowerState(.restartGUI)
            }
        case .reboot:
            confirm("Reboot receiver?", "Live TV and recordings in progress will stop.", action: "Reboot") { [weak self] in
                self?.api?.reboot()
            }
        case .timeshift:
            uds.set(!uds.bool(forKey: "timeshift"), forKey: "timeshift")
            appSettingsChanged()
        case .timeshiftBuffer:
            let options = [30, 60, 120, 180].map { (String($0), $0 >= 60 ? "\($0 / 60) hour\($0 > 60 ? "s" : "")" : "\($0) minutes") }
            pushChoices("Timeshift buffer", options, selected: String(uds.integer(forKey: "timeshiftMinutes"))) { [weak self] value in
                uds.set(Int(value) ?? 60, forKey: "timeshiftMinutes")
                self?.appSettingsChanged()
            }
        case .zap:
            uds.set(!uds.bool(forKey: "zap"), forKey: "zap")
            appSettingsChanged()
        case .transcoding:
            guard transcodingSupported else { return }
            uds.set(!uds.bool(forKey: "useTranscoding"), forKey: "useTranscoding")
            appSettingsChanged()
        case .config(let path):
            guard let item = items[path] else { return }
            ConfigEditor.edit(item, from: self) { [weak self] in self?.reloadItems() }
        case .allSettings:
            navigationController?.pushViewController(ConfigSectionsViewController(), animated: true)
        case .address:
            editText("Receiver address", value: api?.stbAddress ?? "", keyboard: .URL) { [weak self] value in
                let address = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !address.isEmpty else { return }
                uds.set(address, forKey: "stbAddress")
                self?.reconnect()
            }
        case .credentials:
            editCredentials()
        case .search:
            onSearch?()
        }
    }

    // MARK: Actions

    private func appSettingsChanged() {
        api?.loadSettings()
        table.reloadData()
    }

    private func reconnect() {
        STBAPI.restart()
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "tuner.setupready"), object: nil)
    }

    private func pushChoices(_ title: String, _ options: [(String, String)], selected: String, onSelect: @escaping (String) -> Void) {
        let list = ChoiceListViewController(title: title, options: options.map { (value: $0.0, label: $0.1) }, selected: selected) { [weak self] value in
            onSelect(value)
            self?.navigationController?.popViewController(animated: true)
        }
        navigationController?.pushViewController(list, animated: true)
    }

    private func confirm(_ title: String, _ message: String, action: String, handler: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: action, style: .destructive) { _ in handler() })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func editText(_ title: String, value: String, keyboard: UIKeyboardType, onSave: @escaping (String) -> Void) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.text = value
            field.keyboardType = keyboard
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in onSave(alert.textFields?.first?.text ?? "") })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func editCredentials() {
        let alert = UIAlertController(title: "Receiver login", message: "Only needed when the receiver's web interface or streams require authentication.", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "User name"
            field.text = self.api?.username
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addTextField { field in
            field.placeholder = "Password"
            field.text = self.api?.password
            field.isSecureTextEntry = true
        }
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            UserDefaults.standard.set(alert.textFields?[0].text ?? "", forKey: "username")
            UserDefaults.standard.set(alert.textFields?[1].text ?? "", forKey: "password")
            self?.reconnect()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func showError(_ message: String?) {
        let alert = UIAlertController(title: "Could not change the setting", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

/// Edits one receiver setting: checkboxes toggle, selections open a list, numbers/text an input field.
enum ConfigEditor {
    static func edit(_ item: ReceiverConfigItem, from controller: UIViewController, done: @escaping () -> Void) {
        switch item.kind {
        case .checkbox:
            save(item, value: item.isOn ? "false" : "true", from: controller, done: done)
        case .select:
            let list = ChoiceListViewController(title: item.title, options: item.choices, selected: item.current) { value in
                save(item, value: value, from: controller, done: done)
                controller.navigationController?.popViewController(animated: true)
            }
            controller.navigationController?.pushViewController(list, animated: true)
        case .number, .text:
            let range = item.limits.map { " (\($0.min)–\($0.max))" } ?? ""
            let alert = UIAlertController(title: item.title + range, message: nil, preferredStyle: .alert)
            alert.addTextField { field in
                field.text = item.current
                field.keyboardType = item.kind == .number ? .numberPad : .default
                field.autocorrectionType = .no
                field.autocapitalizationType = .none
            }
            alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
                var value = alert.textFields?.first?.text ?? ""
                if item.kind == .number, let number = Int(value), let limits = item.limits {
                    value = String(min(max(number, limits.min), limits.max))
                }
                save(item, value: value, from: controller, done: done)
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            controller.present(alert, animated: true)
        case .other:
            break
        }
    }

    private static func save(_ item: ReceiverConfigItem, value: String, from controller: UIViewController, done: @escaping () -> Void) {
        STBAPI.common()?.saveConfig(path: item.path, value: value) { ok, message in
            if ok {
                item.current = value
            } else {
                let alert = UIAlertController(title: "Could not change “\(item.title)”", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                controller.present(alert, animated: true)
            }
            done()
        }
    }
}

/// Single-choice list (tvOS Settings style).
final class ChoiceListViewController: UITableViewController {
    private let options: [(value: String, label: String)]
    private let selected: String
    private let onSelect: (String) -> Void

    init(title: String, options: [(value: String, label: String)], selected: String, onSelect: @escaping (String) -> Void) {
        self.options = options
        self.selected = selected
        self.onSelect = onSelect
        super.init(style: .grouped)
        self.title = title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundColor = .clear
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let index = options.firstIndex(where: { $0.value == selected }) {
            tableView.scrollToRow(at: IndexPath(row: index, section: 0), at: .middle, animated: false)
        }
    }

    override func indexPathForPreferredFocusedView(in tableView: UITableView) -> IndexPath? {
        return options.firstIndex(where: { $0.value == selected }).map { IndexPath(row: $0, section: 0) }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return options.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "choice") ?? UITableViewCell(style: .default, reuseIdentifier: "choice")
        var content = UIListContentConfiguration.cell()
        content.text = options[indexPath.row].label
        cell.contentConfiguration = content
        cell.accessoryType = options[indexPath.row].value == selected ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onSelect(options[indexPath.row].value)
    }
}

/// All setting sections the receiver exposes.
final class ConfigSectionsViewController: UITableViewController {
    private var sections = [ReceiverConfigSection]()

    init() {
        super.init(style: .grouped)
        title = "Receiver settings"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundColor = .clear
        STBAPI.common()?.getConfigSections { [weak self] sections in
            self?.sections = sections ?? []
            self?.tableView.reloadData()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "section") ?? UITableViewCell(style: .default, reuseIdentifier: "section")
        var content = UIListContentConfiguration.cell()
        content.text = sections[indexPath.row].title
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        navigationController?.pushViewController(ConfigItemsViewController(section: sections[indexPath.row]), animated: true)
    }
}

/// Every item of one setting section, editable by type.
final class ConfigItemsViewController: UITableViewController {
    private let section: ReceiverConfigSection
    private var items = [ReceiverConfigItem]()

    init(section: ReceiverConfigSection) {
        self.section = section
        super.init(style: .grouped)
        title = section.title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundColor = .clear
        load()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func load() {
        STBAPI.common()?.getConfig(section: section.key) { [weak self] items in
            self?.items = items ?? []
            self?.tableView.reloadData()
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return items.isEmpty ? nil : "Enigma2 stores changed settings when it goes to standby or restarts."
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "item") ?? UITableViewCell(style: .value1, reuseIdentifier: "item")
        let item = items[indexPath.row]
        var content = UIListContentConfiguration.valueCell()
        content.text = item.title
        content.secondaryText = item.currentLabel
        cell.contentConfiguration = content
        cell.accessoryType = item.kind == .select ? .disclosureIndicator : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, canFocusRowAt indexPath: IndexPath) -> Bool {
        return items[indexPath.row].isEditable
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        ConfigEditor.edit(items[indexPath.row], from: self) { [weak self] in self?.load() }
    }
}
