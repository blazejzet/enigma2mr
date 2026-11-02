//
//  ChannelLabel.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 16.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit

class TimeLabel: UILabel {
    
    var time : UInt64
    
    
    init(time:UInt64){
        self.time = time
        super.init(frame: CGRect(origin: .zero, size: CGSize(width: 140.0, height: 50.0)))
        self.textColor = UIColor.white
        let ds = Date(timeIntervalSince1970: TimeInterval(time))
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.setLocalizedDateFormatFromTemplate("HH:mm")
        self.text = dateFormatter.string(from: ds)
        self.font = UIFont.boldSystemFont(ofSize: 28);
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.time=0
        super.init(coder: aDecoder)
    }
    
    func position(){
        let t = CGFloat(self.time)/EPGListViewController.density - CGFloat(EPGListViewController.offsetX)
        self.center = CGPoint(x:t , y: 25.0)
    }
    
    
}

