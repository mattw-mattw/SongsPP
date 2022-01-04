//
//  LoginVC.swift
//  just-exploring-3
//
//  Created by Admin on 27/10/2019.
//  Copyright © 2019 mattweir. All rights reserved.
//

import Foundation
import UIKit

class LoginVC: UIViewController {

//    override func viewDidLoad() {
//        super.viewDidLoad()
//
//        app().currentLoginVC = self;
//    }
//
//    override func viewWillDisappear(_ b : Bool) {
//        super.viewWillDisappear(b)
//
//        app().currentLoginVC = nil;
//    }	
    
    @IBOutlet weak var emailText: UITextField!
    @IBOutlet weak var passwordText: UITextField!

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    @IBAction func onLoginButtonClicked(_ sender: UIButton) {
        let spinner = ProgressSpinner(uic: self, title: "Logging in", message: "Requesting");
        app().loginState.login(spinner: spinner, user: emailText.text!, pw: passwordText.text!, twoFactor: "",
                            onFinish: { (success) in
                                spinner.dismissOrReportError(success: success)
                                if (success) {
                                    self.navigationController?.popViewController(animated: true);
                                }
                            })

    }



    
}
