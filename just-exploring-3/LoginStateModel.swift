//
//  LoginState.swift
//  SongMe
//
//  Created by Matt Weir on 4/01/20.
//  Copyright © 2020 mattweir. All rights reserved.
//

import Foundation

	
class MEGARequestOneShot : NSObject, MEGARequestDelegate
{
    var finishFunc : (_ e: MEGAError) -> Void;
    
    init(onFinish : @escaping (_ e: MEGAError) -> Void) {
        finishFunc = onFinish;
    }
    func onRequestFinish(_ api: MEGASdk, request: MEGARequest, error: MEGAError) {
        finishFunc(error)
    }
}

class LoginState //: ObservableObject
{
    
    /*@Published*/ var processing : Bool = false;
    /*@Published*/ var processingTitle : String = "";
    /*@Published*/ var processingMessage : String = "";
    /*@Published*/ var errorMessage : String = "";
    
    /*@Published*/ var loggedInOnline : Bool = false;
    /*@Published*/ var loggedInOffline : Bool = false;
    
    func printState(_ codePoint : String)
    {
        print( "\(codePoint) \(loggedInOnline) \(loggedInOffline) \(processing) \(processingTitle) \(errorMessage)" )
    }

    func login(user : String, pw: String, onProgress : @escaping (String) -> (), onFinish : @escaping (Bool) -> ())
    {
        printState("login start")
        
        processingTitle = "Logging-in"
        processingMessage = "to MEGA.nz";
        processing = true;

        loggedInOnline = false;
        loggedInOffline = false;

        mega().login(withEmail: user, password: pw,
                     delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in
                        if (e.type == .apiOk) {
                            if (self.loginSucceeded())
                            {
                                self.loggedInOnline = true;
                                self.printState("logged in, fetching")
                                self.fetchnodes(onProgress: onProgress, onFinish: onFinish)
                                return;
                            }
                        } else {
                            self.errorMessage = "Login failed: " + e.nameWithErrorCode(e.type.rawValue);
                        }
                        self.processing = false;
                        self.printState("login failed")
                        onFinish(false)
                    }))
        printState("login ends")
    }

    func fetchnodes(onProgress : @escaping (String) -> (), onFinish : @escaping (Bool) -> ())
    {
        printState("fetchnodes starts")
        processingTitle = loggedInOffline ? "Loading Folder Tree" : "Fetching Folder Tree";
        processingMessage = loggedInOffline ? "Loading your last cached folder tree" : "Fetching your folder tree from MEGA.nz";
        processing = true;
        onProgress(processingTitle);
        mega().fetchNodes(
                     with: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in
                        if (e.type == .apiOk) {
                            self.processing = false;
                            self.printState("fetchnodes success")
                            self.loadRoots(onFinish: onFinish)
                            let replaceable = app().playQueue.playerSongIsEphemeral();
                            if (app().needsRestoreOnStartup) {
                                app().playQueue.restoreOnStartup();
                                app().needsRestoreOnStartup = false;
                            }
                            app().playQueue.onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong: replaceable)
                        } else {
                            self.errorMessage = "Login succeeded but FetchNodes failed: " + e.nameWithErrorCode(e.type.rawValue);
                            self.processing = false;
                            self.printState("fetchnodes fail")
                            onFinish(false)
                        }
                     }))
        printState("fetchnodes ends")
    }
    
    func loadRoots(onFinish : @escaping (Bool) -> ())
    {
        app().musicBrowseFolder = nil;
        app().playlistBrowseFolder = nil;

        if let musicPath = app().storageModel.loadSettingFile(leafname: "musicPath") {
            app().musicBrowseFolder = mega().node(forPath: musicPath)
        }
        if let playlistPath = app().storageModel.loadSettingFile(leafname: "playlistPath") {
            app().playlistBrowseFolder = mega().node(forPath: playlistPath)
        }
        
        onFinish(true)
    }
    
    
    func convertToWritableFolderLink(_ currentFolder : MEGANode, onFinish : @escaping (Bool) -> ())
    {
        mega().exportNodeWritable(currentFolder, writable: true, delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in
            if (e.type == .apiOk) {
                return;
            } else {
                self.errorMessage = "Create writable link failed: " + e.nameWithErrorCode(e.type.rawValue);
            }
            self.processing = false;
            self.printState("crete writable link failed")
            onFinish(false)
        }))
    }
    
    func goOnline(onProgress : @escaping (String) -> (), onFinish : @escaping (Bool) -> ())
    {
        printState("go online start")
        
        guard let onlineSid = app().storageModel.loadSettingFile(leafname: "onlineSid")
        else {
            eraseState()
            errorMessage = "No online session info found";
            onFinish(false)
            return
        }
        
        processingTitle = "Resuming session"
        processingMessage = "Logging in with saved session";
        processing = true;
        
        loggedInOnline = false;
        loggedInOffline = false;

        mega().fastLogin(withSession: onlineSid, delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in
            if (e.type == .apiOk) {
                self.loggedInOnline = true;
                self.printState("go online success, fetching")
                self.fetchnodes(onProgress: onProgress, onFinish: onFinish)
            } else {
                self.errorMessage = "Session resume failed: " + e.nameWithErrorCode(e.type.rawValue);
                self.processing = false;
                self.printState("go online fail")
                onFinish(false)
            }
        }))
        printState("go online ends")
    }
    
    func goOffline(onProgress : @escaping (String) -> (), onFinish : @escaping (Bool) -> ())
    {
        printState("go offline start")

        guard let offlineSid = app().storageModel.loadSettingFile(leafname: "offlineSid")
        else {
            errorMessage = "No offline session info found";
            onFinish(false)
            return
        }

        processingTitle = "Resuming Offline"
        processingMessage = "Loading saved session";
        processing = true;		
        
        loggedInOnline = false;
        loggedInOffline = false;

        mega().fastLogin(withSessionOffline: offlineSid, delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in
            if (e.type == .apiOk) {
               self.loggedInOffline = true;
               self.printState("go offline success, fetching")
                self.fetchnodes(onProgress: onProgress, onFinish: onFinish)
            } else {
               self.errorMessage = "Session resume failed: " + e.nameWithErrorCode(e.type.rawValue);
               self.processing = false;
               self.printState("go offline fail")
               onFinish(false)
            }
        }))
        printState("go offline ends")
    }

    func loginSucceeded() ->Bool
    {
        let onlineSid = mega().dumpSession(false);
        let offlineSid = mega().dumpSession(true);
        if (onlineSid != nil && offlineSid != nil &&
            app().storageModel.storeSettingFile(leafname: "onlineSid", content: onlineSid!) &&
            app().storageModel.storeSettingFile(leafname: "offlineSid", content:offlineSid!))
        {
            return true;
        }
        self.errorMessage = "Could not store login details";
        eraseState();
        return false;
    }

    func eraseState()
    {
        if (!self.loggedInOffline && mega().isLoggedIn() != 0) { mega().logout() }
        app().storageModel.deleteSettingFile(leafname: "onlineSid")
        app().storageModel.deleteSettingFile(leafname: "offlineSid")
        app().storageModel.deleteSettingFile(leafname: "musicPath")
        app().storageModel.deleteSettingFile(leafname: "playlistPath")
        self.loggedInOnline = false;
        self.loggedInOffline = false;
    }
    
    func logout(onFinish : @escaping (Bool) -> ())
    {
        printState("logout start")

        processingTitle = "Logging out"
        processingMessage = "Closing and invalidating session";
        processing = true;

        mega().logout(with: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in
            self.processing = false;
            if (e.type == .apiOk)
            {
                self.eraseState();
                self.printState("logout success")
                onFinish(true);
            }
            else
            {
                self.errorMessage = "Logout failed: " + e.nameWithErrorCode(e.type.rawValue);
                self.printState("logout fail")
                onFinish(false);
            }
            }))

        printState("logout ends")
    }

    func logoutFinished()
    {
        // todo: delete all state files
    }

}
