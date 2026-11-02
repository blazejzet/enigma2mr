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
                        "Initial setup",
                        "Watching channel",
                       "EPG",
                       "Movie Details",
                       "Timeshift",
                       "Recordings"]
    var info_messages = ["Initial setup is Automatic. You need to have an Enigma2 based device running OpenWebIF in Your network (New and old API). If failed, You can enter settings manually. If You are using access password, need to enter it in the settings. If not, leave them empty",
                         "During watching You can swipe up and display channel info. Click left or right for swithing channel. Swipe down or tap 'menu button to see EPG menu",
                         "EPG provides access to inormation abot the channels. Click on selection for watching or schedule recording ",
                         "Recorded movie screen provides additional info about movie and allows to watch or delete recording",
                         "While watching channel, video data is recorded on AppleTV Disk. Swipe left and right for jump in recorded video",
                         "Beutiful experience with recording lists. Swipe down or right to delete recording."]
    
    override func viewDidLoad() {
        showInfo()
    }
}
