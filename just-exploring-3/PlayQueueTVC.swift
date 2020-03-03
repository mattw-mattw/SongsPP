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
    //var audioSession = AVAudioSession.sharedInstance()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
 //       self.navigationItem.rightBarButtonItem = self.editButtonItem
//            UIBarButtonItem(title: "Option", style: .done, target: self, action: #selector(optionButton))
        
        pvc = AVPlayerViewController();
        pvc?.updatesNowPlayingInfoCenter = false;
        
        //playerPlaceholder.addSubview(pvc!.view);
        //pvc!.view.frame = playerPlaceholder.bounds;
        //topHStack.addArrangedSubview(payingSongImage)
        topHStack.addArrangedSubview(pvc!.view)
        
        pvc!.player = app().playQueue.player;
        app().playQueueTVC = self;
        //tableView.estimatedSectionHeaderHeight = 40;
        tableView.isEditing = false;
        
        segmentedControl.addTarget(self, action: #selector(segmentedIndexChanged(_:)), for: .valueChanged)

        //try! self.audioSession.setCategory(AVAudioSession.Category.playback)
        //try! self.audioSession.setActive(true)

        //UIApplication.shared.beginReceivingRemoteControlEvents()
        //self.becomeFirstResponder()
        
    }

    var showHistory : Bool = false;
    
    @objc func segmentedIndexChanged(_ value : Int) {
        showHistory = segmentedControl.selectedSegmentIndex == 1;
        tableView.reloadData();
    }
    
    func displaySongs() -> [MEGANode]
    {
        return showHistory ? app().playQueue.playedSongs : app().playQueue.nextSongs;
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

        alert.addAction(UIAlertAction(title: "Save as playlist", style: .default, handler:
            { (UIAlertAction) -> () in app().playQueue.saveAsPlaylist() }));

        alert.addAction(UIAlertAction(title: "Never mind", style: .cancel));
        self.present(alert, animated: false, completion: nil)
    }

    // MARK: - Table view data source

    @IBOutlet weak var playerPlaceholder: UIView!
    @IBOutlet weak var songCountLabel : UILabel!;
    @IBOutlet weak var segmentedControl : UISegmentedControl!;
    @IBOutlet weak var topHStack: UIStackView!
    @IBOutlet weak var playingSongImage: UIImageView!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        redraw();
    }
    
    func redraw()
    {
        tableView.reloadData();
        updateSongCountLabel();
    }
    
    func updateSongCountLabel()
    {
        var sum = 0;
        for n in displaySongs() {
            if (n.duration > 0) { sum += n.duration; }
        }
        songCountLabel.text = String(format: "%d Songs %02d:%02d:%02d", app().playQueue.nextSongs.count, sum/3600, (sum/60)%60, sum%60)
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return displaySongs().count;
    }
    
//    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
////        if (headerControl == nil)
////        {
////            headerControl = UISegmentedControl(frame: CGRect(x: 10, y:5, width: tableView.frame.width - 20, height: 30));
////            headerControl!.insertSegment(withTitle: "<<", at: 0, animated: false);
////            headerControl!.insertSegment(withTitle: "<Current>", at: 1, animated: false);
////            headerControl!.insertSegment(withTitle: ">>", at: 2, animated: false);
////        }
////        return headerControl!;
//        return nil;
//    }
    
    func playingSongUpdated(nodeMaybe: MEGANode?)
    {
        playingSongImage.image = nil;
        if let node = nodeMaybe
        {
            if (node.hasThumbnail())
            {
                if (app().storageModel.thumbnailDownloaded(node)) {
                    if let path = app().storageModel.thumbnailPath(node: node) {
                        if let image = UIImage(contentsOfFile: path) {
                            playingSongImage.image = image;
                        }
                    }
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MusicCell", for: indexPath)
        if let musicCell = cell as? TableViewMusicCell {

        let node = displaySongs()[indexPath.row];
        
//        cell.textLabel?.numberOfLines = 0;
//        cell.textLabel?.lineBreakMode = .byWordWrapping;
        
        var title : String? = node.customTitle;
        if (title == nil) { title = node.name; }
        var bpm : String? = node.customBPM;
        if (bpm == nil) { bpm = ""; }
        var artist : String? = node.customArtist;
        if (artist == nil) { artist = "" }
        
        musicCell.durationLabel.text = String(format: "%02d:%02d", node.duration / 60, node.duration % 60)
        musicCell.titleLabel.text = title!;
        musicCell.bpmLabel.text = bpm!;
        musicCell.artistLabel.text = artist!;
        
        musicCell.thumbnailView.image = nil;
        if (node.hasThumbnail())
        {
            if (app().storageModel.thumbnailDownloaded(node)) {
                if let path = app().storageModel.thumbnailPath(node: node) {
                    if let image = UIImage(contentsOfFile: path) {
                        
                        //cell.imageView!.frame = CGRect(x: cell.imageView!.frame.origin.x
                        //ycell.imageView!.frame.origin.y,width: 40, height: 40)
                        //cell.imageView!.autoresizingMask = [.flexibleWidth]
                        //cell.imageView!.translatesAutoresizingMaskIntoConstraints = true;
                        //cell.imageView!.contentMode = .;
                        musicCell.thumbnailView.image = image;
                    }
                }
            }
        }
        
        musicCell.node = displaySongs()[indexPath.row];
        
        let exists = app().storageModel.fileDownloaded(musicCell.node!);
        
        if (musicCell.progressBar != nil)
        {
            musicCell.contentView.bringSubviewToFront(musicCell.progressBar);
            
            musicCell.progressBar.isHidden = !exists;
            musicCell.progressBar.progress = exists ? 100 : 0;
            musicCell.progressBar.setNeedsDisplay();
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
        
        if (showHistory) {
            let queue = app().playQueue.playedSongs;
            // long press to show menu for song
            if (indexPath.row < queue.count)
            {
                let node = queue[indexPath.row];

                let alert = UIAlertController(title: nil, message: "Song actions", preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: "Play next", style: .default, handler:
                    { (UIAlertAction) -> () in app().playQueue.queueSongNext(node: node); tableView.reloadData() }));
                
                alert.addAction(UIAlertAction(title: "Queue song", style: .default, handler:
                    { (UIAlertAction) -> () in app().playQueue.queueSong(node: node); tableView.reloadData() }));

                alert.addAction(UIAlertAction(title: "Time travel", style: .default, handler:
                    { (UIAlertAction) -> () in app().playQueue.timeTravel(index: indexPath.row); tableView.reloadData() }));

                alert.addAction(UIAlertAction(title: "Never mind", style: .cancel));
                self.present(alert, animated: false, completion: nil)
            }
        }
        else {
            let queue = app().playQueue.nextSongs;
            // long press to show menu for song
            if (indexPath.row < queue.count)
            {
                let node = queue[indexPath.row];

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
