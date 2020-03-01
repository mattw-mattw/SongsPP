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
//        do {
////            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default, options: [.mixWithOthers, .allowAirPlay])
////            print("Playback OK")
//  //          try AVAudioSession.sharedInstance().setActive(true)
// //           print("Session is Active")
//            //try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback);
//
//            //try AVAudioSessionPatch.setSession(AVAudioSession.sharedInstance(), category: .playback, with: [.defaultToSpeaker, .mixWithOthers])
//
// //           application.beginReceivingRemoteControlEvents();
//        } catch {
//            print(error)
//        }
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
    
    var swipedRightSet : [MEGANode] = [];
    
    var playQueueTVC : PlayQueueTVC? = nil;
    var tabBarContoller : MainTabBarController? = nil;

    func downloadProgress(nodeHandle : UInt64, percent : NSNumber )
    {
        if (playQueueTVC != nil)
        {
            playQueueTVC!.downloadProgress(nodeHandle, percent);
        }
    }
    
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

