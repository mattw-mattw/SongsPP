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

    override func viewDidLoad() {
        super.viewDidLoad()
        
        app().currentLoginVC = self;
    }
    
    override func viewWillDisappear(_ b : Bool) {
        super.viewWillDisappear(b)
        
        app().currentLoginVC = nil;
    }
    
    @IBOutlet weak var emailText: UITextField!
    @IBOutlet weak var passwordText: UITextField!
    @IBOutlet weak var musicPathText: UITextField!
    @IBOutlet weak var playlistPathText: UITextField!
    
    var loginAttemptMusicPath : String? = nil;
    var loginAttemptPlaylistPath : String? = nil;
    
    var fullLogin : Bool = false;

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
        let spinnerIndicator = UIActivityIndicatorView(style: .whiteLarge)
        spinnerIndicator.center = CGPoint(x: 135.0, y: 65.5)
        spinnerIndicator.color = UIColor.black
        spinnerIndicator.startAnimating()
        loginBusyControl!.view.addSubview(spinnerIndicator)
        self.present(loginBusyControl!, animated: false, completion: nil)
    }
    
    @IBAction func onLoginButtonClicked(_ sender: UIButton) {
        fullLogin = true;
        startSpinnerControl(message: "Logging in");
        loginAttemptMusicPath = musicPathText.text;
        loginAttemptPlaylistPath = playlistPathText.text;
        mega().login(withEmail: emailText.text!, password: passwordText.text!);
    }

    @IBAction func onResumeSessionButtonClicked(_ sender: UIButton) {
        fullLogin = false;
        do {
            let sid = try String(contentsOf: URL(string: "file://" + cachePath() + "/sid")!, encoding: .utf8);
            
            startSpinnerControl(message: "Resuming Session");
            mega().fastLogin(withSession: sid);
        }
        catch {
            reportMessage(uic: self, message: "No prior session found");
            return;
        }
    }
    
    @IBAction func onLogoutButtonClicked(_ sender: UIButton) {
        startSpinnerControl(message: "Logging out");
        mega().logout();
    }
    
    func loginFinished(error : MEGAError)
    {
        if (error.type == MEGAErrorType.apiOk)
        {
            if (fullLogin)
            {
                do {
                    let sid = mega().dumpSession();
                    try sid!.write(toFile: cachePath()+"/sid", atomically: true, encoding: String.Encoding.utf8);
                    if (loginAttemptMusicPath != nil) {
                        try loginAttemptMusicPath!.write(toFile: cachePath()+"/musicPath", atomically: true, encoding: String.Encoding.utf8);
                    }
                    if (loginAttemptPlaylistPath != nil) {
                        try loginAttemptPlaylistPath!.write(toFile: cachePath()+"/playlistPath", atomically: true, encoding: String.Encoding.utf8);
                    }
                }
                catch {
                    reportMessage(uic: self, message: "Could not store SID, or music/playlist paths");
                }
            }
            loginBusyControl!.message = "Loading MEGA.nz filesystem\n\n";
            mega().fetchNodes();
        }
        else
        {
            loginBusyControl!.dismiss(animated: true);
            loginBusyControl = nil;
            reportMessage(uic: self, message: "Login Failed: " + String(error.nameWithErrorCode(error.type.rawValue)));
        }
    }

    func logoutFinsihed(error : MEGAError)
    {
        if (loginBusyControl != nil)
        {
            loginBusyControl!.dismiss(animated: true);
            loginBusyControl = nil;

            if (error.type == MEGAErrorType.apiOk)
            {
                navigationController?.popViewController(animated: true);
                reportMessage(uic: self, message: "Logout Succeeded");
            }
            else
            {
                reportMessage(uic: self, message: "Logout Failed: " + String(error.type.rawValue));
            }
        }
    }
    

    func fetchnodesFinished(error : MEGAError)
    {
        loginBusyControl!.dismiss(animated: true);
        loginBusyControl = nil;

        if (error.type == MEGAErrorType.apiOk)
        {
            self.navigationController?.popViewController(animated: true);

            do {
                let path = try String(contentsOf: URL(string: "file://" + cachePath() + "/musicPath")!, encoding: .utf8);
                var node = mega().node(forPath: path);
                if (node != nil)
                {
                    app().musicBrowseFolder = node;
                    
                    let path = try String(contentsOf: URL(string: "file://" + cachePath() + "/playlistPath")!, encoding: .utf8);
                    node = mega().node(forPath: path);
                    if (node != nil)
                    {
                        app().playlistBrowseFolder = node;
                    }
                    else
                    {
                        reportMessage(uic: self, message: "Playlist path not found");
                    }
                }
                else
                {
                    reportMessage(uic: self, message: "Music path not found");
                }
            }
            catch {
            }
        }
        else
        {
            reportMessage(uic: self, message: "Login succeeded but fetchnodes failed: "+String(error.nameWithErrorCode(error.type.rawValue)));
        }		
    }

    
}
