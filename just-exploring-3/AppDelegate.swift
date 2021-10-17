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

    var player : AVPlayer? = nil;
    
    func setupRemoteTransportControls() {
        // Get the shared MPRemoteCommandCenter
        let commandCenter = MPRemoteCommandCenter.shared()

        // Add handler for Play Command
        commandCenter.playCommand.addTarget { [unowned self] event in
            if self.player!.rate == 0.0 {
                self.player!.play()
                return .success
            }
            return .commandFailed
        }

        // Add handler for Pause Command
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            if self.player!.rate == 1.0 {
                self.player!.pause()
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.nextTrackCommand.addTarget { event in
            return app().playQueue.goNextTrack() ? .success : .commandFailed;
        }

        commandCenter.previousTrackCommand.addTarget { event in
            return app().playQueue.goSongStartOrPrevTrack() ? .success : .commandFailed;
        }

    }
    
    func setupNowPlaying(node: MEGANode?) {
        
        if let node = node {
        
            var title : String? = node.customTitle;
            if (title == nil) { title = node.name; }
            var artist : String? = node.customArtist;
            if (artist == nil) { artist = "" }
            
            var image : UIImage? = nil;
            if (node.hasThumbnail())
            {
                if (app().storageModel.thumbnailDownloaded(node)) {
                    if let path = app().storageModel.thumbnailPath(node: node) {
                        image = UIImage(contentsOfFile: path);
                    }
                }
            }
            
            var nowPlayingInfo = [String : Any]()
            nowPlayingInfo[MPMediaItemPropertyTitle] = title!;
            nowPlayingInfo[MPMediaItemPropertyArtist] = artist!;
            if image != nil { nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image!.size) { size in return image! } }
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = node.duration / 2;
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = node.duration;
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
        else {
            var nowPlayingInfo = [String : Any]()
            nowPlayingInfo[MPMediaItemPropertyTitle] = "";
            nowPlayingInfo[MPMediaItemPropertyArtist] = "";
            nowPlayingInfo[MPMediaItemPropertyArtwork] = nil;
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0;
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = 0;
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
    }
    
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        player = playQueue.player
        
        do {
//            try AVAudioSessionPatch.setSession(AVAudioSession.sharedInstance(), category: .playback, with: [.defaultToSpeaker, .mixWithOthers])
//            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default, options: [.mixWithOthers, .allowAirPlay])
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback);
            //, mode: AVAudioSession.Mode.default, options: [.mixWithOthers, .allowAirPlay])
////            print("Playback OK")
            try AVAudioSession.sharedInstance().setActive(true)
            
            setupRemoteTransportControls()
//            setupNowPlaying();
// //           print("Session is Active")
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback);
//
//
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

        //if !loginState.loginWritableFolderLink(offline: true, onProgress: { str in }, onFinish: {b in })
        //{
            loginState.goOffline(onProgress: { str in }, onFinish: {b in })
        //}

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        
        playQueue.saveQueueAndHistory(shuttingDown: false);
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        playQueue.saveQueueAndHistory(shuttingDown: true);
    }
    
    var mega : MEGASdk? = nil;
//    var currentLoginVC : LoginVC? = nil;
    var loginState = LoginState();
    var playQueue = PlayQueue();
    var storageModel = StorageModel();
    
    var needsRestoreOnStartup = true;
    
    var musicBrowseFolder : MEGANode? = nil;
    var playlistBrowseFolder : MEGANode? = nil;
    
    var nodeForBrowseFirstLoad : MEGANode? = nil;
    
    var playQueueTVC : PlayQueueTVC? = nil;
    var browseMusicTVC : BrowseTVC? = nil;
    var browsePlaylistsTVC : BrowseTVC? = nil;
    
    var tabBarContoller : MainTabBarController? = nil;
    
    var explanatoryText : String = "";
    
    func clear()
    {
        // get back to on-start state
        loginState.clear();
        playQueue.clear();
        storageModel.clear();

        needsRestoreOnStartup = true;
        musicBrowseFolder = nil;
        playlistBrowseFolder = nil;
        nodeForBrowseFirstLoad = nil;
        if playQueueTVC != nil { playQueueTVC!.clear(); }
        if browseMusicTVC != nil { browseMusicTVC!.clear(); }
        if browsePlaylistsTVC != nil { browsePlaylistsTVC!.clear(); }
        explanatoryText = "";
    }

    func downloadProgress(nodeHandle : UInt64, percent : NSNumber )
    {
        if (playQueueTVC != nil)
        {
            let n = mega!.node(forHandle: nodeHandle)
            if (n != nil && n!.fingerprint != nil) {
                playQueueTVC!.downloadProgress(fingerprint: n!.fingerprint!, percent: percent);
            }
        }
    }
    
    var swipeRightPlaysSong : Bool = true;
    
//    func AddSwipedRightNode(node: MEGANode)
//    {
//        if (swipeRightPlaysSong) { playQueue.queueSong(node: node);}
//        else { swipedRightSet.append(node); }
//    }
    
    func nodePathBetween(_ a: MEGANode?, _ b: MEGANode) -> String
    {
        let textb = Songs__.mega().nodePath(for: b) ?? "";
        let texta = a == nil ? "": (Songs__.mega().nodePath(for: a!) ?? "");
        if (texta == textb)
        {
            return "/";
        }
        else if (textb.hasPrefix(texta))
        {
            if (texta == "/") { return textb; }
            return String(textb.dropFirst(texta.count));
        }
        return textb;
    }

    func nodePath(_ node: MEGANode) -> String
    {
        return nodePathBetween(Songs__.mega().rootNode, node);
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

var accountFolderDoneAlready = false;

func mega(using fileManager : FileManager = .default) -> MEGASdk {
    
    let a = app();
    if (a.mega == nil)
    {
        let path = app().storageModel.accountPath() + "/";
        a.mega = MEGASdk.init(appKey: "dWRWmTiJ", userAgent: "Songs++ " + deviceName(), basePath: path)!;
        a.mega!.add(a.storageModel.transferDelegate);
        a.mega!.add(a.storageModel.megaDelegate);
    }
    return a.mega!;
}

func megaGetLatestFileRevision(_ node : MEGANode?) -> MEGANode?
{
    // check if playlist is updated
    // also check if it even still exists
    var n = mega().node(forHandle: node!.handle);
    while (n != nil) {
        let p = mega().parentNode(for: n!);
        if (p == nil)
        {
            n = nil;
            break;
        }
        if p!.type != .file { break; }
        n = p;
    }
    return n;
}

func megaGetContainingFolder(_ node : MEGANode?) -> MEGANode?
{
    var n = megaGetLatestFileRevision(node);
    if (n != nil) { n = mega().parentNode(for: n!); }
    if (n != nil && n!.type == .file) { n = nil; }
    return n;
}

func shuffleArray(_ a : inout [MEGANode]) -> [MEGANode]
{
    var newQueue : [MEGANode] = []
    while a.count > 0 {
        let row = Int.random(in: 0..<a.count)
        newQueue.append(a[row])
        a.remove(at: row)
    }
    return newQueue;
}

func reportMessage(uic : UIViewController, message : String, continuation : (() -> Void)? = nil)
{
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .cancel));
            uic.present(alert, animated: false, completion: continuation)
    }
}

func CheckOnlineOrWarn(_ warnMessage: String, uic : UIViewController) -> Bool
{
    if app().loginState.online { return true; }
    let alert = UIAlertController(title: "Not Online", message: warnMessage, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .cancel));
    uic.present(alert, animated: false, completion: nil)
    return false;
}


func menuAction_playRightNow(_ node : MEGANode) -> UIAlertAction
{
    return UIAlertAction(title: "Play right now", style: .default, handler:
        { (UIAlertAction) -> () in app().playQueue.playRightNow(node); });
}

func menuAction_playNext(_ node : MEGANode) -> UIAlertAction
{
    return UIAlertAction(title: "Play next", style: .default, handler:
        { (UIAlertAction) -> () in app().playQueue.addSongNext(node); });
}

func menuAction_playLast(_ node : MEGANode) -> UIAlertAction
{
    UIAlertAction(title: "Play last", style: .default, handler:
        { (UIAlertAction) -> () in app().playQueue.addSongLast(node); });
}

func menuAction_songInfo(_ node : MEGANode, viewController : UIViewController) -> UIAlertAction
{
    return UIAlertAction(title: "Info...", style: .default, handler:
        { (UIAlertAction) -> () in
            let vc = app().playQueueTVC?.storyboard?.instantiateViewController(identifier: "EditSongVC") as! EditSongVC;
            vc.node = node;
            viewController.navigationController?.pushViewController(vc, animated: true)
        });
}

func menuAction_songBrowseTo(_ node : MEGANode, viewController : UIViewController) -> UIAlertAction
{
    return UIAlertAction(title: "Browse to", style: .default, handler:
        { (UIAlertAction) -> () in
            app().nodeForBrowseFirstLoad = node;
            app().tabBarContoller?.selectedIndex = 1;
            app().browseMusicTVC?.browseToParent(node);
        });
}

func menuAction_neverMind() -> UIAlertAction
{
    return UIAlertAction(title: "Never mind", style: .cancel);
}

var recentPlaylists : [MEGANode] = [];

func menuAction_addToPlaylistInFolder_recents(_ node : MEGANode, viewController : UIViewController) -> UIAlertAction
{
    return UIAlertAction(title: "Add to Playlist...", style: .default, handler:
        { (UIAlertAction) -> () in
            let alert = UIAlertController(title: nil, message: "Add to Recent Playlist", preferredStyle: .alert)
            
            for i in 0..<recentPlaylists.count {
                
                // check if playlist is updated
                let n : MEGANode? = megaGetLatestFileRevision(recentPlaylists[i]);
                if (n == nil) { continue; }
                
                alert.addAction(menuAction_addToPlaylistExact(playlistNode:n!, nodeToAdd: node, viewController: viewController));
            }
            alert.addAction(menuAction_addToPlaylistInFolder(node, overrideName: "Select from all Playlists...", playlistFolder: app().playlistBrowseFolder!, viewController: viewController));
            alert.addAction(menuAction_neverMind());
            viewController.present(alert, animated: false, completion: nil)
        });
}

func menuAction_addToPlaylistInFolder(_ node : MEGANode, overrideName : String?, playlistFolder : MEGANode, viewController : UIViewController) -> UIAlertAction
{
    return UIAlertAction(title: overrideName != nil ? overrideName : playlistFolder.name + "/ ..."	, style: .default, handler:
        { (UIAlertAction) -> () in
            let alert = UIAlertController(title: nil, message: "Add to Playlist", preferredStyle: .alert)
            
            let list = mega().children(forParent: playlistFolder, order: 1);
            for i in 0..<list.size.intValue {
                let n = list.node(at: i);
                if (n != nil) {
                    if (n!.type == MEGANodeType.file && n!.name.hasSuffix(".playlist"))
                    {
                        alert.addAction(menuAction_addToPlaylistExact(playlistNode: n!, nodeToAdd: node, viewController: viewController));
                    }
                    else if (n!.type != .file)
                    {
                        alert.addAction(menuAction_addToPlaylistInFolder(node, overrideName: nil, playlistFolder: n!, viewController: viewController));
                    }
                }
            }
            alert.addAction(menuAction_neverMind());
            viewController.present(alert, animated: false, completion: nil)
        });
}

func menuAction_addToPlaylistExact(playlistNode : MEGANode, nodeToAdd: MEGANode, viewController : UIViewController) -> UIAlertAction
{
    return UIAlertAction(title: playlistNode.name , style: .default, handler:
        { (UIAlertAction) -> () in
            
            let (json, _) = app().storageModel.getPlaylistFileEditedOrNotAsJSON(playlistNode);
            
            var uploadFolder = mega().parentNode(for: playlistNode);
            while (uploadFolder != nil && uploadFolder!.type == .file)
            {
                uploadFolder = mega().parentNode(for: uploadFolder!);
            }
            if (uploadFolder == nil) { return; }  // todo: alert user
            
            if var nodes = app().playQueue.JSONToNodeHandleArray(json)
            {
                nodes.append(nodeToAdd);
                
                let s = app().playQueue.nodeHandleArrayToJSON(optionalExtraFirstNode: nil, array: nodes);
                
                if let updateFilePath = app().storageModel.playlistPath(node: playlistNode, forEditing: true) {
                    let url = URL(fileURLWithPath: updateFilePath);
                    try! s.write(to: url, atomically: true, encoding: .ascii)
                    
                    for i in 0..<recentPlaylists.count {
                        if (recentPlaylists[i] == playlistNode) {
                            recentPlaylists.remove(at: i);
                            break;
                        }
                    }
                    while (recentPlaylists.count > 5)
                    {
                        recentPlaylists.remove(at: 5);
                    }
                    recentPlaylists.insert(playlistNode, at: 0);
                }
            }
        });
}

func ExtractAndApplyTags(_ node : MEGANode) -> Bool
{
    if (!app().playQueue.isPlayable(node, orMightContainPlayable: false))
    { return true; }
    
    let songPath = app().storageModel.songFingerprintPath(node: node);
    if (songPath == nil) { return false; }

    if !FileManager.default.fileExists(atPath: songPath!)
    { return false; }
    
    var title : NSString? = nil;
    var artist : NSString? = nil;
    var bpm : NSString? = nil;

    if (SongsCPP.getSongProperties(songPath!, title: &title, artist: &artist, bpm: &bpm))
    {
        if (title != nil)
        {
            mega().setCustomNodeAttribute(node, name: "title", value: String(title!), delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in }));
        }
        if (artist != nil)
        {
            mega().setCustomNodeAttribute(node, name: "artist", value: String(artist!), delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in }));
        }
        if (bpm != nil)
        {
            mega().setCustomNodeAttribute(node, name: "BPM", value: String(bpm!), delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in }));
        }
    }
    return true;
}

func RecursiveExtractAndApplyTags(_ node : MEGANode, recursive : Bool, uic : UIViewController)
{
    if (CheckOnlineOrWarn("Please go online so the file attributes can be updated in MEGA", uic: uic))
    {
        if (node.type != .file)
        {
            let list = mega().children(forParent: node, order: 1);
            for i in 0..<list.size.intValue {
                if let n = list.node(at: i) {
                    if (n.type == .file)
                    {
                        _ = ExtractAndApplyTags(n);
                    }
                    else if (recursive)
                    {
                        RecursiveExtractAndApplyTags(n, recursive: 	recursive, uic: uic);
                    }
                }
            }
        }
    }
}



