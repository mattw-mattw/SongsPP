//
//  PlayQueueModel.swift
//  SongMe
//
//  Created by Matt Weir on 4/01/20.
//  Copyright © 2020 mattweir. All rights reserved.
//

import Foundation
import MediaPlayer

class BrowseNode /*: ObservableObject*/ {
    /*@Published*/ var node : MEGANode? = nil;
    /*@Published*/ var subnodes : [ MEGANode ] = [];
    /*@Published*/ var path : String = "";
    var root : MEGANode? = nil;

    func load(_ n : MEGANode?)
    {
        var newPath : String = ""
        var array : [MEGANode] = []
        if (n != nil)
        {
            if (n!.isFile()) { return; }
            let children = mega().children(forParent: n!)
            for i in 0..<children.size.intValue {
                array.append(children.node(at: i))
            }
            newPath = app().nodePath(n!)
        }
        node = n;
        subnodes = array;
        path = newPath;
    }
    
    func loadParent()
    {
        if (node != nil && node != root)
        {
            let n = mega().parentNode(for: node!)
            if (n != nil)
            {
                load(n)
            }
        }
    }
}

class PlayQueue : NSObject, UITextFieldDelegate {

    // permanent items
    var player : AVPlayer = AVPlayer();
    var timeObservation : Any? = nil;

    // things to reset
    var nextSongs : [MEGANode] = [];
    var playedSongs : [MEGANode] = [];
    var currentTimeString = "0:00"
    var nodeInPlayer : MEGANode? = nil;
    var nodeInPlayerStarted : Bool = false;
    var isPlaying : Bool = false;
    var shouldBePlaying : Bool = false;
    
    var noHistoryMode : Bool = false;
    var noHistoryMode_currentTrackIndex : Int = 0;

    func clear()
    {
        player.replaceCurrentItem(with: nil);
        nodeInPlayer = nil;
        nodeInPlayerStarted = false;
        isPlaying = false;
        shouldBePlaying = false;
        currentTimeString = "0:00"
        nextSongs = [];
        playedSongs = [];
    }

    override init() {
        super.init()
        player.addObserver(self, forKeyPath: "rate", options: NSKeyValueObservingOptions.new, context: nil)
    }

    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "rate" {
            isPlaying = player.rate > 0;
            if (isPlaying && !nodeInPlayerStarted)
            {
                nodeInPlayerStarted = true;
                
                if (!noHistoryMode && nodeInPlayer != nil &&
                    nextSongs.count > 0 && nextSongs[0].handle == nodeInPlayer!.handle)
                {
                    nextSongs.remove(at: 0)
                    onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong: false);
                }
            }
        }
    }
    func StringTime(_ nn : Double) -> String
    {
        let n = nn + 0.5
        let mins = Int(n / 60)
        let secs = Int(n) - (mins*60)
        return String(format: "%d:%02d", mins, secs)
    }

    func queueSong(node : MEGANode)
    {
        queueSongs(nodes: [node]);
    }
    
    func queueSongs(nodes : [MEGANode])
    {
        if (timeObservation == nil)
        {
            timeObservation = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: nil) { [weak self] time in
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1)) {
                    guard let self = self else { return }
                    if let ci = self.player.currentItem {
  //                      self.currentTime = ci.currentTime()
  //                      self.duration = ci.duration
  //                      self.sliderPos = self.duration.seconds == 0 ? 0 : self.currentTime.seconds / self.duration.seconds
                        self.currentTimeString = self.StringTime(ci.currentTime().seconds)
  //                      self.durationString = self.StringTime(self.duration.seconds)
                    }
                }
            }
        }
        
        let replaceable = playerSongIsEphemeral();
        var playableNodes = nodes;
        var i: Int = 0;
        while (i < playableNodes.count) {
            if isPlayable(playableNodes[i], orMightContainPlayable: true) {
                i += 1;
            }
            else {
                playableNodes.remove(at: i);
            }
        }
        nextSongs += playableNodes;
        onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong: replaceable);
    }
    
    func queueSongNext(node : MEGANode)
    {
        if isPlayable(node, orMightContainPlayable: true) {
            let replaceable = playerSongIsEphemeral();
            nextSongs.insert(node, at: 0);
            onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong: replaceable);
        }
    }

    func addSongNext(_ node: MEGANode)
    {
        let replaceable = playerSongIsEphemeral();

        var v : [MEGANode] = [];
        app().storageModel.loadSongsFromNodeRecursive(node: node, &v);

        nextSongs.insert(contentsOf: v, at: 0);
        
        onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong: replaceable);
    }

    func moveSongNext(_ row: Int)
    {
        if row < nextSongs.count
        {
            let node = nextSongs[row];
            nextSongs.remove(at: row);
            addSongNext(node);
        }
    }
    
    func addSongLast(_ node: MEGANode)
    {
        let replaceable = playerSongIsEphemeral();
        
        var v : [MEGANode] = [];
        app().storageModel.loadSongsFromNodeRecursive(node: node, &v);
        nextSongs.insert(contentsOf: v, at: nextSongs.count);
        
        onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong: replaceable);
    }
    
    func moveSongLast(_ row: Int)
    {
        if row < nextSongs.count
        {
            let node = nextSongs[row];
            nextSongs.remove(at: row);
            addSongLast(node);
        }
    }
    
    func shuffleQueue()
    {
        let replaceable = playerSongIsEphemeral();

        nextSongs = shuffleArray(&nextSongs);
       
        onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong: replaceable)
    }
    
    func deleteToTop(_ row: Int)
    {
        let replaceable = playerSongIsEphemeral();
        for _ in 0...row
        {
            if (0 < nextSongs.count)
            {
                nextSongs.remove(at: 0);
            }
        }
        
        if noHistoryMode_currentTrackIndex <= row {
            noHistoryMode_currentTrackIndex = nextSongs.count + 100000;
        }
        
        onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong: replaceable);
    }

    func deleteToBottom(_ row: Int)
    {
        let replaceable = playerSongIsEphemeral();
        while row < nextSongs.count
        {
            nextSongs.remove(at: row);
        }
        
        if noHistoryMode_currentTrackIndex >= row {
            noHistoryMode_currentTrackIndex = nextSongs.count + 100000;
        }
        
        onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong: replaceable);
    }
    
    func playRightNow(_ node: MEGANode)
    {
        let replaceable = playerSongIsEphemeral();
        nextSongs.insert(node, at: 0);
        onNextSongsEdited(reloadView: true, triggerPlay: true, canReplacePlayerSong: replaceable);
    }

    func playRightNow(_ row: Int)
    {
        if (noHistoryMode)
        {
            noHistoryMode_currentTrackIndex = row;
            onNextSongsEdited(reloadView: true, triggerPlay: true, canReplacePlayerSong: true);
        }
        else if row < nextSongs.count
        {
            let node = nextSongs[row];
            nextSongs.remove(at: row);
            playRightNow(node);
        }
    }

//    func expandPlaylist(_ row: Int)
//    {
//        var newrow = row+1;
//        let (json, _) = app().storageModel.getPlaylistFileEditedOrNotAsJSON(nextSongs[row])
//        if (json != nil) {
//            if let array = json as? [Any] {
//                for object in array {
//                    print("array entry");
//                    if let attribs = object as? [String : Any] {
//                        print("as object");
//                        if let handleStr = attribs["h"] {
//                            print(handleStr);
//                            let node = mega().node(forHandle: MEGASdk.handle(forBase64Handle: handleStr as! String));
//                            if (node != nil) {
//                                nextSongs.insert(node!, at: newrow);
//                                newrow += 1;
//                            }
//                        }
//                    }
//                }
//            }
//        }
//        nextSongs.remove(at: row);
//    }
    
    let playableExtensions = [ ".mp3", ".m4a", ".aac", ".wav", ".flac", ".aiff", ".au", ".pcm", ".ac3", ".aa", ".aax"];
    let artworkExtensions = [ ".jpg", ".png" ];
    
    func isPlayable(_ n : MEGANode, orMightContainPlayable : Bool) -> Bool
    {
        if orMightContainPlayable {
            if (n.isFile() && n.name.hasSuffix(".playlist")) { return true; }
            if (n.isFolder()) { return true; }
        }
        if (n.isFile()) {
            let name = n.name.lowercased();
            for ext in playableExtensions {
                if name.hasSuffix(ext) { return true; }
            }
        }
        return false;
    }

    func isArtwork(_ n : MEGANode) -> Bool
    {
        if (n.isFile()) {
            let name = n.name.lowercased()
            for ext in artworkExtensions {
                if name.hasSuffix(ext) { return true; }
            }
        }
        return false;
    }

//    func expandAll()
//    {
//        let replaceable = playerSongIsEphemeral();
//        var expanded = false
//        var row : Int = 0;
//        while (row < nextSongs.count)
//        {
//            if (isExpandable(node: nextSongs[row])) {
//                expandQueueItem(row);
//                expanded = true;
//            }
//            else {
//                row += 1;
//            }
//        }
//        if expanded { onNextSongsEdited(reloadView : true, triggerPlay: false, canReplacePlayerSong: replaceable) }
//    }
//
//    func expandQueueItem(_ row: Int)
//    {
//        if (row >= 0 && row < nextSongs.count)
//        {
//            let node = nextSongs[row];
//            if (node.type != MEGANodeType.file)
//            {
//                nextSongs.remove(at: row);
//                let nodeList = mega().children(forParent: node, order: 1)
//                var insertPos = row;
//                for i in 0..<nodeList.size.intValue
//                {
//                    if let n = nodeList.node(at: i) {
//                        if isPlayable(n, orMightContainPlayable: true) {
//                            nextSongs.insert(n, at: insertPos)
//                            insertPos += 1;
//                        }
//                    }
//                }
//            }
//            else if (node.name.hasSuffix(".playlist") && app().storageModel.fileDownloadedByNH(nextSongs[row]))
//            {
//                expandPlaylist(row);
//            }
//        }
//    }
//
//    func isExpandable(node: MEGANode) -> Bool
//    {
//        return node.type != MEGANodeType.file || node.name.hasSuffix(".playlist") && app().storageModel.fileDownloadedByNH(node);
//    }
    
    func downloadAllSongsInQueue(_ removeAlreadyDownloaded : Bool) -> Int
    {
        var newQueue : [MEGANode] = [];
        var started : Int = 0;
        for i in 0..<nextSongs.count {
            if (removeAlreadyDownloaded && !app().storageModel.fileDownloadedByFP(nextSongs[i]))
            {
                newQueue.append(nextSongs[i]);
            }
            if (app().storageModel.startSongDownloadIfAbsent(nextSongs[i]))  // todo: separate out playlists
            {
                started += 1;
            }
        }
        if (removeAlreadyDownloaded)
        {
            nextSongs = newQueue;
        }
        return started;
    }
    
    func playerSongIsEphemeral() -> Bool {
        
        if nodeInPlayer == nil { return true; }
        
        if (noHistoryMode)
        {
            return !nodeInPlayerStarted;
        }
        else
        {
            return nextSongs.count > 0 &&
                   nodeInPlayer!.handle == nextSongs[0].handle &&
                   player.currentTime().seconds == 0 &&
                   !nodeInPlayerStarted;
        }
    }

    func startNextSongDownloads() -> Bool
    {
        let reloadTableView : Bool = false;
        let baseIndex = noHistoryMode ? noHistoryMode_currentTrackIndex : 0;
        var index = baseIndex;
        var numDownloading = 0;
        while (index < nextSongs.count) {
            if (index >= baseIndex + (noHistoryMode ? 3 : 2)) { break }
            
//            while (nextSongs.count > index && isExpandable(node: nextSongs[index]))
//            {
//                expandQueueItem(index);
//                reloadTableView = true;
//            }
            if (index < nextSongs.count &&
                (app().storageModel.isDownloadingByType(nextSongs[index]) ||
                 app().storageModel.startDownloadIfAbsent(node: nextSongs[index])))
            {
                numDownloading += 1;
            }
            if (numDownloading >= 3) { break }
            
            index += 1;
        }
        return reloadTableView;
    }

    func onNextSongsEdited(reloadView : Bool, triggerPlay: Bool, canReplacePlayerSong : Bool)
    {
        var reloadTableView = startNextSongDownloads() || reloadView;

        if (triggerPlay || nodeInPlayer == nil || canReplacePlayerSong)
        {
            loadPlayer(startIt: triggerPlay);
            reloadTableView = startNextSongDownloads()
            reloadTableView = true
        }
        
        if (reloadTableView) {
            app().playQueueTVC?.redraw();
        }
    }
    
    func nodesChanging(_ node: MEGANode)
    {
        if (nodeInPlayer != nil) &&
           (nodeInPlayer!.handle == node.handle)
        {
            nodeInPlayer = node;
            app().playQueueTVC?.playingSongUpdated();
        }
    }
    func nodesFinishedChanging()
    {
    }

    
    func loadPlayer(startIt: Bool)
    {
        if (!playerSongIsEphemeral()) { pushToHistory(); }
        
        let songIndex = noHistoryMode ? noHistoryMode_currentTrackIndex : 0;
        
        if (nextSongs.count > songIndex)
        {
            if let fileURL = app().storageModel.getDownloadedSongURL(nextSongs[songIndex]) {
                let play = startIt || isPlaying;
                nodeInPlayer = nextSongs[songIndex];
                nodeInPlayerStarted = false;
                downloadingNodeToStartPlaying = nil;
                player.replaceCurrentItem(with: AVPlayerItem(url: fileURL));
                if (play) {
                    self.player.play();  // if it does start playing, and we're in history mode, observeValue() will remove queue entry 0, ie song really is in player and not queue anymore
                    shouldBePlaying = true;
                }
                app().setupNowPlaying(node: nodeInPlayer!)
                app().playQueueTVC!.playingSongUpdated()
                return ;
            }
            else if (!app().loginState.online)
            {
                reportMessage(uic: app().playQueueTVC!, message: "Please go online to get the next song")
            }
        }

        shouldBePlaying = startIt && nextSongs.count > 0;
        downloadingNodeToStartPlaying = shouldBePlaying ? nextSongs[0] : nil;
        if (downloadingNodeToStartPlaying == nil)
        {
            downloadingNodeToStartPlaying = nil;
        }
        nodeInPlayer = nil;
        nodeInPlayerStarted = false;
        self.player.replaceCurrentItem(with: nil);
        app().setupNowPlaying(node: nodeInPlayer)
        app().playQueueTVC?.playingSongUpdated()
    }

    var downloadingNodeToStartPlaying : MEGANode? = nil;

    func songDownloaded(node: MEGANode?)
    {
        if (downloadingNodeToStartPlaying == nil) {
            onNextSongsEdited(reloadView: false, triggerPlay: false, canReplacePlayerSong: false)  // reloading the view interrupts users moving tracks around in edit mode
        }
        else if (node != nil && nextSongs.count > 0) {
            if (node!.handle == nextSongs[0].handle) {
                onNextSongsEdited(reloadView: false, triggerPlay: node!.handle == downloadingNodeToStartPlaying!.handle, canReplacePlayerSong: false)  // reloading the view interrupts users moving tracks around in edit mode
            }
        }
    }
    
    func pushToHistory()
    {
        if (noHistoryMode) { return; }
        
        if nodeInPlayer != nil {
            playedSongs.insert(nodeInPlayer!, at: 0);
            nodeInPlayer = nil;
            nodeInPlayerStarted = false;

            while (playedSongs.count > 100)
            {
                playedSongs.remove(at: 100);
            }
        }
    }

    func timeTravel(index: Int)
    {
        let replaceable = playerSongIsEphemeral();
        if (index < playedSongs.count)
        {
            if nodeInPlayer != nil && nextSongs.count > 0 && nextSongs[0] != nodeInPlayer
            {
                nextSongs.insert(nodeInPlayer!, at: 0);
            }
            nodeInPlayer = nil;
            nodeInPlayerStarted = false;
            for i in 0...index {
                nextSongs.insert(playedSongs[i], at: 0);
            }
            playedSongs.removeFirst(index+1);
        }
        onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong : replaceable);
    }

    func goToTappedRow(_ row: Int)
    {
        if (noHistoryMode)
        {
            if (row < nextSongs.count && playerSongIsEphemeral())
            {
                noHistoryMode_currentTrackIndex = row;
                onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong : true);
            }
        }
    }
    
    func goNextTrack() -> Bool
    {
        if (noHistoryMode)
        {             
            if (nextSongs.count > noHistoryMode_currentTrackIndex)
            {
                noHistoryMode_currentTrackIndex += 1;
                onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong : true);
                return true;
            }
        }
        else
        {
            if (nextSongs.count > 0)
            {
                let replaceable = playerSongIsEphemeral();
                if (replaceable) { nextSongs.remove(at: 0); }
                if (!replaceable) { pushToHistory(); }
                onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong : replaceable);
                return true;
            }
        }
        return false;
    }

    func goSongStartOrPrevTrack() -> Bool
    {
        let wasPlaying = player.rate == 1.0;
        if (player.currentTime().seconds > 3.0)
        {
            player.seek(to: CMTime(seconds: 0, preferredTimescale: 1));
            if wasPlaying { self.player.play(); }
            return true;
        }
        else { return goPrevTrack(); }
    }

    func goPrevTrack() -> Bool
    {
        if (playedSongs.count > 0)
        {
            if (noHistoryMode)
            {
                if (noHistoryMode_currentTrackIndex > 0 && nextSongs.count > noHistoryMode_currentTrackIndex-1)
                {
                    noHistoryMode_currentTrackIndex -= 1;
                    onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong : true);
                    return true;
                }
            }
            else
            {
                timeTravel(index: 0);
            }
        }
        return false;
    }

    func onSongFinishedPlaying()
    {
        let replaceable = playerSongIsEphemeral();
        if (noHistoryMode)
        {
            noHistoryMode_currentTrackIndex += 1;
        }
        else
        {
            pushToHistory();
        }
        onNextSongsEdited(reloadView: true, triggerPlay: true, canReplacePlayerSong: replaceable);
    }

    func nodeHandleArrayToJSON(optionalExtraFirstNode : MEGANode?, array : [MEGANode] ) -> String
    {
        var comma = false;
        var s = "[";
        if (optionalExtraFirstNode != nil) {
            s += "{\"h\":\"" + optionalExtraFirstNode!.base64Handle + "\"}";
            comma = true;
        }
        for n in array {
            if comma { s += ","; }
            comma = true;
            s += "{\"h\":\"" + n.base64Handle + "\"}";
        }
        s += "]"
        return s;
    }
    
    func JSONToNodeHandleArray(_ json : Any? ) -> [MEGANode]?
    {
        var result : [MEGANode]? = nil;
        if let array = json as? [Any] {
            result = [];
            for object in array {
                if let attribs = object as? [String : Any] {
                    if let handleStr = attribs["h"] {
                        let node = mega().node(forHandle: MEGASdk.handle(forBase64Handle: handleStr as! String));
                        if (node != nil) {
                            result!.append(node!);
                        }
                    }
                }
            }
        }
        return result;
    }

    func toggleNoHistoryMode()
    {
        let ephemeral = playerSongIsEphemeral();
        noHistoryMode = !noHistoryMode;
        
        if (noHistoryMode && !ephemeral && nodeInPlayer != nil)
        {
            nextSongs.insert(nodeInPlayer!, at: 0)
        }
        if (!noHistoryMode && noHistoryMode_currentTrackIndex == 0 && nodeInPlayer != nil && nextSongs.count > 0 && nextSongs[0].handle == nodeInPlayer!.handle)
        {
            nextSongs.remove(at: 0)
        }
        
        noHistoryMode_currentTrackIndex = 0;
        onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong: ephemeral);
    }
    
    func saveAsPlaylist(uic : UIViewController)
    {
        if (!app().loginState.online)
        {
            reportMessage(uic: app().playQueueTVC!, message: "Please go online to upload the playlist")
            return;
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        var inputName = formatter.string(from: Date());
        
        let textInput = UIAlertController(title: "New playlist name", message: "The .playlist filename extension will be added automatically.  The playlist will appear in your playlist root folder.  The date and time are offered as a default name.", preferredStyle: .alert)
        
        textInput.addTextField( configurationHandler: { newTextField in
            newTextField.text = inputName;
            newTextField.returnKeyType = .go
            newTextField.delegate = self
        });

        textInput.addAction(UIAlertAction(title: "Create playlist", style: .default, handler:
            { (UIAlertAction) -> () in
                if (textInput.textFields != nil) {
                    if textInput.textFields!.first != nil {
                        if (textInput.textFields!.first!.text != nil) {
                            inputName = textInput.textFields!.first!.text!;
                        }
                    }
                }
                let s = self.nodeHandleArrayToJSON(optionalExtraFirstNode: nil, array: self.nextSongs);
                let uploadpath = app().storageModel.uploadFilesPath() + "/" + inputName + ".playlist";
                let url = URL(fileURLWithPath: uploadpath);
                try! s.write(to: url, atomically: true, encoding: .ascii)
                mega().startUpload(withLocalPath:uploadpath, parent: app().playlistBrowseFolder!)
            }));
        
        textInput.addAction(menuAction_neverMind());
        uic.present(textInput, animated: false, completion: nil)
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        // select the date/time default playlist name
        textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
        textField.becomeFirstResponder()
    }

    func saveQueueAndHistory(shuttingDown : Bool)
    {
        if (shuttingDown && !playerSongIsEphemeral()) { pushToHistory() };
        let s1 = nodeHandleArrayToJSON(optionalExtraFirstNode: noHistoryMode || playerSongIsEphemeral() ? nil : nodeInPlayer, array: nextSongs);
        let s2 = nodeHandleArrayToJSON(optionalExtraFirstNode: nil, array: playedSongs);
        do {
            try s1.write(toFile: app().storageModel.settingsPath() + "/nextSongs", atomically: true, encoding: String.Encoding.utf8);
            try s2.write(toFile: app().storageModel.settingsPath() + "/playedSongs", atomically: true, encoding: String.Encoding.utf8);
        }
        catch {
        }
    }

    func restoreOnStartup()
    {
        let ns = app().storageModel.loadFileAsJSON(filename: app().storageModel.settingsPath() + "/nextSongs");
        if (ns != nil) {
            if let a = JSONToNodeHandleArray(ns) {
                nextSongs = a;
            }
        }
        let ps = app().storageModel.loadFileAsJSON(filename: app().storageModel.settingsPath() + "/playedSongs");
        if (ps != nil) {
            if let a = JSONToNodeHandleArray(ps) {
                playedSongs = a;
            }
        }
    }


    
}
