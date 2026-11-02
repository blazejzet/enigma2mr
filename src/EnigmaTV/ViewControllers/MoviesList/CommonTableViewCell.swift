//
//  CommonTableViewCell.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 25.04.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit

class CommonTableViewCell: UITableViewCell {

    
    var backdrop:UIImage?
    var poster:UIImage?
    var picon:UIImage?
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    @IBOutlet weak var lcc: NSLayoutConstraint!
    
    func deleteItem(){
        
    }
    
    func setInidicatorFrame(x:CGFloat){
        lcc.constant=x
    }
    func setInidicatorAlpha(alpha:CGFloat){
        lco.alpha=alpha
    }
    @IBOutlet weak var lco: UIView!
    
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
    
    func conf(){
        self.backdrop = UIImage(named:"poster_placeholder");
        self.poster = UIImage(named:"poster_placeholder");
        //self.backdrop = UIImage(named:"poster_placeholder");
        
     self.lco.backgroundColor = UIColor.init(red: 0, green: 0, blue: 0, alpha: 0.5)
     self.setInidicatorAlpha(alpha: 1.0)
        self.lco.layer.cornerRadius = self.frame.size.height/2
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        //context.previouslyFocusedView?.backgroundColor = UIColor.clear
        if let pv = context.previouslyFocusedView as? CommonTableViewCell{
            self.set(color: UIColor.lightGray, inView: pv)
            
            pv.lco.backgroundColor = UIColor.init(red: 0, green: 0, blue: 0, alpha: 0.5)
           
        }
        if(context.nextFocusedView is UITableViewCell){
           
            if let pv = context.nextFocusedView as? CommonTableViewCell {
                pv.lco.backgroundColor = #colorLiteral(red: 0.01176470588, green: 0.6392156863, blue: 1, alpha: 1)
                self.set(color: UIColor.white, inView: pv)
                if let bck = pv.backdrop{
                    self.f?(bck,picon,pv.poster)
                    
                }else{
                    self.f?(UIImage(named:"poster_placeholder"),picon,nil)
                }
            }
        }
    }
    
    var sp: CGPoint?
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("touchesBegan")
        sp = touches.first?.location(in: self);
        print()
    }
    
    var deletingAvailable = true
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("touchesMoved")
        if self.isFocused && deletingAvailable{
            let cp = touches.first?.location(in: self);
            var r = -(((sp?.x)!-(cp?.x)!)/3)
            print(r)
            if r>150{
                self.setInidicatorFrame(x:r-150)
            }
                
                if r>450{
                    self.setInidicatorAlpha(alpha: 0.5)
                    self.lco.backgroundColor=UIColor.red
                    
                }else{
                    self.setInidicatorAlpha(alpha: 1.0)
//                    self.lco.backgroundColor=#colorLiteral(red: 0.01176470588, green: 0.6392156863, blue: 1, alpha: 1)
                    
                }
            
        }else{
            UIView.animate(withDuration: 0.3, animations: {
                self.setInidicatorAlpha(alpha: 1.0)
                self.setInidicatorFrame(x:0)
//                self.lco.backgroundColor=#colorLiteral(red: 0.01176470588, green: 0.6392156863, blue: 1, alpha: 1)
            })
        }
        print(touches.first?.location(in: self))
        
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("touchesEnded")
        let cp = touches.first?.location(in: self);
        var r = -(((sp?.x)!-(cp?.x)!)/3)
       
        if r>450{
            print("deleting")
            UIView.animate(withDuration: 0.3, animations: {
                self.lco.backgroundColor = UIColor.red;
                self.frame = CGRect(x: self.frame.origin.x, y: self.frame.origin.y, width: self.frame.size.width, height: 0.0)
            }) { _ in
                self.deleteItem()
            }
            
        }else{
            UIView.animate(withDuration: 0.3, animations: {
                self.setInidicatorFrame(x:0)
                self.setInidicatorAlpha(alpha: 1.0)
//                self.lco.backgroundColor=#colorLiteral(red: 0.01176470588, green: 0.6392156863, blue: 1, alpha: 1)
            })
        }
        print(touches.first?.location(in: self))
        
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("touchesCancelled")
        print(touches.first?.location(in: self))
        UIView.animate(withDuration: 0.3, animations: {
            self.setInidicatorFrame(x: 0.0)
            self.setInidicatorAlpha(alpha: 1.0)
//            self.lco.backgroundColor=#colorLiteral(red: 0.01176470588, green: 0.6392156863, blue: 1, alpha: 1)
        })
    }
    
    
    
    var f:((UIImage?,UIImage?,UIImage?)->Void)?
    func backdropcb(f:@escaping ((UIImage?,UIImage?,UIImage?)->Void)){
        self.f=f
    }
    //var deletingAvailable = true
    func requestImage(name:String,tinm:Int,servicename:String){
        if name == "NO DATA" {return;}
        print("Requesting \(name) \(tinm)")
        self.piconSetup(name: servicename)
        STBAPI.common()?.searchInfoWeb(title: name, duration: tinm, eid: 0) {
            image, backdrop, eid, ok in
            DispatchQueue.main.async {
                if (ok ){

                    self.poster = image
                    self.backdrop = backdrop
                    if self.isSelected{
                        self.f?(self.backdrop,self.picon,self.poster)
                    }
                    //self.posterSmall.image=image
                    UIView.animate(withDuration: 0.3){
                        
                    }
                }
                
            }
        }
    }
    
    func piconSetup(name:String){
        var f = "\(name.lowercased().replacingOccurrences(of: " ", with: ""))"
        print(f);
        var p = Bundle.main.path(forResource: f, ofType: "png")
        print(p);
        if let p = p {
            self.picon = UIImage(contentsOfFile: p)
        }
        
    }
    
}
