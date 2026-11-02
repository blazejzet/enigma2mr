//
//  EPGListViewController.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 16.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit

class EPGListViewController: UIViewController {
    //var service:Service?
    var bouquet:Service?
    static var height:CGFloat = 60.0;
    
    static var spacing:CGFloat = 10.0;
    
    static var xwid = 400.0;
    
    
    @IBOutlet weak var serviceNameLabel: UILabel!
    @IBOutlet weak var epgViewContainer: UIView!
    @IBOutlet weak var channelListView: UIView!
    
    @IBOutlet weak var timViewContainer: UIView!
    
    
    
    var channellist : UIScrollView?
    
    static var startupTime: UInt64 = UInt64(Date().timeIntervalSince1970)       //seconds
    
    static var offsetX: CGFloat  = 0.0 //pixels
    static var xposition: CGFloat = 100.0 //pixels
    static var density:CGFloat = 3.0; //seconds per pixel 1920*5 == 160 minutes on screen
    
    static var offsetY: Int  = 0 //lines
    
    
    //var subservices:Servicelist?
    var services: [Service]?
    var delegate:EPGViewController?
    var _epgActiveButtons:Array<Array<EPGButton>?> = Array()
    
    static var activeRow = 1
    static var bottomRow = 7
    static var visibleRows = 9
    
    var visibleTopRow = 0
    var visibleBottomRow = 9
    var visibleBeginTime = EPGListViewController.startupTime
    
    
    var info : InfoView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("Setting startup time")
        EPGListViewController.startupTime  = UInt64(Date().timeIntervalSince1970)
        
        channellist = UIScrollView(frame: CGRect(origin: CGPoint(x:0,y:0), size: epgViewContainer.frame.size))
        channellist?.clipsToBounds = false;
        epgViewContainer.addSubview(channellist!)
        EPGListViewController.offsetX = CGFloat(EPGListViewController.startupTime)/EPGListViewController.density - EPGListViewController.xposition
        
        info = InfoView()
        if let info = info{
            info.alpha=0.0
            channellist?.addSubview(info)
        }
        
        var hhint = (EPGListViewController.startupTime / (60*30)) * 60*30
        for i in 0...48*14{
            let t = TimeLabel(time: hhint)
            self.timViewContainer.addSubview(t)
            t.position()
            hhint = hhint + UInt64(60 * 30)
        }
        
        
        DataProvider.def().getServices(bref: bouquet!.sref!){
            services in
            self.services = services
            self._epgActiveButtons = Array(repeating: Array(), count: services.count)
            var row = 0
            for service in services{
                
                let cl = ChannelLabel(lab:service.sname!,row:row)
                cl.position()
                self.channelListView.addSubview(cl)
                
                row += 1
            }
            self.createEPG(from: EPGListViewController.startupTime-60*60*2, to:EPGListViewController.startupTime+60*60*4, firstVisibleRow: self.visibleTopRow, lastVisibleRow: self.visibleBottomRow, isInit: true)
        }
        
        
        /*STBAPI.common()?.getServices(for:service!,cb:{ (sl:Servicelist) in
            self.subservices = sl
            if let services = self.subservices?.services{
                
                self._epgActiveButtons = Array(repeating: Array(), count: services.count)
                var row = 0
                for service in services{
                    
                    let cl = ChannelLabel(lab:service.servicename!,row:row)
                    cl.position()
                    self.channelListView.addSubview(cl)
                    
                    row += 1
                }
            }
            
            
            self.createEPG(from: EPGListViewController.startupTime, to:EPGListViewController.startupTime+60*60*24);
        },fail:{})
        */
        //TODO: DISPLAY DATA
        
        
    }
    var _visibleRows = 9
    
    func createEPG(from start:UInt64, to end:UInt64, firstVisibleRow: Int, lastVisibleRow: Int, isInit:Bool){
        // w sekundach.
        
        if let services = self.services{
            
            
            
            
            var row = 0
            for service in services{
                service.row = Int16(row)//Zapmiętuje w którym jest wierszu.
                
                var list:Array<EPGButton> = Array()
                if let listold =  self._epgActiveButtons[Int(service.row)] {
                    list = listold
                }
                self.clear(list: &list, from: start, to: end, row: service.row)
                if(row >= firstVisibleRow && row <= lastVisibleRow + 1){

                    self.organizeData(for: service, from: start, to: end, isInit: false)
                }
//                else{
//                    var list:Array<EPGButton> = Array()
//                    if let listold =  self._epgActiveButtons[Int(service.row)] {
//                        list = listold
//                    }
//                    clearOutOfRangeRows(list: &list)
//                }
            row += 1
            }
//
            
            
//            for index in firstVisibleRow...lastVisibleRow{
//                if index >= 0 && index < services.count{
//                    services[index].row = Int16(index)
//                    self.organizeData(for: services[index], from: start, to: end, isInit: isInit)
//                }
//            }
            
            
            
            
        }
        
    }
    
//    func clearOutOfRangeRows(list: inout Array<EPGButton>){
////        print("kkkkkkkkkkkkkk+++ \(list.count)")
//        if list.count != 0{
//            for item in list{
//                item.removeFromSuperview()
//                list.removeFirst()
//            }
////            print("kkkkkkkkkkkkkk \(list.count)")
//            list = Array()
//        }
//    }
    
    func clear(list: inout Array<EPGButton>, from start:UInt64, to end:UInt64, row: Int16){
        var list2:Array<EPGButton> = Array()
        for button in list {
            if let e = button.event{
//                print("----------------deleting  row \(row) visibleTopRow \(visibleTopRow) title \(e.tilte)")
                if (e.begin_timestamp > Int64(end) || e.end_timestamp < Int64(start) || row < visibleTopRow || row > visibleBottomRow){
                    
                    button.removeFromSuperview()
                    //sleep(1)
                }else{
                    list2.append(button)
                }
            }
//            if button.event
        }
         list = Array()
        for button in list2{
            list.append(button)
        }
        self._epgActiveButtons[Int(row)] = list
    }
    
    func organizeData(for service:Service, from start:UInt64, to end:UInt64, isInit:Bool){
    
        DataProvider.def().getEpgForService(sref: service.sref!,sname: service.sname!, begin: Int64(start), end: Int64(end)) { epgEvents in
            DispatchQueue.main.async {
            
                var list:Array<EPGButton> = Array()
                if let listold =  self._epgActiveButtons[Int(service.row)] {
                    list = listold
                }
//                self.clear(list: &list, from: start, to: end, row: service.row)
                self.show( epgEvents, for:service, activeRow:1, onList: &list, atBeginning: false, isInit: isInit)
                self.clear(list: &list, from: start, to: end, row: service.row)
                self._epgActiveButtons[Int(service.row)]=list
                
            }
            
        }
    }
    
    func show(_ events:[EpgEvent], for service:Service, activeRow arow:Int, onList list: inout Array<EPGButton>, atBeginning begin:Bool, isInit:Bool){
        for event in events{
            
            var tmpList2 = list.filter( { $0.event?.tilte == "NO DATA" } )
            
            tmpList2 = tmpList2.filter( {  ( UInt64(visibleBeginTime + 9000) < ($0.event?.begin_timestamp)! ||
                                                UInt64(visibleBeginTime - 9000) > ($0.event?.begin_timestamp)! )} )


            for item in tmpList2{
                item.removeFromSuperview()
                if let index = list.index(of: item) {
                    list.remove(at: index)
                }
            }
            
            var tmpList1 = list.filter( { (event.tilte != "NO DATA" && $0.event?.tilte == "NO DATA") && ( event.begin_timestamp == $0.event?.begin_timestamp ||  event.end_timestamp == $0.event?.end_timestamp) } )
            
            
            for item in tmpList1{
                item.removeFromSuperview()
                if let index = list.index(of: item) {
                    list.remove(at: index)
                }
            }
            
            var alredyExists = list.contains(where: { $0.event?.begin_timestamp == event.begin_timestamp && $0.event?.end_timestamp == event.end_timestamp})
            
//            var outOfRange = false
//            if event.
                
//            }
            if !alredyExists{
                if (event.end_timestamp==0){
                    event.end_timestamp = event.begin_timestamp + event.dudation_sec
                }
                print ("creating button for \(event.begin_timestamp )-\(event.end_timestamp) \(event.tilte)");
                let e = EPGButton.newButton(with:event, andService:service);
                e.position()
                e.delegate=self
                
                self.channellist?.addSubview(e)
                if(begin){
                    list.insert(e, at: 0)
                }else{
                    list.append(e)
                }
            }
        }
    }
    
    
    
    
    var prev :EpgEvent?
    func selected(_ event:EpgEvent, at point:CGPoint, inRow row:Int, focused:Bool){
        
        print("Active row:\(row)")
        print("seleected event time= \(event.begin_timestamp)")
        print("offset time= \(EPGListViewController.offsetX*EPGListViewController.density)")
        
        print("EPGListViewController.offsetX = \(EPGListViewController.offsetX)")
        EPGListViewController.activeRow=row
        if (EPGListViewController.activeRow>EPGListViewController.bottomRow){
            EPGListViewController.offsetY = EPGListViewController.activeRow-EPGListViewController.bottomRow;
        }else{
            EPGListViewController.offsetY = 0;
        }
        
        visibleTopRow = EPGListViewController.offsetY
        visibleBottomRow = EPGListViewController.offsetY+9
        
        
        
        
        var spos = CGFloat(event.begin_timestamp)/EPGListViewController.density
        
        var dif = spos - EPGListViewController.offsetX
        if(dif<0 || dif>1000){
            EPGListViewController.offsetX = spos - EPGListViewController.xposition
            print("EPGListViewController.offsetX = \(EPGListViewController.offsetX)")
            
        }
       
        var now = CGFloat(Date().timeIntervalSince1970)/EPGListViewController.density
        if (EPGListViewController.offsetX < now){
            EPGListViewController.offsetX = now
        }
        
        visibleBeginTime = UInt64(EPGListViewController.offsetX*EPGListViewController.density)
        //\\\\\\
//        print("---------------- visibleTopRow = \(visibleTopRow) | visibleBottomRow = \(visibleBottomRow) | visibleBeginTime = \(visibleBeginTime)")
        if focused{
            print("ar \(row) vtr \(visibleTopRow) vbr \(visibleBottomRow) ")
            self.createEPG(from: visibleBeginTime-60*60*2, to: visibleBeginTime+60*60*4, firstVisibleRow: visibleTopRow, lastVisibleRow: visibleBottomRow, isInit: false)
        }
        self.info?.setup(event)
        self.info?.position()
        
        UIView.animate(withDuration: 0.15){
            self.info?.alpha=1.0
            
            for tt in self.timViewContainer.subviews{
                if let tt = tt as? TimeLabel{
                    tt.position()
                }
            }
            for cb in self.channelListView.subviews{
                let cbb = cb as? ChannelLabel
                cbb?.position()
            }
            
            if let services = self.services{
                for service in services{
                    
                     let row = service.row
                    
                        print("Checking service in:\(row)")
                        if let buttons = self._epgActiveButtons[Int(row)]{
                            print("Service has \(buttons.count) buttons")
                            
                            for button in buttons{
                                button.position()
                            }
                        }else{
                            print("Service has no buttons")
                        }
                    
                }
            }
        }


//    ładuje kolejne komórki, zepsute(nakłada na siebie już istniejące)
//        if let prev = self.prev {
//            if prev.id != event.id{
//                var starttime = EPGListViewController.offsetX*EPGListViewController.density - 60*60
//                var endtime = EPGListViewController.offsetX*EPGListViewController.density + 60*60*3
//                self.createEPG(from: UInt64(starttime), to: UInt64(endtime))
//            }
//
//        }
//        self.prev = event
        
        
        

        /*var tx = EPGListViewController.xpos - Double(point.x);
        EPGListViewController.offset = EPGListViewController.offset - tx*3.0;
        
        var servicenr = 0;
        for var servbtt in _epgActiveButtons{
            
         
            
            if(servicenr - EPGListViewController.offsetY < 0 || servicenr - EPGListViewController.offsetY > visibleServices){
                //Jeśli niewidoczny  wiersz
                if let servbtt = servbtt{   //rozpakowuję
                    for b:EPGButton? in servbtt {   // usuwam buttony
                        b?.removeFromSuperview()
                    }
                }
                _epgActiveButtons[servicenr] = nil  //USUWANIE!
            }else{ // jeśli widoczny
                if (servbtt == nil){ // jeśli nie istnieje tablica
                    var time = UInt64(EPGListViewController.offset)
                    var s:Service  = (subservices?.services![servicenr])!
                    
                    var list:Array<EPGButton> = Array()
                    self.organizeData(for: s, placedIn: servicenr, from: time-60*60, to: time+60*60*2)
                    self._epgActiveButtons[servicenr]=list
                    
                }
            }
            //updating positions...
            print("Selected \(point), \(EPGListViewController.xpos)");
            if(Double(point.x)<EPGListViewController.xpos || point.x>1000){
                //if too far!
                print("UPDATING!")
                
                //UIView.animate(withDuration: 0.1){
                    if let servbtt = servbtt {//rozpakowuję
                        for b: EPGButton in servbtt {
                            b.position(withActiveRow: row)
                        }
                    }
                //}
            }
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            servicenr+=1;
        }*/
        
    }
    
    func pressed(_ event:EpgEvent, atButton button:EPGButton){
        let alert = UIAlertController(title: event.tilte, message: event.shortdesc, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Watch Channel Now", style: .default){ a in
            let service = self.services![button.row!]
            self.delegate?.watch(service, inBouquet: self.bouquet!)
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "bouquetPlayed"), object: ["service":service,"bouquet":self.bouquet!])
   
            alert.dismiss(animated: true, completion: nil)
            self.view.window?.rootViewController?.dismiss(animated: true, completion: nil)
            //self.dismiss()
        })
        alert.addAction(UIAlertAction(title: "Record", style: .default){ a in
            
            STBAPI.common()?.setTimer(sref: event.sref!, eid: Int(event.id)){x in
                if (x){
                    button.setRecorded();
                }
            }
            
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel){ a in
            
        })
        self .present(alert, animated: true, completion: {})
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    override func viewWillAppear(_ animated: Bool) {
        if let s = bouquet{
            serviceNameLabel.text=s.sname
        }
    }
    
    func dismiss(){
        self.dismiss(animated: true, completion:nil)
        self.delegate?.dismiss()
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
