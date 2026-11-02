    //
//  IAPHelper.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 08/04/2020.
//  Copyright © 2020 Blazej Zyglarski. All rights reserved.
//

import UIKit
    
import StoreKit
import SwiftyStoreKit

    class IAPHelper: NSObject{
        static let sharedInstance = IAPHelper()
        var products = [String:SKProduct]()
        var productspurchases = [String:Bool]()
        var result: ((Bool,Bool,SKProduct) -> Void)?
        
       
       //
        func requestProducts(){
            
        }
        
        var success : (()->Void)?
        func buy(product:SKProduct, success:@escaping  ()->Void){
                   self.success = success
                var pid = product.productIdentifier
                  SwiftyStoreKit.purchaseProduct(product, quantity: 1, atomically: true) { result in
                    switch result {
                    case .success(let product):
                        UserDefaults.standard.set(true, forKey: product.productId)
                         print("[S] SUCCESS")
                         self.success?()
                    case .error(let error):
                        UserDefaults.standard.set(false, forKey: pid)
                        print("[S] \(error)")
                    }
                   }
        }
        func restore(product:SKProduct, success:@escaping  ()->Void){
            SwiftyStoreKit.restorePurchases {
                results in
                print("[S] Restored \(results.restoredPurchases.count)")
                print("[S] Failed \(results.restoreFailedPurchases.count)")
                for purchase in results.restoredPurchases{
                    var id = purchase.productId
                    print("[S] P \(purchase.productId) \(purchase.transaction.transactionState) \(purchase.transaction.transactionDate)")
                    if (purchase.transaction.transactionState == .restored || purchase.transaction.transactionState == .purchased){
                         UserDefaults.standard.set(true, forKey: id)
                    }else{
                         UserDefaults.standard.set(false, forKey: id)
                    }
                }
            }
                   self.success = success
                   
        }
        
        
        func requestProducts(c:((Bool,Bool,SKProduct) -> Void)?){
            self.result = c
            var alreaadyused = false;
            if (UserDefaults.standard.string(forKey: "stbAddress") ?? "0.0.0.0" != "0.0.0.0"){
                alreaadyused = true;
            }
            
            
           SwiftyStoreKit.retrieveProductsInfo(["pl.asuri.enigma.monthly","pl.asuri.enigmatv.monthlypromo"]) { result in
                for product in result.retrievedProducts {
                    print("[S] \(product.localizedTitle): \(product.localizedPrice) ")
                    self.products[product.productIdentifier] = product
                    
                    self.productspurchases[product.productIdentifier] = UserDefaults.standard.bool(forKey: product.productIdentifier) ?? false
                    
                   // SwiftyStoreKit.purchaseProduct(product, quantity: 1, atomically: true) { result in
                        // handle result (same as above)
                   // }
                }
                if (alreaadyused){
                    self.result?(alreaadyused,self.productspurchases["pl.asuri.enigmatv.monthlypromo"]!,self.products["pl.asuri.enigmatv.monthlypromo"]!)
                    
                }else{
                    self.result?(alreaadyused,self.productspurchases["pl.asuri.enigma.monthly"]!,self.products["pl.asuri.enigma.monthly"]!)
                }
            }
            
            
        }
        

}
