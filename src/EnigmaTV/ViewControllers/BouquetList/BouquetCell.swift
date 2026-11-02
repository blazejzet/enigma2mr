//
//  BouquetCell.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 16.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit

class BouquetCell: UITableViewCell {
    var service:Service?
    var bouquet:Service?
    var delegate:EPGViewController?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
   
    func configure(bouquet:Service){
        self.bouquet = bouquet
        self.textLabel?.text = bouquet.servicename?.uppercased();
//        self.textLabel.setColor
        self.backgroundColor = UIColor.init(red: 0, green: 0, blue: 0, alpha: 0.5)
//        if let rowHeight = delegate?.tableView.estimatedRowHeight{
        self.layer.cornerRadius = self.frame.size.height/2
//        }
        
        
    }
    func configure(serv:Service){
        self.service = serv;
        self.textLabel?.text = serv.servicename;
        self.backgroundColor = UIColor.init(red: 0, green: 0, blue: 0, alpha: 0.5)
//        if let rowHeight = delegate?.tableView.estimatedRowHeight{
            self.layer.cornerRadius = self.frame.size.height/2
//        }
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
                self.set(color: UIColor.white, inView: pv)
            }
        }
        
        if(context.nextFocusedView is UITableViewCell){
            context.nextFocusedView?.backgroundColor = #colorLiteral(red: 0.01176470588, green: 0.6392156863, blue: 1, alpha: 1)
            if let pv = context.nextFocusedView {
                self.set(color: UIColor.black, inView: pv)
            }
        }
    }

}
