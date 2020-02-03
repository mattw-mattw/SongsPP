//
//  AppDelegate.swift
//  just-exploring-3
//
//  Created by Admin on 23/10/2019.
//  Copyright © 2019 mattweir. All rights reserved.
//

import Foundation
import UIKit
import AVKit
import MediaPlayer

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default, options: [.mixWithOthers, .allowAirPlay])
            print("Playback OK")
            try AVAudioSession.sharedInstance().setActive(true)
            print("Session is Active")
            //try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback);
            
            //try AVAudioSessionPatch.setSession(AVAudioSession.sharedInstance(), category: .playback, with: [.defaultToSpeaker, .mixWithOthers])

            application.beginReceivingRemoteControlEvents();
        } catch {
            print(error)
        }
        return true
    }

    @objc func mediaDidEnd(notification: NSNotification)
    {
        playQueue.onSongFinishedPlaying();
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        NotificationCenter.default.addObserver(self, selector: #selector(mediaDidEnd), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil);

        loginState.goOffline(onProgress: { str in }, onFinish: {b in })
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    var mega : MEGASdk? = nil;
//    var currentLoginVC : LoginVC? = nil;
    var loginState = LoginState();
    var playQueue = PlayQueue();
    var storageModel = StorageModel();
    
    var musicBrowseFolder : MEGANode? = nil;
    var playlistBrowseFolder : MEGANode? = nil;
    
//    var player : AVPlayer = AVPlayer();
//    var handleInPlayer : UInt64 = 0;
//    var shouldBePlaying : Bool = false;
    
//    var nextSongs : [MEGANode] = [];
//    var playedSongs : [MEGANode] = [];
    var swipedRightSet : [MEGANode] = [];

    
    var playQueueTVC : PlayQueueTVC? = nil;
    var tabBarContoller : MainTabBarController? = nil;
    
//    func advanceQueueTo(_ row: Int)
//    {
//        // songs skipped go into the 'played' list
//        for i in 0...row
//        {
//            if (i > 0 && i < row && 1 < nextSongs.count)
//            {
//                playedSongs.insert(nextSongs[1], at: 0);
//                nextSongs.remove(at: 1);
//                if (playedSongs.count > 100)
//                {
//                    playedSongs.remove(at: playedSongs.count-1);
//                }
//            }
//        }
//        StartAnyDownloads();
//    }
//
//    func deleteQueueTo(_ row: Int)
//    {
//        for i in 0...row
//        {
//            if (i > 0 && i < row && 1 < nextSongs.count)
//            {
//                nextSongs.remove(at: 1);
//            }
//        }
//        StartAnyDownloads();
//    }
//
//    func deleteQueueAfter(_ row: Int)
//    {
//        while row + 1 < nextSongs.count
//        {
//            nextSongs.remove(at: row+1);
//        }
//        StartAnyDownloads();
//    }
//
//    func playRightNow(_ row: Int)
//    {
//        if row < nextSongs.count
//        {
//            playedSongs.append(app().nextSongs[0]);
//            nextSongs[0] = nextSongs[row];
//            if (row > 0) { nextSongs.remove(at: row);}
//            handleInPlayer = nextSongs[0].handle;
//        }
//        StartAnyDownloads();
//        playNext(startIt: true);
//    }
//
//    func expandPlaylist(_ row: Int)
//    {
//        var newrow = row+1;
//        do {
//            let filename = cachePath() + "/nextsongs/" + nextSongs[row].name;
//            let content = try String(contentsOf: URL(string: "file://" + filename)!, encoding: .utf8);
//            let contentData = content.data(using: .utf8);
//            let json = try JSONSerialization.jsonObject(with: contentData!, options: []);
//            if let array = json as? [Any] {
//                for object in array {
//                    print("array entry");
//                    if let attribs = object as? [String : Any] {
//                        print("as object");
//                        if let handleStr = attribs["h"] {
//                            print(handleStr);
//                            let node = mega!.node(forHandle: MEGASdk.handle(forBase64Handle: handleStr as! String));
//                            if (node != nil) {
//                                nextSongs.insert(node!, at: newrow);
//                                newrow += 1;
//                            }
//                        }
//                    }
//                }
//            }
//        }
//        catch {
//
//        }
//        nextSongs.remove(at: row);
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
//                let nodeList = mega!.children(forParent: node, order: 1)
//                for i in 0...(nodeList.size.intValue-1)
//                {
//                    nextSongs.insert(nodeList.node(at: i), at: row+i)
//                }
//            }
//            else if (node.name.hasSuffix(".playlist") && downloaded.contains(nextSongs[0].handle))
//            {
//                expandPlaylist(row);
//            }
//        }
//        StartAnyDownloads()
//    }
//
//    func isExpandable(node: MEGANode) -> Bool
//    {
//        return node.type != MEGANodeType.file || node.name.hasSuffix(".playlist") && downloaded.contains(node.handle);
//    }
//
//    func StartAnyDownloads()
//    {
//        while (nextSongs.count > 0 && isExpandable(node: nextSongs[0]))
//        {
//            expandQueueItem(0);
//        }
//        while (nextSongs.count > 1 && isExpandable(node: nextSongs[1]))
//        {
//            expandQueueItem(1);
//        }
//        for i in 0...1
//        {
//            if (i < nextSongs.count)
//            {
//                let node = nextSongs[i];
//                if !downloading.contains(node.handle) && !downloaded.contains(node.handle)
//                {
//                    let filename = cachePath()+"/nextsongs/" + node.name;
//                    mega!.startDownloadNode(node, localPath: filename);
//                    downloading.insert(node.handle);
//                    print("downloading \(filename)")
//                }
//            }
//        }
//    }

    func downloadProgress(nodeHandle : UInt64, percent : NSNumber )
    {
        if (playQueueTVC != nil)
        {
            playQueueTVC!.downloadProgress(nodeHandle, percent);
        }
    }

//    func onSongFinishedPlaying()
//    {
//        if (nextSongs.count > 0)
//        {
//            if (nextSongs[0].handle == handleInPlayer)
//            {
//                playedSongs.append(app().nextSongs[0]);
//                nextSongs.remove(at: 0);
//                if (playedSongs.count > 100)
//                {
//                    playedSongs.remove(at: 0);
//                }
//                handleInPlayer = 0;
//            }
//            playQueueTVC?.tableView.reloadData();
//        }
//        StartAnyDownloads();
//        playNext(startIt: true);
//    }
//
//    func playNext(startIt: Bool)
//    {
//        if (nextSongs.count > 0 && downloaded.contains(nextSongs[0].handle))
//        {
//            let filename = cachePath() + "/nextsongs/" + nextSongs[0].name;
//            let file = URL(fileURLWithPath: filename);
//            player.replaceCurrentItem(with: AVPlayerItem(url: file));
//            if (startIt) { self.player.play(); }
//            handleInPlayer = app().nextSongs[0].handle;
//
//            do {
//                try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default, options: [.mixWithOthers, .allowAirPlay])
//                print("Playback OK")
//                try AVAudioSession.sharedInstance().setActive(true)
//                print("Session is Active")
//                //try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback);
//
//                //try AVAudioSessionPatch.setSession(AVAudioSession.sharedInstance(), category: .playback, with: [.defaultToSpeaker, .mixWithOthers])
//
//                //application.beginReceivingRemoteControlEvents();
//            } catch {
//                print(error)
//            }
//
//        }
//        else
//        {
//            shouldBePlaying = nextSongs.count > 1;
//            handleInPlayer = 0;
//            self.player.replaceCurrentItem(with: nil);
//        }
//    }
//
//    @objc func mediaDidEnd(notification: NSNotification)
//    {
//        onSongFinishedPlaying();
//        playNext(startIt: true);
//    }

    

 
//    func queueSong(node : MEGANode)
//    {
//        nextSongs.append(node);
//        StartAnyDownloads();
//    }
//
//    func queueSongNext(node : MEGANode)
//    {
//        nextSongs.insert(node, at: 0);
//        StartAnyDownloads();
//    }
    
    var swipeRightPlaysSong : Bool = true;
    
    func AddSwipedRightNode(node: MEGANode)
    {
        if (swipeRightPlaysSong) { playQueue.queueSong(node: node);}
        else { swipedRightSet.append(node); }
    }

}

func deviceName() -> String
{
    var systemInfo = utsname()
    uname(&systemInfo)
    let machineMirror = Mirror(reflecting: systemInfo.machine)
    var identifier = machineMirror.children.reduce("") { identifier, element in
        guard let value = element.value as? Int8, value != 0 else { return identifier }
        return identifier + String(UnicodeScalar(UInt8(value)))
    }
    #if (targetEnvironment(simulator))
    identifier = "iOS-sim/" + identifier;
    #endif
    return identifier;
}


func app() -> AppDelegate {
    return UIApplication.shared.delegate as! AppDelegate;
}

func mega(using fileManager : FileManager = .default) -> MEGASdk {
    
    let a = app();
    if (a.mega == nil)
    {
        let path = app().storageModel.cachePath();
        a.mega = MEGASdk.init(appKey: "EelhRa6C", userAgent: "MusicViaMega " + deviceName(), basePath: path == "" ? nil : path)!;
        a.mega!.add(a.storageModel.transferDelegate);
    }
    return a.mega!;
}

func reportMessage(uic : UIViewController, message : String, continuation : (() -> Void)? = nil)
{
    let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Ok", style: .cancel));
    uic.present(alert, animated: false, completion: continuation)
}

