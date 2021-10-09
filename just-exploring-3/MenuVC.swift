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
    @IBOutlet weak var forgetFolderLinkButton : UIButton?
    @IBOutlet weak var goOfflineButton : UIButton?
    @IBOutlet weak var goOnlineButton : UIButton?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        setEnabled();
    }
    
    func setEnabled()
    {
        loginButton?.isEnabled = !app().loginState.accountBySession && !app().loginState.accountByFolderLink;
        logoutButton?.isEnabled = app().loginState.accountBySession && app().loginState.online;
        logoutButton?.isHidden = app().loginState.accountByFolderLink;
        forgetFolderLinkButton?.isEnabled = app().loginState.accountByFolderLink;
        forgetFolderLinkButton?.isHidden = !app().loginState.accountByFolderLink;
        goOfflineButton?.isEnabled = app().loginState.online;
        goOnlineButton?.isEnabled = !app().loginState.online && (app().loginState.accountBySession || app().loginState.accountByFolderLink);
    }
    
    func startSpinnerControl(message : String)
    {
        busyControl = UIAlertController(title: nil, message: message + "\n\n", preferredStyle: .alert)
        let spinnerIndicator = UIActivityIndicatorView(style: .large)
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
    
    @IBAction func onForgetFolderLinkButtonClicked(_ sender: UIButton) {
        startSpinnerControl(message: "Forgetting Folder Link");
        app().loginState.forgetFolderLink(onFinish: { success in
            self.busyControl!.dismiss(animated: true);
            self.busyControl = nil;
            if (!success) { reportMessage(uic: self, message: app().loginState.errorMessage); }
            self.setEnabled();
        })
    }
    
    class LogCallback: NSObject, MEGALoggerDelegate {

        var logStream : OutputStream? = nil;

        func log(withTime time : String, logLevel : Int, source : String, message: String)
        {
            if (logStream != nil) {
                logString(time);
                logString(" ");
                logString(message);
                logString("\n");
            }
        }
        	
        func logString(_ s : String)
        {
            let _ = write(s.data(using: String.Encoding.utf8, allowLossyConversion: false)!);
            
//            let pointer: UnsafePointer<Int8>? = NSString(string: s).utf8String;
//            let length = NSString(string: s).length;
//
//            logStream!.write(UnsafePointer<UInt8>(pointer), maxLength: length);
            
            //data.withUnsafeBytes<UInt8>({ (p	: UnsafePointer<UInt8>) -> Void in
            //  logStream!.write(p, maxLength: data.count)
            //})
        }
        
        func write(_ data: Data) -> Int {
            return data.withUnsafeBytes({ (rawBufferPointer: UnsafeRawBufferPointer) -> Int in
                let bufferPointer = rawBufferPointer.bindMemory(to: UInt8.self)
                return logStream!.write(bufferPointer.baseAddress!, maxLength: data.count)
            })
        }
    }
    
    var logCallback : LogCallback? = nil;
    var logStream : OutputStream? = nil;
    
    func startLogging(verbose : Bool)
    {
        if (logCallback == nil)
        {
            logStream = OutputStream(toFileAtPath: logFilePath(), append: true);
            if (logStream != nil) {
                logStream!.open();
                logCallback = LogCallback();
                logCallback!.logStream = logStream;
                MEGASdk.setLogLevel(.debug);
                mega().add(logCallback!);
            }
        }
    }
    
    func stopLogging()
    {
	    if (logCallback != nil)
        {
            logCallback?.logStream = nil;
            mega().remove(logCallback!);
            logCallback = nil;
        }
        if (logStream != nil)
        {
            logStream!.close();
            logStream = nil;
        }
        MEGASdk.setLogLevel(.error);
    }
    
    func uploadLogFile()
    {
        if (CheckOnlineOrWarn("Please go online before uploading the log file", uic: self))
        {
            if (mega().rootNode != nil) {
                mega().startUpload(withLocalPath: logFilePath(), parent: mega().rootNode!)
            }
        }
    }
    
    func deleteLogFile()
    {
        do {
            try FileManager.default.removeItem(atPath: logFilePath())
        }
        catch {
        }
    }
    
    func logFilePath() -> String
    {
        return app().storageModel.tempFilesPath() + "iOS_logfile.log";
    }
    
    @IBAction func onTroubleshootWithLogFilesClicked(_ sender: UIButton) {

        let alert = UIAlertController(title: "Log file", message: "", preferredStyle: .alert)
        
        let startA1 = UIAlertAction(title: "Start logging to file (debug)", style: .default, handler:
                { (UIAlertAction) -> () in self.startLogging(verbose: false) });
        
        let startA2 = UIAlertAction(title: "Start logging to file (verbose)", style: .default, handler:
                { (UIAlertAction) -> () in self.startLogging(verbose: true) });
        
        let stopA = UIAlertAction(title: "Stop logging to file", style: .default, handler:
                { (UIAlertAction) -> () in self.stopLogging() });
        
        let uploadA = UIAlertAction(title: "Upload log file", style: .default, handler:
                { (UIAlertAction) -> () in self.uploadLogFile() });
        
        let deleteA = UIAlertAction(title: "Delete log file", style: .default, handler:
                { (UIAlertAction) -> () in self.deleteLogFile() });
        
        let cancelA = UIAlertAction(title: "Never mind", style: .cancel);

        startA1.isEnabled = logCallback == nil || logStream == nil;
        startA2.isEnabled = logCallback == nil || logStream == nil;
        stopA.isEnabled = logCallback != nil || logStream != nil;
        uploadA.isEnabled = logCallback == nil && logStream == nil && FileManager.default.fileExists(atPath: logFilePath());
        deleteA.isEnabled = logCallback == nil && logStream == nil && FileManager.default.fileExists(atPath: logFilePath());

        alert.addAction(startA1);
        alert.addAction(startA2);
        alert.addAction(stopA);
        alert.addAction(uploadA);
        alert.addAction(deleteA);
        alert.addAction(cancelA);

        self.present(alert, animated: false, completion: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.

        app().explanatoryText = "<tbd>";

        if let button = sender as? UIButton
        {
        
            if (button.tag == 99)
            {
                app().explanatoryText = aboutText;
            }
            else if (button.tag == 98)
            {
                app().explanatoryText = versionText;
            }
            else if (button.tag == 97)
            {
                app().explanatoryText = howtoText;
            }
        }
    }
    
    let aboutText =
    """
    About Songs++
    1.0
    	
    A simple and reliable music file player with these great attributes:
    * Play music files from your MEGA.nz online storage account.
    * Songs are cached as part of the app's storage.
    * The next two songs to be played are downloaded and cached.
    * Operate without an internet connection, playing already cached songs.
    * Download and cache as many as you want ahead of time.
    * Browse your songs in the folder and file structure of your MEGA.nz account.
    * UI design prevents accidentally changing the playing song.
    * Just one simple list of the upcoming queued songs
    * Create or update playlists which are simple files.
    * Save your new and updated playlists back to your MEGA.nz account.
    * View by filename or by Track and Artist names
    * Extract Track and Artist names from music files (functionality from libtag)
    * Make and save short notes on your music tracks, along with BPM
    * File types considered playable (can be queued, iOS actually plays them): mp3, flac, m4a, aac, wav, aiff, au, pcm, ac3, aa, aax
    * Starts offline to minimise network use, go online easily anytime.
    * Choose your music and playlist folders, and browsing outside those folders won't be possible
    * Convert your login to a Writable Folder Link so that the rest of your account is not even downloaded, for even better privacy and resource use.
    """;
    
    let versionText =
    """
    Version history
    
    1.0
    * Initial version
    """
    
    let howtoText =
    """
    Usage Guide
    
    Quick Tips
    * Tap-hold for a short time on songs etc to activate menu options
    
    Getting Started
    * If you don't have a MEGA.nz account yet, sign up.
    * Upload your music to your account (from a laptop/PC is easiest).
    * Create a Playlist folder if you want to. Music and playlists should be under a common folder.
    * Log into your MEGA.nz account in this app from the "Log in to MEGA" menu.
    * Then go to the "Browse Music" tab
    * Tap on folders to drill into them
    * Tap on the title row to go back up one folder level
    * Once in a folder with songs, choose Option->Queue all (top right)
    * Then go to the "Play Queue" tab
    * You should see the first two songs downloading, with the blue bars increasing
    * Once the first blue bar is full, press Play.
    """
}

