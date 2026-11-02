//
//  MovieCollectionViewCell.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 15.05.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit
import CloudKit
extension UIImage {
    func image(withRotation radians: CGFloat) -> UIImage {
        let scale:CGFloat = 0.5
        let cgImage = self.cgImage!
        let LARGEST_SIZE = CGFloat(max(self.size.width, self.size.height)*1.3)
        let context = CGContext.init(data: nil, width:Int(LARGEST_SIZE), height:Int(LARGEST_SIZE), bitsPerComponent: cgImage.bitsPerComponent, bytesPerRow: 0, space: cgImage.colorSpace!, bitmapInfo: cgImage.bitmapInfo.rawValue)!
        
        var drawRect = CGRect.zero
        drawRect.size = self.size
        let drawOrigin = CGPoint(x: (LARGEST_SIZE - self.size.width) * scale,y: (LARGEST_SIZE - self.size.height) * scale)
        drawRect.origin = drawOrigin
        var tf = CGAffineTransform.identity
        tf = tf.translatedBy(x: LARGEST_SIZE * scale, y: LARGEST_SIZE * scale)
        tf = tf.rotated(by: CGFloat(radians))
        tf = tf.translatedBy(x: LARGEST_SIZE * -scale, y: LARGEST_SIZE * -scale)
        context.concatenate(tf)
        context.draw(cgImage, in: drawRect)
        var rotatedImage = context.makeImage()!
        
        drawRect = drawRect.applying(tf)
        
        rotatedImage = rotatedImage.cropping(to: drawRect)!
        let resultImage = UIImage(cgImage: rotatedImage)
        return resultImage
        
        
    }
}
class BouquetCollectionViewCell: CommonCollectionViewCell {
    
    
    @IBOutlet var picons: [UIImageView]!
    
    
    
    //var service:Service?
    var bouquet:Service?
    
    
    func configure(bouquet:Service){
        self.bouquet = bouquet;
        self.recordingLabel?.text = bouquet.sname;
        self.deletingAvailable=false
        
        var picind=0
        
        for imgvi in picons {
            imgvi.image=nil
        }
        /*STBAPI.common()?.getServices(for: serv, cb: {sl in
            for s in sl.services!{
                if let name = s.servicename{
                    if let p = STBAPI.common()?.getPicon(name: name)
                    {
                        if picind<4{
                        self.picons[picind].image = p.image(withRotation: 0.23)
                        }
                        picind+=1
                        
                    }
                }
            }
        }, fail: {})*/
        
        DataProvider.def().getServices(bref: self.bouquet!.sref!){
            services in
            for s in services{
                if let name = s.sname{
                    if let p = STBAPI.common()?.getPicon(name: name)
                    {
                        if picind<4{
                            self.picons[picind].image = p.image(withRotation: 0.23)
                        }
                        picind+=1
                        
                    }
                }
            }
        }
    }
    
    
    override func select(){
        self.layoutIfNeeded()
        UIView.animate(withDuration: 0.2) {
            self.hC.constant =  220
            self.wC.constant = 640
            self.topmargin = 10.0
            self.shadYC.constant=40.0
            self.topC.constant = self.topmargin;
            self.f?()
            self.layoutIfNeeded()
        }
    }
    
    override func deselect(){
        self.layoutIfNeeded()
        UIView.animate(withDuration: 0.2) {
            self.hC.constant=180
            self.wC.constant=600
            self.shadYC.constant=0.0
            self.topmargin = 40.0
            self.f=nil
            self.topC.constant = self.topmargin;
            self.layoutIfNeeded()
        }
    }
    
}
