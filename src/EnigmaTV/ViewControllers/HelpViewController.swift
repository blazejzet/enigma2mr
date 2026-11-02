//
//  HelpViewController.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 17.04.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit

class HelpViewController: UIViewController {
    @IBOutlet weak var screenshot_view: UIImageView!
    @IBAction func back(_ sender: Any) {
        info-=1;
        if info<0 {
            info = info_images.count-1
        }
        showInfo()
    }
    @IBAction func forward(_ sender: Any) {
        info+=1;
        if info>info_images.count-1 {
            info = 0
        }
        showInfo()
    }
    func showInfo(){
        title_label.text = info_titles[info]
        description_label.text = info_messages[info]
        screenshot_view.image = UIImage(named: info_images[info])
    }
    @IBOutlet weak var title_label: UILabel!
    
    @IBOutlet weak var description_label: UILabel!
    
    var info = 0
    
    
    var info_images = ["s4","s0","s1","s2","s0","s3"]
    var info_titles = [
                        L("Initial setup"),
                        L("Watching a channel"),
                        L("TV guide"),
                        L("Recording details"),
                        L("Timeshift"),
                        L("Recordings")]
    var info_messages = [L("Setup is automatic: the app finds Enigma2 receivers with OpenWebif in your home network. If it finds none, enter the receiver address in Settings. Only enter a user name and password if your receiver requires them."),
                         L("Swipe up for programme information. Click left or right to switch channels. Swipe down for audio and subtitles, press Menu for the TV guide. Press and hold the touch surface to record the channel."),
                         L("The TV guide shows what is on every channel. Select a programme to watch it or to schedule a recording. Search finds programmes on all channels; Rooms shows what your other Apple TVs and receivers are playing."),
                         L("The recording screen shows details about a recording and lets you watch, continue or delete it."),
                         L("While you watch, the picture is buffered on the Apple TV. Pause live TV, then swipe left or right to jump back and forth."),
                         L("All your recordings and scheduled timers in one place. Swipe down on a recording to delete it.")]
    override func viewDidLoad() {
        showInfo()
    }
}
