//
//  TVEventViewController.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 30/05/2020.
//  Copyright © 2020 Blazej Zyglarski. All rights reserved.
//

import UIKit

class TVEventViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        // "NEXT" header only when there is something after it.
        if let events = events, !events.isEmpty {
            return 2 + events.count
        }
        return 1
    }
    
    
    var bouquet:Service?
    var service:Service?
    var event:EpgEvent?
    var now:EpgEvent?
    
    @IBOutlet weak var servicename: UILabel!
    
    @IBOutlet weak var hour: UILabel!
    
    @IBOutlet weak var eventposter: UIImageView!
    
    @IBOutlet weak var eventtitle: UILabel!
    
    @IBOutlet weak var backdrop: UIImageView!
    @IBOutlet weak var servicelogo: UIImageView!
    
    @IBOutlet weak var eventdescription: UILabel!
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0{
            var d = tableView.dequeueReusableCell(withIdentifier: "nowcell") as! NowTableViewCell
            d.setup(e: self.now ?? EpgEvent())
            return d;
        }
        
        if indexPath.row == 1{
        var d = tableView.dequeueReusableCell(withIdentifier: "nextlabel")
            return d!;
        }
        
        
        var d = tableView.dequeueReusableCell(withIdentifier: "nextcell") as! NextTableViewCell
      
        if let event = self.events?[indexPath.row - 2] {
            d.setup(e: event)
        }
        return d;

        
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        context.nextFocusedItem
    }
    
    @IBAction func backPressed(_ sender: Any) {
         NotificationCenter.default.post(name:
            NSNotification.Name(rawValue: "hidePip"), object: [String:Any](), userInfo: ["direction":0])
        self.dismiss(animated: true, completion: nil)
    }
    
    
    
    var events:[EpgEvent]?
    var pindexPath = IndexPath(row: -1, section: 0);
    func tableView(_ tableView: UITableView, didUpdateFocusIn context: UITableViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        guard let indexPath = context.nextFocusedIndexPath else {return}
        if pindexPath.row == indexPath.row {return}
        pindexPath.row = indexPath.row
        var event:EpgEvent?
        if tableView.cellForRow(at: indexPath) is NowTableViewCell{
            event = self.now
        }
        if tableView.cellForRow(at: indexPath) is NextTableViewCell{
            event = self.events?[indexPath.row-2]
        }
        display(event)
    }

    /// Left column: time, title, description, poster and backdrop of `event`
    /// (the running programme when the screen opens, then the focused row).
    private func display(_ event: EpgEvent?) {
        guard isViewLoaded else { return }
        self.backdrop.image = nil
        self.eventposter.image = nil
        guard let event = event, event.hasData else {
            self.eventtitle.text = ""   // the "Now playing" card says "No programme information"
            self.eventdescription.text = ""
            self.hour.text = ""
            return
        }
        self.eventtitle.text = event.title ?? ""
        self.eventdescription.text = event.longdesc ?? event.shortdesc ?? ""
        self.hour.text = event.getBeginTimeString()
        self.event = event
        let eventKey = Int(event.begin_timestamp ?? 0)
        STBAPI.common()?.searchInfoWeb(title: event.title ?? "", duration: event.durationMinutes, eid: eventKey) {
            image, backdrop, eid, ok in
            DispatchQueue.main.async {
                // The user may have moved on to another event meanwhile.
                guard ok, eid == Int(self.event?.begin_timestamp ?? 0) else { return }
                if let backdrop = backdrop { self.backdrop.image = backdrop }
                if let image = image { self.eventposter.image = image }
            }
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //guard let indexPath = context.nextFocusedIndexPath else {return}
        var event_:EpgEvent?
        var showWatchnow=false;
        var showRecord=false;
        if let row = tableView.cellForRow(at: indexPath) as? NowTableViewCell{
            showWatchnow = true
            event_ = row.event
        }
        if let row = tableView.cellForRow(at: indexPath) as? NextTableViewCell{
            event_ = row.event
            showRecord = true
        }
        guard let event = event_ else {return}
        
        guard let service = self.service, let bouquet = self.bouquet else { return }
        let alert = UIAlertController(title: event.title ?? service.servicename, message: event.shortdesc, preferredStyle: .actionSheet)
                if showWatchnow{
                    alert.addAction(UIAlertAction(title: L("Watch Channel Now"), style: .default){ a in
                       alert.dismiss(animated: true, completion: nil)
                       NotificationCenter.default.post(name: NSNotification.Name(rawValue: "bouquetPlayed"), object: ["service":service,"bouquet":bouquet])
                    })
                    alert.addAction(UIAlertAction(title: L("Watch Channel as Picture in Picture"), style: .default){ a in
                       alert.dismiss(animated: true, completion: nil)
                       NotificationCenter.default.post(name: NSNotification.Name(rawValue: "dismiss"), object: ["service":service,"bouquet":bouquet])
                    })
                }
            if showRecord, let eventId = event.id, let sref = event.sref ?? service.servicereference {
             alert.addAction(UIAlertAction(title: L("Schedule recording"), style: .default){ a in
                 STBAPI.common()?.setTimer(sref: sref, eid: eventId){ ok, message in
                     let result = UIAlertController(title: ok ? L("Recording scheduled") : L("Recording not scheduled"),
                                                    message: message, preferredStyle: .alert)
                     result.addAction(UIAlertAction(title: "OK", style: .default))
                     self.present(result, animated: true)
                 }
             })
            }
             alert.addAction(UIAlertAction(title: L("Cancel"), style: .cancel){ a in
                 
             })
             self .present(alert, animated: true, completion: {})
    }
    
    
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 0 {
            
            return 300
        }
        return 66
    }
    
 
    
    @IBOutlet weak var tv: UITableView!
    
    
    @IBAction func watchnow(_ sender: Any) {
        guard let service = service, let bouquet = bouquet else { return }
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "bouquetPlayed"), object: ["service":service, "bouquet":bouquet], userInfo: ["direction":0])
    }



    @IBAction func watchpip(_ sender: Any) {
        guard let service = service, let bouquet = bouquet else { return }
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "pipPlayed"), object: ["service":service, "bouquet":bouquet], userInfo: ["direction":0])
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
            
        
        // Do any additional setup after loading the view.
    }
    
    func setup(){
        if let s = self.servicename{
            s.text = self.service?.displayName ?? self.now?.sname.flatMap { $0 == "<n/a>" ? nil : $0 } ?? ""
            self.servicelogo.backgroundColor = .clear
            self.servicelogo.setPicon(for: service)
            display(self.now)
        }

    }
    func configure(s:Service,b:Service,e:EpgEvent){
        self.bouquet = b
        self.service = s
        self.event = e
        self.now = e
        // Rest of today's programme (~28h) after the running event.
        let from = e.end_timestamp ?? UInt64(Date().timeIntervalSince1970)
        STBAPI.common()?.getFullEPG(for: s, from: from, to: from + 100000){ [weak self] events, _ in
            self?.events = events
            self?.tv?.reloadData()
        }
        setup()
    }


    

}

// MARK: - EPG search (Search tab)

/// Programme search across all channels (OpenWebif `epgsearch`), with "similar programmes" from a result.
final class EPGSearchResultsViewController: UITableViewController, UISearchResultsUpdating {
    private var results = [EpgEvent]()
    private var query = ""
    private var pending: DispatchWorkItem?
    /// Set while showing "similar programmes" of a result instead of search hits.
    private var similarTo: EpgEvent?
    private let emptyLabel = Glass.label(.title3, color: Glass.secondaryText)

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "result")
        tableView.backgroundColor = .clear
        tableView.rowHeight = 124
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        tableView.backgroundView = emptyLabel
        updateEmptyText()
    }

    func updateSearchResults(for searchController: UISearchController) {
        let text = (searchController.searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard text != query else { return }
        query = text
        similarTo = nil
        pending?.cancel()
        guard text.count >= 2 else {
            results = []
            tableView.reloadData()
            updateEmptyText()
            return
        }
        // Wait for a pause in typing – one receiver request per word, not per letter.
        let work = DispatchWorkItem { [weak self] in self?.search(text) }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func search(_ text: String) {
        emptyLabel.text = L("Searching…")
        STBAPI.common()?.searchEPG(text) { [weak self] events in
            guard let self = self, self.query == text, self.similarTo == nil else { return }
            self.show(events)
        }
    }

    private func show(_ events: [EpgEvent]) {
        let now = UInt64(Date().timeIntervalSince1970)
        // Finished programmes cannot be watched or recorded any more.
        results = events.filter { $0.hasData && ($0.end_timestamp ?? 0) > now }
        tableView.reloadData()
        updateEmptyText()
        if !results.isEmpty {
            tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
        }
    }

    private func updateEmptyText() {
        guard results.isEmpty else {
            emptyLabel.text = nil
            return
        }
        if let similar = similarTo {
            emptyLabel.text = L("No other broadcasts of “%@”.", similar.title ?? "")
        } else if query.count >= 2 {
            emptyLabel.text = L("No upcoming programmes match “%@”.", query)
        } else {
            // tvOS lays the results out only once there is a query – a hint here would sit off-centre.
            emptyLabel.text = nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let similar = similarTo, !results.isEmpty else { return nil }
        return L("Also on air: %@", similar.title ?? "")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "result", for: indexPath)
        let event = results[indexPath.row]
        var content = UIListContentConfiguration.subtitleCell()
        content.text = event.title
        let channel = event.sname.flatMap { $0 == "<n/a>" ? nil : $0 }
        content.secondaryText = [isRunning(event) ? L("● Now") : nil, channel, EPGSearchResultsViewController.when(event), L("%d min", event.durationMinutes)]
            .compactMap { $0 }.joined(separator: " · ")
        cell.contentConfiguration = content
        return cell
    }

    private func isRunning(_ event: EpgEvent) -> Bool {
        let now = UInt64(Date().timeIntervalSince1970)
        return (event.begin_timestamp ?? 0) <= now && now < (event.end_timestamp ?? 0)
    }

    /// "Today 20:15", "Tomorrow 21:30", "Wed 5 Nov 20:00".
    static func when(_ event: EpgEvent) -> String? {
        guard let begin = event.begin_timestamp else { return nil }
        let date = Date(timeIntervalSince1970: TimeInterval(begin))
        let time = DateFormatter()
        time.setLocalizedDateFormatFromTemplate("HH:mm")
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return L("Today %@", time.string(from: date)) }
        if calendar.isDateInTomorrow(date) { return L("Tomorrow %@", time.string(from: date)) }
        let day = DateFormatter()
        day.setLocalizedDateFormatFromTemplate("EEE d MMM HH:mm")
        return day.string(from: date)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let event = results[indexPath.row]
        let sheet = UIAlertController(title: event.title,
                                      message: [event.sname, EPGSearchResultsViewController.when(event), event.shortdesc]
                                        .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n"),
                                      preferredStyle: .actionSheet)
        if isRunning(event), let sref = event.sref {
            sheet.addAction(UIAlertAction(title: L("Watch now"), style: .default) { _ in
                DataProvider.def().findService(sref: sref) { service, bouquet in
                    guard let service = service, let bouquet = bouquet else { return }
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "bouquetPlayed"),
                                                    object: ["service": service, "bouquet": bouquet])
                }
            })
        }
        if let sref = event.sref, let id = event.id {
            sheet.addAction(UIAlertAction(title: L("Record"), style: .default) { [weak self] _ in
                STBAPI.common()?.setTimer(sref: sref, eid: id) { ok, message in
                    let result = UIAlertController(title: ok ? L("Recording scheduled") : L("Recording not scheduled"),
                                                   message: message, preferredStyle: .alert)
                    result.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(result, animated: true)
                }
            })
            sheet.addAction(UIAlertAction(title: L("Similar programmes"), style: .default) { [weak self] _ in
                self?.showSimilar(to: event)
            })
        }
        sheet.addAction(UIAlertAction(title: L("Cancel"), style: .cancel))
        present(sheet, animated: true)
    }

    private func showSimilar(to event: EpgEvent) {
        similarTo = event
        emptyLabel.text = L("Searching…")
        STBAPI.common()?.similarEPG(to: event) { [weak self] events in
            guard let self = self, self.similarTo === event else { return }
            self.show(events)
        }
    }
}

extension EPGSearchResultsViewController {
    /// The Search tab: the tvOS search screen (keyboard on top, results below).
    static func makeTab() -> UIViewController {
        let results = EPGSearchResultsViewController(style: .plain)
        let search = UISearchController(searchResultsController: results)
        search.searchResultsUpdater = results
        search.searchBar.placeholder = L("Programme title")
        search.obscuresBackgroundDuringPresentation = false
        let container = UISearchContainerViewController(searchController: search)
        let navigation = UINavigationController(rootViewController: container)
        navigation.tabBarItem.title = L("Search")
        return navigation
    }
}
