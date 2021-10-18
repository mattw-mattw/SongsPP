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
    
    var loginBusyControl : UIAlertController? = nil;

    func startSpinnerControl(message : String)
    {
        loginBusyControl = UIAlertController(title: nil, message: message + "\n\n", preferredStyle: .alert)
        let spinnerIndicator = UIActivityIndicatorView(style: .large)
        spinnerIndicator.center = CGPoint(x: 135.0, y: 65.5)
        spinnerIndicator.color = UIColor.black
        spinnerIndicator.startAnimating()
        loginBusyControl!.view.addSubview(spinnerIndicator)
        self.present(loginBusyControl!, animated: false, completion: nil)
    }
    
    @IBAction func onLoginButtonClicked(_ sender: UIButton) {
        startSpinnerControl(message: "Logging in");
        app().loginState.login(user: emailText.text!, pw: passwordText.text!, twoFactor: "",
                            onProgress: {(message) in self.loginBusyControl!.message = message + "\n\n";},
                            onFinish: { (success) in
                                self.loginBusyControl!.dismiss(animated: true);
                                self.loginBusyControl = nil;
                                if (!success) { reportMessage(uic: self, message: app().loginState.errorMessage); }
                                if (success) { self.navigationController?.popViewController(animated: true); }
                            })

    }



    
}
