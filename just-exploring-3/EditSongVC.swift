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
    
    var busyControl : UIAlertController? = nil;

    
    func textFieldShouldReturn(_ textField: UITextField) ->Bool {
        titleText.resignFirstResponder();
        artistText.resignFirstResponder();
        notesText.resignFirstResponder();
        bpmText.resignFirstResponder();
        return false; // don't do control default, we've processed it
    }
    
    func startSpinnerControl(message : String)
    {
        busyControl = UIAlertController(title: nil, message: message + "\n\n", preferredStyle: .alert)
        let spinnerIndicator = UIActivityIndicatorView(style: .large)
        spinnerIndicator.center = CGPoint(x: 135.0, y: 65.5)
        spinnerIndicator.color = UIColor.black
        spinnerIndicator.startAnimating()
        busyControl!.view.addSubview(spinnerIndicator)
        self.present(busyControl!, animated: false, completion: nil)
    }
    
    func goOnline()
    {
        startSpinnerControl(message: "Going Online");
        app().loginState.goOnline(
            onProgress: {(message) in self.busyControl!.message = message + "\n\n";},
            onFinish: { (success) in
                self.busyControl!.dismiss(animated: true);
                self.busyControl = nil;
                if (!success) { reportMessage(uic: self, message: app().loginState.errorMessage); }
        })
    }

    var pending : Int = 0;
    var setAttrError : MEGAError? = nil;
    func setAttrDone(_ e : MEGAError)
    {
        pending -= 1;
        if (e.type != .apiOk) { setAttrError = e; }
        if (pending <= 0) {
            self.busyControl!.dismiss(animated: true);
            self.busyControl = nil;
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

        let songPath = app().storageModel.songFingerprintPath(node: node!);
        if (songPath == nil) { return; }

        if (SongsCPP.getSongProperties(songPath!, title: &title, artist: &artist, bpm: &bpm)) {
            
            titleText.text = title == nil ? "" : title! as String;
            artistText.text = artist == nil ? "": artist! as String;
            bpmText.text = bpm == nil ? "": bpm! as String;
        }
    }
    
    @IBAction func SaveAllHit(_ sender: Any) {
        if node == nil { return; }
        if !app().loginState.loggedInOnline { goOnline(); }
        if !app().loginState.loggedInOnline { return; }
        
        startSpinnerControl(message: "Saving song data");

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
            filePathLabel.text = mega().nodePath(for: node!);
            
            image.image = nil;
            if (node!.hasThumbnail())
            {
                if (app().storageModel.thumbnailDownloaded(node!)) {
                    if let path = app().storageModel.thumbnailPath(node: node!) {
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

