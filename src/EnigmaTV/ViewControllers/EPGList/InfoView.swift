//
//  InfoView.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 19.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit

class InfoView: UIView {

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    
    //let backgroundImageView:UIImageView
    let coverView:UIImageView
    var backdrop:UIImage?
    let titleLabel:UILabel
    let descriptionLabel:UILabel
    
    init(){
        //backgroundImageView = UIImageView(image: #imageLiteral(resourceName: "blueEPGButton"))
        coverView = UIImageView()
        titleLabel = UILabel(frame: .zero)
        descriptionLabel = UILabel(frame: .zero)
        super.init(frame: CGRect(x: 0.0, y: 0.0, width: 1600.0, height: EPGListViewController.height*3.0))
        
        
        
        
        self.dropShadow()
        self.clipsToBounds = false;
        //backgroundImageView.frame = self.frame
        //self.addSubview(backgroundImageView)
        
        coverView.frame = CGRect(x: 10.0, y: 10.0, width: EPGListViewController.height*2.0-10.0, height: EPGListViewController.height*3.0-20.0)
        self.addSubview(coverView)
        coverView.alpha=0.0
        
        titleLabel.frame = CGRect(origin: CGPoint(x:10.0,y:0.0), size: CGSize(width: 1600, height: EPGListViewController.height))
        titleLabel.text="Some Name"
        titleLabel.textColor = UIColor.white
        titleLabel.font = UIFont.boldSystemFont(ofSize: 28)
        self.addSubview(titleLabel)
        
        descriptionLabel.frame = CGRect(origin: CGPoint(x:10.0,y:EPGListViewController.height), size: CGSize(width: 1500, height: EPGListViewController.height*2.0))
        descriptionLabel.text="Some Description"
        descriptionLabel.numberOfLines=3
        descriptionLabel.font = UIFont.systemFont(ofSize: 28);
        self.addSubview(descriptionLabel)
        descriptionLabel.textColor = UIColor.white
        descriptionLabel.sizeToFit()
        
        //self.clipsToBounds=true;
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func position(){
        var effectiveRow = EPGListViewController.activeRow 
        effectiveRow = effectiveRow - EPGListViewController.offsetY
        
        self.frame = CGRect(x: CGFloat(0.0), y: CGFloat(effectiveRow+1)*CGFloat(EPGListViewController.height+EPGListViewController.spacing), width:1600.0, height: CGFloat(EPGListViewController.height)*3.0)
        
    }
    var eid:Int=0
    func setup(_ event:EpgEvent){
        self.dropShadow()
        
        self.eid = Int(event.id)
        //descriptionLabel.frame = CGRect(origin: CGPoint(x:10.0,y:EPGListViewController.height), size: CGSize(width: 1500, height: EPGListViewController.height*2.0))
        self.coverView.alpha = 0.0
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.setLocalizedDateFormatFromTemplate("HH:mm")
        let h1 = dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(event.begin_timestamp)))
        let h2 = dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(event.begin_timestamp+event.dudation_sec)))
        
        dateFormatter.setLocalizedDateFormatFromTemplate("EEEE | dd MM yyyy")
        let h3 = dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(event.begin_timestamp)))
        
        let durationinminu = event.dudation_sec / Int64(60)
        titleLabel.text = "\(event.tilte!) | \(h1) - \(h2) | \(h3) | \(durationinminu) minut"
        
        descriptionLabel.text = event.longdesc
        descriptionLabel.sizeToFit()
        
        
        STBAPI.common()?.searchInfoWeb(title: event.tilte ?? "-", duration: Int(durationinminu), eid: Int(event.id), cb: {
        image, backdrop, eid, ok in
         DispatchQueue.main.sync {
            
            if (ok && self.eid == eid){
                self.backdrop = image
                self.coverView.image = image
                UIView.animate(withDuration: 0.3){
                self.coverView.alpha = 1.0
                }
                UIView.animate(withDuration: 0.1){
                self.descriptionLabel.frame = CGRect(origin: CGPoint(x:10.0+EPGListViewController.height*2.2,y:EPGListViewController.height), size: CGSize(width: 1300, height: EPGListViewController.height*2.0))
                self.titleLabel.frame = CGRect(origin: CGPoint(x:10.0+EPGListViewController.height*2.2,y:0.0), size: CGSize(width: 1300, height: EPGListViewController.height))
                self.descriptionLabel.sizeToFit()
                }
                
            }else{
                UIView.animate(withDuration: 0.1){
                self.coverView.alpha = 0.0
                self.descriptionLabel.frame = CGRect(origin: CGPoint(x:10.0,y:EPGListViewController.height), size: CGSize(width: 1500, height: EPGListViewController.height*2.0))
                self.titleLabel.frame = CGRect(origin: CGPoint(x:10.0,y:0.0), size: CGSize(width: 1600, height: EPGListViewController.height))
                self.descriptionLabel.sizeToFit()
                }
            }
            
        }
       })
        
        
        
        
        
        
        
        
        
        
    }
    
}
