//
//  BouquetCell.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 16.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit

class TunerCell: UITableViewCell {
    var info:TunerInfo?
    var delegate:SettingsViewController?
    
    @IBOutlet weak var tunerName: UILabel!
    
    @IBOutlet weak var vendorName: UILabel!
    
    @IBOutlet weak var teamName: UILabel!
    @IBOutlet weak var ipName: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
   
    func configure(serv:TunerInfo){
        self.info = serv;
        
        self.vendorName.text = serv.model
        self.tunerName.text = serv.brand
        self.teamName.text = serv.boxtype
        self.ipName.text = serv.ip
        
        self.backgroundColor = UIColor.init(red: 0, green: 0, blue: 0, alpha: 0.5)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func set(color: UIColor, inView v: UIView ){
        for subview in v.subviews{
            for subview in subview.subviews{
                print(subview)
                if let label = subview as? UILabel{
                    label.textColor = color
                }
            }
        }
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        
        if(context.previouslyFocusedView is UITableViewCell){
            context.previouslyFocusedView?.backgroundColor = UIColor.init(red: 0, green: 0, blue: 0, alpha: 0.5)
            if let pv = context.previouslyFocusedView {
                self.set(color: UIColor.lightGray, inView: pv)
            }
        }
        
        if(context.nextFocusedView is UITableViewCell){
            context.nextFocusedView?.backgroundColor = #colorLiteral(red: 0.01176470588, green: 0.6392156863, blue: 1, alpha: 1)
            if let pv = context.nextFocusedView {
                self.set(color: UIColor.white, inView: pv)
            }
        }
    }

}
