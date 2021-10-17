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
                            if (self.saveSession(isWriteableLink: false))
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
        
        app().nodeForBrowseFirstLoad = app().musicBrowseFolder;
        app().browseMusicTVC?.load(node: app().musicBrowseFolder);
        app().browsePlaylistsTVC?.load(node: app().playlistBrowseFolder);

        onFinish(true)
    }
    
    
    func convertToWritableFolderLink(_ currentFolder : MEGANode, onProgress : @escaping (String) -> (), onFinish : @escaping (Bool) -> ())
    {
        mega().exportNodeWritable(currentFolder, writable: 1 == 1, delegate: MEGARequestOneShot(onRequestFinish: { (e: MEGAError, req: MEGARequest) -> Void in
            if (e.type == .apiOk && req.link != nil && req.privateKey != nil) {
                onProgress("Logging out");
                self.logout(onFinish: {b in
                
                    onProgress("Loading Folder Link");
                    _ = self.loginWritableFolderLink(writableLink: req.link, writableAuth: req.privateKey, onProgress: onProgress, onFinish: onFinish);
                })
                return;
            }
            self.errorMessage = "Create writable link failed: " + e.nameWithErrorCode(e.type.rawValue);
            self.processing = false;
            self.printState("create writable link failed")
            onFinish(false)
        }))
    }

    func loginWritableFolderLink(writableLink: String, writableAuth: String, onProgress : @escaping (String) -> (), onFinish : @escaping (Bool) -> ()) -> Bool
    {
        printState("Writable folder link start")

        processingTitle = "Resuming Link"
        processingMessage = "Logging in with saved writable folder link";
        processing = true;
        
        accountBySession = false;
        accountByFolderLink = false;
        online = false;

        mega().login(toFolderLinkAuthed: writableLink, folderAuth: writableAuth, offline: false, delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in
            if (e.type == .apiOk) {
                
                // save the new online and offline session strings.
                self.accountByFolderLink = true;
                self.online = true;
                self.printState("Writable folder link success, fetching")
                self.fetchnodes(onProgress: onProgress, onFinish: { (success: Bool) -> Void in
                    let b = success && self.saveSession(isWriteableLink: true);
                    onFinish(b);
                })
                return;
            } else {
                self.errorMessage = "Writable folder link failed: " + e.nameWithErrorCode(e.type.rawValue);
                self.processing = false;
                self.printState("Writable folder link fail")
            }
            onFinish(false)
        }))
        printState("Writable folder link ends")
        return true;
    }
    
    func goOnline(onProgress : @escaping (String) -> (), onFinish : @escaping (Bool) -> ())
    {
        printState("go online start")
        
        let onlineSidAcct = app().storageModel.loadSettingFile(leafname: "onlineSidAcct")
        let onlineSidLink = app().storageModel.loadSettingFile(leafname: "onlineSidLink")
        if ((onlineSidAcct ?? onlineSidLink) == nil) {
            clear();
            errorMessage = "No online session info found";
            onFinish(false)
            return
        }
        
        processingTitle = "Resuming session"
        processingMessage = "Logging in with saved session";
        processing = true;
        
        mega().fastLogin(withSession: (onlineSidAcct ?? onlineSidLink)!, delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in
            if (e.type == .apiOk) {
                self.accountBySession = onlineSidAcct != nil;
                self.accountByFolderLink = onlineSidLink != nil;
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

        let offlineSidAcct = app().storageModel.loadSettingFile(leafname: "offlineSidAcct")
        let offlineSidLink = app().storageModel.loadSettingFile(leafname: "offlineSidLink")
        if ((offlineSidAcct ?? offlineSidLink) == nil) {
            errorMessage = "No offline session info found";
            onFinish(false)
            return
        }

        processingTitle = "Resuming Offline"
        processingMessage = "Loading saved session";
        processing = true;
        
        mega().fastLogin(withSessionOffline: (offlineSidAcct ?? offlineSidLink)!, delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in
            if (e.type == .apiOk) {
                self.accountBySession = offlineSidAcct != nil;
                self.accountByFolderLink = offlineSidLink != nil;
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

    func saveSession(isWriteableLink : Bool) ->Bool
    {
        let onlineSid = mega().dumpSession(false);
        let offlineSid = mega().dumpSession(true);
        if (onlineSid != nil && offlineSid != nil &&
            app().storageModel.storeSettingFile(leafname: "onlineSid" + (isWriteableLink ? "Link": "Acct"), content: onlineSid!) &&
            app().storageModel.storeSettingFile(leafname: "offlineSid" + (isWriteableLink ? "Link": "Acct"), content: offlineSid!))
        {
            app().storageModel.deleteSettingFile(leafname: "onlineSid" + (!isWriteableLink ? "Link": "Acct"))
            app().storageModel.deleteSettingFile(leafname: "offlineSid" + (!isWriteableLink ? "Link": "Acct"))
            return true;
        }
        self.errorMessage = "Could not store login details";
        self.processing = false;
        clear();
        return false;
    }

    func clear()
    {
        app().storageModel.deleteSettingFile(leafname: "onlineSidAcct")
        app().storageModel.deleteSettingFile(leafname: "offlineSidAcct")
        app().storageModel.deleteSettingFile(leafname: "onlineSidLink")
        app().storageModel.deleteSettingFile(leafname: "offlineSidLink")
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
                self.clear();
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
                self.clear();
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
