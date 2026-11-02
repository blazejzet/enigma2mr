//
//  EPGViewController.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 16.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit
import AVKit

class EPGViewController: UIViewController, UITableViewDelegate, UITableViewDataSource,
UICollectionViewDelegate, UICollectionViewDataSource{
    //var sl: Servicelist?
    var bouquets: [Service]?
    var delegate:ViewController?
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBAction func turnOFF(_ sender: Any) {
        STBAPI.common()?.turnOff()
    }
    @IBAction func reboot(_ sender: Any) {
        STBAPI.common()?.reboot()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if  let bouquets = self.bouquets{
            if bouquets.count>0 {
                return bouquets.count
            }else{
                return 1
            }
        }
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var bcell = tableView.dequeueReusableCell(withIdentifier: "bcell") as? BouquetCell
        if  let bouquets = bouquets {
            if bouquets.count>0 {
                    bcell?.configure(bouquet: bouquets[indexPath.row])
                    bcell?.delegate = self
            }else{
                    bcell = tableView.dequeueReusableCell(withIdentifier: "bcellempty") as? BouquetCell
                    
            }
            
        }else{
             bcell = tableView.dequeueReusableCell(withIdentifier: "bcellempty") as? BouquetCell
            
        }
        return bcell!;
    }
    
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
         tableView.deselectRow(at: indexPath, animated: true)
    }
    
    @IBAction func clearTest(){
        //EPGHelper.getInstance()?.testClear()
    }
    
    

    override func viewDidLoad() {
        super.viewDidLoad()
        //STBAPI.common()?.getServices(cb:{ (sl:Servicelist) in
        //    print("got \(sl.services?.count) bouquets")
        //    self.sl = sl
        //    self.tableView.reloadData()
        //    //self.collectionView.reloadData()
        //}){
            
        //}
        
        
        
      
          
       

         DispatchQueue.global().async {
            STBAPI.common()?.getServices(cb: {list in
                //list.bouquet
                
            }, fail: {
                
            })
            //EPGHelper.getBouquets { bouquets in
                self.bouquets = bouquets
    //            sleep(20)
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
            
        }
        //let AirPlayButton = AVRoutePickerView(frame: CGRect(x: 757, y: 933, width: 79, height: 79))
        //view.addSubview(AirPlayButton)
        
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
       
            if let services = self.bouquets {
                return services.count
            
        }
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        
        
        
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "zz", for: indexPath)
            
            if let cell = cell as? BouquetCollectionViewCell{
                cell.clv = collectionView
               
                    if let bouquets = bouquets {
                         let i = bouquets[indexPath.row]
                            cell.configure(bouquet: i)
                       
                }
                
            }
            return cell
        
        
        
    }
    
    
    
    
    
    
    
    
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier{
        case "recordings","recordings2":
            let dvc = segue.destination as? Movies2ViewController
            dvc?.delegate  = self
        case "showsettings2":
            print("Settnings2")
        default:
            print("Starting EPG")
            if  let bouquets = bouquets{
                
                    if let ind = tableView.indexPathForSelectedRow
                        {
                        let bouquet = bouquets[ind.row]
                        let dvc = segue.destination as? EPGListViewController
                        dvc?.bouquet = bouquet
                        dvc?.delegate  = self
                    }
                    
                    
                    
                
            }
        }
        
        
        
    }
 
    func watch(_ service:Service, inBouquet bouquet:Service){
        delegate?.watch(service, inBouquet: bouquet)
    }
    
    func watchMovie(_ event:Movie){
        delegate?.watchMovie(event)
        self.dismiss()
    }
    func dismiss(){
        self.dismiss(animated: true, completion: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if let pp = context.previouslyFocusedIndexPath{
            if let cm:CommonCollectionViewCell =  collectionView.cellForItem(at: pp) as? CommonCollectionViewCell {
                cm.deselect()
            }
        }
        if let pp = context.nextFocusedIndexPath{
            if let cm:CommonCollectionViewCell =  collectionView.cellForItem(at: pp) as? CommonCollectionViewCell {
                
                
                cm.select()
            }
            
        }
        
    }
    

}
