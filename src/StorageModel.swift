//
//  StorageModel.swift
//  SongMe
//
//  Created by Matt Weir on 4/01/20.
//  Copyright © 2020 mattweir. All rights reserved.
//

import Foundation
import Intents

//class TransferHandler: NSObject, MEGATransferDelegate {
//    
//    func onTransferStart(_ api: MEGASdk, transfer: MEGATransfer) {
//    }
//    
////    func onTransferUpdate(_ api: MEGASdk, transfer: MEGATransfer) {
////        let percent = NSNumber(value: transfer.transferredBytes.floatValue / transfer.totalBytes.floatValue);
////        app().downloadProgress(nodeHandle: transfer.nodeHandle, percent: percent)
////    }
//    
//    func onTransferFinish(_ api: MEGASdk, transfer request: MEGATransfer, error: MEGAError) {
//        let n = mega().node(forHandle: request.nodeHandle)
//        if (n != nil && n!.fingerprint != nil) {
//            if (error.type.rawValue == 0)
//            {
//                globals.storageModel.fileArrived(fingerprint: n!.fingerprint!, node: n!);
//            }
//            else
//            {
//                globals.storageModel.fileFailed(fingerprint: n!.fingerprint!, node: n!);
//            }
//        }
//    }
//    
//    func onTransferTemporaryError(_ api: MEGASdk, transfer request: MEGATransfer, error: MEGAError) {
////        api.cancelTransfer(request);
//  //      let n = mega().node(forHandle: request.nodeHandle)
//    //    if (n != nil && n!.fingerprint != nil) {
//      //      globals.storageModel.fileFailed(fingerprint: n!.fingerprint!);
//        //}
//    }
//}

//func replaceNodeIn(_ n : MEGANode, _ v : inout [MEGANode]) -> Bool
//{
//    var result : Bool = false;
//    for i in v.indices {
//        if v[i].handle == n.handle
//            // attempt to handle file versions but not quite right
//            //|| (n.type == .file && v[i].type == .file && n.parentHandle == v[i].handle)
//        {
//            v[i] = n;
//            result = true;
//        }
//    }
//    return result;
//}
//
//func isThumbnailInNodeVec(_ thumbHandle : String, _ v : [MEGANode]) -> Bool
//{
//    for i in v.indices {
//        if let th = v[i].thumbnailAttributeHandle {
//            if (th == thumbHandle) {
//                return true;
//            }
//        }
//    }
//    return false;
//}

//class MEGAHandler: NSObject, MEGADelegate {
//
//    func onNodesUpdate(_ api: MEGASdk, nodeList : MEGANodeList?)
//    {
//        if (nodeList == nil) {
//            return; // yes it is null sometimes
//        }
//        for i in 0..<nodeList!.size.intValue {
//            let node = nodeList!.node(at: i)
//            
//            if (node == nil) { continue; }
//            
//            globals.playQueue.nodesChanging(node!);
//            if (app().playQueueTVC != nil) { app().playQueueTVC!.nodesChanging(node!); }
//            if (app().browseMusicTVC != nil) { app().browseMusicTVC!.nodesChanging(node!); }
//            if (app().browsePlaylistsTVC != nil) { app().browsePlaylistsTVC!.nodesChanging(node!); }
//            
//            if (node!.name != nil &&
//                node!.name!.hasSuffix(".playlist")) {
//                _ = globals.storageModel.startDownloadIfAbsent(node: node!);
//            }
//            
//            // in case it now has a thumbnail, start it downloading
//            _ = globals.storageModel.thumbnailDownloaded(node!);
//        }
//
//        globals.playQueue.nodesFinishedChanging();
//        if (app().playQueueTVC != nil) { app().playQueueTVC!.nodesFinishedChanging();}
//        if (app().browseMusicTVC != nil) { app().browseMusicTVC!.nodesFinishedChanging();}
//        if (app().browsePlaylistsTVC != nil) { app().browsePlaylistsTVC!.nodesFinishedChanging();}
//    }
//    
//    func onThumbnailUpdate(node : MEGANode)
//    {
//        globals.playQueue.nodesChanging(node);
//        if (app().playQueueTVC != nil) { app().playQueueTVC!.nodesChanging(node); }
//        if (app().browseMusicTVC != nil) { app().browseMusicTVC!.nodesChanging(node); }
//        if (app().browsePlaylistsTVC != nil) { app().browsePlaylistsTVC!.nodesChanging(node); }
//        globals.playQueue.nodesFinishedChanging();
//        if (app().playQueueTVC != nil) { app().playQueueTVC!.nodesFinishedChanging();}
//        if (app().browseMusicTVC != nil) { app().browseMusicTVC!.nodesFinishedChanging();}
//        if (app().browsePlaylistsTVC != nil) { app().browsePlaylistsTVC!.nodesFinishedChanging();}
//    }
//}

class StorageModel {
    
    var index : [String : [String : String]] = [:];
    
//    var downloadingFP : Set<String> = [];
//    var downloadedFP : Set<String> = [];
//    
//    var downloadingNH : Set<UInt64> = [];
//    var downloadedNH : Set<UInt64> = [];
//
//    var downloadingThumbnail : Set<String> = [];
//    var downloadedThumbnail : Set<String> = [];

    //var transferDelegate = TransferHandler();
    //var megaDelegate = MEGAHandler();
    

    func clear()
    {
//        downloadingFP = [];
//        downloadedFP = [];
//        
//        downloadingNH = [];
//        downloadedNH = [];
//
//        downloadingThumbnail = [];
//        downloadedThumbnail = [];
    }
    
    func load()
    {
        //_ exportFolder : String
        let attrsFile = Path(rp: "", r: .IndexFile, f: false);
        
        let attrsJson = loadFileAsJSON(filename: attrsFile.fullPath())
        
        if let array = attrsJson as? [Any] {
            for object in array {
                if let attribs = object as? [String : String] {
                    if var p = attribs["npath"] {
                        if (p.hasPrefix("/music/music/"))
                        {
                            p = String(p.suffix(from: p.index(p.startIndex, offsetBy: 13)))
                        }
                        index[p] = attribs;
                    }
                }
            }
        }
    }
    
//    func attrs_of_node(mega_node : MEGANode) -> [String : String]?
//    {
//        var p : String = app().nodePath(mega_node);
//        if (p.hasPrefix("/music/music/"))
//        {
//            p = String(p.suffix(from: p.index(p.startIndex, offsetBy: 13)))
//        }
//        var result = index[p];
//        if result != nil && result!["title"] == nil {
//            result!["title"] = URL(fileURLWithPath: p).lastPathComponent;
//        }
//        return result;
//    }
//    
    func lookupSong(_ n: Path) -> [String : String]?
    {
        assert(n.rt == Path.RootType.MusicRoot);
        
        var result = index[n.relativePath];
        if result != nil && result!["title"] == nil {
            result!["title"] = URL(fileURLWithPath: n.relativePath).lastPathComponent;
        }
        return result;
    }
    
//    func deleteCachedFiles(includingAccountAndSettings : Bool) -> Bool
//    {
//        clear();
//        
//        var result : Bool = true;
//        do
//        {
//            if (includingAccountAndSettings)
//            {
//                try FileManager.default.removeItem(at: URL(fileURLWithPath: storageBasePath()));
//            }
//            else
//            {
//                try FileManager.default.removeItem(at: URL(fileURLWithPath: cacheFilesPath()));
//            }
//            try FileManager.default.removeItem(at: URL(fileURLWithPath: tempFilesPath()));
//        }
//        catch {
//            result = false;
//        }
//        
//        // recreate those folders again (now empty) so we don't have issues with the next login etc.
//        globals.storageModel.alreadyCreatedFolders = [];
//        _ = accountPath();
//        _ =  cacheFilesPath();
//        _ = tempFilesPath();
//        
//        return result;
//    }

//    func fileDownloadedByFP(_ node: MEGANode) -> Bool
//    {
//        if (node.fingerprint == nil) { return false; }
//        if downloadedFP.contains(node.fingerprint!) { return true; }
//        guard let filename = songFingerprintPath(node: node) else { return false }
//        let exists = FileManager.default.fileExists(atPath: filename);
//        if (exists && node.fingerprint != nil) { downloadedFP.insert(node.fingerprint!); }
//        return exists;
//    }
//
//    func fileDownloadedByNH(_ node: MEGANode) -> Bool
//    {
//        if downloadedNH.contains(node.handle) { return true; }
//        guard let filename = playlistPath(node: node, forEditing: false) else { return false }
//        let exists = FileManager.default.fileExists(atPath: filename);
//        if (exists) { downloadedNH.insert(node.handle); }
//        return exists;
//    }
//
//    func fileDownloadedByType(_ node: MEGANode) -> Bool
//    {
//        if (node.name != nil && node.name!.hasSuffix(".playlist")) {
//            return fileDownloadedByNH(node);
//        } else {
//            return fileDownloadedByFP(node);
//        }
//    }
//    
//    func thumbnailDownloaded(_ node: MEGANode) -> Bool
//    {
//        if (node.thumbnailAttributeHandle == nil) {return false;}
//        let ta = node.thumbnailAttributeHandle!;
//        if (ta.contains("______")) {
//            return false;
//        }
//        //print ("thumbnail handle " + ta + " for " + node.name)
//        if downloadedThumbnail.contains(ta) { return true; }
//        guard let filename = thumbnailPath(node: node) else { return false }
//        let exists = FileManager.default.fileExists(atPath: filename);
//        if (exists) { downloadedThumbnail.insert(ta); }
//        if (!exists && !downloadingThumbnail.contains(ta)) {
//            downloadingThumbnail.insert(ta);
//            mega().getThumbnailNode(node, destinationFilePath: filename, delegate:
//                    MEGARequestOneShot(onFinish:
//                        { (e: MEGAError) -> Void in
//                            self.downloadedThumbnail.insert(ta); // prevent cycle if it doesn't work
//                            self.downloadingThumbnail.remove(ta);
//                            self.megaDelegate.onThumbnailUpdate(node: node);
//            }));
//        }
//        return exists;
//    }
    
//    func playlistPath(n: Path, forEditing : Bool) -> Path?
//    {
//        var s = n; //playlistsFolderPath() + "/" + MEGASdk.base64Handle(forHandle: node.handle)! + ".playlist";
//        //var s = songFingerprintPath(node: node);
//        s.relativePath += (forEditing ? ".editing": "");
//        //s += (forUpload ? ".upload": "");
//        return s;
//    }
    
//    func getOldPlaylistsFolder() -> MEGANode?
//    {
//        var node : MEGANode? = nil;
//        if (globals.playlistBrowseFolder != nil)
//        {
//            node = mega().node(forPath: "old-playlist-versions", node: globals.playlistBrowseFolder!);
//            if (node == nil && globals.loginState.online)
//            {
//                mega().createFolder(withName: "old-playlist-versions", parent: globals.playlistBrowseFolder!)
//            }
//        }
//        return node;
//    }

//    func songFingerprintPath(node: MEGANode) -> String?
//    {
//        if node.type != .file {
//            print ("attempted fingerprint path for a non-file: " + (node.name ?? "<nil>"))
//            return nil;
//        }
//        if (node.fingerprint == nil) {
//            print ("fingerprint was nil for: " + (node.name ?? "<nil>"))
//            return nil;
//        }
//        
//        if (node.name == nil) { return nil }
//        
//        let u = URL(fileURLWithPath: node.name!);
//        let pathExtension = u.pathExtension;
//
//        return songsFolderPath() + "/" + node.fingerprint! + "." + pathExtension;
//    }
    
//    func thumbnailPath(node: MEGANode) -> String?
//    {
//        if node.type != .file {
//            print ("attempted fingerprint path for a non-file: " + (node.name ?? "<nil>"))
//            return nil;
//        }
//        if (node.fingerprint == nil) {
//            print ("fingerprint was nil for: " + (node.name ?? "<nil>"))
//            return nil;
//        }
//        
//        if let b64 = node.thumbnailAttributeHandle {
//            return thumbnailsFolderPath() + "/" + b64 + ".jpg";
//        }
//        return nil;
//    }
    
//    func getDownloadedSongURL(_ node: MEGANode) -> URL?
//    {
//        guard let filename = songFingerprintPath(node: node) else { return nil }
//        return FileManager.default.fileExists(atPath: filename) ? URL(fileURLWithPath: filename) : nil;
//    }


//    func getPlaylistFileAsJSON(_ n: Path, edited : Bool) -> Any?
//    {
//        if let filename = playlistPath(n: n, forEditing: edited) {
//            return getPlaylistFileAsJSON(filename);
//        }
//        return nil;
//    }

//    func getPlaylistFileEditedOrNotAsJSON(_ n: Path) -> (Any?, Bool)
//    {
//        var p = getPlaylistFileAsJSON(n, edited: true);
//        if (p == nil) {
//            p = getPlaylistFileAsJSON(n, edited: false);
//            return (p, false);
//        }
//        return (p, true);
//    }

    

//    func isDownloadingByFP(_ node : MEGANode) -> Bool
//    {
//        if (node.fingerprint == nil) { return false; }
//        return downloadingFP.contains(node.fingerprint!)
//    }
//
//    func isDownloadingByNH(_ node : MEGANode) -> Bool
//    {
//        return downloadingNH.contains(node.handle)
//    }
//    
//    func isDownloadingByType(_ node: MEGANode) -> Bool
//    {
//        if (node.name != nil &&
//            node.name!.hasSuffix(".playlist")) {
//            return isDownloadingByNH(node);
//        } else {
//            return isDownloadingByFP(node);
//        }
//    }

//    func startDownloadIfAbsent( node: MEGANode) -> Bool
//    {
//        if (!globals.loginState.online) { return false; }
//        
//        if (node.name != nil &&
//            node.name!.hasSuffix(".playlist")) {
//            return startPlaylistDownloadIfAbsent(node);
//        } else {
//            return startSongDownloadIfAbsent(node);
//        }
//    }
//    
//    func startSongDownloadIfAbsent(_ node: MEGANode) -> Bool
//    {
//        if (!globals.loginState.online) { return false; }
//
//        // also start thumbnail downlaoding if it has one and we don't have it already
//        _ = thumbnailDownloaded(node);
//
//        if !isDownloadingByFP(node) && !fileDownloadedByFP(node)
//        {
//            if let filename = songFingerprintPath(node: node) {
//                mega().startDownloadNode(node, localPath: filename);
//                downloadingFP.insert(node.fingerprint!);
//                downloadingNH.insert(node.handle);
//                return true
//            }
//        }
//        return false
//    }
//    
//    func startPlaylistDownloadIfAbsent(_ node: MEGANode) -> Bool
//    {
//        if (!globals.loginState.online) { return false; }
//
//        if !isDownloadingByNH(node) && !fileDownloadedByNH(node)
//        {
//            if let filename = playlistPath(node: node, forEditing: false) {
//                mega().startDownloadNode(node, localPath: filename);
//                downloadingNH.insert(node.handle);
//                return true
//            }
//        }
//        return false
//    }
//    
//    func fileArrived(fingerprint : String, node : MEGANode)
//    {
//        downloadingFP.remove(fingerprint);
//        downloadingNH.remove(node.handle);
//        globals.playQueue.songDownloaded(node: node)
//    }
//   
//   func fileFailed(fingerprint : String, node : MEGANode)
//   {
//       downloadingFP.remove(fingerprint);
//       downloadingNH.remove(node.handle);
//       globals.playQueue.songDownloaded(node: nil)
//   }

    
    func loadSettingFile(leafname : String) -> String?
    {
        do {
            return try String(contentsOf: URL(fileURLWithPath: Path.folderManager.settingsPath() + "/" + leafname), encoding: .utf8);
        }
        catch {
        }
        return nil;
    }
    
    func storeSettingFile(leafname : String, content : String) -> Bool
    {
        do {
            let path = Path(rp: leafname, r: .Settings, f: false);
            try content.write(toFile: path.fullPath(), atomically: true, encoding: String.Encoding.utf8);
            print("Wrote file: " + path.fullPath())
            return true;
        }
        catch {
            return false;
        }
    }
    
    func deleteSettingFile(leafname : String)
    {
        let path = Path(rp: leafname, r: .Settings, f: false);
        if FileManager.default.fileExists(atPath: path.fullPath()) {
            do {
                try FileManager.default.removeItem(atPath: path.fullPath())
                print("Removed file: " + path.fullPath())
            }
            catch {
                print("Failed to remove file " + path.fullPath())
            }
        }
    }
    




//    func accountPath() -> String
//    {
//        let p = storageBasePath() + "/account";
//        assureFolderExists(p, doneName: "account");
//        return p;
//    }



//    func songsFolderPath() -> String
//    {
//        let p = cacheFilesPath() + "/songs";
//        assureFolderExists(p, doneName: "songs")
//        return p;
//    }

//    func thumbnailsFolderPath() -> String
//    {
//        let p = cacheFilesPath() + "/thumbnails";
//        assureFolderExists(p, doneName: "thumbnails")
//        return p;
//    }

//    func playlistsFolderPath() -> String
//    {
//        let p = cacheFilesPath() + "/playlists";
//        assureFolderExists(p, doneName: "playlists")
//        return p;
//    }


    
//    func tempFilesPath() -> String
//    {
//        // .cachesDirectory: Stores files in here that can be discarded when the space is low. This is a good location for any content that can be re-downloaded when needed.
//        // Contents of this directory is not included in the backups. When the device is low on disk space then iOS can help by clearing caches. Files will never be removed
//        // from your cache if your application is running and OS will start by clearing caches from apps that haven’t been used in a while.
//        let cacheUrls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask);
//        assureFolderExists(cacheUrls[0].standardizedFileURL.path, doneName: "tempBase");
//        let tmpPath = cacheUrls[0].appendingPathComponent("tmp").standardizedFileURL.path;
//        assureFolderExists(tmpPath, doneName: "tmp")
//        return tmpPath;
//    }
    
//    func uploadFilesPath() -> String
//    {
//        let p = tempFilesPath() + "/uploads";
//        assureFolderExists(p, doneName: "uploads")
//        return p;
//    }


}

