//
//  BrowseTVC.swift
//  just-exploring-3
//
//  Created by Admin on 28/10/2019.
//  Copyright © 2019 mattweir. All rights reserved.
//

import Foundation
import UIKit

class BrowseTVC: UITableViewController {

    var nodeList : MEGANodeList? = nil;
    var currentFolder : MEGANode? = nil;
    
    var parentTap : UITapGestureRecognizer?
    
    var topRightButton : UIButton? = nil;
    
    override func viewDidLoad() {
        super.viewDidLoad()

        parentTap = UITapGestureRecognizer(target: self, action: #selector(onParentTap))
        parentTap!.numberOfTapsRequired = 1
        folderPathLabelCtrl.addGestureRecognizer(parentTap!)
        folderPathLabelCtrl.isUserInteractionEnabled = true;
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        
//        topRightButton = UIButton(type: .custom);
//        topRightButton!.setTitle("Option", for: .normal)
//        topRightButton!.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
//        topRightButton!.addTarget(self, action: #selector(onTopRightButton), for: .touchUpInside)
//        let item1 = UIBarButtonItem(customView: topRightButton!)
//        self.navigationItem.rightBarButtonItem = item1;
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if (app().tabBarContoller != nil) {
            app().tabBarContoller!.navigationItem.rightBarButtonItem =
                  UIBarButtonItem(title: "Option", style: .done, target: self, action: #selector(optionButton))
        }
    }
    
    @objc func onParentTap(sender : UITapGestureRecognizer) {
        loadParentFolder()
    }

    @objc func optionButton(sender : UITapGestureRecognizer) {
        let alert = UIAlertController(title: nil, message: "Song actions", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Queue all", style: .default, handler:
            { (UIAlertAction) -> () in self.QueueAll() }));
              
        alert.addAction(UIAlertAction(title: "Never mind", style: .cancel));
        self.present(alert, animated: false, completion: nil)
    }
    
    func QueueAll()
    {
        if (nodeList != nil)
        {
            var nodes : [MEGANode] = [];
            for i in 0..<nodeList!.size.intValue {
                nodes.append(nodeList!.node(at: i))
            }
            app().playQueue.queueSongs(nodes: nodes)
        }
    }

    @IBOutlet weak var folderPathLabelCtrl: UILabel!
    
    func load(node : MEGANode?)
    {
        currentFolder = node;
        nodeList = node == nil ? nil : mega().children(forParent: currentFolder!, order: 1)
        tableView.reloadData();
        var text : String? = nil;
        if (node != nil)
        {
            text = mega().nodePath(for: node!);
            if (text != nil)
            {
                print("listing for " + text!);
                if (text != nil) {
                    let n = text!.firstIndex(of: "/");
                    if (n != nil)
                    {
                        text! = String.init(text!.suffix( from: n!));
                    }
                }
            }
        }
        if (folderPathLabelCtrl != nil)
        {
            folderPathLabelCtrl.text = text == nil ? "" : text;
        }
    }
    
    func loadParentFolder()
    {
        if (currentFolder != nil && currentFolder != rootFolder())
        {
            let parent = mega().parentNode(for: currentFolder!)
            if (parent != nil)
            {
                load(node: parent);
            }
        }
    }
    
    @IBAction func onNavigateParentButtonClicked(_ sender: UIButton) {
        loadParentFolder()
    }
    
    func isPlaylists() -> Bool
    {
        return self.title == "Playlists";
    }
    
    func rootFolder() -> MEGANode?
    {
        return isPlaylists() ? app().playlistBrowseFolder : app().musicBrowseFolder;
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        load(node: rootFolder());
    }

    // MARK: - Table view data source

//    override func tableView(_ tableView : UITableView, accessoryButtonTappedForRowWith: IndexPath)
//    {
//        let node = nodeList?.node(at: accessoryButtonTappedForRowWith.row)
//        if (node!.type != MEGANodeType.file)
//        {
//            load(node: node);
//        }
//    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return nodeList == nil ? 0 : nodeList!.size.intValue
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let node = nodeList?.node(at: indexPath.row)
        
        let cell = tableView.dequeueReusableCell(withIdentifier: node?.type == MEGANodeType.folder ? "FolderCell" : "MusicCell", for: indexPath)

        if (node!.type == MEGANodeType.folder)
        {
            cell.textLabel?.text = node!.name + "/";
        }
        else
        {
            cell.textLabel?.text = node!.name
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // tap a row to drill into it, if it's a folder
        tableView.deselectRow(at: indexPath, animated: false)
        if (indexPath.row < nodeList!.size.intValue)
        {
            let node = nodeList?.node(at: indexPath.row)
            if (node?.type == MEGANodeType.folder)
            {
                DispatchQueue.main.async( execute: { self.load(node: node) } );
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
            
//            let alert = UIAlertController(title: nil, message: "Song actions", preferredStyle: .alert)
//            if (node!.type == MEGANodeType.file)
//            {
//                alert.addAction(UIAlertAction(title: "Queue to Play", style: .default, handler: { (UIAlertAction) -> () in app().queueSong(node: node!) }));
//                alert.addAction(UIAlertAction(title: "Play Next", style: .default, handler: { (UIAlertAction) -> () in app().queueSongNext(node: node!) }));
//            }
//            else
//            {
//                alert.addAction(UIAlertAction(title: "Enter folder", style: .default, handler: { (UIAlertAction) -> () in self.load(node: node) }));
//            }
//            alert.addAction(UIAlertAction(title: "Never mind", style: .cancel));
//            self.present(alert, animated: false, completion: nil)
        
        
        return false;
    }
    
    override func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return true;
    }
    
    override func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
    }
    
    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let node = nodeList?.node(at: indexPath.row)
        let action = UIContextualAction(style: .normal, title: "Add to swiped-right set", handler:
            {   (ac: UIContextualAction, view:UIView, success: (Bool)->Void) in
                app().AddSwipedRightNode(node: node!)
                tableView.reloadData();
            })
        action.backgroundColor = .green
        let v = UISwipeActionsConfiguration(actions: [action]);
        v.performsFirstActionWithFullSwipe = true;
        return v;
    }
    
    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
