//
//  MenuVC.swift
//  SongMe
//
//  Created by Matt Weir on 4/01/20.
//  Copyright © 2020 mattweir. All rights reserved.
//

import Foundation
import UIKit

class MenuVC: UIViewController, UIDocumentPickerDelegate, FileManagerDelegate {

//    @IBOutlet weak var loginButton : UIButton?
//    @IBOutlet weak var logoutButton : UIButton?
//    @IBOutlet weak var forgetFolderLinkButton : UIButton?
//    @IBOutlet weak var goOfflineButton : UIButton?
//    @IBOutlet weak var goOnlineButton : UIButton?
//    @IBOutlet var reloadAccountButton: UIButton!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        setEnabled();
    }

    var isImport = false;

    @IBAction func onImportFromSharedFolder(_ sender: Any) {
        isImport = true;
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder]);
        picker.delegate = self;
        //picker.directoryURL = "/";
        present(picker, animated: true, completion: nil)
    }
    
    
    @IBAction func onExportMetadata(_ sender: Any) {
        isImport = false;
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder]);
        picker.delegate = self;
        //picker.directoryURL = "/";
        present(picker, animated: true, completion: nil)
    }
    
    func createFolder(_ url : String) -> Void
    {
        do {
            if !FileManager.default.fileExists(atPath: url) {
                try FileManager.default.createDirectory(atPath: url, withIntermediateDirectories: true, attributes: nil);
            }
            var urv = URLResourceValues();
            urv.isExcludedFromBackup = true;
            var attribUrl = URL(fileURLWithPath: url)
            try attribUrl.setResourceValues(urv);
        }
        catch
        {
        }
    }
    
    actor scanQueue  // actor = thread safe
    {
        var q : [(URL?, URL?)] = [];
        
        func push(_ a : URL?, _ b : URL?)
        {
            q.append((a, b));
        }
        
        func pop() -> (URL?, URL?)?
        {
            if q.count == 0 { return nil; }
            let (a, b) = q[q.count-1];
            q.remove(at: q.count-1);
            return (a,b)
        }
    }
    
    var sc = scanQueue();
    
    func ScanDoubleDirs(_ source : String, _ dest : String)
    {
        print("scanning folders  \(source) \(dest) ")
        do
        {
            var sourceItems = try FileManager.default.contentsOfDirectory(atPath: source);
            var destItems = try FileManager.default.contentsOfDirectory(atPath: dest);
            try sourceItems.sort(by: {(a,b) throws -> Bool in a < b } )
            try destItems.sort(by: {(a,b) throws -> Bool in a < b } )
            
            var i = 0;
            var j = 0;
            while true {
                var ileaf = i < sourceItems.count ? sourceItems[i] : nil;
                var jleaf = j < destItems.count ? destItems[j] : nil;
                if (ileaf != nil && jleaf != nil) {
                    if (ileaf! < jleaf!) { jleaf = nil; }
                    else if (jleaf! < ileaf!) { ileaf = nil; }
                }
                if (ileaf == nil && jleaf == nil) { break; }
                
                let ii = source + "/" + (ileaf == nil ? jleaf! : ileaf!)
                let jj = dest + "/" + (jleaf == nil ? ileaf! : jleaf!)
                if (ileaf != nil && jleaf != nil) {

                    i += 1;
                    j += 1;
                    var resultStorage: ObjCBool = false;
                    FileManager.default.fileExists(atPath: ii, isDirectory: &resultStorage)
                    if (resultStorage.boolValue)
                    {
                        ScanDoubleDirs(ii, jj)
                    }
                    else {
                        //print("skipping pre-existing  \(ii) \(jj) ")
                        if (ileaf == "songs++index.json")
                        {
                            print("copying  \(ii) \(jj) ")
                            try FileManager.default.removeItem(atPath: jj)
                            try FileManager.default.copyItem(atPath: ii, toPath: jj)
                        }
                    }
                    continue;
                }
                else if (ileaf != nil) {
                    i += 1;
                    
                    var resultStorage: ObjCBool = false;
                    FileManager.default.fileExists(atPath: ii, isDirectory: &resultStorage)
                    if (resultStorage.boolValue)
                    {
                        print("creating dest folder  \(jj) ")
                        try FileManager.default.createDirectory(atPath: jj, withIntermediateDirectories: false)
                        ScanDoubleDirs(ii, jj)
                    }
                    else
                    {
                        print("copying  \(ii) \(jj) ")
                        try FileManager.default.copyItem(atPath: ii, toPath: jj)
                    }
                }
                else if (jleaf != nil) {
                    j += 1;
                    //let leaf = jj!.lastPathComponent;
                    //ii = URL(fileURLWithPath: dest + "/" + leaf, isDirectory: jj!.hasDirectoryPath);
                }
                else {
                    break;
                }
                //await sc.push(ii, jj)
            }
            
            
        }
        catch
        {
            print("scan failed at \(source) \(dest) due to \(error)")
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL])
    {
        //for u in urls {
        //    reportMessage(uic: self, message: u.absoluteString)
        //}
        
        if (urls.count != 1) { return; }
        let url = urls[0];
        
        if isImport {
            let importFolder = globals.storageModel.importFolderPath();
            
            guard url.startAccessingSecurityScopedResource() else { return };
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let fm = FileManager();
                fm.delegate = self;
                
                var source = url.relativeString;
                if (source.contains("file://"))
                {
                    source.removeFirst(7);
                }
                
                ScanDoubleDirs(source, importFolder + "/root2");
                
                
                //try fm.copyItem(at: url,
                //                to: URL(fileURLWithPath: importFolder + "/root2", isDirectory: true));
            }
//            catch
//            {
//                reportMessage(uic: self, message: "copy failed: \(error)")
//            }
        }
        else
        {
            let exportFolder = globals.storageModel.cacheFilesPath() + "/export";
            
            deleteOldExportFolder(exportFolder);
            createFolder(exportFolder);
            createFolder(exportFolder + "/thumb");
            createFolder(exportFolder + "/playlist");
            
            exportNodeAttribs(globals.musicBrowseFolder!, exportFolder);
            //exportPlaylists(globals.playlistBrowseFolder!, exportFolder + "/playlist")
            
            outputJsonAttrs(exportFolder)
            
            guard url.startAccessingSecurityScopedResource() else { return };
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let fm = FileManager();
                fm.delegate = self;
                
                try fm.copyItem(at: URL(fileURLWithPath: exportFolder, isDirectory: true),
                                                 to: url.appendingPathComponent("songs++index", isDirectory: true));
            }
            catch
            {
                reportMessage(uic: self, message: "copy failed: \(error)")
            }
        }
    }
    
    func fileManager(_ fileManager: FileManager, shouldCopyItemAtPath srcPath: String, toPath dstPath: String) -> Bool {
        let exists = fileManager.fileExists(atPath: dstPath);
        if exists { print("skip " + srcPath + " -> " + dstPath);}
        if !exists { print("copy " + srcPath + " -> " + dstPath);}
        return !exists;
    }
    
    func deleteOldExportFolder(_ exportFolder : String)
    {
        do {
            try FileManager.default.removeItem(at: URL(fileURLWithPath: exportFolder, isDirectory: true));
        }
        catch
        {
            reportMessage(uic: self, message: "remove old folder failed: \(error)")
        }
    }
    	
    func exportNodeAttribs(_ n : MEGANode, _ exportFolder : String)
    {
        if (n.isFolder())
        {
            let children = mega().children(forParent: n)
            for i in 0..<children.size.intValue {
                exportNodeAttribs(children.node(at: i), exportFolder)
            }
        }
        else
        {
            exportAttribs(n, exportFolder)
        }
    }
    
    func exportPlaylists(_ n : MEGANode, _ exportFolder : String)
    {
        let children = mega().children(forParent: n)
        for i in 0..<children.size.intValue {
            let nn = children.node(at: i)!;
            if (nn.isFolder())
            {
                createFolder(exportFolder + "/" + nn.name!);
                exportPlaylists(nn, exportFolder + "/" + nn.name!)
            }
            else
            {
                exportPlaylist(nn, exportFolder)
            }
        }
    }
    
    func exportPlaylist(_ n : MEGANode, _ exportFolder : String)
    {
        
//        var v : [String] = [];
//        globals.storageModel.loadSongsFromPathRecursive(node: n, &v, recurse: true, filterIntent: nil);
//        
//        var playlist : [[String: String]] = [];
//        
//        for nn in v {
//            var jn : [String: String] = [:];
//            jn["mega_h"] = nn.base64Handle;
//            jn["npath"] = app().nodePath(nn);
//            
//            if let filename = globals.storageModel.songFingerprintPath(node: nn) {
//                if let sparseFingerprint = globals.mega?.fingerprint(forFilePath: filename, modificationTime: Date(timeIntervalSince1970: 0)) {
//                    jn["sparse_fp"] = sparseFingerprint;
//                }
//            }
//            playlist.append(jn);
//        }
//        
//        do {
//            let jsonData = try JSONSerialization.data(withJSONObject: playlist, options: JSONSerialization.WritingOptions.sortedKeys)
//            let str = String(data: jsonData, encoding: .utf8);
//            let url = URL(fileURLWithPath: exportFolder + "/" + n.name!);
//            try! str!.write(to: url, atomically: true, encoding: .utf8)
//        } catch {
//        }

    }
    
    func exportThumbnail(_ n : MEGANode, _ exportFolder : String)
    {
//        if (globals.storageModel.thumbnailDownloaded(n)) {
//            if let path = globals.storageModel.thumbnailPath(node: n) {
//                
//                if let thumbFingerprint = globals.mega?.fingerprint(forFilePath: path, modificationTime: Date(timeIntervalSince1970: 0)) {
//                    do {
//                        try FileManager.default.copyItem(atPath: path, toPath: exportFolder + "/thumb/" + thumbFingerprint + ".jpg")
//                    }
//                    catch {
//                    }
//                }
//            }
//        }
    }
    
    var jsonAttrs : [[String: String]] = [];
    var thumbsDone : Set<String> = [];
    
    func exportAttribs(_ n : MEGANode, _ exportFolder : String)
    {
        
        var jn : [String: String] = [:];
        jn["mega_h"] = n.base64Handle;
        jn["npath"] = app().nodePath(n);
        
        var title : String? = n.customTitle;
        if (title == nil) { title = n.name; }
        jn["title"] = title!;
        
        var bpm : String? = n.customBPM;
        if (bpm == nil) { bpm = ""; }
        jn["bpm"] = bpm!;
        
        var artist : String? = n.customArtist;
        if (artist == nil) { artist = "" }
        jn["artist"] = artist!;
        
        let notes : String? = n.customNotes;
        if (notes != nil) {
            jn["notes"] = notes!;
        }
//        
//        if (globals.playQueue.isPlayable(n, orMightContainPlayable: false)) {
//            jn["durat"] = String(format: "%02d:%02d", n.duration / 60, n.duration % 60)
//        }
//        
//        if (globals.storageModel.thumbnailDownloaded(n)) {
//            if let path = globals.storageModel.thumbnailPath(node: n) {
//                
//                if let thumbFingerprint = globals.mega?.fingerprint(forFilePath: path, modificationTime: Date(timeIntervalSince1970: 0)) {
//                    jn["thumb"] = thumbFingerprint;
//                    if !thumbsDone.contains(thumbFingerprint) {
//                        thumbsDone.insert(thumbFingerprint)
//                        do {
//                            //try FileManager.default.copyItem(atPath: path, toPath: exportFolder + "/thumb/" + thumbFingerprint + ".jpg");
//                        }
//                        catch {
//                        }
//                    }
//                }
//            }
//        }
        
        if let filename = globals.storageModel.songFingerprintPath(node: n) {
            if let sparseFingerprint = globals.mega?.fingerprint(forFilePath: filename, modificationTime: Date(timeIntervalSince1970: 0)) {
                jn["sparse_fp"] = sparseFingerprint;
            }
        }
        
        jsonAttrs.append(jn);
    }
    
    func outputJsonAttrs(_ exportFolder : String)
    {
        do {

            //Convert to Data
            let jsonData = try JSONSerialization.data(withJSONObject: jsonAttrs, options: JSONSerialization.WritingOptions.sortedKeys)
            let str = String(data: jsonData, encoding: .utf8);
            //let url = URL(fileURLWithPath: exportFolder + "/songs++index.json", isDirectory: false);
            //globals.mega!.platformSetRLimitNumFile(100000);
            try! str!.write(toFile: exportFolder + "/songs++index.json", atomically: false, encoding: .utf8)  //(to: url, atomically: true, encoding: .utf8)
        } catch {
            print("index file write failed: \(error)")
        }
    }
    
    func setEnabled()	
    {
//        loginButton?.isEnabled = !globals.loginState.accountBySession && !globals.loginState.accountByFolderLink;
//        logoutButton?.isEnabled = globals.loginState.accountBySession && globals.loginState.online;
//        logoutButton?.isHidden = globals.loginState.accountByFolderLink;
//        forgetFolderLinkButton?.isEnabled = globals.loginState.accountByFolderLink;
//        forgetFolderLinkButton?.isHidden = !globals.loginState.accountByFolderLink;
//        goOfflineButton?.isEnabled = globals.loginState.online;
//        goOnlineButton?.isEnabled = !globals.loginState.online && (globals.loginState.accountBySession || globals.loginState.accountByFolderLink);
//        reloadAccountButton.isEnabled = globals.loginState.online && (globals.loginState.accountBySession || globals.loginState.accountByFolderLink);
    }
    
//    @IBAction func onLoginClicked(_ sender: Any) {
//        let alert = UIAlertController(title: "Log in to MEGA", message: "Log in with your MEGA email and password.  If you have 2FA turned on, enter that also.", preferredStyle: .alert)
//        
//        alert.addTextField( configurationHandler: { newTextField in
//            newTextField.placeholder = "email";
//            newTextField.returnKeyType = .next
//        });
//
//        alert.addTextField( configurationHandler: { newTextField in
//            newTextField.placeholder = "password";
//            newTextField.isSecureTextEntry = true;
//            newTextField.returnKeyType = .next
//        });
//
//        alert.addTextField( configurationHandler: { newTextField in
//            newTextField.placeholder = "2FA code";
//            newTextField.returnKeyType = .next
//        });
//
//        alert.addAction(UIAlertAction(title: "Log in", style: .default, handler: { (UIAlertAction) -> () in
//            if (alert.textFields != nil && alert.textFields!.count == 3) {
//                let email = alert.textFields![0].text ?? "";
//                let pw = alert.textFields![1].text ?? "";
//                let twoFA = alert.textFields![2].text ?? "";
//                
//                let spinner = ProgressSpinner(uic: self, title: "Logging in", message: "");
//                
//                globals.loginState.login(spinner: spinner, user: email, pw: pw, twoFactor: twoFA,
//                                    onFinish: { (success) in
//                                        spinner.dismissOrReportError(success: success);
//                                        if (success) { self.navigationController?.popViewController(animated: true); }
//                                        self.setEnabled()
//                                    })
//            }}));
//        
//        alert.addAction(menuAction_neverMind());
//        present(alert, animated: false, completion: nil)
//    }
//    
//    @IBAction func onGoOfflineButtonClicked(_ sender: UIButton) {
//        let spinner = ProgressSpinner(uic: self, title: "Going Offline", message: "");
//        globals.loginState.goOffline(spinner: spinner,
//            onFinish: { (success) in
//                spinner.dismissOrReportError(success: success);
//                self.setEnabled();
//            })
//    }
//    
//    @IBAction func onGoOnlineButtonClicked(_ sender: UIButton) {
//        let spinner = ProgressSpinner(uic: self, title: "Going Online", message: "");
//        globals.loginState.goOnline(spinner: spinner,
//            onFinish: { (success) in
//                spinner.dismissOrReportError(success: success);
//                self.setEnabled();
//            })
//    }
//    
//    @IBAction func onReloadAccountClicked(_ sender: Any) {
//        
//        let alert = UIAlertController(title: "Refetch Account", message: "This action re-fetches and caches your account folder and file tree from the servers.  It can be useful if you think it has gotten out of sync, perhaps with thumbnails available for some copies of a file but not others, for example.", preferredStyle: .alert)
//        
//        alert.addAction(UIAlertAction(title: "Refetch Account", style: .default, handler: { (UIAlertAction) -> () in
//            
//            let spinner = ProgressSpinner(uic: self, title: "Reloading Account", message: "");
//            
//            mega().localLogout();
//            do {
//                try FileManager.default.removeItem(atPath: globals.storageModel.accountPath());
//            }
//            catch {
//            }
//            globals.storageModel.alreadyCreatedFolders = [];
//            _ = globals.storageModel.accountPath(); // recreate folder
//            globals.loginState.goOnline(spinner: spinner, onFinish: {b in
//                spinner.dismissOrReportError(success: b);
//            });
//        }));
//
//        alert.addAction(UIAlertAction(title: "Never mind", style: .cancel));
//        self.present(alert, animated: false, completion: nil)
//    }
//    
//    @IBAction func onLogoutButtonClicked(_ sender: UIButton) {
//        
//        let alert = UIAlertController(title: "Logout", message: "Keeping your cached files can be useful when swapping between a full account, or a writable folder link, by avoiding re-downloading those files.", preferredStyle: .alert)
//        
//        let startA1 = UIAlertAction(title: "Logout and wipe all cached data", style: .default, handler:
//                { (UIAlertAction) -> () in self.logoutAndDealWithCache(deleteCache: true) });
//        
//        let startA2 = UIAlertAction(title: "Logout but keep cached data", style: .default, handler:
//                { (UIAlertAction) -> () in self.logoutAndDealWithCache(deleteCache: false) });
//
//        let cancelA = UIAlertAction(title: "Never mind", style: .cancel);
//
//        alert.addAction(startA1);
//        alert.addAction(startA2);
//        alert.addAction(cancelA);
//
//        self.present(alert, animated: false, completion: nil)
//    }
//    
//    func logoutAndDealWithCache(deleteCache : Bool)
//    {
//        let spinner = ProgressSpinner(uic: self, title: "Logging out", message: "");
//        globals.loginState.logout(spinner: spinner, onFinish: { success_in in
//            
//            var success = success_in;
//            
//            if (success)
//            {
//                app().clear();
//                if (deleteCache)
//                {
//                    success = globals.storageModel.deleteCachedFiles(includingAccountAndSettings: true);
//                    if (!success)
//                    {
//                        spinner.setErrorMessage("Failed to erase cache after logout");
//                    }
//                }
//            }
//            
//            spinner.dismissOrReportError(success: success);
//            self.setEnabled();
//        })
//    }
//    
//    @IBAction func onForgetFolderLinkButtonClicked(_ sender: UIButton) {
//        
//        let alert = UIAlertController(title: "Forget folder link", message: "This operation is the equivalent of logging out when using a writable folder link. You have the option to wipe cached files or not also. Keeping your cached files can be useful if you log back into your full account as you won't need to re-download those files.", preferredStyle: .alert)
//        
//        let startA1 = UIAlertAction(title: "Forget folder and wipe all cached data", style: .default, handler:
//                { (UIAlertAction) -> () in self.forgetFolderLinkAndDealWithCache(deleteCache: true) });
//        
//        let startA2 = UIAlertAction(title: "Forget folder but keep cached data", style: .default, handler:
//                { (UIAlertAction) -> () in self.forgetFolderLinkAndDealWithCache(deleteCache: false) });
//
//        let cancelA = UIAlertAction(title: "Never mind", style: .cancel);
//
//        alert.addAction(startA1);
//        alert.addAction(startA2);
//        alert.addAction(cancelA);
//
//        self.present(alert, animated: false, completion: nil)
//    }
//    
//    func forgetFolderLinkAndDealWithCache(deleteCache: Bool)
//    {
//        let spinner = ProgressSpinner(uic: self, title: "Forgetting Folder Link", message: "");
//        globals.loginState.forgetFolderLink(spinner: spinner, onFinish: { success in
//            var b = success;
//            if (b) {
//                if (deleteCache)
//                {
//                    spinner.updateTitleMessage("Deleting cache", "Folder link already forgotten.")
//                    if (!globals.storageModel.deleteCachedFiles(includingAccountAndSettings: true))
//                    {
//                        b = false;
//                        spinner.setErrorMessage("Failed to erase cache after wiping folder link");
//                    }
//                }
//                app().clear();
//            }
//            spinner.dismissOrReportError(success: b);
//            self.setEnabled();
//        })
//    }
//    
//    @IBAction func OnClearFileCacheClicked(_ sender: Any) {
//        
//        let alert = UIAlertController(title: "Clear Cached Files", message: "Clearing your cached files can be useful to gain storage space for your device, or to cause files to re-download, or to make sure all orphaned local cached files are cleaned up.", preferredStyle: .alert)
//        
//        let startA1 = UIAlertAction(title: "Wipe all cached files", style: .default, handler:
//            { (UIAlertAction) -> () in
//            
//                let spinner = ProgressSpinner(uic: self, title: "Clearing Cache", message: "");
//            
//                if (globals.storageModel.deleteCachedFiles(includingAccountAndSettings: false))
//                {
//                    spinner.dismiss();
//                    reportMessage(uic: self, message: "Cached files cleared");
//                }
//                else
//                {
//                    spinner.setErrorMessage("Some cached data failed to delete");
//                    spinner.dismissOrReportError(success: false);
//                }
//            });
//        
//        let cancelA = UIAlertAction(title: "Never mind", style: .cancel);
//
//        alert.addAction(startA1);
//        alert.addAction(cancelA);
//
//        self.present(alert, animated: false, completion: nil)
//    }
//    
//    class LogCallback: NSObject, MEGALoggerDelegate {
//
//        var logStream : OutputStream? = nil;
//
//        func log(withTime time : String, logLevel : Int, source : String, message: String)
//        {
//            if (logStream != nil) {
//                logString(time);
//                logString(" ");
//                logString(message);
//                logString("\n");
//            }
//        }
//        	
//        func logString(_ s : String)
//        {
//            let _ = write(s.data(using: String.Encoding.utf8, allowLossyConversion: false)!);
//            
////            let pointer: UnsafePointer<Int8>? = NSString(string: s).utf8String;
////            let length = NSString(string: s).length;
////
////            logStream!.write(UnsafePointer<UInt8>(pointer), maxLength: length);
//            
//            //data.withUnsafeBytes<UInt8>({ (p	: UnsafePointer<UInt8>) -> Void in
//            //  logStream!.write(p, maxLength: data.count)
//            //})
//        }
//        
//        func write(_ data: Data) -> Int {
//            return data.withUnsafeBytes({ (rawBufferPointer: UnsafeRawBufferPointer) -> Int in
//                let bufferPointer = rawBufferPointer.bindMemory(to: UInt8.self)
//                return logStream!.write(bufferPointer.baseAddress!, maxLength: data.count)
//            })
//        }
//    }
//    
//    var logCallback : LogCallback? = nil;
//    var logStream : OutputStream? = nil;
//    
//    func startLogging(verbose : Bool)
//    {
//        if (logCallback == nil)
//        {
//            logStream = OutputStream(toFileAtPath: logFilePath(), append: true);
//            if (logStream != nil) {
//                logStream!.open();
//                logCallback = LogCallback();
//                logCallback!.logStream = logStream;
//                MEGASdk.setLogLevel(.debug);
//                mega().add(logCallback!);
//            }
//        }
//    }
//    
//    func stopLogging()
//    {
//	    if (logCallback != nil)
//        {
//            logCallback?.logStream = nil;
//            mega().remove(logCallback!);
//            logCallback = nil;
//        }
//        if (logStream != nil)
//        {
//            logStream!.close();
//            logStream = nil;
//        }
//        MEGASdk.setLogLevel(.error);
//    }
//    
//    func uploadLogFile()
//    {
//        if (CheckOnlineOrWarn("Please go online before uploading the log file", uic: self))
//        {
//            if (mega().rootNode != nil) {
//                mega().startUpload(withLocalPath: logFilePath(), parent: mega().rootNode!)
//            }
//        }
//    }
//    
//    func deleteLogFile()
//    {
//        do {
//            try FileManager.default.removeItem(atPath: logFilePath())
//        }
//        catch {
//        }
//    }
//    
//    func logFilePath() -> String
//    {
//        return globals.storageModel.tempFilesPath() + "/iOS_logfile.log";
//    }
//    
//    @IBAction func onTroubleshootWithLogFilesClicked(_ sender: UIButton) {
//
//        let alert = UIAlertController(title: "Log file", message: "", preferredStyle: .alert)
//        
//        let startA1 = UIAlertAction(title: "Start logging to file (debug)", style: .default, handler:
//                { (UIAlertAction) -> () in self.startLogging(verbose: false) });
//        
//        let startA2 = UIAlertAction(title: "Start logging to file (verbose)", style: .default, handler:
//                { (UIAlertAction) -> () in self.startLogging(verbose: true) });
//        
//        let stopA = UIAlertAction(title: "Stop logging to file", style: .default, handler:
//                { (UIAlertAction) -> () in self.stopLogging() });
//        
//        let uploadA = UIAlertAction(title: "Upload log file", style: .default, handler:
//                { (UIAlertAction) -> () in self.uploadLogFile() });
//        
//        let deleteA = UIAlertAction(title: "Delete log file", style: .default, handler:
//                { (UIAlertAction) -> () in self.deleteLogFile() });
//        
//        let cancelA = UIAlertAction(title: "Never mind", style: .cancel);
//
//        startA1.isEnabled = logCallback == nil || logStream == nil;
//        startA2.isEnabled = logCallback == nil || logStream == nil;
//        stopA.isEnabled = logCallback != nil || logStream != nil;
//        uploadA.isEnabled = logCallback == nil && logStream == nil && FileManager.default.fileExists(atPath: logFilePath());
//        deleteA.isEnabled = logCallback == nil && logStream == nil && FileManager.default.fileExists(atPath: logFilePath());
//
//        alert.addAction(startA1);
//        alert.addAction(startA2);
//        alert.addAction(stopA);
//        alert.addAction(uploadA);
//        alert.addAction(deleteA);
//        alert.addAction(cancelA);
//
//        self.present(alert, animated: false, completion: nil)
//    }

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
    * Play music files from your MEGA online storage account.
    * Songs are cached as part of the app's storage.
    * The next two songs to be played are downloaded and cached.
    * Works offline (without an internet connection) to play already cached songs.
    * Near-Zero Energy Impact in offline mode, Low Impact in online mode.
    * Download and cache as many songs as you want ahead of time.
    * Browse your songs in the folder and file structure of your MEGA account, online or offline.
    * UI design avoids accidentally changing the playing song.
    * Just one simple list of the upcoming queued songs
    * Create or update playlists which are simple JSON files.
    * Save your new and updated playlists back to your MEGA account.
    * View by filename or by Track and Artist names
    * Extract Track and Artist names from music files (functionality from libtag)
    * Make and save short notes on your music tracks, along with BPM
    * File types considered playable (can be queued, iOS actually plays them): mp3, flac, m4a, aac, wav, aiff, au, pcm, ac3, aa, aax
    * Starts offline to minimise network use, go online easily anytime.
    * Choose your music and playlist folders, and browsing outside those folders won't be possible
    * An option to log into one folder of your MEGA account, for privacy and minimal RAM use.
    """;
    
    let versionText =
    """
    Version history
    
    1.0.2
    * Fixed deletion of single items from Play Queue History
    
    1.0.1
    * Created a free/Lite version of the app, limited to adding 25 items to the play queue at once.
    
    1.0
    * Initial version
    """
    
    let howtoText =
    """
    Usage Guide
    
    Quick Tips
    * Tap-hold for a short time on songs etc to see menu options.
    * To be able to see newly added/updated songs, `Go Online` from the menu.
    * Use the iOS control center for next/previous track and volume.
    * Use the MEGA app for creating folders, moving songs/playlists between folders, deleting files etc.
    
    Getting Started
    * If you don't have a MEGA account yet, get the MEGA app and sign up there.
    * Upload your music to your account from the MEGA app.
    * Create a Playlist folder if you don't have one yet. Music and Playlists should be under a common folder.
    * Log into your MEGA account in this app from the `Log in to MEGA` menu.
    * Then go to the `Browse Music` tab.
    * Tap on folders to drill into them.
    * Tap on the title row to go back up one folder level.
    * (Option here for an advanced version, see the next secton below)
    * Navigate to your top-level Music folder and `Option->Set as the Music Folder`.
    * On the Playlists tab, navigate to your top-level Playlists folder and `Option->Set as the Playlist Folder`.
    * On the Brows Music tab, navigate to your favourite music and choose `Option->Queue all` (top right).
    * Then go to the `Play Queue` tab.
    * You should see the first two songs downloading, with the blue bars increasing.
    * Once the first blue bar is full, press Play.
    
    Getting Started (advanced version)
    * This version logs into just your Music/Playlist folders for better security and less resource use.
    * As above, but before setting Music or Playlist folders, instead `Set as the top available folder`
    * For that, choose a folder that contains both your Music and Playlist folders.
    * Your login will be converted to a Writable Folder Link instead.
    * Only that portion of your account will even be downloaded from the servers.
    * Less storage used, less RAM used, less network used, better security.
    * After that, continue as above and select your Music and Playlist folders.
    
    How to download all songs
    * First queue all your songs from your Browse Music root folder, `Option->Queue all`.
    * Then from the Play Queue tab, `Option->Download entire queue`.
    * For large downloads, have your device charging as decrypting many files is quite power intensive.
    
    Managing online/offline
    * When the app starts up, it will be in offline mode.
    * Offline mode means it won't try to use the internet, saving battery and bandwidth.
    * Go Online from the Menu tab anytime.
    * In Online mode, updates from your MEGA account will be received.
    * To make any adjustments such as saving playlists, you must be in Online mode.
    
    Managing storage
    * Downloaded and cached songs, thumbnails, and playlists are part of the App's storage
    * These cached files won't be backed up in your iCloud phone backup, or PC backup, saving time and space.
    * You can always download them from MEGA again.
    * If you need to free up space on the phone, use Menu->Clear File Cache.
    
    Playlists
    * Choose your Playlists folder, in Playlists tab, if you haven't already.
    * Navigate to the folder your playlists are/will be stored in, and `Option->Set as Playlists Folder`.
    * To make a new playlist, assemble some songs in the Play Queue, and then `Option->Save as playlist` (you must be in Online Mode).
    * To add a song to a playlist, tap-hold on a song and choose `Add to Playlist...`
    * From the Play Queue that option is not available to save menu space, so select `Browse To` first, then add it.
    * Rearrange a playlist or remove songs by `Option->Rearrange mode` from within the playlist.
    * Playlist adds/edits are not automatically saved, you need to browse to it in the Playlists tab, and press `Save` (you must be in Online Mode).
    * You can organize your playlists into folders too, that should be done in the MEGA app.
    
    Play Queue / History / No-history mode
    * In Play Queue, by default it's in history moved.
    * In history mode, each song that plays disappears from the top of the queue, moved to the History section.
    * Tap History to see the played songs, and Queue to go back to the upcoming songs.
    * Activate `Mode->No-History mode` when you don't want the played song to move to the History list.
    * In no-history mode, the queue doesn't change, and an indicator moves down to the next song when one ends.
    
    Track/Artist names and Thumbnails
    * In the Play Queue tab, the songs are shown by Track/Artist name, and the thumbnail picture, if available.
    * If those are not available, the file name is shown.
    * In the Browse Music tab, file and folder names are shown by default.
    * Tap the circled folder icon (top right) to switch to see Track/Artist name instead of filename.
    * If Track and Artist names are not showing, try extracting them from the file.
    * Extract Track/Artist names by tap-hold and choose `Info...` from the menu (more details below).
    * You can also attempt to extract Title/Artist in bulk in a folder tree with `Option->Extract` in Browse Music tab.
        
    Edit song details with the `Info...` context menu
    * Tap `Extract tags from File` to see if the names can be pulled from the file itself.
    * If not, you can type in the Title and Artist yourself.
    * Additionally you can save a short Note about the song, and record the BPM.
    * Remember to press `Save all` before exiting the Info page, otherwise changes are discarded.
    
    Add Thumbnails for songs that don't have them yet
    * If a song file has an embedded image then its thumbnail should have been set on upload, otherwise it won't have one initially.
    * If you have songs in a folder from an album, often that folder will have an artwork file too
    * Tap-hold on the artwork file (it should be .jpg or .png) and `Option->Set as artwork for songs in this folder`.
    * You may have album folders converted from your CDs which may not contain artwork.
    * You can always upload a suitable .jpg in order to use that function if one is not there already.
    * If a thumbnail on a song won't change, you can remove all copies in the cloud account, and then re-upload (it must be removed from the trash first also).

    Search Music
    * In the Browse Music tab, tap the magnifying glass (top left) to search the current folder and folders below.
    * Type some text into the search field and press Return.
    * Songs that have matching text in the filename, Title, Artist, or Notes will be shown.
    * The usual options are available from the tap-hold menu
    * Tap the circle-folder icon (top right) to see them shown by Track/Artist names, with relative path.
    * You can also filter to show only downloaded (or not) songs with the rain-cloud icon (top right)
    
    Miscellaneous
    * App supports light and dark mode, according to system settings.
    
    """
}

