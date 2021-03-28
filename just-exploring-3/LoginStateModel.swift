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
    var finishFunc : ((_ e: MEGAError) -> Void)?;
    var finishRequestFunc : ((_ e: MEGAError, _ request : MEGARequest) -> Void)?;

    init(onFinish : @escaping (_ e: MEGAError) -> Void) {
        finishFunc = onFinish;
        finishRequestFunc = nil
    }
    
    init(onRequestFinish : @escaping (_ e: MEGAError, _ request : MEGARequest) -> Void) {
        finishFunc = nil;
        finishRequestFunc = onRequestFinish;
    }

    func onRequestFinish(_ api: MEGASdk, request: MEGARequest, error: MEGAError) {
        if (finishFunc != nil ) { finishFunc!(error) }
        if (finishRequestFunc != nil ) { finishRequestFunc!(error, request) }
    }
}

class LoginState //: ObservableObject
{
    
    var processing : Bool = false;
    var processingTitle : String = "";
    var processingMessage : String = "";
    var errorMessage : String = "";
    
    var accountBySession : Bool = false;
    var accountByFolderLink : Bool = false;
    var online : Bool = false;

    func printState(_ codePoint : String)
    {
        print( "\(codePoint) \(online) \(accountBySession) \(accountByFolderLink) \(processing) \(processingTitle) \(errorMessage)" )
    }

    func login(user : String, pw: String, onProgress : @escaping (String) -> (), onFinish : @escaping (Bool) -> ())
    {
        printState("login start")
        
        processingTitle = "Logging-in"
        processingMessage = "to MEGA.nz";
        processing = true;

        online = false;
        accountBySession = false;
        accountByFolderLink = false;

        mega().login(withEmail: user, password: pw,
                     delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in
                        if (e.type == .apiOk) {
                            if (self.loginSucceeded())
                            {
                                self.accountBySession = true;
                                self.online = true;
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
        processingTitle = !online ? "Loading Folders" : "Fetching Folders";
        processingMessage = !online ? "Loading your last cached folder tree" : "Fetching your folder tree from MEGA.nz";
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
    
    
    func convertToWritableFolderLink(_ currentFolder : MEGANode, onProgress : @escaping (String) -> (), onFinish : @escaping (Bool) -> ())
    {
        mega().exportNodeWritable(currentFolder, writable: 1 == 1, delegate: MEGARequestOneShot(onRequestFinish: { (e: MEGAError, req: MEGARequest) -> Void in
            if (e.type == .apiOk && req.link != nil && req.privateKey != nil) {
                if (app().storageModel.storeSettingFile(leafname: "writableLink", content: req.link) &&
                    app().storageModel.storeSettingFile(leafname: "writableAuth", content: req.privateKey))
                {
                    onProgress("Logging out");
                    self.logout(onFinish: {b in
                    
                        // logging out wiped everything, put these back
                        _ = app().storageModel.storeSettingFile(leafname: "writableLink", content: req.link)
                        _ = app().storageModel.storeSettingFile(leafname: "writableAuth", content: req.privateKey)

                        onProgress("Loading Folder Link");
                        _ = self.goOnlineWritableFolderLink(onProgress: onProgress, onFinish: onFinish);
                    })
                    return;
                }
            }
            self.errorMessage = "Create writable link failed: " + e.nameWithErrorCode(e.type.rawValue);
            self.processing = false;
            self.printState("create writable link failed")
            onFinish(false)
        }))
    }

    func goOnlineWritableFolderLink(onProgress : @escaping (String) -> (), onFinish : @escaping (Bool) -> ()) -> Bool
    {
        let writableLink = app().storageModel.loadSettingFile(leafname: "writableLink")
        let writableAuth = app().storageModel.loadSettingFile(leafname: "writableAuth")
        
        if (writableLink == nil || writableAuth == nil || writableLink!.isEmpty || writableAuth!.isEmpty) { return false; }
        
        printState("Writable folder link start")

        processingTitle = "Resuming Link"
        processingMessage = "Logging in with saved writable folder link";
        processing = true;
        
        accountBySession = false;
        accountByFolderLink = false;
        online = false;

        mega().login(toFolderLinkAuthed: writableLink!, folderAuth: writableAuth!, delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in
            if (e.type == .apiOk) {
                self.accountByFolderLink = true;
                self.online = true;
                self.printState("Writable folder link success, fetching")
                self.fetchnodes(onProgress: onProgress, onFinish: onFinish)
            } else {
                self.errorMessage = "Writable folder link failed: " + e.nameWithErrorCode(e.type.rawValue);
                self.processing = false;
                self.printState("Writable folder link fail")
                onFinish(false)
            }
        }))
        printState("Writable folder link ends")
        return true;
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
        
        mega().fastLogin(withSession: onlineSid, delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in
            if (e.type == .apiOk) {
                self.accountBySession = true;
                self.online = true;
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
        
        mega().fastLogin(withSessionOffline: offlineSid, delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in
            if (e.type == .apiOk) {
                self.accountBySession = true;
                self.online = false;
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
        if (!self.accountBySession && mega().isLoggedIn() != 0) { mega().logout() }
        app().storageModel.deleteSettingFile(leafname: "onlineSid")
        app().storageModel.deleteSettingFile(leafname: "offlineSid")
        app().storageModel.deleteSettingFile(leafname: "writableLink")
        app().storageModel.deleteSettingFile(leafname: "writableAuth")
        app().storageModel.deleteSettingFile(leafname: "musicPath")
        app().storageModel.deleteSettingFile(leafname: "playlistPath")
        self.accountBySession = false;
        self.accountByFolderLink = false;
        self.online = false;
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

    func forgetFolderLink(onFinish : @escaping (Bool) -> ())
    {
        printState("forgetFolderLink start")

        processingTitle = "Closing Folder Link"
        processingMessage = "Forgetting Writable Folder Link";
        processing = true;

        mega().localLogout(with: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in
            self.processing = false;
            if (e.type == .apiOk)
            {
                self.eraseState();
                self.printState("Link forgotten")
                onFinish(true);
            }
            else
            {
                self.errorMessage = "Link forget failed: " + e.nameWithErrorCode(e.type.rawValue);
                self.printState("link forget fail")
                onFinish(false);
            }
            }))

        printState("forgetFolderLink ends")
    }


}
