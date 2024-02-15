//
//  EditSongVC.swift
//  SongMe
//
//  Created by Matt Weir on 5/03/20.
//  Copyright © 2020 mattweir. All rights reserved.
//

import Foundation
import UIKit

class EditSongVC: UIViewController, UITextFieldDelegate {
    
    var node : MEGANode? = nil;
    @IBOutlet weak var titleText: UITextField!
    @IBOutlet weak var artistText: UITextField!
    @IBOutlet weak var notesText: UITextField!
    @IBOutlet weak var bpmText: UITextField!
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var filePathLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleText.delegate = self;
        artistText.delegate = self;
        notesText.delegate = self;
        bpmText.delegate = self;
    }
    
    func textFieldShouldReturn(_ textField: UITextField) ->Bool {
        titleText.resignFirstResponder();
        artistText.resignFirstResponder();
        notesText.resignFirstResponder();
        bpmText.resignFirstResponder();
        return false; // don't do control default, we've processed it
    }
    
    func goOnline()
    {
        let spinner = ProgressSpinner(uic: self, title: "Going Online", message: "");

        globals.loginState.goOnline(spinner: spinner,
            onFinish: { (success) in
                spinner.dismissOrReportError(success: success)
        })
    }
    
    var saveAllSpinner : ProgressSpinner? = nil;

    var pending : Int = 0;
    var setAttrError : MEGAError? = nil;
    func setAttrDone(_ e : MEGAError)
    {
        pending -= 1;
        if (e.type != .apiOk) { setAttrError = e; }
        if (pending <= 0 && saveAllSpinner != nil) {
            self.saveAllSpinner!.dismiss();
            self.saveAllSpinner = nil;
            if (setAttrError != nil && setAttrError!.type != .apiOk) {
                reportMessage(uic: self, message: "Attribute set failed: " + e.nameWithErrorCode(setAttrError!.type.rawValue));
            }
        }
    }
    
    @IBAction func ExtractTagsHit(_ sender : Any) {

        if (node == nil) { return; }
        
        var title : NSString? = nil;
        var artist : NSString? = nil;
        var bpm : NSString? = nil;

        let songPath = globals.storageModel.songFingerprintPath(node: node!);
        if (songPath == nil) { return; }

        if (SongsCPP.getSongProperties(songPath!, title: &title, artist: &artist, bpm: &bpm)) {
            
            titleText.text = title == nil ? "" : title! as String;
            artistText.text = artist == nil ? "": artist! as String;
            bpmText.text = bpm == nil ? "": bpm! as String;
        }
    }
    
    @IBAction func SaveAllHit(_ sender: Any) {
        if node == nil { return; }
        if !globals.loginState.online { goOnline(); }
        if !globals.loginState.online { return; }
        
        saveAllSpinner = ProgressSpinner(uic: self, title: "Saving song data", message: "");

        setAttrError = nil;
        pending += 4;
        mega().setCustomNodeAttribute(node!, name: "title", value: titleText.text!, delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in self.setAttrDone(e) }));
        mega().setCustomNodeAttribute(node!, name: "artist", value: artistText.text!, delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in self.setAttrDone(e) }));
        mega().setCustomNodeAttribute(node!, name: "BPM", value: bpmText.text!, delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in self.setAttrDone(e) }));
        mega().setCustomNodeAttribute(node!, name: "notes", value: notesText.text!, delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in self.setAttrDone(e) }));
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if (node != nil)
        {
            var title : String? = node!.customTitle;
            if (title == nil) { title = node!.name; }
            var bpm : String? = node!.customBPM;
            if (bpm == nil) { bpm = ""; }
            var artist : String? = node!.customArtist;
            if (artist == nil) { artist = "" }
            var notes : String? = node!.customNotes;
            if (notes == nil) { notes = "" }

            titleText.text = title!;
            bpmText.text = bpm!;
            artistText.text = artist!;
            notesText.text = notes!;
            filePathLabel.text = app().nodePath(node!);
            
            image.image = nil;
            if (node!.hasThumbnail())
            {
                if (globals.storageModel.thumbnailDownloaded(node!)) {
                    if let path = globals.storageModel.thumbnailPath(node: node!) {
                        if let imagefile = UIImage(contentsOfFile: path) {
                            image.image = imagefile;
                        }
                    }
                }
            }
        }
        else
        {
            titleText.text = "";
            artistText.text = "";
            notesText.text = "";
            bpmText.text = "";
            image.image = nil;
            filePathLabel.text = "";
        }
    }
    
    var lastTap = DispatchTime(uptimeNanoseconds: 0)
    var firstTap = DispatchTime(uptimeNanoseconds: 0)
    var tapCount : UInt64 = 0;

    @IBAction func TapBeatHit(_ sender: Any) {
        let t = DispatchTime.now()
        if (lastTap.uptimeNanoseconds + 3000000000 < t.uptimeNanoseconds)
        {
            firstTap = t;
            lastTap = t;
            tapCount = 0;
            bpmText.text = "";
        }
        else
        {
            lastTap = t;
            tapCount += 1;
            let b : UInt64 = tapCount * 60 * 1000000000 / (lastTap.uptimeNanoseconds - firstTap.uptimeNanoseconds);
            bpmText.text = "\(b)"
        }
    }
    
}

