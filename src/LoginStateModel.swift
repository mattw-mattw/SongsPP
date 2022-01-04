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
        
        let requestCopy = request.clone();
        let errorCopy = error.clone();
        
        DispatchQueue.main.async {
            if (self.finishFunc != nil ) { self.finishFunc!(errorCopy!) }
            if (self.finishRequestFunc != nil ) { self.finishRequestFunc!(errorCopy!, requestCopy!) }
        }
    }
}

class LoginState //: ObservableObject
{
    
//    var processing : Bool = false;
//    var processingTitle : String = "";
//    var processingMessage : String = "";
//    var errorMessage : String = "";
    
    var accountBySession : Bool = false;
    var accountByFolderLink : Bool = false;
    var online : Bool = false;

    func login(spinner : ProgressSpinner, user : String, pw: String, twoFactor: String, onFinish : @escaping (Bool) -> ())
    {
        online = false;
        accountBySession = false;
        accountByFolderLink = false;

        mega().multiFactorAuthLogin(withEmail: user, password: pw, pin:twoFactor,
             delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in
                if (e.type == .apiOk) {
                    if (self.saveSession(isWriteableLink: false))
                    {
                        self.accountBySession = true;
                        self.online = true;
                        self.fetchnodes(spinner: spinner, onFinish: onFinish)
                        return;
                    } else {
                        spinner.setErrorMessage("Could not store login details");
                        self.clear();
                        onFinish(false);
                    }
                } else {
                    spinner.setErrorMessage("Login failed: " + e.nameWithErrorCode(e.type.rawValue));
                    onFinish(false);
                }
            }))
    }

    func fetchnodes(spinner : ProgressSpinner, onFinish : @escaping (Bool) -> ())
    {
        if (online) {
            spinner.updateTitleMessage("Fetching Folders", "Fetching your folder tree from MEGA");
        } else {
            spinner.updateTitleMessage("Loading Folders", "Loading your last cached folder tree");
        }
        mega().fetchNodes(
                     with: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in
                        if (e.type == .apiOk) {
                            self.loadRoots(onFinish: onFinish)
                            let replaceable = app().playQueue.playerSongIsEphemeral();
                            if (app().needsRestoreOnStartup) {
                                app().playQueue.restoreOnStartup();
                                app().needsRestoreOnStartup = false;
                            }
                            app().playQueue.onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong: replaceable)
                        } else {
                            spinner.setErrorMessage("Login succeeded but FetchNodes failed: " + e.nameWithErrorCode(e.type.rawValue) + ". Please exit the app and restart it to recover.");
                            onFinish(false)
                        }
                     }))
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
    
    
    func convertToWritableFolderLink(spinner : ProgressSpinner, _ currentFolder : MEGANode, onFinish : @escaping (Bool) -> ())
    {
        spinner.updateTitleMessage("Writable Folder Link", "Creating a writable folder link for subsequent logins.");

        mega().exportNodeWritable(currentFolder, writable: 1 == 1, delegate: MEGARequestOneShot(onRequestFinish: { (e: MEGAError, req: MEGARequest) -> Void in
            if (e.type == .apiOk && req.link != nil && req.privateKey != nil) {
                self.logout(spinner : spinner, onFinish: {b in
                    self.loginWritableFolderLink(spinner: spinner, writableLink: req.link, writableAuth: req.privateKey, onFinish: onFinish);
                })
            } else {
                spinner.setErrorMessage("Create writable link failed: " + e.nameWithErrorCode(e.type.rawValue));
                onFinish(false);
            }
        }))
    }

    func loginWritableFolderLink(spinner : ProgressSpinner, writableLink: String, writableAuth: String, onFinish : @escaping (Bool) -> ())
    {
        spinner.updateTitleMessage("Resuming Link", "Logging in with saved writable folder link");
        
        accountBySession = false;
        accountByFolderLink = false;
        online = false;

        mega().login(toFolderLinkAuthed: writableLink, folderAuth: writableAuth, offline: false, delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in
            if (e.type == .apiOk) {
                // save the new online and offline session strings.
                self.accountByFolderLink = true;
                self.online = true;
                self.fetchnodes(spinner: spinner, onFinish: { (success: Bool) -> Void in
                    if (!success) {
                        onFinish(false);
                    } else {
                        if (self.saveSession(isWriteableLink: true)) {
                            onFinish(true);
                        } else {
                            spinner.setErrorMessage("Could not store login details");
                            self.clear();
                            onFinish(false);
                        }
                    }
                })
            } else {
                spinner.setErrorMessage("Writable folder link request failed: " + e.nameWithErrorCode(e.type.rawValue));
                onFinish(false)
            }
        }));
    }
    
    func goOnline(spinner : ProgressSpinner, onFinish : @escaping (Bool) -> ())
    {
        let onlineSidAcct = app().storageModel.loadSettingFile(leafname: "onlineSidAcct")
        let onlineSidLink = app().storageModel.loadSettingFile(leafname: "onlineSidLink")
        if ((onlineSidAcct ?? onlineSidLink) == nil) {
            clear();
            spinner.setErrorMessage("No online session info found");
            onFinish(false)
            return
        }
        
        spinner.updateTitleMessage("Resuming session", "Logging in with saved session")
        
        mega().fastLogin(withSession: (onlineSidAcct ?? onlineSidLink)!, delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in
            if (e.type == .apiOk) {
                self.accountBySession = onlineSidAcct != nil;
                self.accountByFolderLink = onlineSidLink != nil;
                self.online = true;
                self.fetchnodes(spinner: spinner, onFinish: onFinish)
            } else {
                spinner.setErrorMessage("Session resume failed: " + e.nameWithErrorCode(e.type.rawValue));
                onFinish(false)
            }
        }));
    }
    
    func goOffline(spinner : ProgressSpinner, onFinish : @escaping (Bool) -> ())
    {
        let offlineSidAcct = app().storageModel.loadSettingFile(leafname: "offlineSidAcct")
        let offlineSidLink = app().storageModel.loadSettingFile(leafname: "offlineSidLink")
        if ((offlineSidAcct ?? offlineSidLink) == nil) {
            spinner.setErrorMessage("No offline session info found");
            onFinish(false);
            return
        }

        spinner.updateTitleMessage("Resuming Offline", "Loading saved session");
        
        mega().fastLogin(withSessionOffline: (offlineSidAcct ?? offlineSidLink)!, delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in
            if (e.type == .apiOk) {
                self.accountBySession = offlineSidAcct != nil;
                self.accountByFolderLink = offlineSidLink != nil;
                self.online = false;
                self.fetchnodes(spinner: spinner, onFinish: onFinish)
            } else {
                spinner.setErrorMessage("Session resume failed: " + e.nameWithErrorCode(e.type.rawValue));
                onFinish(false)
            }
        }))
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
    
    func logout(spinner : ProgressSpinner, onFinish : @escaping (Bool) -> ())
    {
        spinner.updateTitleMessage("Logging out", "Closing and invalidating the old logged in session.");
        
        mega().logout(with: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in
            if (e.type == .apiOk)
            {
                self.clear();
                onFinish(true);
            }
            else
            {
                spinner.setErrorMessage("Logout failed: " + e.nameWithErrorCode(e.type.rawValue));
                onFinish(false);
            }
        }))
    }

    func forgetFolderLink(spinner : ProgressSpinner, onFinish : @escaping (Bool) -> ())
    {
        spinner.updateTitleMessage("Closing Folder Link", "Forgetting Writable Folder Link");

        mega().localLogout(with: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in
            if (e.type == .apiOk)
            {
                self.clear();
                onFinish(true);
            }
            else
            {
                spinner.setErrorMessage("Link forget failed: " + e.nameWithErrorCode(e.type.rawValue));
                onFinish(false);
            }
        }))
    }


}
