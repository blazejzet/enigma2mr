//
//  UIButtonRounded.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 16/01/2020.
//  Copyright © 2020 Blazej Zyglarski. All rights reserved.
//

import UIKit

class UIButtonRounded: UIButton {

    
    
     required init?(coder: NSCoder) {
           super.init(coder: coder)
           self.layer.cornerRadius = 30.0
           self.clipsToBounds  = true
       }

}
