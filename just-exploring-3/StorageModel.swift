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
        if (error.type.rawValue == 0)
        {
            app().storageModel.fileArrived(handle: request.nodeHandle);
        }
        else
        {
            app().storageModel.fileFailed(handle: request.nodeHandle);
        }
    }
}

class StorageModel {
    
    var downloading : Set<UInt64> = [];
    var downloaded : Set<UInt64> = [];

    var downloadingThumbnail : Set<UInt64> = [];
    var downloadedThumbnail : Set<UInt64> = [];

    var transferDelegate = TransferHandler();

    func fileDownloaded(_ node: MEGANode) -> Bool
    {
        if downloaded.contains(node.handle) { return true; }
        guard let filename = fileFingerprintPath(node: node) else { return false }
        let exists = FileManager.default.fileExists(atPath: filename);
        if (exists) { downloaded.insert(node.handle); }
        return exists;
    }
    
    func thumbnailDownloaded(_ node: MEGANode) -> Bool
    {
        if downloadedThumbnail.contains(node.handle) { return true; }
        guard let filename = thumbnailPath(node: node) else { return false }
        let exists = FileManager.default.fileExists(atPath: filename);
        if (exists) { downloadedThumbnail.insert(node.handle); }
        if (!exists && !downloadingThumbnail.contains(node.handle)) {
            downloadingThumbnail.insert(node.handle);
            mega().getThumbnailNode(node, destinationFilePath: filename)
        }
        return exists;
    }
    
    func fileFingerprintPath(node: MEGANode) -> String?
    {
        if node.type != .file {
            print ("attempted fingerprint path for a non-file: " + (node.name == nil ? "<nil>": node.name))
            return nil;
        }
        guard let fp = node.fingerprint else {
            print ("fingerprint was nil for: " + (node.name == nil ? "<nil>": node.name))
            return nil;
        }
        var b = false;
        assureFolderExists(cachePath() + "/fp/" + fp, doneAlready: &b);
        return cachePath() + "/fp/" + node.fingerprint + "/" + node.name;
    }
    
    func thumbnailPath(node: MEGANode) -> String?
    {
        if let f = fileFingerprintPath(node: node)  { return f + ".jpg"; }
        return nil;
    }
    
    func getDownloadedFileURL(_ node: MEGANode) -> URL?
    {
        guard let filename = fileFingerprintPath(node: node) else { return nil }
        return FileManager.default.fileExists(atPath: filename) ? URL(fileURLWithPath: filename) : nil;
    }

    func getUploadPlaylistFileURL() -> String
    {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        var doneAlready = false;
        assureFolderExists(cachePath() + "/upload/", doneAlready: &doneAlready);
        return cachePath() + "/upload/" + formatter.string(from: Date()) + ".playlist";
    }
    
    func getDownloadedFileAsJSON(_ node: MEGANode) -> Any?
    {
        do
        {
            if let filename = fileFingerprintPath(node: node) {
                let content = try String(contentsOf: URL(fileURLWithPath: filename), encoding: .utf8);
                let contentData = content.data(using: .utf8);
                return try JSONSerialization.jsonObject(with: contentData!, options: []);
            }
        }
        catch {
        }
        return nil;
    }

    func isDownloading(_ node : MEGANode) -> Bool
    {
        return downloading.contains(node.handle)
    }
    
    func startDownloadIfAbsent(_ node: MEGANode) -> Bool
    {
        if !isDownloading(node) && !fileDownloaded(node)
        {
            if let filename = fileFingerprintPath(node: node) {
                mega().startDownloadNode(node, localPath: filename);
                downloading.insert(node.handle);
                print("downloading \(filename)")
                return true
            }
        }
        return false
    }
    
   func fileArrived(handle : UInt64)
   {
       downloading.remove(handle);
       app().playQueue.songDownloaded(handle)
   }
   
   func fileFailed(handle : UInt64)
   {
       downloading.remove(handle);
   }

    
    func loadSettingFile(leafname : String) -> String?
    {
        do {
            return try String(contentsOf: URL(fileURLWithPath: cachePath() + "/" + leafname), encoding: .utf8);
        }
        catch {
        }
        return nil;
    }
    
    func storeSettingFile(leafname : String, content : String) -> Bool
    {
        do {
            try content.write(toFile: cachePath() + "/" + leafname, atomically: true, encoding: String.Encoding.utf8);
            return true;
        }
        catch {
            return false;
        }
    }
    
    func deleteSettingFile(leafname : String)
    {
        do {
            try FileManager.default.removeItem(atPath: cachePath() + "/" + leafname)
        }
        catch {
            print("Failed to remove file " + cachePath() + "/" + leafname)
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

    
    func cachePath() -> String
    {
        // choosing applicationSupportDirectory means the files will not be accessible from other apps,
        // won't be removed by the system (unlike cache directories) and we can set flags to prevent
        // the files being synced by iTunes or iCloud.
        // https://developer.apple.com/library/archive/qa/qa1719/_index.html
        let folderUrls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask);
        assureFolderExists(folderUrls[0].standardizedFileURL.path, doneAlready: &createdFolder1);
        let cachePath = folderUrls[0].appendingPathComponent("mm").standardizedFileURL.path;
        assureFolderExists(cachePath, doneAlready: &createdFolder2)
        let byFingerprint = cachePath + "/fp";
        assureFolderExists(byFingerprint, doneAlready: &createdFolder3)
        return cachePath;
    }
}
