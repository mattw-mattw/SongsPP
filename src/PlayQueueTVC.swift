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
    var showHistory : Bool = false;
    
    var playQueue = app().playQueue;

    func clear()
    {
        playQueue.player.replaceCurrentItem(with: nil);
        playQueue.nodeInPlayer = nil;
        playingSongUpdated();
        showHistory = false;
        redraw();
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        
        pvc = AVPlayerViewController();
        pvc?.updatesNowPlayingInfoCenter = false;
        
        //playerPlaceholder.addSubview(pvc!.view);
        //pvc!.view.frame = playerPlaceholder.bounds;
        //topHStack.addArrangedSubview(payingSongImage)
        pvc!.view.frame = CGRect(x: 0, y: 0, width: playerLocationView.frame.width, height: playerLocationView.frame.height);
        
        playerLocationView.addSubview(pvc!.view);
        pvc!.didMove(toParent: self);
        pvc!.player = playQueue.player;

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

    @IBAction func HistoryButtonHit(_ sender: Any) {
        queueButton.setTitleShadowColor(UIColor.clear, for: .normal);
        historyButton.setTitleShadowColor(UIColor.white, for: .normal);
        showHistory = true;
        setOptionModeButtons();
        redraw()
    }
    
    @IBAction func QueueButtonHit(_ sender: Any) {
        queueButton.setTitleShadowColor(UIColor.white, for: .normal);
        historyButton.setTitleShadowColor(UIColor.clear, for: .normal);
        showHistory = false;
        setOptionModeButtons();
        redraw()
    }
    
    func displaySongs() -> [MEGANode]
    {
        return showHistory ? playQueue.playedSongs : playQueue.nextSongs;
    }
    
    func setOptionModeButtons()
    {
        navigationItem.rightBarButtonItem =
              UIBarButtonItem(title: "Option", style: .done, target: self, action: #selector(optionButton))
        navigationItem.leftBarButtonItem =
              UIBarButtonItem(title: "Mode", style: .done, target: self, action: #selector(modeButton))
    }
    
//    override func viewDidAppear(_ animated: Bool) {
//    }
    
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

            let replaceable = playQueue.playerSongIsEphemeral();
            let numStarted = playQueue.downloadAllSongsInQueue(removeAlreadyDownloaded);
            playQueue.onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong: replaceable)

            let alert = UIAlertController(title: "Downloading", message: "Initiated " + String(numStarted) + " downloads (and " + String(app().storageModel.downloadingThumbnail.count) + " thumbnails).", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel));
            self.present(alert, animated: false, completion: nil)
        }
    }

    var nodesChanged: Bool = false;
    
    func nodesChanging(_ node: MEGANode)
    {
        if (replaceNodeIn(node, &playQueue.nextSongs) ||
            replaceNodeIn(node, &playQueue.playedSongs) )
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

    let rearrangeModeCheckbox = ContextMenuCheckbox("Rearrange mode", false);
    let noHistoryModeCheckbox = ContextMenuCheckbox("No-History mode", false);
    
    @objc func optionButton() {
        
        if (showHistory) {
            reportMessage(uic: self, message: "Please switch to Queue instead of History to use this Menu, to be clear about the songs being operated on.");
            return;
        }
        
        let alert = UIAlertController(title: nil, message: "Options", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Download entire queue", style: .default, handler:
            { (UIAlertAction) -> () in self.checkDownloadAll() }));
        
        alert.addAction(UIAlertAction(title: "Shuffle queue", style: .default, handler:
                                        { (UIAlertAction) -> () in self.playQueue.shuffleQueue() }));
        
        alert.addAction(UIAlertAction(title: "Save as playlist", style: .default, handler:
                                        { (UIAlertAction) -> () in self.playQueue.saveAsPlaylist(uic: self) }));

        alert.addAction(UIAlertAction(title: "Never mind", style: .cancel));

        self.present(alert, animated: false, completion: nil)
    }
    
    @objc func modeButton() {
        
        let alert = UIAlertController(title: nil, message: "Mode", preferredStyle: .alert)
        
        alert.addTextField( configurationHandler: { newTextField in
            self.rearrangeModeCheckbox.takeOverTextField(newTextField: newTextField)
        });

        alert.addTextField( configurationHandler: { newTextField in
            self.noHistoryModeCheckbox.takeOverTextField(newTextField: newTextField)
        });
        
        alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { (UIAlertAction) -> Void in

            self.tableView.isEditing = self.rearrangeModeCheckbox.flag;
            
            if (self.playQueue.noHistoryMode != self.noHistoryModeCheckbox.flag) {
                self.playQueue.toggleNoHistoryMode();
                self.historyButton.isHidden = self.playQueue.noHistoryMode;
            }
        }));

        self.present(alert, animated: false, completion: nil)
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
    @IBOutlet var topHStackContent: UIStackView!
    @IBOutlet weak var playingSongImage: UIImageView!
    @IBOutlet weak var playingSongText: UILabel!
    @IBOutlet var playerLocationView: UIView!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);

        if (!showHistory)
        {
            if (playQueue.noHistoryMode_currentTrackIndex >= playQueue.nextSongs.count)
            {
                playQueue.noHistoryMode_currentTrackIndex = 0;
                playQueue.onNextSongsEdited(reloadView: false, triggerPlay: false, canReplacePlayerSong: false)
            }
        }
        
        setOptionModeButtons();
        playingSongUpdated();
        redraw();
    }
    
    func redraw()
    {
        tableView.reloadData();
        updateSongCountLabel();
        historyButton.isHidden = playQueue.noHistoryMode;
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
    
    func GetAppIcon() -> UIImage {
        return UIImage(named: "HighResIcon")!;
    }
    
    func playingSongUpdated()
    {
        playingSongImage.image = nil;
        playingSongText.text = "";
        if let node = playQueue.nodeInPlayer
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
        
        if (playingSongImage.image == nil && playingSongText.text == "")
        {
            playingSongImage.image = GetAppIcon();
            playingSongText.text = "Songs++"
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let node = displaySongs()[indexPath.row];

        let notes : String? = node.customNotes;
        
        let cell = tableView.dequeueReusableCell(withIdentifier: notes == nil || notes! == "" ? "MusicCell" : "MusicCellWithNotes", for: indexPath)

        if let musicCell = cell as? TableViewMusicCell {
            musicCell.populateFromNode(node);

            if (playQueue.noHistoryMode &&
                    indexPath.row == playQueue.noHistoryMode_currentTrackIndex
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
            let node = playQueue.nodeInPlayer;
            if (node != nil) {
                let alert = UIAlertController(title: nil, message: "Song actions", preferredStyle: .alert)
                alert.addAction(menuAction_songInfo(node!, viewController: self));
                alert.addAction(menuAction_songBrowseTo(node!, viewController: self));
                if (app().playlistBrowseFolder != nil && playQueue.isPlayable(node!, orMightContainPlayable: false)) {
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
            let queue = playQueue.playedSongs;
            // long press to show menu for song
            if (indexPath.row < queue.count)
            {
                let node = queue[indexPath.row];

                let alert = UIAlertController(title: nil, message: "Song actions", preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: "Play next", style: .default, handler:
                                                { (UIAlertAction) -> () in self.playQueue.queueSongNext(node: node); tableView.reloadData() }));
                
                alert.addAction(UIAlertAction(title: "Queue song", style: .default, handler:
                                                { (UIAlertAction) -> () in self.playQueue.queueSong(node: node); tableView.reloadData() }));

                alert.addAction(UIAlertAction(title: "Time travel", style: .default, handler:
                                                { (UIAlertAction) -> () in self.playQueue.timeTravel(index: indexPath.row); self.QueueButtonHit(self); tableView.reloadData() }));
                
                alert.addAction(menuAction_songInfo(node, viewController: self));
                alert.addAction(menuAction_songBrowseTo(node, viewController: self));
                alert.addAction(menuAction_neverMind());
                self.present(alert, animated: false, completion: nil)
            }
        }
        else {
            // long press to show menu for song
            if (indexPath.row < playQueue.nextSongs.count)
            {
                let node = playQueue.nextSongs[indexPath.row];

                let alert = UIAlertController(title: nil, message: "Song actions", preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: "Play right now", style: .default, handler: {
                    (UIAlertAction) -> () in self.playQueue.playRightNow(indexPath.row); tableView.reloadData() }));
                
                if (!playQueue.noHistoryMode)
                {
                    alert.addAction(UIAlertAction(title: "Play next", style: .default, handler: {
                        (UIAlertAction) -> () in self.playQueue.moveSongNext(indexPath.row); tableView.reloadData() }));
                
                    alert.addAction(UIAlertAction(title: "Play last", style: .default, handler: {
                        (UIAlertAction) -> () in self.playQueue.moveSongLast(indexPath.row); tableView.reloadData() }));
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
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        if (self.presentedViewController != nil) {
            // it was a tap-hold for menu
            return;
        }

        tableView.deselectRow(at: indexPath, animated: false)
        playQueue.goToTappedRow(indexPath.row)
    }
    
    func UnqueueMenu(_ row: Int)
    {
        let alert = UIAlertController(title: nil, message: "Unqueue actions", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Clear to top", style: .default, handler: {
            (UIAlertAction) -> () in self.playQueue.deleteToTop(row); self.tableView.reloadData() }));
        
        alert.addAction(UIAlertAction(title: "Clear to bottom", style: .default, handler: {
            (UIAlertAction) -> () in self.playQueue.deleteToBottom(row); self.tableView.reloadData() }));
        
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
        return indexPath.row >= 0 && indexPath.row < playQueue.nextSongs.count;
    }

    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete && indexPath.row < playQueue.nextSongs.count {
            let replaceable = playQueue.playerSongIsEphemeral();
            playQueue.nextSongs.remove(at: indexPath.row)
            
            if playQueue.noHistoryMode_currentTrackIndex == indexPath.row {
                playQueue.noHistoryMode_currentTrackIndex = playQueue.nextSongs.count + 100000;
            }
            else if playQueue.noHistoryMode_currentTrackIndex > indexPath.row {
                playQueue.noHistoryMode_currentTrackIndex -= 1;
            }

            playQueue.onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong: replaceable);
        }
    }

    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
        if fromIndexPath.row < playQueue.nextSongs.count && to.row < playQueue.nextSongs.count {
            let replaceable = playQueue.playerSongIsEphemeral();
            let item = playQueue.nextSongs.remove(at: fromIndexPath.row);
            playQueue.nextSongs.insert(item, at: to.row);
            
            if (playQueue.noHistoryMode) {
                if playQueue.noHistoryMode_currentTrackIndex == fromIndexPath.row {
                    playQueue.noHistoryMode_currentTrackIndex = to.row;
                } else {
                    if playQueue.noHistoryMode_currentTrackIndex > fromIndexPath.row { playQueue.noHistoryMode_currentTrackIndex -= 1; }
                    if playQueue.noHistoryMode_currentTrackIndex >= to.row { playQueue.noHistoryMode_currentTrackIndex += 1; }
                }
            }
            playQueue.onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong: replaceable);
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
