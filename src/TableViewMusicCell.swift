//
//  TableViewMusicCell.swift
//  SongMe
//
//  Created by Admin on 12/11/2019.
//  Copyright © 2019 mattweir. All rights reserved.
//

import UIKit

class TableViewMusicCell: UITableViewCell {

    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var bpmLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var thumbnailView: UIImageView!
    @IBOutlet var isPlayingIndicator_noHistory: UIImageView?
    
    //var node : MEGANode?
    var songAttr : [String : String] = [:];
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func populateFromSongAttr(_ attr : [String : String])
    {
        //node = n;
        songAttr = attr;
        
        var title : String? = attr["title"];
        if (title == nil) {
            title = attr["npath"];
            if title != nil {
                title = leafName(title!);
            }
        }
        if (title == nil) { title = "<unknown>"; }
        titleLabel.text = title!;
        var bpm : String? = attr["bpm"]
        if (bpm == nil) { bpm = ""; }
        bpmLabel.text = bpm!;

        var artist : String? = attr["artist"] ?? "";
        if (artist == nil) { artist = "" }
        artistLabel.text = artist!;

        var durat : String? = attr["durat"]
        if (durat == nil) { durat = "" }
        durationLabel.text = durat!;

        thumbnailView.image = nil;

        if let thumb = attr["thumb"] {
            let path = Path(rp: thumb, r: .ThumbFile, f: false);
            if let image = UIImage(contentsOfFile: path.fullPath()) {
                thumbnailView.image = image;
            }
        }
        
        if (progressBar != nil)
        {
            contentView.bringSubviewToFront(progressBar);
        
            let exists = true; //node != nil ? globals.storageModel.fileDownloadedByType(node!) : false;

            progressBar.isHidden = !exists;
            progressBar.progress = exists ? 100 : 0;
            progressBar.setNeedsDisplay();
        }
        
        if (isPlayingIndicator_noHistory != nil)
        {
            isPlayingIndicator_noHistory!.isHidden = true;
        }
    }
}

class TableViewMusicCellWithNotes: TableViewMusicCell {

    @IBOutlet weak var notesLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    override func populateFromSongAttr(_ attr : [String : String])
    {
        super.populateFromSongAttr(attr);
        
        let notes : String? = attr["notes"];

        if (notes != nil) {
            notesLabel.text = notes!;
        }
    }

}

