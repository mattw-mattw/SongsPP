//
//  PlayQueueModel.swift
//  SongMe
//
//  Created by Matt Weir on 4/01/20.
//  Copyright © 2020 mattweir. All rights reserved.
//

import Foundation


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
    var handleInPlayer : UInt64 = 0;
    var isPlaying : Bool = false;
    var shouldBePlaying : Bool = false;
    var timeObservation : Any? = nil;
    
    override init() {
        super.init()
        player.addObserver(self, forKeyPath: "rate", options: NSKeyValueObservingOptions.new, context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "rate" {
            if player.rate > 0 && nextSongs.count > 0 {
                handleInPlayer = nextSongs[0].handle;
                isPlaying = true;
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
        
        var playableNodes = nodes;
        var i: Int = 0;
        while (i < playableNodes.count) {
            if isPlayable(playableNodes[i]) {
                i += 1;
            }
            else {
                playableNodes.remove(at: i);
            }
        }
        nextSongs += playableNodes;
        onNextSongsEdited(reloadView: true);
        if (nextSongs.count > 0 && handleInPlayer == 0)
        {
            playNow(startIt: shouldBePlaying);
        }
    }
    
    func queueSongNext(node : MEGANode)
    {
        if isPlayable(node) {
            nextSongs.insert(node, at: nextSongs.count > 0 && handleInPlayer == nextSongs[0].handle ? 1 : 0);
            onNextSongsEdited(reloadView: true);
        }
    }
    
    func moveSongNext(_ row: Int)
    {
        if row > 1 && row < nextSongs.count
        {
            let node = nextSongs[row];
            nextSongs.remove(at: row);
            nextSongs.insert(node, at: nextSongs.count > 0 && handleInPlayer == nextSongs[0].handle ? 1 : 0);
            onNextSongsEdited(reloadView: true);
        }
    }
    
    func moveSongLast(_ row: Int)
    {
        if row < nextSongs.count
        {
            let node = nextSongs[row];
            nextSongs.remove(at: row);
            nextSongs.insert(node, at: nextSongs.count);
            onNextSongsEdited(reloadView: true);
        }
    }
    
    func shuffleQueue()
    {
        let start = nextSongs.count > 0 && handleInPlayer != 0 ? 1 : 0;
        var newQueue : [MEGANode] = []
        while nextSongs.count > start {
            let row = Int.random(in: start..<nextSongs.count)
            newQueue.append(nextSongs[row])
            nextSongs.remove(at: row)
        }
        nextSongs.append(contentsOf: newQueue);
        onNextSongsEdited(reloadView: true)
    }
    
    func deleteToTop(_ row: Int)
    {
        for _ in 1...row
        {
            if (1 < nextSongs.count)
            {
                nextSongs.remove(at: 1);
            }
        }
        onNextSongsEdited(reloadView: true);
    }

    func deleteToBottom(_ row: Int)
    {
        while row < nextSongs.count
        {
            nextSongs.remove(at: row);
        }
        onNextSongsEdited(reloadView: true);
    }
    
    func playRightNow(_ row: Int)
    {
        if row < nextSongs.count
        {
            let node = nextSongs[row];
            nextSongs.remove(at: row);
            if (row > 0) { moveSongToHistory(index: 0) }
            nextSongs.insert(node, at: 0);
        }
        onNextSongsEdited(reloadView: true);
        playNow(startIt: true);
    }

    func expandPlaylist(_ row: Int)
    {
        var newrow = row+1;
        if let json = app().storageModel.getDownloadedFileAsJSON(nextSongs[row]) {
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
    
    func isPlayable(_ n : MEGANode) -> Bool
    {
        return !n.name.hasSuffix(".jpg")
    }
    
    func expandAll()
    {
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
        if expanded { onNextSongsEdited(reloadView : true) }
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
                        if isPlayable(n) {
                            nextSongs.insert(n, at: insertPos)
                            insertPos += 1;
                        }
                    }
                }
            }
            else if (node.name.hasSuffix(".playlist") && app().storageModel.fileDownloaded(nextSongs[0]))
            {
                expandPlaylist(row);
            }
        }
    }
    
    func isExpandable(node: MEGANode) -> Bool
    {
        return node.type != MEGANodeType.file || node.name.hasSuffix(".playlist") && app().storageModel.fileDownloaded(node);
    }

    var downloadNextOnly = true;

    func onNextSongsEdited(reloadView : Bool)
    {
        var reloadTableView : Bool = reloadView;
        var index = 0;
        var numDownloading = 0;
        while (index < nextSongs.count) {
            if (downloadNextOnly && index >= 2) { break }
            
            while (nextSongs.count > index && isExpandable(node: nextSongs[index]))
            {
                expandQueueItem(index);
                reloadTableView = true;
            }
            if (app().storageModel.isDownloading(nextSongs[index]) ||
                app().storageModel.startDownloadIfAbsent(nextSongs[index]))
            {
                numDownloading += 1;
            }
            if (numDownloading >= 3) { break }
            
            index += 1;
        }
        
        if (nextSongs.count > 0 && !isPlaying && handleInPlayer != nextSongs[0].handle)
        {
            if let fileURL = app().storageModel.getDownloadedFileURL(nextSongs[0]) {
                player.replaceCurrentItem(with: AVPlayerItem(url: fileURL));
            }
        }
        
//        if app().loginState.loggedInOnline {
//            for i in 0...1
//            {
//                if (i < nextSongs.count)
//                {
//                    app().storageModel.startDownloadIfAbsent(nextSongs[i])
//                }
//            }
//        }
        
        if (reloadTableView) {
            app().playQueueTVC?.tableView.reloadData();
        }
    }
    
    func playNow(startIt: Bool)
    {
        if (nextSongs.count > 0)
        {
            if let fileURL = app().storageModel.getDownloadedFileURL(nextSongs[0]) {
                player.replaceCurrentItem(with: AVPlayerItem(url: fileURL));
                if (startIt) {
                    self.player.play();
                    handleInPlayer = nextSongs[0].handle;
                }
                
                do {
                    try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default, options: [.mixWithOthers, .allowAirPlay])
                    print("Playback OK")
                    try AVAudioSession.sharedInstance().setActive(true)
                    print("Session is Active")
                    //try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback);
                    
                    //try AVAudioSessionPatch.setSession(AVAudioSession.sharedInstance(), category: .playback, with: [.defaultToSpeaker, .mixWithOthers])
                    
                    //application.beginReceivingRemoteControlEvents();
                } catch {
                    print(error)
                }
                return;
            }
            else if (app().loginState.loggedInOffline)
            {
                reportMessage(uic: app().playQueueTVC!, message: "Please go online to get the next song")
            }
        }

        shouldBePlaying = nextSongs.count > 1;
        handleInPlayer = 0;
        self.player.replaceCurrentItem(with: nil);
    }

    func songDownloaded(_ handle : UInt64)
    {
        onNextSongsEdited(reloadView: false)  // reloading the view interrupts users moving tracks around in edit mode
        if (nextSongs.count > 0 && handle == nextSongs[0].handle && handleInPlayer == 0)
        {
            playNow(startIt: true);
        }
    }
    
    func moveSongToHistory(index: Int)
    {
        playedSongs.insert(nextSongs[index], at: 0);
        nextSongs.remove(at: index);
        while (playedSongs.count > 100)
        {
            playedSongs.remove(at: 100);
        }
    }
    
    func onSongFinishedPlaying()
    {
        if (nextSongs.count > 0)
        {
            if (nextSongs[0].handle == handleInPlayer)
            {
                moveSongToHistory(index: 0);
                handleInPlayer = 0;
            }
        }
        onNextSongsEdited(reloadView: true);
        playNow(startIt: true);
    }

}
