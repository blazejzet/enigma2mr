//
//  ChannelLabel.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 16.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit

class ChannelLabel: UILabel {

    var row : Int
    
    
    init(lab:String, row:Int){
        self.row = row
        super.init(frame: .zero)
        self.text = "    \(lab.uppercased())"
        self.font = UIFont.boldSystemFont(ofSize: 32);
        self.backgroundColor=UIColor.black
        self.textColor = UIColor.white
        //b.bringSubview(toFront: b.titleLabel!)
        //b.contentHorizontalAlignment = .left
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.row = 1
        super.init(coder: aDecoder)
    }
    
    func position(){
        var effectiveRow = row
        if row > EPGListViewController.activeRow {
            effectiveRow = row + 3
        }
        effectiveRow = effectiveRow - EPGListViewController.offsetY
        
            self.frame = CGRect(x: CGFloat(0.0), y: CGFloat(effectiveRow)*CGFloat(EPGListViewController.height+EPGListViewController.spacing), width: CGFloat(EPGListViewController.xwid), height: CGFloat(EPGListViewController.height))
        
        
        
    }
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

}
