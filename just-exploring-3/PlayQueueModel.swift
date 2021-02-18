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
            let np = mega().nodePath(for: n!)
            if (np != nil)
            {
                newPath = np!
            }
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

class PlayQueue : NSObject /*(ObservableObject*/ {
    /*@Published*/ var nextSongs : [MEGANode] = [];
    /*@Published*/ var playedSongs : [MEGANode] = [];
    
//    @Published var sliderPos : Double = 0.0;
//    @Published var currentTime = CMTime()
//    @Published var duration = CMTime()
//    @Published var durationString = "0:00"
    /*@Published*/ var currentTimeString = "0:00"

    var player : AVPlayer = AVPlayer();
    var nodeInPlayer : MEGANode? = nil;
    var nodeInPlayerIsFrontOfList = false;
    var isPlaying : Bool = false;
    var shouldBePlaying : Bool = false;
    var timeObservation : Any? = nil;
    
    

    override init() {
        super.init()
        player.addObserver(self, forKeyPath: "rate", options: NSKeyValueObservingOptions.new, context: nil)
    }

    var removeFirstSongOnPlay = false;
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "rate" {
            if !isPlaying && player.rate > 0 {
                isPlaying = true;
                if (removeFirstSongOnPlay && nodeInPlayerIsFrontOfList)
                {
                    nextSongs.remove(at: 0)
                    nodeInPlayerIsFrontOfList = false;
                    removeFirstSongOnPlay = false;
                    onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong: false);
                }
            }
            if (player.rate == 0)
            {
                isPlaying = false;
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
    
    func moveSongNext(_ row: Int)
    {
        if row < nextSongs.count
        {
            let replaceable = playerSongIsEphemeral();
            let node = nextSongs[row];
            nextSongs.remove(at: row);
            nextSongs.insert(node, at: 0);
            onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong: replaceable);
        }
    }
    
    func moveSongLast(_ row: Int)
    {
        if row < nextSongs.count
        {
            let replaceable = playerSongIsEphemeral();
            let node = nextSongs[row];
            nextSongs.remove(at: row);
            nextSongs.insert(node, at: nextSongs.count);
            onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong: replaceable);
        }
    }
    
    func shuffleQueue()
    {
        let replaceable = playerSongIsEphemeral();
        var newQueue : [MEGANode] = []
        while nextSongs.count > 0 {
            let row = Int.random(in: 0..<nextSongs.count)
            newQueue.append(nextSongs[row])
            nextSongs.remove(at: row)
        }
        nextSongs.append(contentsOf: newQueue);
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
        onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong: replaceable);
    }

    func deleteToBottom(_ row: Int)
    {
        let replaceable = playerSongIsEphemeral();
        while row < nextSongs.count
        {
            nextSongs.remove(at: row);
        }
        onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong: replaceable);
    }
    
    func playRightNow(_ row: Int)
    {
        let replaceable = playerSongIsEphemeral();
        if row < nextSongs.count
        {
            let node = nextSongs[row];
            nextSongs.remove(at: row);
            nextSongs.insert(node, at: 0);
        }
        onNextSongsEdited(reloadView: true, triggerPlay: true, canReplacePlayerSong: replaceable);
    }

    func expandPlaylist(_ row: Int)
    {
        var newrow = row+1;
        if let json = app().storageModel.getDownloadedPlaylistAsJSON(nextSongs[row]) {
            if let array = json as? [Any] {
                for object in array {
                    print("array entry");
                    if let attribs = object as? [String : Any] {
                        print("as object");
                        if let handleStr = attribs["h"] {
                            print(handleStr);
                            let node = mega().node(forHandle: MEGASdk.handle(forBase64Handle: handleStr as! String));
                            if (node != nil) {
                                nextSongs.insert(node!, at: newrow);
                                newrow += 1;
                            }
                        }
                    }
                }
            }
        }
        nextSongs.remove(at: row);
    }
    
    var playableExtensions = [ ".mp3", ".m4a", ".aac", ".wav", ".flac", ".aiff", ".au", ".pcm", ".ac3", ".aa", ".aax"];
    
    func isPlayable(_ n : MEGANode, orMightContainPlayable : Bool) -> Bool
    {
        if orMightContainPlayable {
            if (n.isFile() && n.name.hasSuffix(".playlist")) { return true; }
            if (n.isFolder()) { return true; }
        }
        if (n.isFile()) {
            if let name = n.name {
                for ext in playableExtensions {
                    if name.hasSuffix(ext) { return true; }
                }
            }
        }
        return false;
    }
    
    func expandAll()
    {
        let replaceable = playerSongIsEphemeral();
        var expanded = false
        var row : Int = 0;
        while (row < nextSongs.count)
        {
            if (isExpandable(node: nextSongs[row])) {
                expandQueueItem(row);
                expanded = true;
            }
            else {
                row += 1;
            }
        }
        if expanded { onNextSongsEdited(reloadView : true, triggerPlay: false, canReplacePlayerSong: replaceable) }
    }
    
    func expandQueueItem(_ row: Int)
    {
        if (row >= 0 && row < nextSongs.count)
        {
            let node = nextSongs[row];
            if (node.type != MEGANodeType.file)
            {
                nextSongs.remove(at: row);
                let nodeList = mega().children(forParent: node, order: 1)
                var insertPos = row;
                for i in 0..<nodeList.size.intValue
                {
                    if let n = nodeList.node(at: i) {
                        if isPlayable(n, orMightContainPlayable: true) {
                            nextSongs.insert(n, at: insertPos)
                            insertPos += 1;
                        }
                    }
                }
            }
            else if (node.name.hasSuffix(".playlist") && app().storageModel.fileDownloaded(nextSongs[row]))
            {
                expandPlaylist(row);
            }
        }
    }
    
    func isExpandable(node: MEGANode) -> Bool
    {
        return node.type != MEGANodeType.file || node.name.hasSuffix(".playlist") && app().storageModel.fileDownloaded(node);
    }

//    var downloadNextOnly = true;
    
    func downloadAllSongsInQueue(_ removeAlreadyDownloaded : Bool) -> Int
    {
        var newQueue : [MEGANode] = [];
        var started : Int = 0;
        for i in 0..<nextSongs.count {
            if (!app().storageModel.fileDownloaded(nextSongs[i]))
            {
                newQueue.append(nextSongs[i]);
                if (app().storageModel.startSongDownloadIfAbsent(nextSongs[i]))  // todo: separate out playlists
                {
                    started += 1;
                }
            }
        }
        if (removeAlreadyDownloaded)
        {
            nextSongs = newQueue;
        }
        return started;
    }
    
    func playerSongIsEphemeral() -> Bool {
        return
            nodeInPlayer == nil || (nextSongs.count > 0 &&
            nodeInPlayer!.handle == nextSongs[0].handle &&
            player.currentTime().seconds == 0 && nodeInPlayerIsFrontOfList);
    }

    func onNextSongsEdited(reloadView : Bool, triggerPlay: Bool, canReplacePlayerSong : Bool)
    {
        var reloadTableView : Bool = reloadView;
        var index = 0;
        var numDownloading = 0;
        while (index < nextSongs.count) {
            if (index >= 2) { break }
            
            while (nextSongs.count > index && isExpandable(node: nextSongs[index]))
            {
                expandQueueItem(index);
                reloadTableView = true;
            }
            if (index < nextSongs.count &&
                (app().storageModel.isDownloading(nextSongs[index]) ||
                app().storageModel.startDownloadIfAbsent(nextSongs[index])))
            {
                numDownloading += 1;
            }
            if (numDownloading >= 3) { break }
            
            index += 1;
        }
        
        if (triggerPlay || nodeInPlayer == nil || canReplacePlayerSong)
        {
            loadPlayer(startIt: triggerPlay);
            reloadTableView = true
        }
        
        if (reloadTableView) {
            app().playQueueTVC?.redraw();
        }
    }
    
    func loadPlayer(startIt: Bool)
    {
        if (!playerSongIsEphemeral()) { pushToHistory(); }
        
        if (nextSongs.count > 0)
        {
            if let fileURL = app().storageModel.getDownloadedFileURL(nextSongs[0]) {
                let play = startIt || isPlaying;
                nodeInPlayer = nextSongs[0];
                nodeInPlayerIsFrontOfList = true;
                player.replaceCurrentItem(with: AVPlayerItem(url: fileURL));
                if (play) {
                    nextSongs.remove(at: 0);
                    nodeInPlayerIsFrontOfList = false;
                    self.player.play();
                    shouldBePlaying = true;
                }
                removeFirstSongOnPlay = !startIt;
                app().setupNowPlaying(node: nodeInPlayer!)
                app().playQueueTVC!.playingSongUpdated()
                return ;
            }
            else if (app().loginState.loggedInOffline)
            {
                reportMessage(uic: app().playQueueTVC!, message: "Please go online to get the next song")
            }
        }

        shouldBePlaying = startIt && nextSongs.count > 0;
        nodeInPlayer = nil;
        nodeInPlayerIsFrontOfList = false;
        self.player.replaceCurrentItem(with: nil);
        app().setupNowPlaying(node: nodeInPlayer)
        app().playQueueTVC?.playingSongUpdated()
    }

    func songDownloaded()
    {
        onNextSongsEdited(reloadView: false, triggerPlay: false, canReplacePlayerSong: false)  // reloading the view interrupts users moving tracks around in edit mode
    }
    
    func pushToHistory()
    {
        if nodeInPlayer != nil {
            playedSongs.insert(nodeInPlayer!, at: 0);
            nodeInPlayer = nil;
            nodeInPlayerIsFrontOfList = false;

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
            nodeInPlayerIsFrontOfList = false;
            for i in 0...index {
                nextSongs.insert(playedSongs[i], at: 0);
            }
            playedSongs.removeFirst(index+1);
        }
        onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong : replaceable);
    }

    func goNextTrack() -> Bool
    {
        let replaceable = playerSongIsEphemeral();
        if (nextSongs.count > 0)
        {
            if (replaceable) { nextSongs.remove(at: 0); }
            if (!replaceable) { pushToHistory(); }
            onNextSongsEdited(reloadView: true, triggerPlay: false, canReplacePlayerSong : replaceable);
            return true;
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
            timeTravel(index: 0);
        }
        return false;
    }

    func onSongFinishedPlaying()
    {
        let replaceable = playerSongIsEphemeral();
        pushToHistory();
        onNextSongsEdited(reloadView: true, triggerPlay: true, canReplacePlayerSong: replaceable);
    }

    func nodeHandleArrayToJSON(_ array : [MEGANode] ) -> String
    {
        var comma = false;
        var s = "[";
        for n in array {
            if comma { s += ","; }
            comma = true;
            s += "{\"h\":\"" + n.base64Handle + "\"}";
        }
        s += "]"
        return s;
    }
    
    func JSONToNodeHandleArray(_ json : Any? ) -> [MEGANode]
    {
        var result : [MEGANode] = [];
        if let array = json as? [Any] {
            for object in array {
                if let attribs = object as? [String : Any] {
                    if let handleStr = attribs["h"] {
                        let node = mega().node(forHandle: MEGASdk.handle(forBase64Handle: handleStr as! String));
                        if (node != nil) {
                            result.append(node!);
                        }
                    }
                }
            }
        }
        return result;
    }

    
    func saveAsPlaylist()
    {
        if (app().loginState.loggedInOffline)
        {
            reportMessage(uic: app().playQueueTVC!, message: "Please go online to upload the playlist")
            return;
        }

        let s = nodeHandleArrayToJSON(nextSongs);
        let uploadpath = app().storageModel.getUploadPlaylistFileURL();
        let url = URL(fileURLWithPath: uploadpath);
        try! s.write(to: url, atomically: true, encoding: .ascii)
        mega().startUpload(withLocalPath:uploadpath, parent: app().playlistBrowseFolder!)
    }

    func saveOnShutdown()
    {
        if (!playerSongIsEphemeral()) { pushToHistory() };
        let s1 = nodeHandleArrayToJSON(nextSongs);
        let s2 = nodeHandleArrayToJSON(playedSongs);
        do {
            try s1.write(toFile: app().storageModel.storagePath() + "/nextSongs", atomically: true, encoding: String.Encoding.utf8);
            try s2.write(toFile: app().storageModel.storagePath() + "/playedSongs", atomically: true, encoding: String.Encoding.utf8);
        }
        catch {
        }
    }

    func restoreOnStartup()
    {
        let ns = app().storageModel.loadFileAsJSON(filename: app().storageModel.storagePath() + "/nextSongs");
        if (ns != nil) {
            nextSongs = JSONToNodeHandleArray(ns);
        }
        let ps = app().storageModel.loadFileAsJSON(filename: app().storageModel.storagePath() + "/playedSongs");
        if (ps != nil) {
            playedSongs = JSONToNodeHandleArray(ps);
        }
    }


    
}
