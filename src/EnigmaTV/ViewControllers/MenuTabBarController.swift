//
//  MenuTabBarController.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 06/11/2019.
//  Copyright © 2019 Blazej Zyglarski. All rights reserved.
//

import UIKit

class MenuTabBarController: UITabBarController {

    /// Receiver discovery (from the storyboard). Shown as the Settings tab only when no receiver
    /// is configured; otherwise it is opened from Settings → "Search for receivers…".
    private var discovery: SettingsViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        guard var controllers = viewControllers else { return }

        if let index = controllers.firstIndex(where: { $0 is SettingsViewController }) {
            discovery = controllers[index] as? SettingsViewController
            if STBAPI.common()?.isConfigured == true {
                let settings = ReceiverSettingsViewController()
                settings.onSearch = { [weak self] in self?.showDiscovery() }
                let navigation = UINavigationController(rootViewController: settings)
                controllers[index] = navigation
            }
        }

        // Titles by content (the storyboard order is EPG, Settings, Recordings).
        for controller in controllers {
            let content = (controller as? UINavigationController)?.viewControllers.first ?? controller
            switch content {
            case is BouquetsGalleryViewController: controller.tabBarItem.title = "EPG"
            case is Movies2ViewController: controller.tabBarItem.title = "Recordings"
            case is SettingsViewController, is ReceiverSettingsViewController: controller.tabBarItem.title = "Settings"
            default: break
            }
        }
        // EPG, Recordings, Settings – as in the tvOS apps.
        let order: (UIViewController) -> Int = { controller in
            let content = (controller as? UINavigationController)?.viewControllers.first ?? controller
            switch content {
            case is BouquetsGalleryViewController: return 0
            case is Movies2ViewController: return 1
            default: return 2
            }
        }
        controllers.sort { order($0) < order($1) }
        setViewControllers(controllers, animated: false)
    }

    #if DEBUG
    /// Screenshot helper: move focus from the tab bar into the selected screen.
    var debugFocusContent = false

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if debugFocusContent, let content = selectedViewController {
            return [content]
        }
        return super.preferredFocusEnvironments
    }

    func debugFocusIntoContent() {
        debugFocusContent = true
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
        debugFocusContent = false
    }
    #endif

    private func showDiscovery() {
        guard let discovery = discovery else { return }
        discovery.modalPresentationStyle = .overFullScreen
        present(discovery, animated: true)
    }

}
