//
//  TableViewMusicCell.swift
//  SongMe
//
//  Created by Admin on 12/11/2019.
//  Copyright © 2019 mattweir. All rights reserved.
//

import UIKit

class TableViewMusicCell: UITableViewCell {

    @IBOutlet weak var progressBar: UIProgressView?
    
    var node : MEGANode?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
