//
//  AVPlayerVC.swift
//  just-exploring-3
//
//  Created by Admin on 28/10/2019.
//  Copyright © 2019 mattweir. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import AVKit
import MediaPlayer

//class AVPlayerVC: AVPlayerViewController {
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        self.player = app().playQueue.player;
//        self.updatesNowPlayingInfoCenter = true;
//        //self.appliesPrefferredDisplayCriteriaAutomatically = true;
//    }
//
////    override func viewWillAppear(_ animated: Bool) {
////        super.viewWillAppear(animated);
////
////        if (self.player == nil || self.player!.currentItem == nil)
////        {
////            playNext(startIt: false);
////        }
////    }
////
//    func updateNowPlaying()
//    {
//        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
//            MPMediaItemPropertyTitle: "track title",
//            MPMediaItemPropertyArtist: "track artiste"
//        ];
//    }
//
//    @objc func mediaDidStart()
//    {
//        shouldBePlaying = true;
//        //updateNowPlaying();
//
//        do {
//            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowAirPlay])
//            print("Playback OK")
//            try AVAudioSession.sharedInstance().setActive(true)
//            print("Session is Active")
//        } catch {
//            print(error)
//        }
//    }
//
//    var shouldBePlaying = false;
//
//
////    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
////        if object as AnyObject? === self.player {
////            if keyPath == "status" {
////                if self.player?.status == .readyToPlay {
////                    mediaDidStart();
////                }
////            }
////        }
////    }
//
//}
