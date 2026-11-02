//
//  AppDelegate.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 15.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

import UIKit
import AERecord
import CoreData
import SwiftyStoreKit
import AVFoundation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Live TV must not dim/sleep while playing.
        application.isIdleTimerDisabled = true
        // Playback session: makes the app the "Now Playing" app (Control Center, iPhone remote, Siri).
        try? AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, mode: AVAudioSessionModeMoviePlayback, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
        #if DEBUG
        // `-EnigmaResetSettings YES`: start like a fresh install (used for the App Review demo recording).
        if UserDefaults.standard.bool(forKey: "EnigmaResetSettings"), let bundle = Bundle.main.bundleIdentifier {
            // Key by key (removePersistentDomain can be served stale by the preferences cache).
            for key in UserDefaults.standard.persistentDomain(forName: bundle)?.keys ?? Dictionary<String, Any>().keys {
                UserDefaults.standard.removeObject(forKey: key)
            }
            UserDefaults.standard.synchronize()
            print("Settings reset: stbAddress=\(UserDefaults.standard.string(forKey: "stbAddress") ?? "nil")")
        }
        #endif
        AppDelegate.registerSettingsBundleDefaults()
        //EPGHelper.preloadingEPG()
        /*SwiftyStoreKit.completeTransactions(){
            p in
            print("[S] Completed purchases")
            print(p)
            for p in p {
                
                if(p.transaction.transactionState == .purchased || p.transaction.transactionState == .restored){
                    UserDefaults.standard.set(true, forKey:  p.productId)
                }else{
                    UserDefaults.standard.set(false, forKey:  p.productId)
                }
               
            }
        }
        let appleValidator = AppleReceiptValidator(service: .production, sharedSecret: "your-shared-secret")
        SwiftyStoreKit.verifyReceipt(using: appleValidator) { result in
            switch result {
            case .success(let receipt):
                var productId = "pl.asuri.enigma.monthly"
                // Verify the purchase of a Subscription
                var purchaseResult = SwiftyStoreKit.verifySubscription(
                    ofType: .autoRenewable, // or .nonRenewing (see below)
                    productId: productId,
                    inReceipt: receipt)
                    
                switch purchaseResult {
                case .purchased(let expiryDate, let items):
                    print("\(productId) is valid until \(expiryDate)\n\(items)\n")
                    UserDefaults.standard.set(true, forKey: productId)
                case .expired(let expiryDate, let items):
                    print("\(productId) is expired since \(expiryDate)\n\(items)\n")
                    UserDefaults.standard.set(false, forKey: productId)
                case .notPurchased:
                    print("The user has never purchased \(productId)")
                    UserDefaults.standard.set(false, forKey: productId)
                }
                
                productId = "pl.asuri.enigmatv.monthlypromo"
                // Verify the purchase of a Subscription
                 purchaseResult = SwiftyStoreKit.verifySubscription(
                    ofType: .autoRenewable, // or .nonRenewing (see below)
                    productId: productId,
                    inReceipt: receipt)
                    
                switch purchaseResult {
                case .purchased(let expiryDate, let items):
                    print("\(productId) is valid until \(expiryDate)\n\(items)\n")
                    UserDefaults.standard.set(true, forKey: productId)
                case .expired(let expiryDate, let items):
                    print("\(productId) is expired since \(expiryDate)\n\(items)\n")
                    UserDefaults.standard.set(false, forKey: productId)
                case .notPurchased:
                    print("The user has never purchased \(productId)")
                    UserDefaults.standard.set(false, forKey: productId)
                }

            case .error(let error):
                print("Receipt verification failed: \(error)")
            }
        }
        */
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        //let l = self.window?.rootViewController as? ViewController
        //l?.stop()
        //let l = self.window?.rootViewController as? ViewController
        //l?.stop()
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    // Background/foreground handling lives in SceneDelegate (UIScene lifecycle, required by tvOS 27;
    // the scene is declared in Info.plist → UIApplicationSceneManifest).

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        ////EPGHelper.preloadingEPG()
       
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    /// Values in Settings.bundle are only shown by the Settings app; they are not
    /// readable through UserDefaults until registered, so register them here.
    private static func registerSettingsBundleDefaults() {
        guard let url = Bundle.main.url(forResource: "Root", withExtension: "plist", subdirectory: "Settings.bundle"),
              let root = NSDictionary(contentsOf: url),
              let specifiers = root["PreferenceSpecifiers"] as? [[String: Any]] else { return }
        var defaults = [String: Any]()
        for specifier in specifiers {
            if let key = specifier["Key"] as? String, let value = specifier["DefaultValue"] {
                defaults[key] = value
            }
        }
        UserDefaults.standard.register(defaults: defaults)
    }
}

/// Owns the window (the root ViewController comes from Main.storyboard via the scene configuration)
/// and stops/restarts playback around backgrounding.
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    /// sceneWillEnterForeground is also called on first launch – only restart after a real background.
    private var wasInBackground = false

    private var player: ViewController? {
        return window?.rootViewController as? ViewController
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        wasInBackground = true
        player?.stop()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        guard wasInBackground, let player = player else { return }
        wasInBackground = false
        player.perform(#selector(ViewController.resume), with: nil, afterDelay: 1.0)
        player.perform(#selector(ViewController.checkSettings), with: nil, afterDelay: 1.0)
    }

}

