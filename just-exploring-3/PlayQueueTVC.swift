//
//  PlayQueueTVC.swift
//  just-exploring-3
//
//  Created by Admin on 28/10/2019.
//  Copyright © 2019 mattweir. All rights reserved.
//

import Foundation
import UIKit
import AVKit

class PlayQueueTVC: UITableViewController {

    var pvc : AVPlayerViewController? = nil;
    var headerControl : UISegmentedControl? = nil;
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
 //       self.navigationItem.rightBarButtonItem = self.editButtonItem
//            UIBarButtonItem(title: "Option", style: .done, target: self, action: #selector(optionButton))
        
        pvc = AVPlayerViewController();
        playerPlaceholder.addSubview(pvc!.view);
        pvc!.view.frame = playerPlaceholder.bounds;
        pvc!.player = app().playQueue.player;
        app().playQueueTVC = self;
        tableView.estimatedSectionHeaderHeight = 40;
        tableView.isEditing = false;
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if (app().tabBarContoller != nil) {
            app().tabBarContoller!.navigationItem.rightBarButtonItem =
                  UIBarButtonItem(title: "Option", style: .done, target: self, action: #selector(optionButton))
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        if (app().tabBarContoller != nil) {
            app().tabBarContoller!.navigationItem.rightBarButtonItem = nil;
        }
    }
   
    @objc func optionButton() {
        
        let alert = UIAlertController(title: nil, message: "Options", preferredStyle: .alert)
        let b = app().playQueue.downloadNextOnly;
        
        alert.addAction(UIAlertAction(title: b ? "Download entire queue" : "Download next only", style: .default, handler:
            { (UIAlertAction) -> () in app().playQueue.downloadNextOnly.toggle() ; app().playQueue.onNextSongsEdited(reloadView: true) }));
        
        alert.addAction(UIAlertAction(title: "Shuffle queue", style: .default, handler:
            { (UIAlertAction) -> () in app().playQueue.shuffleQueue() }));
        
        alert.addAction(UIAlertAction(title: "Expand all", style: .default, handler:
            { (UIAlertAction) -> () in app().playQueue.expandAll() }));
        
        alert.addAction(UIAlertAction(title: tableView.isEditing ? "Disable Edit" : "Enable Edit", style: .default, handler:
            { (UIAlertAction) -> () in self.tableView.isEditing.toggle() }));

        alert.addAction(UIAlertAction(title: "Never mind", style: .cancel));
        self.present(alert, animated: false, completion: nil)
    }

    // MARK: - Table view data source

    @IBOutlet weak var playerPlaceholder: UIView!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        
        tableView.reloadData();
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return app().playQueue.nextSongs.count;
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if (headerControl == nil)
        {
            headerControl = UISegmentedControl(frame: CGRect(x: 10, y:5, width: tableView.frame.width - 20, height: 30));
            headerControl!.insertSegment(withTitle: "<<", at: 0, animated: false);
            headerControl!.insertSegment(withTitle: "<Current>", at: 1, animated: false);
            headerControl!.insertSegment(withTitle: ">>", at: 2, animated: false);
        }
        return headerControl!;
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MusicCell", for: indexPath)
        
        cell.textLabel?.text = app().playQueue.nextSongs[indexPath.row].name
        
        let musicCell = cell as? TableViewMusicCell
        if (musicCell != nil)
        {
            musicCell!.node = app().playQueue.nextSongs[indexPath.row];
            
            let exists = app().storageModel.fileDownloaded(musicCell!.node!);
            
            if (musicCell!.progressBar != nil)
            {
                musicCell!.contentView.bringSubviewToFront(musicCell!.progressBar!);
                
                musicCell!.progressBar!.isHidden = !exists;
                musicCell!.progressBar!.progress = exists ? 100 : 0;
                musicCell!.progressBar!.setNeedsDisplay();
            }
        }
        
        return cell
    }
    
    func downloadProgress(_ nodeHandle : UInt64, _ percent : NSNumber )
    {
        let vc = tableView.visibleCells;
        for cell in vc
        {
            let musicCell = cell as? TableViewMusicCell
            if (musicCell != nil)
            {
                if musicCell!.node != nil
                {
                    if musicCell!.progressBar != nil
                    {
                        if musicCell!.node!.handle == nodeHandle
                        {
                            musicCell!.progressBar!.isHidden = false;
                            musicCell!.progressBar!.progress = percent.floatValue;
                            musicCell!.progressBar!.setNeedsDisplay();
                        }
                    }
                }
            }
        }
    }

    override func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {

        if (tableView.isEditing) { return false; }
        
        let queue = app().playQueue.nextSongs;
        // long press to show menu for song
        if (indexPath.row < queue.count)
        {
            let node = queue[indexPath.row];

            let alert = UIAlertController(title: nil, message: "Song actions", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Delete to top", style: .default, handler:
                { (UIAlertAction) -> () in app().playQueue.deleteToTop(indexPath.row); tableView.reloadData() }));
            
            alert.addAction(UIAlertAction(title: "Delete to bottom", style: .default, handler:
                { (UIAlertAction) -> () in app().playQueue.deleteToBottom(indexPath.row); tableView.reloadData() }));
            
            alert.addAction(UIAlertAction(title: "Play next", style: .default, handler:
                { (UIAlertAction) -> () in app().playQueue.moveSongNext(indexPath.row); tableView.reloadData() }));
            
            alert.addAction(UIAlertAction(title: "Play right now", style: .default, handler:
                { (UIAlertAction) -> () in app().playQueue.playRightNow(indexPath.row); tableView.reloadData() }));
            
            if (node.type != MEGANodeType.file)
            {
                alert.addAction(UIAlertAction(title: "Expand folder", style: .default, handler:
                    { (UIAlertAction) -> () in app().playQueue.expandQueueItem(indexPath.row); tableView.reloadData() }));
            }
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
        if editingStyle == .delete {
            app().playQueue.nextSongs.remove(at: indexPath.row)
            app().playQueue.onNextSongsEdited(reloadView: true);
        }
    }

    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
        let item = app().playQueue.nextSongs.remove(at: fromIndexPath.row);
        app().playQueue.nextSongs.insert(item, at: to.row);
        app().playQueue.onNextSongsEdited(reloadView: true);
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
