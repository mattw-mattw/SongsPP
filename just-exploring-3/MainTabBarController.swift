//
//  MainTabBarController.swift
//  SongMe
//
//  Created by Matt Weir on 9/01/20.
//  Copyright © 2020 mattweir. All rights reserved.
//

import Foundation
import UIKit

class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        app().tabBarContoller = self;
    }
}
