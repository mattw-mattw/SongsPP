//
//  MenuVC.swift
//  SongMe
//
//  Created by Matt Weir on 4/01/20.
//  Copyright © 2020 mattweir. All rights reserved.
//

import Foundation
import UIKit

class MenuVC: UIViewController {

    var busyControl : UIAlertController? = nil;

    @IBOutlet weak var loginButton : UIButton?
    @IBOutlet weak var logoutButton : UIButton?
    @IBOutlet weak var goOfflineButton : UIButton?
    @IBOutlet weak var goOnlineButton : UIButton?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        setEnabled();
    }
    
    func setEnabled()
    {
        loginButton?.isEnabled = !app().loginState.loggedInOnline && !app().loginState.loggedInOffline;
        logoutButton?.isEnabled = app().loginState.loggedInOnline;
        goOfflineButton?.isEnabled = app().loginState.loggedInOnline;
        goOnlineButton?.isEnabled = app().loginState.loggedInOffline;
    }
    
    func startSpinnerControl(message : String)
    {
        busyControl = UIAlertController(title: nil, message: message + "\n\n", preferredStyle: .alert)
        let spinnerIndicator = UIActivityIndicatorView(style: .whiteLarge)
        spinnerIndicator.center = CGPoint(x: 135.0, y: 65.5)
        spinnerIndicator.color = UIColor.black
        spinnerIndicator.startAnimating()
        busyControl!.view.addSubview(spinnerIndicator)
        self.present(busyControl!, animated: false, completion: nil)
    }

    @IBAction func onGoOfflineButtonClicked(_ sender: UIButton) {
        startSpinnerControl(message: "Going Offline");
        app().loginState.goOffline(
            onProgress: {(message) in self.busyControl!.message = message + "\n\n";},
            onFinish: { (success) in
                self.busyControl!.dismiss(animated: true);
                self.busyControl = nil;
                if (!success) { reportMessage(uic: self, message: app().loginState.errorMessage) }
                self.setEnabled();
            })

    }
    
    @IBAction func onGoOnlineButtonClicked(_ sender: UIButton) {
        startSpinnerControl(message: "Going Online");
        app().loginState.goOnline(
            onProgress: {(message) in self.busyControl!.message = message + "\n\n";},
            onFinish: { (success) in
                self.busyControl!.dismiss(animated: true);
                self.busyControl = nil;
                if (!success) { reportMessage(uic: self, message: app().loginState.errorMessage); }
                self.setEnabled();
        })
    }
    
    @IBAction func onLogoutButtonClicked(_ sender: UIButton) {
        startSpinnerControl(message: "Logging out");
        app().loginState.logout(onFinish: { success in
            self.busyControl!.dismiss(animated: true);
            self.busyControl = nil;
            if (!success) { reportMessage(uic: self, message: app().loginState.errorMessage); }
            self.setEnabled();
        })
    }

}

