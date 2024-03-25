//
//  PlayListTVC.swift
//  just-exploring-3
//
//  Created by Admin on 28/10/2019.
//  Copyright © 2019 mattweir. All rights reserved.
//

import Foundation
import UIKit
import AVKit


//class TransferOnFinishDelegate: NSObject, MEGATransferDelegate {
//    
//    var finishFunc : ((_ e: MEGAError, _ h: MEGAHandle) -> Void)?;
//    
//    init(onFinish : @escaping (_ e: MEGAError, _ h: MEGAHandle) -> Void) {
//        finishFunc = onFinish;
//    }
//    
//    func onTransferStart(_ api: MEGASdk, transfer: MEGATransfer) {
//    }
//    
//    func onTransferUpdate(_ api: MEGASdk, transfer: MEGATransfer) {
//    }
//    
//    func onTransferFinish(_ api: MEGASdk, transfer request: MEGATransfer, error: MEGAError) {
//        if (finishFunc != nil ) {
//            
//            let requestClone = request.clone();
//            let errorClone = error.clone();
//            
//            DispatchQueue.main.async {
//                self.finishFunc!(errorClone!, requestClone!.nodeHandle)
//            }
//        }
//    }
//    
//    func onTransferTemporaryError(_ api: MEGASdk, transfer request: MEGATransfer, error: MEGAError) {
//    }
//}

class PlaylistTVC: UITableViewController {

    @IBOutlet weak var folderPathLabelCtrl: UILabel!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var revertButton: UIButton!

    var playlistNode : Path? = nil;
    var playlistSongs : [Path] = [];
    var playlistToLoad : Path? = nil;
    var loadedOk : Bool = false;
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.estimatedRowHeight = 43.5;
        tableView.rowHeight = UITableView.automaticDimension;
        tableView.isEditing = false;
    }

    
    
    override func viewDidAppear(_ animated: Bool) {
        navigationItem.rightBarButtonItem =
            UIBarButtonItem(title: "Option", style: .done, target: self, action: #selector(optionButton))
        
//        if (!loadedOk)
//        {
//            let message = globals.loginState.online ?
//            "The playlist has not been downloaded yet, please give it a moment and then retry.":
//            "The playlist has not been downloaded yet.  Please go online so it can download, and it will be available shortly afterward";
//            
//            if playlistNode != nil {
//                _ = globals.storageModel.startPlaylistDownloadIfAbsent(playlistNode!);
//            }
//            
//            let alert = UIAlertController(title: "Playlist absent", message: message, preferredStyle: .alert)
//            alert.addAction(UIAlertAction(title: "Ok", style: .cancel));
//            self.present(alert, animated: false, completion: { () -> Void in
//                self.navigationController?.popViewController(animated: true);
//            })
//        }
    }
    
//    @objc func popVC() {
//        self.navigationController?.popViewController(animated: true);
//    }
    
    override func viewDidDisappear(_ animated: Bool) {
        navigationItem.rightBarButtonItem = nil;
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);

        if (playlistToLoad != nil)
        {
            // load it again if the user switched away and back, they may have added songs
            loadPlaylist(n: playlistToLoad!)
        }

        adjustControls();
    }

    let rearrangeModeCheckbox = ContextMenuCheckbox("Rearrange mode", false);
    
    @objc func optionButton() {
        
        let alert = UIAlertController(title: nil, message: "Options", preferredStyle: .alert)

        alert.addTextField( configurationHandler: { newTextField in
            self.rearrangeModeCheckbox.takeOverTextField(newTextField: newTextField)
        });

        alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { (UIAlertAction) -> Void in
            self.tableView.isEditing = self.rearrangeModeCheckbox.flag;
        }));
        self.present(alert, animated: false, completion: nil)
    }
    
    @IBAction func onSaveButton() {
        
//        if (CheckOnlineOrWarn("Please go online before uploading the changed playlist", uic: self))
//        {
            if (playlistNode == nil) { return; }
            
            do {
                try savePlaylist(editing : false);
            } catch {
                reportMessage(uic: self, message: "Error while saving: \(error)")
            }
            
//            if let parentFolder = megaGetContainingFolder(playlistNode!) {
//            
//                saveAsEditing();
//            
//                if let updateFilePath = globals.storageModel.playlistPath(node: playlistNode!, forEditing: true) {
//                    
//                    if (globals.loginState.accountByFolderLink && globals.playlistBrowseFolder != nil)
//                    {
//                        if let oldPlaylistsFolder = globals.storageModel.getOldPlaylistsFolder() {
//                        // folder links don't link versions yet
//                            let formatter = DateFormatter()
//                            formatter.dateFormat = "yyyyMMdd-HHmmss"
//                            var newname = playlistNode!.name;
//                            if (newname == nil) { newname = "playlist.playlist"; }
//                            if newname!.hasSuffix(".playlist") {
//                                newname!.removeSubrange((newname?.lastIndex(where: {$0 == "."})! ?? newname!.endIndex) ..< newname!.endIndex);
//                            }
//                            newname! += ".old." + formatter.string(from: Date()) + ".playlist";
//                            
//                            mega().move(playlistNode!, newParent: oldPlaylistsFolder, newName: newname!)
//                        }
//                        else
//                        {
//                            reportMessage(uic: self, message: "Creating old-versions folder, as creating file versions through writable folder links doesn't work yet.  Until that works, the old version of the playlist will be put in that folder with a timestamp from when it was replaced.  Please retry, the folder should be created by now.");
//                            return;
//                        }
//                    }
//
//                    let spinner = ProgressSpinner(uic: self, title: "Uploading Playlist", message: "");
//                    
//                    mega().startUploadToFile(withLocalPath: updateFilePath, parent: parentFolder, filename:playlistNode!.name!,
//                                             delegate: TransferOnFinishDelegate(onFinish: { (e: MEGAError, h: MEGAHandle) -> Void in
//
//                        var success = e.type == .apiOk;
//                        if (success) {
//                            do {
//                                try FileManager.default.removeItem(atPath: updateFilePath);
//                                
//                                if let newNode = mega().node(forHandle: h) {
//                                    for i in 0..<app().recentPlaylists.count {
//                                        if (app().recentPlaylists[i].handle == self.playlistNode!.handle)
//                                        {
//                                            app().recentPlaylists[i] = newNode;
//                                        }
//                                    }
//                                }
//                                
//                                // go back to list of playlists, the new one should be replaced there now
//                                self.navigationController?.popViewController(animated: true);
//                                
//                            } catch {
//                                success = false;
//                                spinner.setErrorMessage("Could not remove the upload file afterward");
//                            }
//                        } else {
//                            success = false;
//                            spinner.setErrorMessage("Error uploading: " + e.nameWithErrorCode(e.type.rawValue));
//                        }
//
//                        spinner.dismissOrReportError(success: success)
//
//                    }));
//                }
 //           }
        
            adjustControls();
//        }
    }
    
    @IBAction func onRevertButton() {
        if (playlistNode == nil) { return; }
        do {
            try FileManager.default.removeItem(atPath: playlistNode!.edited().fullPath());
        } catch {
            // etc
        }
        loadPlaylist(n: playlistNode!)
        adjustControls();
    }

    func adjustControls() {
        folderPathLabelCtrl.text = playlistNode == nil ? "<playlist>" : leafName(playlistNode!);
        
        let edited = playlistNode == nil ? false : FileManager.default.fileExists(atPath: playlistNode!.edited().fullPath());

        saveButton.isEnabled = edited;
        revertButton.isEnabled = edited;
    }
    
    func savePlaylist(editing: Bool) throws
    {
        if (playlistNode == nil) { return; }
        let s = globals.playQueue.nodeHandleArrayToJSON(optionalExtraFirstNode: nil, array: playlistSongs);
        
        let url = editing ?
                    URL(fileURLWithPath: playlistNode!.edited().fullPath())
                :   URL(fileURLWithPath: playlistNode!.fullPath());
        
        try s.write(to: url, atomically: true, encoding: .ascii)
        
        if (!editing)
        {
            try FileManager.default.removeItem(atPath: playlistNode!.edited().fullPath());
        }
        
        adjustControls();
    }
    
    // MARK: - Table view data source
    
    func loadPlaylist(n: Path)
    {
        playlistNode = n;
        playlistSongs = [];
        
        do {
            let json = try globals.storageModel.getPlaylistFileAsJSON(n, editedIfAvail: true);
            
            loadedOk = true;
            
            if (loadedOk)
            {
                playlistSongs = [];
                globals.storageModel.loadSongsFromPlaylistRecursive(json: json, &playlistSongs, recurse: true, filterIntent: nil);
            }
        }
        catch {
            reportMessage(uic: self, message: "Failed to load: \(error)")
        }
        redraw();
        adjustControls();
    }
    
    func redraw()
    {
        tableView.reloadData();
    }

    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return playlistSongs.count;
    }


    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let n = playlistSongs[indexPath.row];

        let songAttr = globals.storageModel.lookupSong(n);
        
        let notes : String? = songAttr?["notes"]; //node.customNotes;
        
        let cell = tableView.dequeueReusableCell(withIdentifier: notes == nil || notes! == "" ? "MusicCell" : "MusicCellWithNotes", for: indexPath)

        if let musicCell = cell as? TableViewMusicCell {
            musicCell.populateFromSongAttr(songAttr ?? [:]);
        }
        
        return cell
    }
    
    override func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {

        let n = playlistSongs[indexPath.row];
        let songAttr = globals.storageModel.lookupSong(n);
        let notes : String? = songAttr?["notes"];
        return notes == nil || notes! == "" ? 43.5 : 70;
    }
    
    override func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {

        //if (tableView.isEditing) { return false; }
        

        // long press to show menu for song
        if (indexPath.row < playlistSongs.count)
        {
            let n = playlistSongs[indexPath.row];

            let alert = UIAlertController(title: nil, message: "Song actions", preferredStyle: .alert)
            alert.addAction(menuAction_playNext(n, uic: self));
            alert.addAction(menuAction_songBrowseTo(n, viewController: self));
            alert.addAction(menuAction_neverMind());
            self.present(alert, animated: false, completion: nil)
        }
        
        return false;
    }
    
    override func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return true;
    }
    
    override func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
    }

    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return indexPath.row >= 0;
    }

    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete && indexPath.row < globals.playQueue.nextSongs.count {
            playlistSongs.remove(at: indexPath.row)
            do
            {
                try savePlaylist(editing: true);
            }
            catch {
            }
            redraw()
        }
    }

    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
        if fromIndexPath.row < playlistSongs.count && to.row < playlistSongs.count {
            let item = playlistSongs.remove(at: fromIndexPath.row);
            playlistSongs.insert(item, at: to.row);
            do
            {
                try savePlaylist(editing: true);
            }
            catch {
            }
            redraw()
        }
    }

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
