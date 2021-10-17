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



class PlaylistTVC: UITableViewController, MEGATransferDelegate {

    @IBOutlet weak var folderPathLabelCtrl: UILabel!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var revertButton: UIButton!

    var playlistNode : MEGANode? = nil;
    var playlistSongs : [MEGANode] = [];
    var playlistToLoad : MEGANode? = nil;
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.estimatedRowHeight = 43.5;
        tableView.rowHeight = UITableView.automaticDimension;
        tableView.isEditing = false;
    }

    
    
    override func viewDidAppear(_ animated: Bool) {
        navigationItem.rightBarButtonItem =
            UIBarButtonItem(title: "Option", style: .done, target: self, action: #selector(optionButton))
        
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
            loadPlaylist(node: playlistToLoad!)
        }

        adjustControls();
    }

   
    @objc func optionButton() {
        
        let alert = UIAlertController(title: nil, message: "Options", preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: tableView.isEditing ? "Disable Rearrange" : "Enable Rearrange", style: .default, handler:
            { (UIAlertAction) -> () in self.tableView.isEditing.toggle() }));

//        alert.addAction(UIAlertAction(title: "Save as playlist", style: .default, handler:
//            { (UIAlertAction) -> () in app().playQueue.saveAsPlaylist() }));

        alert.addAction(UIAlertAction(title: "Never mind", style: .cancel));
        self.present(alert, animated: false, completion: nil)
    }
    
    
    var spinnerBusyControl : UIAlertController? = nil;

    func startSpinnerControl(message : String)
    {
        spinnerBusyControl = UIAlertController(title: nil, message: message + "\n\n", preferredStyle: .alert)
        let spinnerIndicator = UIActivityIndicatorView(style: .large)
        spinnerIndicator.center = CGPoint(x: 135.0, y: 65.5)
        spinnerIndicator.color = UIColor.black
        spinnerIndicator.startAnimating()
        spinnerBusyControl!.view.addSubview(spinnerIndicator)
        self.present(spinnerBusyControl!, animated: false, completion: nil)
    }
    
    func onTransferFinish(_ api: MEGASdk, transfer request: MEGATransfer, error: MEGAError) {
        spinnerBusyControl!.dismiss(animated: true);
        spinnerBusyControl = nil;
        if (error.type.rawValue != 0)
        {
            reportMessage(uic: self, message: "Error uploading: " + error.nameWithErrorCode(error.type.rawValue));
        }
        else
        {
            self.navigationController?.popViewController(animated: true);
        }
    }
    
    @IBAction func onSaveButton() {
        
        if (CheckOnlineOrWarn("Please go online before uploading the changed playlist", uic: self))
        {
            if (playlistNode == nil) { return; }
            
            if let parentFolder = megaGetContainingFolder(playlistNode!) {
            
                saveAsEditing();
            
                if let updateFilePath = app().storageModel.playlistPath(node: playlistNode!, forEditing: true) {
                    
                    if (app().loginState.accountByFolderLink && app().playlistBrowseFolder != nil)
                    {
                        if let oldPlaylistsFolder = app().storageModel.getOldPlaylistsFolder() {
                        // folder links don't link versions yet
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyyMMdd-HHmmss"
                            var newname = playlistNode!.name;
                            if (newname == nil) { newname = "playlist.playlist"; }
                            if newname!.hasSuffix(".playlist") {
                                newname!.removeSubrange((newname?.lastIndex(where: {$0 == "."})! ?? newname!.endIndex) ..< newname!.endIndex);
                            }
                            newname! += ".old." + formatter.string(from: Date()) + ".playlist";
                            
                            mega().move(playlistNode!, newParent: oldPlaylistsFolder, newName: newname!)
                        }
                        else
                        {
                            reportMessage(uic: self, message: "Creating old-versions folder, as creating file versions through writable folder links doesn't work yet.  Until that works, the old version of the playlist will be put in that folder with a timestamp from when it was replaced.  Please retry, the folder should be created by now.");
                            return;
                        }
                    }

                    startSpinnerControl(message: "Uploading Playlist");
                    
                    mega().startUploadToFile(withLocalPath: updateFilePath, parent: parentFolder, filename:playlistNode!.name,
                         delegate: self);
                }
            }
        
            adjustControls();
        }
    }
    
    @IBAction func onRevertButton() {
        if (playlistNode == nil) { return; }
        if let updateFilePath = app().storageModel.playlistPath(node: playlistNode!, forEditing: true) {
            do {
                try FileManager.default.removeItem(atPath: updateFilePath);
            } catch {
                // etc
            }
            loadPlaylist(node: playlistNode!)
        }
        adjustControls();
    }

    func adjustControls() {
        folderPathLabelCtrl.text = playlistNode == nil ? "<playlist>" : playlistNode!.name;
        
        var edited = false;
        if let editingPath = app().storageModel.playlistPath(node: playlistNode!, forEditing: true) {
            edited = FileManager.default.fileExists(atPath: editingPath);
        }
        saveButton.isEnabled = edited;
        revertButton.isEnabled = edited;
    }
    
    func saveAsEditing() {
        if (playlistNode == nil) { return; }
        let s = app().playQueue.nodeHandleArrayToJSON(optionalExtraFirstNode: nil, array: playlistSongs);
        
        if let editingPath = app().storageModel.playlistPath(node: playlistNode!, forEditing: true) {
            let url = URL(fileURLWithPath: editingPath);
            try! s.write(to: url, atomically: true, encoding: .ascii)
        }
        
        adjustControls();
    }
    
    // MARK: - Table view data source
    
    func loadPlaylist(node: MEGANode)
    {
        playlistNode = node;
        playlistSongs = [];
        let (json, _) = app().storageModel.getPlaylistFileEditedOrNotAsJSON(node);
        if (json != nil)
        {
            if let array = json as? [Any] {
                for object in array {
                    print("array entry");
                    if let attribs = object as? [String : Any] {
                        print("as object");
                        if let handleStr = attribs["h"] {
                            print(handleStr);
                            let node = mega().node(forHandle: MEGASdk.handle(forBase64Handle: handleStr as! String));
                            if (node != nil) {
                                playlistSongs.append(node!);
                            }
                        }
                    }
                }
            }
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

        let node = playlistSongs[indexPath.row];

        let notes : String? = node.customNotes;
        
        let cell = tableView.dequeueReusableCell(withIdentifier: notes == nil || notes! == "" ? "MusicCell" : "MusicCellWithNotes", for: indexPath)

        if let musicCell = cell as? TableViewMusicCell {
            musicCell.populateFromNode(node);
        }
        
        return cell
    }
    
    override func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let node = playlistSongs[indexPath.row];
        let notes : String? = node.customNotes;
        return notes == nil || notes! == "" ? 43.5 : 70;
    }
    
    override func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {

        //if (tableView.isEditing) { return false; }
        

        // long press to show menu for song
        if (indexPath.row < playlistSongs.count)
        {
            let node = playlistSongs[indexPath.row];

            let alert = UIAlertController(title: nil, message: "Song actions", preferredStyle: .alert)
            alert.addAction(menuAction_playNext(node));
            alert.addAction(menuAction_songBrowseTo(node, viewController: self));
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
        if editingStyle == .delete && indexPath.row < app().playQueue.nextSongs.count {
            playlistSongs.remove(at: indexPath.row)
            saveAsEditing();
            redraw()
        }
    }

    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
        if fromIndexPath.row < playlistSongs.count && to.row < playlistSongs.count {
            let item = playlistSongs.remove(at: fromIndexPath.row);
            playlistSongs.insert(item, at: to.row);
            saveAsEditing();
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
