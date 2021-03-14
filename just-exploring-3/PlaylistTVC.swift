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



class PlaylistTVC: UITableViewController {

    @IBOutlet weak var folderPathLabelCtrl: UILabel!

    var playlistSongs : [MEGANode] = [];
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.estimatedRowHeight = 43.5;
        tableView.rowHeight = UITableView.automaticDimension;
        tableView.isEditing = false;
    }

    
    
    override func viewDidAppear(_ animated: Bool) {
        navigationItem.rightBarButtonItem =
            UIBarButtonItem(title: "Playlists", style: .done, target: self, action: #selector(popVC))
    }
    
    @objc func popVC() {
        self.navigationController?.popViewController(animated: true);
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        navigationItem.rightBarButtonItem = nil;
    }
   

    @objc func optionButton() {
        
        let alert = UIAlertController(title: nil, message: "Options", preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Never mind", style: .cancel));
        self.present(alert, animated: false, completion: nil)
    }

    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
    }
    
    // MARK: - Table view data source
    
    func loadPlaylist(node: MEGANode)
    {
        playlistSongs = [];
        if let json = app().storageModel.getDownloadedPlaylistAsJSON(node) {
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

        if (tableView.isEditing) { return false; }
        

        // long press to show menu for song
        if (indexPath.row < app().playQueue.nextSongs.count)
        {
            let node = app().playQueue.nextSongs[indexPath.row];

            let alert = UIAlertController(title: nil, message: "Song actions", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Play next", style: .default, handler:
                { (UIAlertAction) -> () in app().playQueue.moveSongNext(indexPath.row); tableView.reloadData() }));
            
            alert.addAction(UIAlertAction(title: "Play right now", style: .default, handler:
                { (UIAlertAction) -> () in app().playQueue.playRightNow(indexPath.row); tableView.reloadData() }));
            
            alert.addAction(UIAlertAction(title: "Send to bottom", style: .default, handler:
                { (UIAlertAction) -> () in app().playQueue.moveSongLast(indexPath.row); tableView.reloadData() }));
            
            if (node.type != MEGANodeType.file)
            {
                alert.addAction(UIAlertAction(title: "Expand folder", style: .default, handler:
                    { (UIAlertAction) -> () in app().playQueue.expandQueueItem(indexPath.row); tableView.reloadData() }));
            }

            alert.addAction(UIAlertAction(title: "Delete to top", style: .default, handler:
                { (UIAlertAction) -> () in app().playQueue.deleteToTop(indexPath.row); tableView.reloadData() }));
            
            alert.addAction(UIAlertAction(title: "Delete to bottom", style: .default, handler:
                { (UIAlertAction) -> () in app().playQueue.deleteToBottom(indexPath.row); tableView.reloadData() }));
            
            alert.addAction(UIAlertAction(title: "Never mind", style: .cancel));
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
        return indexPath.row > 0;
    }

    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
//        if editingStyle == .delete && indexPath.row < app().playQueue.nextSongs.count {
//            app().playQueue.nextSongs.remove(at: indexPath.row)
//            app().playQueue.onNextSongsEdited(reloadView: true, triggerPlay: false);
//        }
    }

    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
//        if fromIndexPath.row < app().playQueue.nextSongs.count && to.row < app().playQueue.nextSongs.count {
//            let item = app().playQueue.nextSongs.remove(at: fromIndexPath.row);
//            app().playQueue.nextSongs.insert(item, at: to.row);
//            app().playQueue.onNextSongsEdited(reloadView: true, triggerPlay: false);
//        }
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
