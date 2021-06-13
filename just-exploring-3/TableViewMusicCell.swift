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
    
    var node : MEGANode?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func populateFromNode(_ n : MEGANode)
    {
        node = n;
        
        var title : String? = node?.customTitle;
        if (title == nil) { title = node?.name; }
        titleLabel.text = title!;

        var bpm : String? = node?.customBPM;
        if (bpm == nil) { bpm = ""; }
        bpmLabel.text = bpm!;

        var artist : String? = node?.customArtist;
        if (artist == nil) { artist = "" }
        artistLabel.text = artist!;

        thumbnailView.image = nil;
        durationLabel.text = "";

        if (node != nil) {
            if (node!.isFolder()) {
                durationLabel.text = String("Folder")
            } else {
                durationLabel.text = String(format: "%02d:%02d", node!.duration / 60, node!.duration % 60)
            }
        
            if (node!.hasThumbnail())
            {
                if (app().storageModel.thumbnailDownloaded(node!)) {
                    if let path = app().storageModel.thumbnailPath(node: node!) {
                        if let image = UIImage(contentsOfFile: path) {
                            
                            //cell.imageView!.frame = CGRect(x: cell.imageView!.frame.origin.x
                            //ycell.imageView!.frame.origin.y,width: 40, height: 40)
                            //cell.imageView!.autoresizingMask = [.flexibleWidth]
                            //cell.imageView!.translatesAutoresizingMaskIntoConstraints = true;
                            //cell.imageView!.contentMode = .;
                            thumbnailView.image = image;
                        }
                    }
                }
            }
        }
        
        if (progressBar != nil)
        {
            contentView.bringSubviewToFront(progressBar);
        
            let exists = node != nil ? app().storageModel.fileDownloaded(node!) : false;

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
    
    override func populateFromNode(_ node : MEGANode)
    {
        super.populateFromNode(node);
        
        let notes : String? = node.customNotes;

        if (notes != nil) {
            notesLabel.text = notes!;
        }
    }

}

