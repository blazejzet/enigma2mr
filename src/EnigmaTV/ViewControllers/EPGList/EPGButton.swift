//
//  EPGButton.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 16.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit


extension UIView {

    func dropShadow() {

        let view = self

       
        let shadowLayer = view.layer
        shadowLayer.cornerRadius = self.frame.size.height/2
        shadowLayer.frame = view.frame
        shadowLayer.shadowPath = UIBezierPath(roundedRect: view.bounds, cornerRadius: self.frame.size.height/2).cgPath
        shadowLayer.shadowOpacity = 0.8
        shadowLayer.shadowRadius = 45
        shadowLayer.masksToBounds = false
        shadowLayer.shadowOffset = .zero
        
        //b.background?.clipsToBounds=true

        
    }
    func delShadow(){
        let view = self
        let shadowLayer = view.layer
        shadowLayer.shadowPath = nil
         shadowLayer.shadowRadius = 0
        shadowLayer.shadowOpacity = 0.0
    }
}


class EPGButton: UIButton {
    var event:EpgEvent?
    var type: UIButtonType = UIButtonType.system
    var row:Int?
    var oframe :CGRect?
    var background :UIImageView?
    var backgroundBlur: UIVisualEffectView?
    weak var delegate:EPGListViewController?
    
    
    func setRecorded(){
        var r="🔴 ";
        self.setTitle("\(r)\(self.event!.tilte!.uppercased())", for: .normal)
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        //EPGButton* b = (EPGButton*)context.nextFocusedItem;
        //[self.delegate selected:b At:b.frame.origin onRow:b.row];
        let b = context.nextFocusedItem as? EPGButton
        print("title \(event?.tilte) isfocused \(isFocused)")
        if let b = b{
            self.delegate?.selected(b.event!, at: b.frame.origin, inRow:b.row!, focused: isFocused)
            UIView.animate(withDuration: 0.1){
                if (b==self){
                    
                    print("eventid: \(b.event?.id), \(b.event?.sref), \(b.event?.sname)");
                    self.oframe=self.background?.frame
                      self.background?.frame = CGRect(x: (self.oframe?.origin.x)!-10, y: (self.oframe?.origin.y)!-10, width: (self.oframe?.size.width)!+20, height: (self.oframe?.size.height)!+20)

                    self.background?.layer.cornerRadius = self.oframe!.size.height/2+10
                    //self.backgroundBlur?.layer.cornerRadius = self.oframe!.size.height/2+10
                    self.background?.backgroundColor = .white;
                    //self.background?.image = #imageLiteral(resourceName: "blueEPGButton")
                    self.background?.alpha = 0.2
                    self.superview?.bringSubview(toFront: self)
                    
                    self.dropShadow()
                    
                }else{
                    self.background?.backgroundColor = .black;
                    self.background?.alpha = 0.1;
                    
                    self.background?.frame =  self.oframe!
                    //self.background?.image = #imageLiteral(resourceName: "grayEPGButton")
                    //self.background?.alpha = 0.0
                    
                    self.background?.layer.cornerRadius = self.oframe!.size.height/2
                    //self.backgroundBlur?.layer.cornerRadius = self.oframe!.size.height/2
                    
                   self.delShadow()
                    
                    
                }
            }
        }
    }
    class func newButton(with event:EpgEvent, andService service:Service) -> EPGButton {
        let b =  EPGButton()
        b.event = event
        b.row = Int(service.row)
        b.frame = .zero
        
        
        b.background = UIImageView(frame: CGRect(origin: .zero, size: b.frame.size))
       //b.background?.alpha = 0.0
        
      
        
        //let blurEffect = UIBlurEffect(style: .dark)
        //le/t blurredEffectView = UIVisualEffectView(effect: blurEffect)
        //blurredEffectView.frame = b.bounds
        //b.backgroundBlur = blurredEffectView
        
        
        
        //b.addSubview(b.backgroundBlur!)
        b.addSubview(b.background!)
        var r = ""
        if (event.timer != nil){r="🔴 ";}
        b.setTitle("\(r)\(event.tilte!.uppercased())", for: .normal)
        
        
        
        b.titleLabel?.font = UIFont.systemFont(ofSize: 32);
        
        if event is EpgEventFake{
            b.setTitleColor(.lightGray, for: .normal)
        }
        b.bringSubview(toFront: b.titleLabel!)
        b.contentHorizontalAlignment = .left
        b.titleEdgeInsets = .init(top: 0, left: 10, bottom: 0, right: 0)
        b.background?.backgroundColor = .black;
        b.background?.alpha = 0.1;
        
        //b.background?.image = #imageLiteral(resourceName: "grayEPGButton");
        b.background?.clipsToBounds=true
        //b.backgroundBlur?.clipsToBounds=true
        
        
        b.addTarget(b, action: #selector(EPGButton.pressed), for: .primaryActionTriggered)
        return b
    }
    
    @objc func pressed(_ sender: UIGestureRecognizer){
        delegate?.pressed(self.event!, atButton: self)
    }
    
    init() {
        super.init(frame: .zero)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func position(){
        
        if let row = self.row {
            var effectiveRow = row
            if row > EPGListViewController.activeRow {
                effectiveRow = row + 3
            }
            effectiveRow = effectiveRow - EPGListViewController.offsetY
            
            let width = CGFloat(self.event!.dudation_sec)/CGFloat(EPGListViewController.density)-CGFloat(EPGListViewController.spacing)
            let start = CGFloat(self.event!.begin_timestamp)/CGFloat(EPGListViewController.density)-CGFloat(EPGListViewController.offsetX)
            let top = CGFloat(effectiveRow)*CGFloat(EPGListViewController.height+EPGListViewController.spacing)
            let height = CGFloat(EPGListViewController.height)
            
            self.frame = CGRect(x: start, y: top, width: width, height: height)
            self.background?.frame = CGRect(x: 0.0, y: 0.0, width: width, height: height)
            //self.backgroundBlur?.frame = CGRect(x: 0.0, y: 0.0, width: width, height: height)
            
            self.background?.layer.cornerRadius = height/2
            //self.backgroundBlur?.layer.cornerRadius = height/2
            
            
            if(start<0){
                self.titleEdgeInsets = .init(top: 0, left: (-start)+10, bottom: 0, right: 0)
            }else{
                 self.titleEdgeInsets = .init(top: 0, left: 10, bottom: 0, right: 0)
            }
        }
    }
    
    deinit {
        print("Deleting button \(self.titleLabel?.text)")
    }
    
    
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

}
