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
        if v[i].handle == n.handle || (n.type == .file && v[i].type == .file && n.parentHandle == v[i].handle) {
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

    func onNodesUpdate(_ api: MEGASdk, nodeList : MEGANodeList)
    {
        if (nodeList == nil) {
            return; // yes it is null sometimes
        }
        for i in 0..<nodeList.size.intValue {
            let node = nodeList.node(at: i)
            
            if (node == nil) { continue; }
            
            app().playQueue.nodesChanging(node!);
            if (app().playQueueTVC != nil) { app().playQueueTVC!.nodesChanging(node!); }
            if (app().browseMusicTVC != nil) { app().browseMusicTVC!.nodesChanging(node!); }
            if (app().browsePlaylistsTVC != nil) { app().browsePlaylistsTVC!.nodesChanging(node!); }
            
            if (node!.name.hasSuffix(".playlist")) {
                _ = app().storageModel.startDownloadIfAbsent(node: node!);
            }
        }

        app().playQueue.nodesFinishedChanging();
        if (app().playQueueTVC != nil) { app().playQueueTVC!.nodesFinishedChanging();}
        if (app().browseMusicTVC != nil) { app().browseMusicTVC!.nodesFinishedChanging();}
        if (app().browsePlaylistsTVC != nil) { app().browsePlaylistsTVC!.nodesFinishedChanging();}
    }
    
    func onThumbnailUpdate(thumbHandle : String)
    {
        if (isThumbnailInNodeVec(thumbHandle, app().playQueue.nextSongs) ||
            isThumbnailInNodeVec(thumbHandle, app().playQueue.playedSongs) ) {
            app().playQueueTVC?.redraw();
        }
        
        if (app().playQueue.nodeInPlayer != nil) &&
           (app().playQueue.nodeInPlayer!.thumbnailAttributeHandle != nil &&
                app().playQueue.nodeInPlayer!.thumbnailAttributeHandle! == thumbHandle)
        {
            app().playQueueTVC?.playingSongUpdated();
        }
        
        if (app().browseMusicTVC != nil) {
            if (isThumbnailInNodeVec(thumbHandle, app().browseMusicTVC!.nodeArray)) {
                app().browseMusicTVC!.redraw();
            }
        }
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

    func fileDownloadedByFP(_ node: MEGANode) -> Bool
    {
        if (node.fingerprint == nil) { return false; }
        if downloadedFP.contains(node.fingerprint!) { return true; }
        guard let filename = songFingerprintPath(node: node) else { return false }
        let exists = FileManager.default.fileExists(atPath: filename);
        if (exists) { downloadedFP.insert(node.fingerprint); }
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
        if (node.name.hasSuffix(".playlist")) {
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
        if downloadedThumbnail.contains(ta) { return true; }
        guard let filename = thumbnailPath(node: node) else { return false }
        let exists = FileManager.default.fileExists(atPath: filename);
        if (exists) { downloadedThumbnail.insert(ta); }
        if (!exists && !downloadingThumbnail.contains(ta)) {
            downloadingThumbnail.insert(ta);
            mega().getThumbnailNode(node, destinationFilePath: filename, delegate:
                    MEGARequestOneShot(onFinish:
                        { (e: MEGAError) -> Void in
                            self.megaDelegate.onThumbnailUpdate(thumbHandle: ta)
                            self.downloadingThumbnail.remove(ta);}));
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
        var node = app().playlistBrowseFolder;
        if (node != nil && app().loginState.accountByFolderLink)
        {
            node = mega().node(forPath: "˜old-versions˜", node: node!);
            if (node == nil)
            {
                if (app().loginState.online)
                {
                    mega().createFolder(withName: "˜old-versions˜", parent: app().playlistBrowseFolder!)
                }
                return app().playlistBrowseFolder!
            }
        }
        return node;
    }

    func songFingerprintPath(node: MEGANode) -> String?
    {
        if node.type != .file {
            print ("attempted fingerprint path for a non-file: " + (node.name == nil ? "<nil>": node.name))
            return nil;
        }
        if (node.fingerprint == nil) {
            print ("fingerprint was nil for: " + (node.name == nil ? "<nil>": node.name))
            return nil;
        }
        
        let u = URL(fileURLWithPath: node.name);
        let pathExtension = u.pathExtension;

        return songsFolderPath() + "/" + node.fingerprint + "." + pathExtension;
    }
    
    func thumbnailPath(node: MEGANode) -> String?
    {
        if node.type != .file {
            print ("attempted fingerprint path for a non-file: " + (node.name == nil ? "<nil>": node.name))
            return nil;
        }
        if (node.fingerprint == nil) {
            print ("fingerprint was nil for: " + (node.name == nil ? "<nil>": node.name))
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

    func getUploadPlaylistFileURL() -> String
    {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        var doneAlready = false;
        assureFolderExists(tempFilesPath() + "/upload/", doneAlready: &doneAlready);
        return tempFilesPath() + "/upload/" + formatter.string(from: Date()) + ".playlist";
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
    
    func getPlaylistFileAsJSON(_ node: MEGANode, edited : Bool) -> Any?
    {
        do
        {
            if let filename = playlistPath(node: node, forEditing: edited) {
                let content = try String(contentsOf: URL(fileURLWithPath: filename), encoding: .utf8);
                let contentData = content.data(using: .utf8);
                return try JSONSerialization.jsonObject(with: contentData!, options: []);
            }
        }
        catch {
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
        if (node.name.hasSuffix(".playlist")) {
            return isDownloadingByNH(node);
        } else {
            return isDownloadingByFP(node);
        }
    }

    func startDownloadIfAbsent( node: MEGANode) -> Bool
    {
        if (!app().loginState.online) { return false; }
        
        if (node.name.hasSuffix(".playlist")) {
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
            return try String(contentsOf: URL(fileURLWithPath: storagePath() + "/" + leafname), encoding: .utf8);
        }
        catch {
        }
        return nil;
    }
    
    func storeSettingFile(leafname : String, content : String) -> Bool
    {
        do {
            try content.write(toFile: storagePath() + "/" + leafname, atomically: true, encoding: String.Encoding.utf8);
            return true;
        }
        catch {
            return false;
        }
    }
    
    func deleteSettingFile(leafname : String)
    {
        do {
            try FileManager.default.removeItem(atPath: storagePath() + "/" + leafname)
        }
        catch {
            print("Failed to remove file " + storagePath() + "/" + leafname)
        }
    }
    
    func assureFolderExists(_ url : String, doneAlready : inout Bool) -> Void
    {
        if (doneAlready) { return; }
        do {
            if !FileManager.default.fileExists(atPath: url) {
                try FileManager.default.createDirectory(atPath: url, withIntermediateDirectories: true, attributes: nil);
            }
            var urv = URLResourceValues();
            urv.isExcludedFromBackup = true;
            var attribUrl = URL(fileURLWithPath: url)
            try attribUrl.setResourceValues(urv);
            doneAlready = true;
        }
        catch
        {
            print("directory does not exist and could not be created or could not be set non-backup: \(url)")
        }
    }
    
    var createdFolder1 = false;
    var createdFolder2 = false;
    var createdFolder3 = false;
    var createdFolder4 = false;
    var createdFolder5 = false;

    func storagePath() -> String
    {
        // choosing applicationSupportDirectory means the files will not be accessible from other apps,
        // won't be removed by the system (unlike cache directories) and we can set flags to prevent
        // the files being synced by iTunes or iCloud.
        // https://developer.apple.com/library/archive/qa/qa1719/_index.html
        let folderUrls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask);
        assureFolderExists(folderUrls[0].standardizedFileURL.path, doneAlready: &createdFolder1);
        let path = folderUrls[0].appendingPathComponent("dl").standardizedFileURL.path;
        assureFolderExists(path, doneAlready: &createdFolder2)
        return path;
    }

    func songsFolderPath() -> String
    {
        let p = storagePath() + "/songs";
        assureFolderExists(p, doneAlready: &createdFolder3)
        return p;
    }

    func thumbnailsFolderPath() -> String
    {
        let p = storagePath() + "/thumbnails";
        assureFolderExists(p, doneAlready: &createdFolder4)
        return p;
    }

    func playlistsFolderPath() -> String
    {
        let p = storagePath() + "/playlists";
        assureFolderExists(p, doneAlready: &createdFolder5)
        return p;
    }

    var createdCacheFolder1 = false;
    var createdCacheFolder2 = false;

    func tempFilesPath() -> String
    {
        // .cachesDirectory: Stores files in here that can be discarded when the space is low. This is a good location for any content that can be re-downloaded when needed.
        // Contents of this directory is not included in the backups. When the device is low on disk space then iOS can help by clearing caches. Files will never be removed
        // from your cache if your application is running and OS will start by clearing caches from apps that haven’t been used in a while.
        let cacheUrls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask);
        assureFolderExists(cacheUrls[0].standardizedFileURL.path, doneAlready: &createdCacheFolder1);
        let tmpPath = cacheUrls[0].appendingPathComponent("tmp").standardizedFileURL.path;
        assureFolderExists(tmpPath, doneAlready: &createdCacheFolder2)
        return tmpPath;
    }

}
