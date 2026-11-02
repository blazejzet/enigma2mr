//
//  ViewController.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 15.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit
import CloudKit
import StoreKit


extension UIViewController{
    func dismissAllVC(){
     self.presentedViewController?.dismissAllVC()
     self.presentedViewController?.dismiss(animated: true, completion: nil)
    }
}


class ViewController: UIViewController {
    var sv:StreamView?
    
    @IBOutlet weak var finfo: UILabel!
    @IBOutlet weak var hudView: UIView!
    
    @IBOutlet weak var tvView: UIView!
    
    @IBOutlet weak var channelArrowLeft: UIButton!
    @IBOutlet weak var channelArrowRight: UIButton!
    
    var dvc : UIViewController?
    
    @objc func dismissVC(notification:NSNotification){
        print("play movie");
        //print(dvc);
        let dvc = self.dvc;
        dvc?.dismiss(animated: true, completion: {
            dvc?.dismiss(animated: true, completion: nil)
        });
        if let movie = notification.object as? Movie{
            self.watchMovie(movie)
        }
        
    }
    @objc func dismissVCCont(notification:NSNotification){
        print("play movie");
        //print(dvc);
        let dvc = self.dvc;
        dvc?.dismiss(animated: true, completion: {
            dvc?.dismiss(animated: true, completion: nil)
        });
        if let movie = notification.object as? Movie{
            self.continueMovie(movie)
            
            
            
        }
        
    }
    
    @objc func hidePip(notification:NSNotification){
        print("hiding pip");
        self.sv?.hidePip()
    }
    
    @objc func dismiss(notification:NSNotification){
    print("play stream");
    if let dvc = self.dvc{
        dvc.dismiss(animated: true){
            dvc.dismiss(animated: true, completion: nil)
        }
        }}
    
    @objc func bouquetPlayed(notification:NSNotification){
           print("play stream");
           if let dvc = self.dvc{
               dvc.dismiss(animated: true){
                   dvc.dismiss(animated: true, completion: nil)
               }
           }
           if let dict = notification.object as? [String:Any]{
               print(dict)
              if let bouquet = dict["bouquet"] as? Service, let service = dict["service"] as? Service{
               
                   self.watch(service, inBouquet: bouquet)
               }
               
           }
           
       }
    
    
    
    @objc func bouquetPrepared(notification:NSNotification){
           print("prepare stream");
          
           if let dict = notification.object as? [String:Any]{
               print(dict)
              if let bouquet = dict["bouquet"] as? Service, let service = dict["service"] as? Service{
               
                if let cser = self.watching as? Service {
                    if service.servicereference != cser.servicereference{
                        self.prepare(service, inBouquet: bouquet)
                     }
                }else{
                    self.prepare(service, inBouquet: bouquet)
                }
                
               }
               
           }
           
       }
    
    
    
    @objc func rfinfo(){
        DispatchQueue.main.async {
        UIView.animate(withDuration: 0.3, animations: {
            self.finfo.alpha=0.0
        })
        }
    }
    func sfinfo(){
        DispatchQueue.main.async {
        UIView.animate(withDuration: 0.3, animations: {
            self.finfo.alpha=1.0
        })
        }
        self.perform(#selector(ViewController.rfinfo), with: nil, afterDelay: 5.0)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ////EPGHelper.showAll(text: "VC")
        
        ////EPGHelper.preloadingEPG()
       // //EPGHelper.getInstance()?.displayall(text: "VC");
        
        //pl.asuri.enigmatv.monthly
        //pl.asuri.enigmatv.monthlypromo
        
        
        
        self.perform(#selector(ViewController.rfinfo), with: nil, afterDelay: 5.0)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.dismissVC(notification:)), name: NSNotification.Name(rawValue: "moviePlayed"), object: nil);
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.dismissVCCont(notification:)), name: NSNotification.Name(rawValue: "movieContinue"), object: nil);
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.bouquetPlayed(notification:)), name: NSNotification.Name(rawValue: "bouquetPlayed"), object: nil);
        
               NotificationCenter.default.addObserver(self, selector: #selector(ViewController.dismiss(notification:)), name: NSNotification.Name(rawValue: "dismiss"), object: nil);
               
                      NotificationCenter.default.addObserver(self, selector: #selector(ViewController.hidePip(notification:)), name: NSNotification.Name(rawValue: "hidePip"), object: nil);
                      
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.bouquetPrepared(notification:)), name: NSNotification.Name(rawValue: "bouquetPrepared"), object: nil);
                  
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.watch_alternative(_:)), name: NSNotification.Name(rawValue: "setMainPlayer"), object: nil)
       
        
        
        
        // Do any additional setup after loading the view, typically from a nib.
        sv = StreamView();
        self.tvView.addSubview(sv!);
        sv?.onTimeshiftStatus = { [weak self] text in
            guard let self = self else { return }
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(ViewController.rfinfo), object: nil)
            self.finfo.text = text
            self.sfinfo()
        }
        
       /* var g = UITapGestureRecognizer(target: self, action: #selector(ViewController.epgTapped))
        g.allowedPressTypes = [NSNumber(value: UIPressType.select.rawValue)]
        sv?.addGestureRecognizer(g)*/
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
    }
    
    @objc func checkSettings(){
        if self.refreshonload{
            STBAPI.restart();
            self.refreshonload = false
            self.restartPlayer();
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
       print("V APPEARED");
        /*IAPHelper.sharedInstance.requestProducts() { alreadyused, purchased, product in
            print("[S] alreadyused \(alreadyused); purchased \(purchased); product  \(product.localizedTitle) \(product.localizedPrice)")
            if (purchased){
                
                self.restartPlayer();
            }else{
                if (alreadyused){
                    self.performSegue(withIdentifier: "pay_olduser", sender: product)
                }else{
                    self.performSegue(withIdentifier: "pay_newuser", sender: product)
                }

            }
        }*/
        self.restartPlayer();
        
        // viewDidAppear can run more than once – install the observers only the first time.
        guard !observersInstalled else { return }
        observersInstalled = true
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "tuner.setupready"), object: nil, queue: nil, using: { [weak self] _ in
                   print("SETUP DONE")
                   self?.dismissAllVC()
                   self?.restartPlayer();
               })
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "exit"), object: nil, queue: nil, using: {_ in
        print("[S] Leaving app, due to not paying")
                  exit(EXIT_SUCCESS)
               })
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "payd"), object: nil, queue: nil, using: { [weak self] _ in
                   print("SETUP DONE")
                   self?.dismissAllVC()
                   self?.restartPlayer();
               })
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "tuner.manualsetup"), object: nil, queue: nil, using: { [weak self] _ in
            print("SETUP MANUALLY")
            self?.dismissAllVC()
            self?.refreshonload=true;
        })
        
        

    }
    private var observersInstalled = false
    var refreshonload = false;
    
    func restartPlayer(){
        let generation = playbackGeneration
        STBAPI.common()?.test(success:{ tunerinfo in
            // A channel/recording chosen meanwhile (or stop()) wins over this restart.
            guard generation == self.playbackGeneration else { return }
            self.start()
            #if DEBUG
            if self.runAutomatedTestIfRequested() || self.showScreenIfRequested() || self.runDemoIfRequested() { return }
            #endif
            self.perform(#selector(ViewController.tapMenu(_:)), with: self, afterDelay: 1.0)
        },
                              failure:{
            guard generation == self.playbackGeneration else { return }
            guard let api = STBAPI.common(), api.isConfigured else {
                // No receiver chosen yet – search the network.
                self.performSegue(withIdentifier: "showsettings", sender: self)
                return
            }
            api.checkLocalNetworkAccess { denied in
                if denied {
                    self.showLocalNetworkDenied()
                } else {
                    self.showReceiverUnreachable(address: api.stbAddress ?? "")
                }
            }
        })
    }

    /// tvOS blocks local network access for this app – nothing on the LAN can be reached.
    private func showLocalNetworkDenied() {
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(title: "Allow Local Network access",
                                      message: "EnigmaTV needs access to your local network to reach the receiver. Turn it on in Settings → Privacy & Security → Local Network → EnigmaTV.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Try again", style: .default) { _ in self.restartPlayer() })
        present(alert, animated: true)
    }

    /// The configured receiver did not answer: offer to retry instead of starting a new search,
    /// and keep checking in the background – a short network hiccup resolves itself.
    private func showReceiverUnreachable(address: String) {
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(title: "Receiver not reachable",
                                      message: "\(address) does not answer. Check that it is switched on and connected to the network.",
                                      preferredStyle: .alert)
        var retry: Timer?
        alert.addAction(UIAlertAction(title: "Try again", style: .default) { _ in
            retry?.invalidate()
            self.restartPlayer()
        })
        alert.addAction(UIAlertAction(title: "Search for receivers", style: .default) { _ in
            retry?.invalidate()
            self.performSegue(withIdentifier: "showsettings", sender: self)
        })
        present(alert, animated: true)
        retry = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self, weak alert] timer in
            guard let alert = alert, alert.presentingViewController != nil else {
                timer.invalidate()
                return
            }
            STBAPI.common()?.getInfo(success: { _ in
                timer.invalidate()
                alert.dismiss(animated: true) { self?.restartPlayer() }
            }, failure: {})
        }
    }
    
    override func viewWillLayoutSubviews() {
        //print("V LS");
        // sv?.playStream(ref: "1:0:19:1F4:1C37:17B8:FFFF0000:0:0:0:");
        //sv?.playLastStream()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.stop()
    }
    /// Bumped by stop() and by every explicit channel/recording choice, so that a start() or continueMovie()
    /// still waiting for its data does not start (or replace) playback afterwards.
    private var playbackGeneration = 0

    /// Recording whose media is in the player (watching changes only once continueMovie() has its data).
    private var playingMovie: Movie?
    /// Recording chosen with "continue" whose saved position is still being fetched.
    private var pendingMovie: Movie?
    /// Recording and position when stop() ran (the CloudKit save may still be in flight on return).
    private var stoppedMovie: (movie: Movie, position: Float)?

    /// An explicit channel/recording choice: drop pending startup, foreground resume and continueMovie().
    private func supersedePendingPlayback(){
        playbackGeneration += 1
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(start), object: nil)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(resume), object: nil)
        stoppedMovie = nil
        pendingMovie = nil
    }

    func stop(){
        playbackGeneration += 1
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(start), object: nil)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(resume), object: nil)
        if let movie = playingMovie, sv?.mode == .movie, sv?.mp?.media != nil {   // a second stop() must not reset it
            // A resume seek still waiting for .playing is the real position.
            stoppedMovie = (movie, sv?.changeToPosition ?? sv?.mp?.position ?? 0)
        }
        saveMoviePosition()
        sv?.stop()
        
    }
    
    @objc func start(){
        guard UIApplication.shared.applicationState != .background else { return }
        let generation = playbackGeneration
        sv?.getLastService{ service, bouquet in
            guard generation == self.playbackGeneration, UIApplication.shared.applicationState != .background else { return }
            if let service = service, let bouquet = bouquet {
                self.watch(service, inBouquet: bouquet)
            }
        }
    }

    /// Foreground entry: continue the recording that was playing, otherwise the last channel.
    @objc func resume(){
        if let stopped = stoppedMovie {
            guard UIApplication.shared.applicationState != .background else { return }
            watchMovie(stopped.movie)
            sv?.changeToPosition = stopped.position > 0 && stopped.position < 0.99 ? stopped.position : nil
        } else if let movie = pendingMovie ?? (watching as? Movie) {
            continueMovie(movie)
        } else {
            start()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    var  privateCloudDatabase:CKDatabase?

    /// Stores how far the current recording was watched ("continue watching").
    private func saveMoviePosition(){
        // While a resume seek is pending the stored position is still the right one.
        guard let movie = playingMovie, sv?.mode == .movie, sv?.changeToPosition == nil, let x = sv?.mp?.position else { return }
        let y = Int(x*100.0)
        // 0 also means "just opened" – never overwrite a saved position with it.
        guard y > 0, let serviceref = movie.serviceref, let database = CloudSync.database else { return }
        self.privateCloudDatabase = database
        database.fetch(withRecordID: CKRecord.ID(recordName: serviceref), completionHandler: {(r,_ ) in
            if let r = r {
                print("updating time to : \(y)")
                r["watched"] = NSNumber(integerLiteral: y)
                database.save(r) { _, error in
                    if let error = error { print("saving position failed: \(error)") }
                }
            }
        })
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        saveMoviePosition()
        print("bbbbbbb func prepare")
        self.dvc = segue.destination
        
         if let evc = segue.destination as? PayViewController{
            evc.product = sender as! SKProduct
            
        }
        
        if let evc = segue.destination as? ChannelSwipeViewController{
            switch segue.identifier {
            case "channelSwipeLeft":
                evc.initialDirection = .Left
            case "channelSwipeRight":
                evc.initialDirection = .Right
            default:
                break
            }
            evc.service = self.watching as? Service
            evc.bouquet = self.bouquet
            
        }
        
        if let evc = segue.destination as? AudioTrackViewController{
            //tutja przekazanie
            evc.sv = self.sv
        }
        
        
        if let evc = segue.destination as? InfoViewController
        {//jeśli pokazujemy informacje...
            if let movie = self.watching as? Movie{
                // w przypadku filmu z nagrań.
                var dp = MovieDataProvider()
                dp.movie = movie
                dp.mp = sv?.mp
                evc.delegate = self
                evc.edp = dp
            }
            if let service = self.watching as? Service{
                // w przypadku programu live
                if sv?.timeshift ?? false {
                    //jeśli timeshift aktywny
                    let tsdp = TimeshiftDataProvider()
                    tsdp.sv = sv
                    tsdp.mp = sv?.mp
                    tsdp.refresh()
                    evc.delegate=self
                    evc.service = service
                    evc.edp = tsdp
                }else{
                    //jeśli tmieshift nieaktywny
                    evc.delegate=self
                    if let sref = service.servicereference{
                        STBAPI.common()?.nowPlaying(at: sref, sname: service.servicename ?? ""){
                            [weak evc] nowE, nextE in
                            let edp = EventDataProvider()
                            edp.event = nowE
                            edp.nextevent = nextE
                            edp.serviceName = service.servicename
                            evc?.service = service
                            evc?.edp = edp
                        }
                    }

                }
            }
        }
        
        
        
        
        
        
//        if let evc = segue.destination as? EPGViewController{
//            evc.delegate = self
//        }
        
    }
        
        
        
    
    
    var watching:Any?
    var bouquet:Service?
    var services:[Service]?
   // var subservices:Servicelist?
    
        
        @objc func watch_alternative(_ notification: Notification){
    //        _ service:Service, inBouquet bouquet:Service, direction:Int = 0
            guard let service = notification.userInfo?["service"] as? Service,
                  let bouquet = notification.userInfo?["bouquet"] as? Service else { return }
            self.watch(service, inBouquet: bouquet)
          
        }
    
    func prepare(_ service:Service, inBouquet bouquet:Service, dir:Direction = .Center){
        sv?.prepare(service, inBouquet:bouquet)
    }
        
    
    func watch(_ service:Service, inBouquet bouquet:Service, dir:Direction = .Center){
        print("watching \(service.servicename) in \(bouquet.servicename)")
        //self.sv?.alpha = 0.2
        
        self.switchChannel(dir)
        supersedePendingPlayback()
        playingMovie = nil
        self.bouquet = bouquet
        self.watching = service
        // Channel lists for up/down switching come from DataProvider (ChannelSwipeViewController).
        sv?.play(service, inBouquet:bouquet)
    }
        
    func watchMovie(_ movie:Movie){
        supersedePendingPlayback()
        self.watching = movie
        playingMovie = movie
        self.bouquet=nil
        sv?.changeToPosition = nil
        sv?.play(movie)
        showInfo(for: movie)
    }
    func continueMovie(_ movie:Movie){
        guard let serviceref = movie.serviceref, let database = CloudSync.database else {
            watchMovie(movie)
            return
        }
        supersedePendingPlayback()
        let generation = playbackGeneration
        pendingMovie = movie
        self.privateCloudDatabase = database
        // Read the saved position before playback starts: the info overlay segue saves the player position.
        database.fetch(withRecordID: CKRecord.ID(recordName: serviceref)) { r, _ in
            let watched = (r?["watched"] as? NSNumber)?.intValue ?? 0
            DispatchQueue.main.async {
                guard generation == self.playbackGeneration,
                      UIApplication.shared.applicationState != .background else { return }
                self.pendingMovie = nil
                self.watching = movie
                self.bouquet = nil
                self.playingMovie = movie
                self.sv?.play(movie)
                // Applied by StreamView once VLC reports .playing (a seek before that is ignored).
                self.sv?.changeToPosition = watched > 0 && watched < 100 ? Float(watched) / 100.0 : nil
                self.showInfo(for: movie)
            }
        }
    }
    
    @objc func showInfoService(){
        self.showInfo(for: watching!)
    }
    
    func showInfo(for media:Any){
           self.performSegue(withIdentifier: "info", sender: media)
       }

    func showChooser(for media:Any){
           self.performSegue(withIdentifier: "chooser", sender: media)
       }
       
    
    
    @IBAction func swipeRight(_ sender: Any){
        print("gesture: swipe right")
        if let _ = self.watching as? Service{
            performSegue(withIdentifier: "channelSwipeRight", sender: nil)
        }
//        performSegue(withIdentifier: "swipeChannel", sender: nil)
        
    }
    
    @IBAction func swipeLeft(_ sender: Any){
        print("gesture: swipe left")
        if let _ = self.watching as? Service{
            performSegue(withIdentifier: "channelSwipeLeft", sender: nil)
        }
    }
    
    @IBAction func tapRight(_ sender: Any) {
        print("gesture: tap right")
        if let _ = self.watching as? Service{
            performSegue(withIdentifier: "channelSwipeRight", sender: nil)
        }
//        if let service = watching as? Service{
//            var row =  service.row
//            print("tapRight \(services?.count)")
//                if let list = services{
//                    row = row + 1
//                    if (row>=list.count){
//                        row=0
//                    }
//                    let newservice = list[Int(row)]
//                    print("switching to \(row)")
//
//                    self.watch(newservice, inBouquet: self.bouquet!, dir: .Left)
//                }
//
//        }
//        print("gesture: tap right")
        
    }
    @IBAction func tapLeft(_ sender: Any) {
        print("gesture: tap left")
        if let _ = self.watching as? Service{
            performSegue(withIdentifier: "channelSwipeLeft", sender: nil)
        }
//        if let service = watching as? Service{
//            if var row =  service.row{
//                if let list = services{
//                    row = row - 1
//                    if (row<0){
//                        row=list.count-1
//                    }
//                    print("switching to \(row)")
//                    let newservice = list[row]
//
//                    self.watch(newservice, inBouquet: self.bouquet!, dir: .Right)
//                }
//            }
//        }
    }
    
    func switchChannel(_ dir:Direction){
        DispatchQueue.main.async{
        UIView.animate(withDuration: 0.3, animations: {
            
            if dir == Direction.Center{
                self.sv?.center=CGPoint(x:1920.0/2.0,y:540.0)
            }
            //self.sv?.alpha=0.0
        }, completion: {_ in
            self.sv?.center=CGPoint(x:1920.0/2.0,y:540)
        })
        }
        
    }
    
    /// Menu opens the EPG. For a few seconds afterwards the player lets Menu through to the system,
    /// so pressing it again goes to the Home screen (the app is suspended – not killed via exit()).
    @IBAction func tapMenu(_ sender: Any) {
        self.performSegue(withIdentifier: "epg", sender: sender)
        setMenuGesturesEnabled(false)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(ViewController.menuUnlock), object: nil)
        self.perform(#selector(ViewController.menuUnlock), with: nil, afterDelay: 4.0)
    }
    @objc func menuUnlock(){
        setMenuGesturesEnabled(true)
    }

    private func setMenuGesturesEnabled(_ enabled: Bool) {
        let menu = NSNumber(value: UIPress.PressType.menu.rawValue)
        var views: [UIView] = [view]
        while let v = views.popLast() {
            for recognizer in v.gestureRecognizers ?? [] where recognizer.allowedPressTypes.contains(menu) {
                recognizer.isEnabled = enabled
            }
            views.append(contentsOf: v.subviews)
        }
    }
    //PILOt
    
    @IBAction func playPausePressed(_ sender: Any) {
        //if (sv?.timeshift)!{
            sv?.stTogglePause()
        //}else{
        //    sv?.switchToTimeshift()
            //sv?.stpause()
        //}
        //switching to timeShift
    }
    

}



enum Direction{
    case Left,Right,Center
}

#if DEBUG
// MARK: - Automated test scenarios (Debug builds only)
//
// Launch with `-EnigmaTest timeshift` (e.g. `xcrun simctl launch <sim> <bundle id> -EnigmaTest timeshift`).
// Runs scripted player actions and logs "TEST ..." lines, so playback can be verified without a remote.
extension ViewController {

    /// Returns true when a scenario was started (the automatic EPG menu is then skipped).
    func runAutomatedTestIfRequested() -> Bool {
        guard let scenario = UserDefaults.standard.string(forKey: "EnigmaTest") else { return false }
        print("TEST start scenario=\(scenario)")
        let steps: [(TimeInterval, String, () -> Void)] = [
            (8, "watching", {}),
            (10, "pause", { self.sv?.stTogglePause() }),
            (20, "paused 10s", {}),
            (21, "resume", { self.sv?.stTogglePause() }),
            (28, "after resume (expect ~10s delay)", {}),
            (30, "seek -20s", { self.sv?.seekTimeshift(by: -20) }),
            (38, "after seek (expect ~30s delay)", {}),
            (40, "go live", { self.sv?.goLive() }),
            (48, "after live (expect ~3-5s delay)", {}),
            (50, "next channel", { self.testSwitchChannel(offset: 1) }),
            (60, "after channel change", {}),
            (62, "background", { self.stop() }),
            (66, "foreground", { self.start() }),
            (76, "after foreground", {}),
            (78, "info overlay", { self.performSegue(withIdentifier: "info", sender: nil) }),
            (80, "info overlay shown", { self.testLogInfoOverlay() }),
            (84, "done", {}),
        ]
        for (time, name, action) in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + time) {
                action()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.testLog(name, t: time) }
            }
        }
        return true
    }

    private static var demoStarted = false

    /// `-EnigmaResetSettings YES -EnigmaDemo YES`: a hands-free walkthrough for the App Review video –
    /// receiver discovery and selection (in the discovery screen), then TV guide, programme details,
    /// live TV with info overlay, channel switching, audio/subtitles, recordings and settings.
    func runDemoIfRequested() -> Bool {
        guard UserDefaults.standard.bool(forKey: "EnigmaDemo") else { return false }
        guard !ViewController.demoStarted else { return true }
        ViewController.demoStarted = true
        UserDefaults.standard.set(30, forKey: "EnigmaOverlaySeconds")
        print("DEMO start")

        var t: TimeInterval = 0
        func step(_ delay: TimeInterval, _ name: String, _ action: @escaping () -> Void) {
            t += delay
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                print("DEMO \(name)")
                action()
            }
        }
        var tabs: MenuTabBarController? { return self.presentedViewController as? MenuTabBarController }
        var gallery: BouquetsGalleryViewController? { return tabs?.viewControllers?.first as? BouquetsGalleryViewController }
        func select<T>(_ type: T.Type) {
            guard let tabs = tabs, let index = tabs.viewControllers?.firstIndex(where: {
                ((($0 as? UINavigationController)?.viewControllers.first) ?? $0) is T
            }) else { return }
            tabs.selectedIndex = index
        }
        func scroll(section: Int, to item: Int) {
            guard let cv = gallery?.cv, section < cv.numberOfSections, item < cv.numberOfItems(inSection: section) else { return }
            cv.scrollToItem(at: IndexPath(item: item, section: section), at: .centeredHorizontally, animated: true)
        }

        // TV guide
        step(1, "guide") { self.tapMenu(self) }
        step(3, "focus") { tabs?.debugFocusIntoContent() }
        step(3, "browse 1") { scroll(section: 0, to: 4) }
        step(3, "browse 2") { scroll(section: 0, to: 6) }
        step(3, "browse 3") { scroll(section: 1, to: 3) }
        step(3, "browse 4") { scroll(section: 0, to: 5) }
        // Programme details → watch
        step(3, "details") {
            // TVP1 in the author's Favourites (its neighbour TVP2 carries regular programmes too).
            guard let gallery = gallery, gallery.cv.numberOfItems(inSection: 0) > 5 else { return }
            let item = IndexPath(item: 5, section: 0)
            gallery.cv.selectItem(at: item, animated: false, scrollPosition: [])
            gallery.performSegue(withIdentifier: "showdetails", sender: gallery.cv.cellForItem(at: item))
        }
        step(6, "watch") { (tabs?.presentedViewController as? TVEventViewController)?.watchnow(self) }
        // Live TV
        step(7, "info") { self.performSegue(withIdentifier: "info", sender: nil) }
        step(7, "hide info") { self.presentedViewController?.dismiss(animated: true) }
        step(2, "channel switch") { self.performSegue(withIdentifier: "channelSwipeRight", sender: nil) }
        step(3, "next channel") { (self.presentedViewController as? ChannelSwipeViewController)?.rightArrowClicked(self) }
        step(4, "close switch") { self.presentedViewController?.dismiss(animated: true) }
        step(3, "audio") { self.performSegue(withIdentifier: "chooser", sender: nil) }
        step(5, "close audio") { self.presentedViewController?.dismiss(animated: true) }
        // Recordings & settings
        step(3, "menu") { self.tapMenu(self) }
        step(2, "recordings") { select(Movies2ViewController.self) }
        step(5, "settings") { select(ReceiverSettingsViewController.self) }
        step(6, "all settings") {
            let navigation = tabs?.selectedViewController as? UINavigationController
            navigation?.pushViewController(ConfigSectionsViewController(), animated: true)
        }
        step(5, "back to TV") {
            UserDefaults.standard.removeObject(forKey: "EnigmaOverlaySeconds")
            self.dismissAllVC()
        }
        step(4, "end") {}
        return true
    }

    /// `-EnigmaScreen epg|recordings|settings|timeshift|allsettings|recordingsettings|details|info|swipe|audio|discovery` opens that screen
    /// (for screenshots on a device without using the remote).
    func showScreenIfRequested() -> Bool {
        guard let screen = UserDefaults.standard.string(forKey: "EnigmaScreen") else { return false }
        print("TEST screen=\(screen)")
        func tab(_ type: AnyClass) {
            performSegue(withIdentifier: "epg", sender: self)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                guard let tabs = self.presentedViewController as? UITabBarController,
                      let index = tabs.viewControllers?.firstIndex(where: {
                          ((($0 as? UINavigationController)?.viewControllers.first) ?? $0).isKind(of: type)
                      }) else { return }
                tabs.selectedIndex = index
            }
        }
        let focusContent = UserDefaults.standard.bool(forKey: "EnigmaFocus")
        if focusContent {
            DispatchQueue.main.asyncAfter(deadline: .now() + 9) {
                (self.presentedViewController as? MenuTabBarController)?.debugFocusIntoContent()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            switch screen {
            case "timeshift":
                // Watch ~75 s, jump 40 s back, show the overlay with the timeshift badge.
                DispatchQueue.main.asyncAfter(deadline: .now() + 70) {
                    self.sv?.seekTimeshift(by: -40)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                        self.performSegue(withIdentifier: "info", sender: nil)
                    }
                }
            case "epg": tab(BouquetsGalleryViewController.self)
            case "recordings": tab(Movies2ViewController.self)
            case "settings": tab(ReceiverSettingsViewController.self)
            case "allsettings", "recordingsettings":
                tab(ReceiverSettingsViewController.self)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    let navigation = (self.presentedViewController as? UITabBarController)?.selectedViewController as? UINavigationController
                    let next: UIViewController = screen == "allsettings"
                        ? ConfigSectionsViewController()
                        : ConfigItemsViewController(section: ReceiverConfigSection(key: "Recording", title: "Recording Settings"))
                    navigation?.pushViewController(next, animated: false)
                }
            case "details":
                tab(BouquetsGalleryViewController.self)
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                    guard let tabs = self.presentedViewController as? UITabBarController,
                          let gallery = tabs.selectedViewController as? BouquetsGalleryViewController,
                          gallery.cv.numberOfSections > 0, gallery.cv.numberOfItems(inSection: 0) > 0 else { return }
                    let item = min(UserDefaults.standard.integer(forKey: "EnigmaItem"), gallery.cv.numberOfItems(inSection: 0) - 1)
                    let first = IndexPath(item: item, section: 0)
                    gallery.cv.scrollToItem(at: first, at: .centeredHorizontally, animated: false)
                    gallery.cv.layoutIfNeeded()
                    gallery.cv.selectItem(at: first, animated: false, scrollPosition: [])
                    gallery.performSegue(withIdentifier: "showdetails", sender: gallery.cv.cellForItem(at: first))
                }
            case "info": self.performSegue(withIdentifier: "info", sender: nil)
            case "swipe": self.performSegue(withIdentifier: "channelSwipeRight", sender: nil)
            case "audio": self.performSegue(withIdentifier: "chooser", sender: nil)
            case "discovery": self.performSegue(withIdentifier: "showsettings", sender: nil)
            default: print("TEST unknown screen \(screen)")
            }
        }
        return true
    }

    private func testLog(_ step: String, t: TimeInterval) {
        guard let sv = sv, let player = sv.mp else { return }
        let window = TimeShiftRecorder.common().window
        let buffered = window.map { String(format: "%.0fs", $0.end - $0.start) } ?? "-"
        let state = VLCMediaPlayerStateToString(player.state) as String
        let channel = (watching as? Service)?.servicename ?? "-"
        print(String(format: "TEST t=%02.0f %@ | channel=%@ state=%@ playing=%@ timeshift=%@ delay=%.1fs buffered=%@ received=%dKB vlcTime=%@ video=%@",
                     t, step, channel, state, player.isPlaying ? "yes" : "no", sv.timeshift ? "yes" : "no",
                     sv.timeshiftDelay, buffered, (TimeShiftRecorder.common().conn2?.getDataSize() ?? 0) / 1024,
                     player.time.stringValue as String, "\(Int(player.videoSize.width))x\(Int(player.videoSize.height))"))
    }

    private func testSwitchChannel(offset: Int) {
        guard let service = watching as? Service, let bouquet = bouquet, let bref = bouquet.servicereference else { return }
        DataProvider.def().getServices(bref: bref) { services in
            guard let next = DataProvider.def().neighbour(of: service, in: services, offset: offset) else { return }
            self.watch(next, inBouquet: bouquet)
        }
    }

    private func testLogInfoOverlay() {
        guard let info = presentedViewController as? InfoViewController, let edp = info.edp else {
            print("TEST info overlay: not presented")
            return
        }
        print("TEST info overlay: service=\(edp.getServiceName()) now=\(edp.getCurrentEvent()?.title ?? "-") next=\(edp.getNextEvent()?.title ?? "-") current=\(edp.getCurrentTime()) window=\(edp.getTimeshiftStartTime())-\(edp.getTimeshiftStopTime())")
    }
}
#endif
