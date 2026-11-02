//
//  MoviesViewController.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 17.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit
import CloudKit

class MoviesViewController: UIViewController, UITableViewDelegate,UITableViewDataSource,MVCProt {
    
    @IBOutlet weak var service: UIImageView!
    
    @IBOutlet weak var backdrop: UIImageView!
    @IBOutlet weak var POSTER: UIImageView!
    
    
    //var delegate:EPGViewController?
    func watch(_ event:Movie){
        //delegate?.watchMovie(event)
        
    }
    func dismiss(){
        self.dismiss(animated: true, completion: {
            
        })
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var all = 0
        if let movies =  mlist?.movies{
            all += movies.count
        }
        if let timers = tlist?.timers{
            all += timers.count
        }
        return all
    }
    @IBOutlet weak var tableView: UITableView!
    
    func findCK(movie:Movie)->CKRecord?{
        
        guard let serviceref = movie.serviceref else { return nil }
        let ref = CKRecord.ID(recordName: serviceref)
        if let list = self.rlist{
            for  ckr in list{
                if (ckr.recordID.isEqual(ref)){
                    
                    return ckr
                }
            }
        }
        return nil;
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
         tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var lim = 0
        if let timers = tlist?.timers{
            lim =  timers.count
        }
        
        if indexPath.row >= lim{
            let tc = tableView.dequeueReusableCell(withIdentifier: "mcell") as? MovieCell
            tc?.poster = UIImage(named: "poster_placeholder")
            tc?.backdrop = UIImage(named: "poster_placeholder")
            tc?.del = self
            if let movies =  mlist?.movies{
                let movie = movies[indexPath.row-lim]
                tc?.configure(serv: movie!,ck:self.findCK(movie:movie!))
                //tc?.del = self
            }
            tc?.f = { bck,log,poster in
                self.backdrop.image = bck
                self.service.image = log
                self.POSTER.image = poster
                
            }
            return tc!
        }else{
            let tc = tableView.dequeueReusableCell(withIdentifier: "tcell") as? TimerCell
            if let timers =  tlist?.timers{
                let timer = timers[indexPath.row]
                tc?.configure(serv: timer)
                tc?.del = self
            }
            tc?.f = { bck,log,poster in
                self.backdrop.image = bck
                self.service.image = log
                self.POSTER.image = poster
            }
            return tc!
        }
        
    }
    var mlist :MoviesList?
    var tlist :TimerList?
    
    var rlist :[CKRecord]?
    public func reload(){
        print("Reloading info from iCloud and db.")
        STBAPI.common()?.getMovies(){
            moviesList in
            self.mlist = moviesList
            DispatchQueue.main.async {

            self.tableView.reloadData()
            
            }
        }
        
        STBAPI.common()?.getTimers(){
            tList in
            self.tlist = tList
            DispatchQueue.main.async {
                self.tableView.reloadData()

            }
        }
        guard let privateCloudDatabase = CloudSync.database else { return }
        //let id = CKRecordID(recordName: serv.serviceref!)
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "MovieInfo", predicate: predicate)
       
        privateCloudDatabase.perform(query, inZoneWith: nil) { (records, error) in
            guard let records = records else {
                print("Error querying records: ", error)
                return
            }
            print("Found \(records.count) records matching query")
            // rlist is read by the cells on main – assign it there too.
            DispatchQueue.main.async{
                self.rlist=records
                self.tableView.reloadData()
            }
        }
        
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.indexDisplayMode = .alwaysHidden
        reload()

        // Do any additional setup after loading the view.
    }
    
//    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //if let movies =  mlist?.movies{
        //    let movie = movies[indexPath.row]
        //    self.watch(movie!)
        //    self.dismiss()
        //}
//    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        var lim = 0
        if let timers = tlist?.timers{
            lim =  timers.count
        }
        if let s = segue.destination as? MovieInfoViewController{
            if let movies =  mlist?.movies{
                if let indexPath = tableView.indexPathForSelectedRow{
                    if let movie = movies[indexPath.row-lim]{
                        s.movie = movie
                        s.delegate=self
                    }
                }
            }
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
