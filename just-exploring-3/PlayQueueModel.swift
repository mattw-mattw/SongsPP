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

class PlayQueue /*: ObservableObject*/ {
    /*@Published*/ var nextSongs : [MEGANode] = [];
    /*@Published*/ var playedSongs : [MEGANode] = [];
    
//    @Published var sliderPos : Double = 0.0;
//    @Published var currentTime = CMTime()
//    @Published var duration = CMTime()
//    @Published var durationString = "0:00"
    /*@Published*/ var currentTimeString = "0:00"

    var player : AVPlayer = AVPlayer();
    var handleInPlayer : UInt64 = 0;
    var shouldBePlaying : Bool = false;
    var timeObservation : Any? = nil;
        
    func StringTime(_ nn : Double) -> String
    {
        let n = nn + 0.5
        let mins = Int(n / 60)
        let secs = Int(n) - (mins*60)
        return String(format: "%d:%02d", mins, secs)
    }
    
    func queueSong(node : MEGANode)
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
        
        nextSongs.append(node);
        
        StartAnyDownloads();
        if (nextSongs.count > 0 && handleInPlayer == 0)
        {
            playNext(startIt: shouldBePlaying);
        }
    }
    
    func queueSongNext(node : MEGANode)
    {
        nextSongs.insert(node, at: 0);
        StartAnyDownloads();
        if (nextSongs.count > 0 && handleInPlayer == 0)
        {
            playNext(startIt: shouldBePlaying);
        }
    }

    func advanceQueueTo(_ row: Int)
    {
        // songs skipped go into the 'played' list
        for i in 0...row
        {
            if (i > 0 && i < row && 1 < nextSongs.count)
            {
                playedSongs.insert(nextSongs[1], at: 0);
                nextSongs.remove(at: 1);
                if (playedSongs.count > 100)
                {
                    playedSongs.remove(at: playedSongs.count-1);
                }
            }
        }
        StartAnyDownloads();
    }
    
    func deleteQueueTo(_ row: Int)
    {
        for i in 0...row
        {
            if (i > 0 && i < row && 1 < nextSongs.count)
            {
                nextSongs.remove(at: 1);
            }
        }
        StartAnyDownloads();
    }

    func deleteQueueAfter(_ row: Int)
    {
        while row + 1 < nextSongs.count
        {
            nextSongs.remove(at: row+1);
        }
        StartAnyDownloads();
    }
    
    func playRightNow(_ row: Int)
    {
        if row < nextSongs.count
        {
            playedSongs.append(nextSongs[0]);
            nextSongs[0] = nextSongs[row];
            if (row > 0) { nextSongs.remove(at: row);}
            handleInPlayer = nextSongs[0].handle;
        }
        StartAnyDownloads();
        playNext(startIt: true);
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
    
    func expandQueueItem(_ row: Int)
    {
        if (row >= 0 && row < nextSongs.count)
        {
            let node = nextSongs[row];
            if (node.type != MEGANodeType.file)
            {
                nextSongs.remove(at: row);
                let nodeList = mega().children(forParent: node, order: 1)
                for i in 0...(nodeList.size.intValue-1)
                {
                    nextSongs.insert(nodeList.node(at: i), at: row+i)
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

    func StartAnyDownloads()
    {
        while (nextSongs.count > 0 && isExpandable(node: nextSongs[0]))
        {
            expandQueueItem(0);
        }
        while (nextSongs.count > 1 && isExpandable(node: nextSongs[1]))
        {
            expandQueueItem(1);
        }

        if app().loginState.loggedInOnline {
            for i in 0...1
            {
                if (i < nextSongs.count)
                {
                    app().storageModel.startDownloadIfAbsent(nextSongs[i])
                }
            }
        }
    }
    
    func playNext(startIt: Bool)
    {
        if (nextSongs.count > 0)
        {
            if let fileURL = app().storageModel.getDownloadedFileURL(nextSongs[0]) {
                player.replaceCurrentItem(with: AVPlayerItem(url: fileURL));
                if (startIt) { self.player.play(); }
                handleInPlayer = nextSongs[0].handle;
                
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
            else
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
        if (nextSongs.count > 0 && handle == nextSongs[0].handle && handleInPlayer == 0)
        {
            playNext(startIt: true);
        }
    }
    
    func onSongFinishedPlaying()
    {
        if (nextSongs.count > 0)
        {
            if (nextSongs[0].handle == handleInPlayer)
            {
                playedSongs.append(nextSongs[0]);
                nextSongs.remove(at: 0);
                if (playedSongs.count > 100)
                {
                    playedSongs.remove(at: 0);
                }
                handleInPlayer = 0;
            }
        }
        StartAnyDownloads();
        playNext(startIt: true);
    }

}
