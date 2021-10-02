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
//    var headerControl : UISegmentedControl? = nil;
    //var audioSession = AVAudioSession.sharedInstance()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        
        pvc = AVPlayerViewController();
        pvc?.updatesNowPlayingInfoCenter = false;
        
        //playerPlaceholder.addSubview(pvc!.view);
        //pvc!.view.frame = playerPlaceholder.bounds;
        //topHStack.addArrangedSubview(payingSongImage)
        topHStack.addArrangedSubview(pvc!.view)
        
        pvc!.player = app().playQueue.player;
        app().playQueueTVC = self;
        tableView.estimatedRowHeight = 43.5;
        tableView.rowHeight = UITableView.automaticDimension;
        tableView.isEditing = false;
        
//        segmentedControl.addTarget(self, action: #selector(segmentedIndexChanged(_:)), for: .valueChanged)

        //try! self.audioSession.setCategory(AVAudioSession.Category.playback)
        //try! self.audioSession.setActive(true)

        //UIApplication.shared.beginReceivingRemoteControlEvents()
        //self.becomeFirstResponder()
        
        let longPressGR1 = UILongPressGestureRecognizer(target: self, action: #selector(playingItemMenu(press:)));
        let longPressGR2 = UILongPressGestureRecognizer(target: self, action: #selector(playingItemMenu(press:)));
        //longPressGR.minimumPressDuration = 2.0;
        playingSongImage.addGestureRecognizer(longPressGR1);
        playingSongImage.isUserInteractionEnabled = true;
        playingSongText.addGestureRecognizer(longPressGR2);
        playingSongText.isUserInteractionEnabled = true;
        
//        tabBarContoller!.viewControllers?.forEach { let _ = $0.view }
//        let _ = app().tabBarContoller!.viewControllers![1].view;


    }

    @IBOutlet weak var songLabel : UILabel!;
    
    @IBOutlet weak var historyButton: UIButton!
    @IBOutlet weak var queueButton: UIButton!
    var showHistory : Bool = false;

    @IBAction func HistoryButtonHit(_ sender: Any) {
        queueButton.setTitleShadowColor(UIColor.clear, for: .normal);
        historyButton.setTitleShadowColor(UIColor.white, for: .normal);
        showHistory = true;
        setOptionButton(history: showHistory)
        redraw()
    }
    
    @IBAction func QueueButtonHit(_ sender: Any) {
        queueButton.setTitleShadowColor(UIColor.white, for: .normal);
        historyButton.setTitleShadowColor(UIColor.clear, for: .normal);
        showHistory = false;
        setOptionButton(history: showHistory)
        redraw()
    }
    
    func displaySongs() -> [MEGANode]
    {
        return showHistory ? app().playQueue.playedSongs : app().playQueue.nextSongs;
    }
    
    func setOptionButton(history : Bool)
    {
        navigationItem.rightBarButtonItem = history ? nil :
              UIBarButtonItem(title: "Option", style: .done, target: self, action: #selector(optionButton))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        setOptionButton(history: showHistory)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        app().tabBarContoller!.navigationItem.rightBarButtonItem = nil;
    }
    
    func checkDownloadAll()
    {
        let alert = UIAlertController(title: "Download Info", message: "This function will start downloading everything not yet already downloaded, or already downloading, in the current queue as quickly as it can.  For a large number of files, it's best to be on wifi and plugged into a power source (for decryption) before starting this operation.", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Start downloads", style: .default, handler:
                { (UIAlertAction) -> () in self.downloadAll(false) }));
        
        alert.addAction(UIAlertAction(title: "Remove already downloaded from the queue first", style: .default, handler:
                { (UIAlertAction) -> () in self.downloadAll(true) }));
        
        alert.addAction(UIAlertAction(title: "Never mind", style: .cancel));
        
        self.present(alert, animated: false, completion: nil)
    }
    
    func downloadAll(_ removeAlreadyDownloaded : Bool)
    {
        if (CheckOnlineOrWarn("Please go online before activating downloads.", uic: self)) {

            let replaceable = app().playQueue.playerSongIsEphemeral();
            let numStarted = app().playQueue.downloadAllSongsInQueue(removeAlreadyDownloaded);
            app().playQueue.onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong: replaceable)

            let alert = UIAlertController(title: "Downloading", message: "Initiated " + String(numStarted) + " downloads (and " + String(app().storageModel.downloadingThumbnail.count) + " thumbnails).", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel));
            self.present(alert, animated: false, completion: nil)
        }
    }

    var nodesChanged: Bool = false;
    
    func nodesChanging(_ node: MEGANode)
    {
        if (replaceNodeIn(node, &app().playQueue.nextSongs) ||
            replaceNodeIn(node, &app().playQueue.playedSongs) )
        {
            nodesChanged = true;
        }
    }
    func nodesFinishedChanging()
    {
        if (nodesChanged)
        {
            redraw();
            nodesChanged = false;
        }
    }

    @objc func optionButton() {
        
        if (showHistory) { return; }
        
        let alert = UIAlertController(title: nil, message: "Options", preferredStyle: .alert)
//        let b = app().playQueue.downloadNextOnly;
        
        alert.addAction(UIAlertAction(title: "Download entire queue", style: .default, handler:
            { (UIAlertAction) -> () in self.checkDownloadAll() }));
        
        alert.addAction(UIAlertAction(title: "Shuffle queue", style: .default, handler:
            { (UIAlertAction) -> () in app().playQueue.shuffleQueue() }));
        
        alert.addAction(UIAlertAction(title: "Expand all", style: .default, handler:
            { (UIAlertAction) -> () in app().playQueue.expandAll() }));
        
        alert.addAction(UIAlertAction(title: tableView.isEditing ? "Disable Rearrange" : "Enable Rearrange", style: .default, handler:
            { (UIAlertAction) -> () in self.tableView.isEditing.toggle() }));

        alert.addAction(UIAlertAction(title: "Save as playlist", style: .default, handler:
            { (UIAlertAction) -> () in app().playQueue.saveAsPlaylist() }));

        alert.addAction(UIAlertAction(title: app().playQueue.noHistoryMode ? "Disable no-history mode" : "Enable no-history mode", style: .default, handler:
            { (UIAlertAction) -> () in  self.toggleNoHistoryMode() }));

        alert.addAction(UIAlertAction(title: "Never mind", style: .cancel));
        self.present(alert, animated: false, completion: nil)
    }

   func toggleNoHistoryMode()
   {
        app().playQueue.toggleNoHistoryMode();
        historyButton.isHidden = app().playQueue.noHistoryMode;
   }
    
    func editSong(node : MEGANode?) {
        let vc = self.storyboard?.instantiateViewController(identifier: "EditSongVC") as! EditSongVC
        vc.node = node;
        self.navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Table view data source

    @IBOutlet weak var playerPlaceholder: UIView!
    @IBOutlet weak var songCountLabel : UILabel!;
//    @IBOutlet weak var segmentedControl : UISegmentedControl!;
    @IBOutlet weak var topHStack: UIStackView!
    @IBOutlet weak var playingSongImage: UIImageView!
    @IBOutlet weak var playingSongText: UILabel!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        redraw();
    }
    
    func redraw()
    {
        tableView.reloadData();
        updateSongCountLabel();
        historyButton.isHidden = app().playQueue.noHistoryMode;
    }
    
    func updateSongCountLabel()
    {
        var sum = 0;
        for n in displaySongs() {
            if (n.duration > 0) { sum += n.duration; }
        }
        songCountLabel.text = String(format: "%d Songs %02d:%02d:%02d", displaySongs().count, sum/3600, (sum/60)%60, sum%60)
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
    
    func playingSongUpdated()
    {
        playingSongImage.image = nil;
        playingSongText.text = "";
        if let node = app().playQueue.nodeInPlayer
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

            var text : String? = node.customTitle;
            if (text == nil) { text = node.name; }
            let artist : String? = node.customArtist;
            if (artist != nil) { text! += "\n" + artist! }
            playingSongText.text = text!;
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let node = displaySongs()[indexPath.row];

        let notes : String? = node.customNotes;
        
        let cell = tableView.dequeueReusableCell(withIdentifier: notes == nil || notes! == "" ? "MusicCell" : "MusicCellWithNotes", for: indexPath)

        if let musicCell = cell as? TableViewMusicCell {
            musicCell.populateFromNode(node);

            if (app().playQueue.noHistoryMode &&
                    indexPath.row == app().playQueue.noHistoryMode_currentTrackIndex
                    && musicCell.isPlayingIndicator_noHistory != nil)
            {
                musicCell.isPlayingIndicator_noHistory!.isHidden = false;
            }
        }
        
        return cell
    }
    
    override func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let node = displaySongs()[indexPath.row];
        let notes : String? = node.customNotes;
        return notes == nil || notes! == "" ? 43.5 : 70;
    }
    
    func downloadProgress(fingerprint : String, percent : NSNumber )
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
                        if musicCell!.node!.fingerprint != nil && musicCell!.node!.fingerprint! == fingerprint
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

    @objc func playingItemMenu(press : UILongPressGestureRecognizer)
    {
        if press.state == .began {
            let node = app().playQueue.nodeInPlayer;
            if (node != nil) {
                let alert = UIAlertController(title: nil, message: "Song actions", preferredStyle: .alert)
                alert.addAction(menuAction_songInfo(node!, viewController: self));
                alert.addAction(menuAction_songBrowseTo(node!, viewController: self));
                if (app().playlistBrowseFolder != nil && app().playQueue.isPlayable(node!, orMightContainPlayable: false)) {
                    alert.addAction(menuAction_addToPlaylistInFolder_recents(node!, viewController: self));
                }
                alert.addAction(menuAction_neverMind());
                self.present(alert, animated: false, completion: nil)
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
                    { (UIAlertAction) -> () in app().playQueue.timeTravel(index: indexPath.row); self.QueueButtonHit(self); tableView.reloadData() }));
                
                alert.addAction(menuAction_songInfo(node, viewController: self));
                alert.addAction(menuAction_songBrowseTo(node, viewController: self));
                alert.addAction(menuAction_neverMind());
                self.present(alert, animated: false, completion: nil)
            }
        }
        else {
            // long press to show menu for song
            if (indexPath.row < app().playQueue.nextSongs.count)
            {
                let node = app().playQueue.nextSongs[indexPath.row];

                let alert = UIAlertController(title: nil, message: "Song actions", preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: "Play right now", style: .default, handler:
                    { (UIAlertAction) -> () in app().playQueue.playRightNow(indexPath.row); tableView.reloadData() }));
                
                alert.addAction(UIAlertAction(title: "Play next", style: .default, handler:
                    { (UIAlertAction) -> () in app().playQueue.moveSongNext(indexPath.row); tableView.reloadData() }));
                
                alert.addAction(UIAlertAction(title: "Play last", style: .default, handler:
                    { (UIAlertAction) -> () in app().playQueue.moveSongLast(indexPath.row); tableView.reloadData() }));
                
                if (node.type != MEGANodeType.file)
                {
                    alert.addAction(UIAlertAction(title: "Expand folder", style: .default, handler:
                        { (UIAlertAction) -> () in app().playQueue.expandQueueItem(indexPath.row); tableView.reloadData() }));
                }

                if (node.type == MEGANodeType.file && node.name.hasSuffix(".playlist"))
                {
                    alert.addAction(UIAlertAction(title: "Expand playlist", style: .default, handler:
                        { (UIAlertAction) -> () in app().playQueue.expandQueueItem(indexPath.row); tableView.reloadData() }));
                }

                alert.addAction(UIAlertAction(title: "Unqueue...", style: .default, handler:
                                                { (UIAlertAction) -> () in self.UnqueueMenu(indexPath.row) }));
                
                alert.addAction(menuAction_songInfo(node, viewController: self));
                alert.addAction(menuAction_songBrowseTo(node, viewController: self));
                alert.addAction(menuAction_neverMind());
                self.present(alert, animated: false, completion: nil)
            }
        }
        
        return false;
    }
    
    func UnqueueMenu(_ row: Int)
    {
        let alert = UIAlertController(title: nil, message: "Unqueue actions", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Unqueue to top (inclusive)", style: .default, handler:
            { (UIAlertAction) -> () in app().playQueue.deleteToTop(row); self.tableView.reloadData() }));
        
        if (row >= 1) {
            alert.addAction(UIAlertAction(title: "Unqueue to top (exclusive)", style: .default, handler:
                { (UIAlertAction) -> () in app().playQueue.deleteToTop(row - 1); self.tableView.reloadData() }));
        }
        
        alert.addAction(UIAlertAction(title: "Unqueue to bottom (inclusive)", style: .default, handler:
            { (UIAlertAction) -> () in app().playQueue.deleteToBottom(row); self.tableView.reloadData() }));
        
        if (row + 1 < app().playQueue.nextSongs.count) {
            alert.addAction(UIAlertAction(title: "Unqueue to bottom (exclusive)", style: .default, handler:
            { (UIAlertAction) -> () in app().playQueue.deleteToBottom(row + 1); self.tableView.reloadData() }));
        }
        
        alert.addAction(UIAlertAction(title: "Never mind", style: .cancel));
        self.present(alert, animated: false, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return true;
    }
    
    override func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
    }

    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return indexPath.row >= 0 && indexPath.row < app().playQueue.nextSongs.count;
    }

    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete && indexPath.row < app().playQueue.nextSongs.count {
            let replaceable = app().playQueue.playerSongIsEphemeral();
            app().playQueue.nextSongs.remove(at: indexPath.row)
            app().playQueue.onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong: replaceable);
        }
    }

    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
        if fromIndexPath.row < app().playQueue.nextSongs.count && to.row < app().playQueue.nextSongs.count {
            let replaceable = app().playQueue.playerSongIsEphemeral();
            let item = app().playQueue.nextSongs.remove(at: fromIndexPath.row);
            app().playQueue.nextSongs.insert(item, at: to.row);
            app().playQueue.onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong: replaceable);
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
