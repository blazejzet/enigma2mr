//
//  PayViewController.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 09/04/2020.
//  Copyright © 2020 Blazej Zyglarski. All rights reserved.
//

import UIKit
import StoreKit


class PayViewController: UIViewController {
 
    var product: SKProduct? {
        didSet{
            if let x = price_label{
                conf()
            }
        }
    }
    
    @IBOutlet weak var price_label: UILabel!
    @IBOutlet weak var free_label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
        if let p = product{
            conf()
        }
        // Do any additional setup after loading the view.
    }

    func conf(){
        self.price_label.text = "Then  \(self.product!.localizedPrice!) / month"
        self.free_label.text = "Get \(self.product!.introductoryPrice!.subscriptionPeriod.numberOfUnits) \(unit(unitRawValue: self.product!.introductoryPrice!.subscriptionPeriod.unit.rawValue)) for free"
    }
    
    func unit(unitRawValue:UInt)-> String {
        switch unitRawValue {
            case 0: return "days"
            case 1: return "weeks"
            case 2: return "months"
            case 3: return "years"
            default: return ""
            
        }
    }
    
    @IBAction func tapMenu(_ sender: Any) {
        NotificationCenter.default.post(name: NSNotification.Name("exit"), object: nil)
    }
    
    @IBAction func subscribe(_ sender: Any) {
        IAPHelper.sharedInstance.buy(product:self.product!){
            NotificationCenter.default.post(name: NSNotification.Name("payd"), object: nil)
        }
    }
    
    @IBAction func restore(_ sender: Any) {
        
        IAPHelper.sharedInstance.restore(product:self.product!){
            NotificationCenter.default.post(name: NSNotification.Name("payd"), object: nil)
        }
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
