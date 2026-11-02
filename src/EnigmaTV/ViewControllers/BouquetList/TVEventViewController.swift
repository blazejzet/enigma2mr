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
        
        if let events = events{
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
        self.eventtitle.text = event?.title ?? ""
        self.eventdescription.text = event?.longdesc ?? event?.shortdesc ?? ""
        self.hour.text = event?.begin_timestamp == nil ? "" : event?.getBeginTimeString()
        guard let event = event else { return }
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
                    alert.addAction(UIAlertAction(title: "Watch Channel Now", style: .default){ a in
                       alert.dismiss(animated: true, completion: nil)
                       NotificationCenter.default.post(name: NSNotification.Name(rawValue: "bouquetPlayed"), object: ["service":service,"bouquet":bouquet])
                    })
                    alert.addAction(UIAlertAction(title: "Watch Channel as Picture in Picture", style: .default){ a in
                       alert.dismiss(animated: true, completion: nil)
                       NotificationCenter.default.post(name: NSNotification.Name(rawValue: "dismiss"), object: ["service":service,"bouquet":bouquet])
                    })
                }
            if showRecord, let eventId = event.id, let sref = event.sref ?? service.servicereference {
             alert.addAction(UIAlertAction(title: "Schedule recording", style: .default){ a in
                 STBAPI.common()?.setTimer(sref: sref, eid: eventId){ ok, message in
                     let result = UIAlertController(title: ok ? "Recording scheduled" : "Recording not scheduled",
                                                    message: message, preferredStyle: .alert)
                     result.addAction(UIAlertAction(title: "OK", style: .default))
                     self.present(result, animated: true)
                 }
             })
            alert.addAction(UIAlertAction(title: "Schedule notificatoin", style: .default){ a in
                //STBAPI.common()?.setTimer(sref: event.sref!, eid: Int(event.id!)){x in
                //}
            })
            }
             alert.addAction(UIAlertAction(title: "Cancel", style: .cancel){ a in
                 
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
