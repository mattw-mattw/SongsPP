//
//  LoginVC.swift
//  just-exploring-3
//
//  Created by Admin on 27/10/2019.
//  Copyright © 2019 mattweir. All rights reserved.
//

import Foundation
import UIKit

class ViewTextVC: UIViewController {

    override func viewWillAppear(_ animated: Bool) {
        TextControl.text = app().explanatoryText;
        super.viewWillAppear(animated);
    }
    
    @IBOutlet var TextControl: UILabel!
    
}
