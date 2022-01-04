//
//  StorageModel.swift
//  SongMe
//
//  Created by Matt Weir on 4/01/20.
//  Copyright © 2020 mattweir. All rights reserved.
//

import Foundation


class TransferHandler: NSObject, MEGATransferDelegate {
    
    func onTransferStart(_ api: MEGASdk, transfer: MEGATransfer) {
    }
    
    func onTransferUpdate(_ api: MEGASdk, transfer: MEGATransfer) {
        let percent = NSNumber(value: transfer.transferredBytes.floatValue / transfer.totalBytes.floatValue);
        app().downloadProgress(nodeHandle: transfer.nodeHandle, percent: percent)
    }
    
    func onTransferFinish(_ api: MEGASdk, transfer request: MEGATransfer, error: MEGAError) {
        let n = mega().node(forHandle: request.nodeHandle)
        if (n != nil && n!.fingerprint != nil) {
            if (error.type.rawValue == 0)
            {
                app().storageModel.fileArrived(fingerprint: n!.fingerprint!, node: n!);
            }
            else
            {
                app().storageModel.fileFailed(fingerprint: n!.fingerprint!, node: n!);
            }
        }
    }
    
    func onTransferTemporaryError(_ api: MEGASdk, transfer request: MEGATransfer, error: MEGAError) {
//        api.cancelTransfer(request);
  //      let n = mega().node(forHandle: request.nodeHandle)
    //    if (n != nil && n!.fingerprint != nil) {
      //      app().storageModel.fileFailed(fingerprint: n!.fingerprint!);
        //}
    }
}

func replaceNodeIn(_ n : MEGANode, _ v : inout [MEGANode]) -> Bool
{
    var result : Bool = false;
    for i in v.indices {
        if v[i].handle == n.handle
            // attempt to handle file versions but not quite right
            //|| (n.type == .file && v[i].type == .file && n.parentHandle == v[i].handle)
        {
            v[i] = n;
            result = true;
        }
    }
    return result;
}

func isThumbnailInNodeVec(_ thumbHandle : String, _ v : [MEGANode]) -> Bool
{
    for i in v.indices {
        if let th = v[i].thumbnailAttributeHandle {
            if (th == thumbHandle) {
                return true;
            }
        }
    }
    return false;
}

class MEGAHandler: NSObject, MEGADelegate {

    func onNodesUpdate(_ api: MEGASdk, nodeList : MEGANodeList?)
    {
        if (nodeList == nil) {
            return; // yes it is null sometimes
        }
        for i in 0..<nodeList!.size.intValue {
            let node = nodeList!.node(at: i)
            
            if (node == nil) { continue; }
            
            app().playQueue.nodesChanging(node!);
            if (app().playQueueTVC != nil) { app().playQueueTVC!.nodesChanging(node!); }
            if (app().browseMusicTVC != nil) { app().browseMusicTVC!.nodesChanging(node!); }
            if (app().browsePlaylistsTVC != nil) { app().browsePlaylistsTVC!.nodesChanging(node!); }
            
            if (node!.name != nil &&
                node!.name!.hasSuffix(".playlist")) {
                _ = app().storageModel.startDownloadIfAbsent(node: node!);
            }
            
            // in case it now has a thumbnail, start it downloading
            _ = app().storageModel.thumbnailDownloaded(node!);
        }

        app().playQueue.nodesFinishedChanging();
        if (app().playQueueTVC != nil) { app().playQueueTVC!.nodesFinishedChanging();}
        if (app().browseMusicTVC != nil) { app().browseMusicTVC!.nodesFinishedChanging();}
        if (app().browsePlaylistsTVC != nil) { app().browsePlaylistsTVC!.nodesFinishedChanging();}
    }
    
    func onThumbnailUpdate(node : MEGANode)
    {
        app().playQueue.nodesChanging(node);
        if (app().playQueueTVC != nil) { app().playQueueTVC!.nodesChanging(node); }
        if (app().browseMusicTVC != nil) { app().browseMusicTVC!.nodesChanging(node); }
        if (app().browsePlaylistsTVC != nil) { app().browsePlaylistsTVC!.nodesChanging(node); }
        app().playQueue.nodesFinishedChanging();
        if (app().playQueueTVC != nil) { app().playQueueTVC!.nodesFinishedChanging();}
        if (app().browseMusicTVC != nil) { app().browseMusicTVC!.nodesFinishedChanging();}
        if (app().browsePlaylistsTVC != nil) { app().browsePlaylistsTVC!.nodesFinishedChanging();}
    }
}

class StorageModel {
    
    var downloadingFP : Set<String> = [];
    var downloadedFP : Set<String> = [];
    
    var downloadingNH : Set<UInt64> = [];
    var downloadedNH : Set<UInt64> = [];

    var downloadingThumbnail : Set<String> = [];
    var downloadedThumbnail : Set<String> = [];

    var transferDelegate = TransferHandler();
    var megaDelegate = MEGAHandler();
    
    var alreadyCreatedFolders : Set<String> = [];

    func clear()
    {
        downloadingFP = [];
        downloadedFP = [];
        
        downloadingNH = [];
        downloadedNH = [];

        downloadingThumbnail = [];
        downloadedThumbnail = [];

        alreadyCreatedFolders = [];
    }
    
    func deleteCachedFiles(includingAccountAndSettings : Bool) -> Bool
    {
        clear();
        
        var result : Bool = true;
        do
        {
            if (includingAccountAndSettings)
            {
                try FileManager.default.removeItem(at: URL(fileURLWithPath: storageBasePath()));
            }
            else
            {
                try FileManager.default.removeItem(at: URL(fileURLWithPath: cacheFilesPath()));
            }
            try FileManager.default.removeItem(at: URL(fileURLWithPath: tempFilesPath()));
        }
        catch {
            result = false;
        }
        
        // recreate those folders again (now empty) so we don't have issues with the next login etc.
        app().storageModel.alreadyCreatedFolders = [];
        _ = accountPath();
        _ =  cacheFilesPath();
        _ = tempFilesPath();
        
        return result;
    }

    func fileDownloadedByFP(_ node: MEGANode) -> Bool
    {
        if (node.fingerprint == nil) { return false; }
        if downloadedFP.contains(node.fingerprint!) { return true; }
        guard let filename = songFingerprintPath(node: node) else { return false }
        let exists = FileManager.default.fileExists(atPath: filename);
        if (exists && node.fingerprint != nil) { downloadedFP.insert(node.fingerprint!); }
        return exists;
    }

    func fileDownloadedByNH(_ node: MEGANode) -> Bool
    {
        if downloadedNH.contains(node.handle) { return true; }
        guard let filename = playlistPath(node: node, forEditing: false) else { return false }
        let exists = FileManager.default.fileExists(atPath: filename);
        if (exists) { downloadedNH.insert(node.handle); }
        return exists;
    }

    func fileDownloadedByType(_ node: MEGANode) -> Bool
    {
        if (node.name != nil && node.name!.hasSuffix(".playlist")) {
            return fileDownloadedByNH(node);
        } else {
            return fileDownloadedByFP(node);
        }
    }
    
    func thumbnailDownloaded(_ node: MEGANode) -> Bool
    {
        if (node.thumbnailAttributeHandle == nil) {return false;}
        let ta = node.thumbnailAttributeHandle!;
        if (ta.contains("______")) {
            return false;
        }
        //print ("thumbnail handle " + ta + " for " + node.name)
        if downloadedThumbnail.contains(ta) { return true; }
        guard let filename = thumbnailPath(node: node) else { return false }
        let exists = FileManager.default.fileExists(atPath: filename);
        if (exists) { downloadedThumbnail.insert(ta); }
        if (!exists && !downloadingThumbnail.contains(ta)) {
            downloadingThumbnail.insert(ta);
            mega().getThumbnailNode(node, destinationFilePath: filename, delegate:
                    MEGARequestOneShot(onFinish:
                        { (e: MEGAError) -> Void in
                            self.downloadedThumbnail.insert(ta); // prevent cycle if it doesn't work
                            self.downloadingThumbnail.remove(ta);
                            self.megaDelegate.onThumbnailUpdate(node: node);
            }));
        }
        return exists;
    }
    
    func playlistPath(node: MEGANode, forEditing : Bool) -> String?
    {
        var s = playlistsFolderPath() + "/" + MEGASdk.base64Handle(forHandle: node.handle)! + ".playlist";
        //var s = songFingerprintPath(node: node);
        s += (forEditing ? ".editing": "");
        //s += (forUpload ? ".upload": "");
        return s;
    }
    
    func getOldPlaylistsFolder() -> MEGANode?
    {
        var node : MEGANode? = nil;
        if (app().playlistBrowseFolder != nil)
        {
            node = mega().node(forPath: "old-playlist-versions", node: app().playlistBrowseFolder!);
            if (node == nil && app().loginState.online)
            {
                mega().createFolder(withName: "old-playlist-versions", parent: app().playlistBrowseFolder!)
            }
        }
        return node;
    }

    func songFingerprintPath(node: MEGANode) -> String?
    {
        if node.type != .file {
            print ("attempted fingerprint path for a non-file: " + (node.name ?? "<nil>"))
            return nil;
        }
        if (node.fingerprint == nil) {
            print ("fingerprint was nil for: " + (node.name ?? "<nil>"))
            return nil;
        }
        
        if (node.name == nil) { return nil }
        
        let u = URL(fileURLWithPath: node.name!);
        let pathExtension = u.pathExtension;

        return songsFolderPath() + "/" + node.fingerprint! + "." + pathExtension;
    }
    
    func thumbnailPath(node: MEGANode) -> String?
    {
        if node.type != .file {
            print ("attempted fingerprint path for a non-file: " + (node.name ?? "<nil>"))
            return nil;
        }
        if (node.fingerprint == nil) {
            print ("fingerprint was nil for: " + (node.name ?? "<nil>"))
            return nil;
        }
        
        if let b64 = node.thumbnailAttributeHandle {
            return thumbnailsFolderPath() + "/" + b64 + ".jpg";
        }
        return nil;
    }
    
    func getDownloadedSongURL(_ node: MEGANode) -> URL?
    {
        guard let filename = songFingerprintPath(node: node) else { return nil }
        return FileManager.default.fileExists(atPath: filename) ? URL(fileURLWithPath: filename) : nil;
    }
  
    func loadFileAsJSON(filename : String) -> Any?
    {
        do
        {
            let content = try String(contentsOf: URL(fileURLWithPath: filename), encoding: .utf8);
            let contentData = content.data(using: .utf8);
            return try JSONSerialization.jsonObject(with: contentData!, options: []);
        }
        catch {
        }
        return nil;
    }
    
    func getPlaylistFileAsJSON(_ filename: String) -> Any?
    {
        do
        {
            let content = try String(contentsOf: URL(fileURLWithPath: filename), encoding: .utf8);
            let contentData = content.data(using: .utf8);
            return try JSONSerialization.jsonObject(with: contentData!, options: []);
        }
        catch {
        }
        return nil;
    }

    func getPlaylistFileAsJSON(_ node: MEGANode, edited : Bool) -> Any?
    {
        if let filename = playlistPath(node: node, forEditing: edited) {
            return getPlaylistFileAsJSON(filename);
        }
        return nil;
    }

    func getPlaylistFileEditedOrNotAsJSON(_ node: MEGANode) -> (Any?, Bool)
    {
        var p = getPlaylistFileAsJSON(node, edited: true);
        if (p == nil) {
            p = getPlaylistFileAsJSON(node, edited: false);
            return (p, false);
        }
        return (p, true);
    }
    
    func loadSongsFromPlaylistRecursive(json: Any, _ v : inout [MEGANode], recurse: Bool)
    {
        if let array = json as? [Any] {
            for object in array {
                if let attribs = object as? [String : Any] {
                    if let handleStr = attribs["h"] {
                        print(handleStr);
                        var node = mega().node(forHandle: MEGASdk.handle(forBase64Handle: handleStr as! String));
                        if (node == nil)
                        {
                            if let lkpath = attribs["lkpath"] {
                                node = mega().node(forPath: lkpath as! String);
                            }
                        }
                        if (node != nil) {
                            loadSongsFromNodeRecursive(node: node!, &v, recurse: recurse);
                        }
                    }
                }
            }
        }
    }
    
    func loadSongsFromNodeRecursive(node: MEGANode, _ v : inout [MEGANode], recurse: Bool)
    {
        if (node.name == nil) { return }
        if (node.type != MEGANodeType.file)
        {
            let nodeList = mega().children(forParent: node, order: 1)
            for i in 0..<nodeList.size.intValue
            {
                if let n = nodeList.node(at: i) {
                    loadSongsFromNodeRecursive(node: n, &v, recurse: recurse);
                }
            }
        }
        else if (node.name!.hasSuffix(".playlist") && app().storageModel.fileDownloadedByNH(node))
        {
            if (recurse) {
                let (json, _) = app().storageModel.getPlaylistFileEditedOrNotAsJSON(node);
                if (json != nil) {
                    loadSongsFromPlaylistRecursive(json: json!, &v, recurse: recurse);
                }
            }
        }
        else if app().playQueue.isPlayable(node, orMightContainPlayable: false)
        {
            v.append(node)
        }
    }
    

    func isDownloadingByFP(_ node : MEGANode) -> Bool
    {
        if (node.fingerprint == nil) { return false; }
        return downloadingFP.contains(node.fingerprint!)
    }

    func isDownloadingByNH(_ node : MEGANode) -> Bool
    {
        return downloadingNH.contains(node.handle)
    }
    
    func isDownloadingByType(_ node: MEGANode) -> Bool
    {
        if (node.name != nil &&
            node.name!.hasSuffix(".playlist")) {
            return isDownloadingByNH(node);
        } else {
            return isDownloadingByFP(node);
        }
    }

    func startDownloadIfAbsent( node: MEGANode) -> Bool
    {
        if (!app().loginState.online) { return false; }
        
        if (node.name != nil &&
            node.name!.hasSuffix(".playlist")) {
            return startPlaylistDownloadIfAbsent(node);
        } else {
            return startSongDownloadIfAbsent(node);
        }
    }
    
    func startSongDownloadIfAbsent(_ node: MEGANode) -> Bool
    {
        if (!app().loginState.online) { return false; }

        // also start thumbnail downlaoding if it has one and we don't have it already
        _ = thumbnailDownloaded(node);

        if !isDownloadingByFP(node) && !fileDownloadedByFP(node)
        {
            if let filename = songFingerprintPath(node: node) {
                mega().startDownloadNode(node, localPath: filename);
                downloadingFP.insert(node.fingerprint!);
                downloadingNH.insert(node.handle);
                return true
            }
        }
        return false
    }
    
    func startPlaylistDownloadIfAbsent(_ node: MEGANode) -> Bool
    {
        if (!app().loginState.online) { return false; }

        if !isDownloadingByNH(node) && !fileDownloadedByNH(node)
        {
            if let filename = playlistPath(node: node, forEditing: false) {
                mega().startDownloadNode(node, localPath: filename);
                downloadingNH.insert(node.handle);
                return true
            }
        }
        return false
    }
    
    func fileArrived(fingerprint : String, node : MEGANode)
    {
        downloadingFP.remove(fingerprint);
        downloadingNH.remove(node.handle);
        app().playQueue.songDownloaded(node: node)
    }
   
   func fileFailed(fingerprint : String, node : MEGANode)
   {
       downloadingFP.remove(fingerprint);
       downloadingNH.remove(node.handle);
       app().playQueue.songDownloaded(node: nil)
   }

    
    func loadSettingFile(leafname : String) -> String?
    {
        do {
            return try String(contentsOf: URL(fileURLWithPath: settingsPath() + "/" + leafname), encoding: .utf8);
        }
        catch {
        }
        return nil;
    }
    
    func storeSettingFile(leafname : String, content : String) -> Bool
    {
        do {
            try content.write(toFile: settingsPath() + "/" + leafname, atomically: true, encoding: String.Encoding.utf8);
            print("Wrote file: " + settingsPath() + "/" + leafname)
            return true;
        }
        catch {
            return false;
        }
    }
    
    func deleteSettingFile(leafname : String)
    {
        if FileManager.default.fileExists(atPath: settingsPath() + "/" + leafname) {
            do {
                try FileManager.default.removeItem(atPath: settingsPath() + "/" + leafname)
                print("Removed file: " + settingsPath() + "/" + leafname)
            }
            catch {
                print("Failed to remove file " + settingsPath() + "/" + leafname)
            }
        }
    }
    
    func assureFolderExists(_ url : String, doneName : String) -> Void
    {
        if (alreadyCreatedFolders.contains(doneName)) { return; }
        do {
            if !FileManager.default.fileExists(atPath: url) {
                try FileManager.default.createDirectory(atPath: url, withIntermediateDirectories: true, attributes: nil);
            }
            var urv = URLResourceValues();
            urv.isExcludedFromBackup = true;
            var attribUrl = URL(fileURLWithPath: url)
            try attribUrl.setResourceValues(urv);
            alreadyCreatedFolders.insert(doneName);
        }
        catch
        {
            print("directory does not exist and could not be created or could not be set non-backup: \(url)")
        }
    }

    func storageBasePath() -> String
    {
        // choosing applicationSupportDirectory means the files will not be accessible from other apps,
        // won't be removed by the system (unlike cache directories) and we can set flags to prevent
        // the files being synced by iTunes or iCloud.
        // https://developer.apple.com/library/archive/qa/qa1719/_index.html
        let folderUrls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask);
        let p = folderUrls[0].standardizedFileURL.path;
        assureFolderExists(p, doneName: "base");
        return p;
    }

    func accountPath() -> String
    {
        let p = storageBasePath() + "/account";
        assureFolderExists(p, doneName: "account");
        return p;
    }

    func settingsPath() -> String
    {
        let p = storageBasePath() + "/settings";
        assureFolderExists(p, doneName: "settings");
        return p;
    }

    func cacheFilesPath() -> String
    {
        let p = storageBasePath() + "/cache";
        assureFolderExists(p, doneName: "cache");
        return p;
    }

    func songsFolderPath() -> String
    {
        let p = cacheFilesPath() + "/songs";
        assureFolderExists(p, doneName: "songs")
        return p;
    }

    func thumbnailsFolderPath() -> String
    {
        let p = cacheFilesPath() + "/thumbnails";
        assureFolderExists(p, doneName: "thumbnails")
        return p;
    }

    func playlistsFolderPath() -> String
    {
        let p = cacheFilesPath() + "/playlists";
        assureFolderExists(p, doneName: "playlists")
        return p;
    }

    func tempFilesPath() -> String
    {
        // .cachesDirectory: Stores files in here that can be discarded when the space is low. This is a good location for any content that can be re-downloaded when needed.
        // Contents of this directory is not included in the backups. When the device is low on disk space then iOS can help by clearing caches. Files will never be removed
        // from your cache if your application is running and OS will start by clearing caches from apps that haven’t been used in a while.
        let cacheUrls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask);
        assureFolderExists(cacheUrls[0].standardizedFileURL.path, doneName: "tempBase");
        let tmpPath = cacheUrls[0].appendingPathComponent("tmp").standardizedFileURL.path;
        assureFolderExists(tmpPath, doneName: "tmp")
        return tmpPath;
    }
    
    func uploadFilesPath() -> String
    {
        let p = tempFilesPath() + "/uploads";
        assureFolderExists(p, doneName: "uploads")
        return p;
    }


}

