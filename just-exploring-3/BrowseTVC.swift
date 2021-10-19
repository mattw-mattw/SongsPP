//
//  BrowseTVC.swift
//  just-exploring-3
//
//  Created by Admin on 28/10/2019.
//  Copyright © 2019 mattweir. All rights reserved.
//

import Foundation
import UIKit

class ContextMenuCheckbox : NSObject, UITextFieldDelegate {
    
    var flag : Bool = false;
    var imageButton : UIButton = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50));

    init(_ text: String, _ initial : Bool)
    {
        super.init();
        flag = initial;
        imageButton.setImage(UIImage(systemName: "circle")!, for: .normal)
        imageButton.setImage(UIImage(systemName: "checkmark.circle")!, for: .selected)
        imageButton.setTitle("  " + text, for: .normal);
        imageButton.setTitle("  " + text, for: .selected);
        imageButton.setTitleColor(.label, for: .normal)
        imageButton.setTitleColor(.label, for: .selected)
    }
    
    func takeOverTextField(newTextField : UITextField)
    {
        newTextField.text = ""
        newTextField.isEnabled = true;
        
        flag = !flag;
        toggleCheckbox(newTextField);
        
        newTextField.leftView = imageButton;
        newTextField.leftViewMode = .always;
        
        newTextField.delegate = self;
    }
    
    @objc func toggleCheckbox(_ textField: UITextField) {
        flag = !flag;
        imageButton.isEnabled = true;
        imageButton.isSelected = flag;
        imageButton.addTarget(self, action: #selector(self.toggleCheckbox(_:)), for: .touchUpInside)
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool
    {
        return false;
    }
}

class BrowseTVC: UITableViewController, UITextFieldDelegate {

    var nodeArray : [MEGANode] = [];
    var currentFolder : MEGANode? = nil;
    
    var parentTap : UITapGestureRecognizer?
    
    var topRightButton : UIButton? = nil;
    
    @IBOutlet weak var filterEnableButton: UIButton!
    @IBOutlet weak var filterDownloadedButton: UIButton!
    @IBOutlet weak var folderPathLabelCtrl: UILabel!
    @IBOutlet weak var filterTextCtrl: UITextField!
    @IBOutlet weak var folderNamesIcon: UIButton!
    @IBOutlet weak var trackNamesIcon: UIButton!
    var filtering : Bool = false;
    var filterSearchString : String = "";
    var showingTrackNames : Bool = false;
    
    let filterIncludeDownloaded = ContextMenuCheckbox("Include downloaded", true);
    let filterIncludeNonDownloaded = ContextMenuCheckbox("Include non-downloaded", true);
    
    func clear()
    {
        nodeArray = [];
        currentFolder = nil;
        filtering = false;
        filterIncludeDownloaded.flag = true;
        filterIncludeNonDownloaded.flag = true;
        filterSearchString = "";
        showingTrackNames = false;
        folderPathLabelCtrl.text = "";
        filterTextCtrl.text = "";
        
        showHideFilterElements(filter: false);
        redraw();
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        parentTap = UITapGestureRecognizer(target: self, action: #selector(onParentTap))
        parentTap!.numberOfTapsRequired = 1
        folderPathLabelCtrl.addGestureRecognizer(parentTap!)
        folderPathLabelCtrl.isUserInteractionEnabled = true;
        filterTextCtrl.delegate = self;
        
        showHideFilterElements(filter: false);
        showHideFolderTrackNames()

        if (app().nodeForBrowseFirstLoad != nil && !isPlaylists()) {
            if app().nodeForBrowseFirstLoad!.type == .file {
                browseToParent(app().nodeForBrowseFirstLoad!);
            } else {
                browseToFolder(app().nodeForBrowseFirstLoad!);
            }
        }
        else {
            load(node: rootFolder());
        }
        app().nodeForBrowseFirstLoad  = nil;

        if (isPlaylists()) {
            app().browsePlaylistsTVC = self;
        }
        else {
            app().browseMusicTVC = self;
        }

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
    }
    
    var selectRowOnAppear = -1;
    
    override func viewDidAppear(_ animated: Bool) {
        navigationItem.rightBarButtonItem =
              UIBarButtonItem(title: "Option", style: .done, target: self, action: #selector(optionButton))
        
        if (selectRowOnAppear >= 0 && selectRowOnAppear < nodeArray.count)
        {
            tableView.selectRow(at: IndexPath(row: selectRowOnAppear, section: 0), animated: true, scrollPosition: .middle)
        }
        selectRowOnAppear = -1;
    }
    
    @objc func onParentTap(sender : UITapGestureRecognizer) {
        loadParentFolder()
    }

    @objc func optionButton(sender : UITapGestureRecognizer) {
        let alert = UIAlertController(title: nil, message: "Song actions", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Queue all", style: .default, handler:
            { (UIAlertAction) -> () in self.QueueAll() }));

        alert.addAction(UIAlertAction(title: "Shuffle queue all", style: .default, handler:
            { (UIAlertAction) -> () in self.ShuffleQueueAll() }));

        if (currentFolder != nil)
        {

            if app().loginState.accountBySession && !isPlaylists() && app().musicBrowseFolder == nil {
                alert.addAction(UIAlertAction(title: "Set as the top available folder...", style: .default, handler:
                    { (UIAlertAction) -> () in self.CheckSetAsWritableFolderLink() }));
            }

            if !isPlaylists() && app().musicBrowseFolder == nil {
                alert.addAction(UIAlertAction(title: "Set as the Music Folder...", style: .default, handler:
                    { (UIAlertAction) -> () in self.CheckSetAsMusicFolder() }));
            }
            if isPlaylists() && app().playlistBrowseFolder == nil {
                alert.addAction(UIAlertAction(title: "Set as the Playlist Folder...", style: .default, handler:
                    { (UIAlertAction) -> () in self.CheckSetAsPlaylistFolder() }));
            }
        
            if !isPlaylists() {
                alert.addAction(UIAlertAction(title: "Extract Title/Artist/BPM...", style: .default, handler:
                    { (UIAlertAction) -> () in self.ExtractTitleArtistBPM() }));
            }
        }

        alert.addAction(menuAction_neverMind());
        self.present(alert, animated: false, completion: nil)
    }

    func showHideFilterElements(filter : Bool)
    {
        if isPlaylists() {
            filtering = false;
            filterEnableButton.isHidden = true;
            folderNamesIcon.isHidden = true;
            trackNamesIcon.isHidden = true;
        } else {
            filtering = filter;
        }
        folderPathLabelCtrl.isHidden = filtering;
        filterTextCtrl.isHidden = !filtering;
        filterDownloadedButton.isHidden = !filtering;
        filterTextCtrl.resignFirstResponder();
    }
    
    func showHideFolderTrackNames()
    {
        if isPlaylists() {
            folderNamesIcon.isHidden = true;
            trackNamesIcon.isHidden = true;
        } else {
            folderNamesIcon.isHidden = showingTrackNames;
            trackNamesIcon.isHidden = !showingTrackNames;
        }
    }
    
    @IBAction func onTrackNames(_ sender: UIButton) {
        showingTrackNames = false;
        showHideFolderTrackNames();
        tableView.reloadData();
    }
    
    @IBAction func onFolderNames(_ sender: UIButton) {
        showingTrackNames = true;
        showHideFolderTrackNames();
        tableView.reloadData();
    }
    
    func reFilter()
    {
        filterTextCtrl.resignFirstResponder();
        load(node: currentFolder);
    }
 
    func textFieldShouldReturn(_ textField: UITextField) ->Bool {
        filterSearchString = "";
        if (filterTextCtrl.text != nil) { filterSearchString = filterTextCtrl.text!; }

        filterTextCtrl.resignFirstResponder();
        reFilter();
        return false; // don't do control default, we've processed it
    }

    @IBAction func onFilterButton(_ sender: UIButton) {
        showHideFilterElements(filter: !filtering);
        reFilter();
    }
    
    @IBAction func onFilterTextEdited(_ sender: UIButton) {
        showHideFilterElements(filter: !filtering);
    }
    
    func bullet(_ b : Bool) -> String
    {
        if (b) {
            return "\u{2022}";
        }
        else {
            return "";
        }
    }
    

    @IBAction func onFilterDownloadedButton(_ sender: UIButton) {
        let alert = UIAlertController(title: nil, message: "Filter on cached or not", preferredStyle: .alert)
        
        alert.addTextField( configurationHandler: { newTextField in
            self.filterIncludeDownloaded.takeOverTextField(newTextField: newTextField)
        });
        alert.addTextField( configurationHandler: { newTextField in
            self.filterIncludeNonDownloaded.takeOverTextField(newTextField: newTextField)
        });
        
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (UIAlertAction) -> () in
            self.reFilter();
        }));
        self.present(alert, animated: false, completion: nil)
    }
    
    func CheckSetAsWritableFolderLink()
    {
        let path = app().nodePath(currentFolder!)
        let alert = UIAlertController(title: "Writable Folder Link", message: "Convert from logging in to your whole account to logging in to just this folder: \"" + path + "\". This action will create a Writable Folder Link for this folder, and the app will log into that link instead of your full account.  Use this function on a folder containing your Music and Playlists.  The rest of your account will no longer be loaded by this app, saving resources and improving privacy and convenience.  You can still select subfolders for Music and Playlists afterward.", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Switch login to a Folder Link here", style: .default, handler:
            { (UIAlertAction) -> () in self.SetAsWritableFolderLink()}));

        alert.addAction(UIAlertAction(title: "Never mind", style: .cancel));

        self.present(alert, animated: false, completion: nil)
    }
    
    
    var busyControl : UIAlertController? = nil;
    
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
    
    func SetAsWritableFolderLink()
    {
        if (!app().loginState.online)
        {
            let alert = UIAlertController(title: "Please go online first", message: "Creating a writable folder link requires being online", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel));
            self.present(alert, animated: false, completion: nil)
            return;
        }
        
        startSpinnerControl(message: "Writable Folder Link");
        app().loginState.convertToWritableFolderLink(currentFolder!, 
            onProgress: {(message) in self.busyControl!.message = message + "\n\n";},
            onFinish: { (success) in
                self.busyControl!.dismiss(animated: true);
                self.busyControl = nil;
                if (!success) { reportMessage(uic: self, message: app().loginState.errorMessage) }
            });
    }
    
    func CheckSetAsMusicFolder()
    {
        let path = app().nodePath(currentFolder!)
        let alert = UIAlertController(title: "Set Music Root Folder", message: "Makes folder \"" + path + "\" the root folder for this Music screen, so that the rest of your account cannot be browsed from this view.  Subfolders of this folder can be browsed.  It cannot be changed unless you log out and log in again, or the path is no longer available (eg. by moving or renaming it in the cloud).", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Yes set it", style: .default, handler:
            { (UIAlertAction) -> () in self.SetAsMusicFolder() }));

        alert.addAction(UIAlertAction(title: "Never mind", style: .cancel));

        self.present(alert, animated: false, completion: nil)
    }
    
    func SetAsMusicFolder()
    {
        app().musicBrowseFolder = nil;
        let path = app().nodePath(currentFolder!)
        let _ = app().storageModel.storeSettingFile(leafname : "musicPath", content: path);
        if let musicPath = app().storageModel.loadSettingFile(leafname: "musicPath") {
            app().musicBrowseFolder = mega().node(forPath: musicPath)
        }
        load(node: rootFolder());
    }

    func CheckSetAsPlaylistFolder()
    {
        let path = app().nodePath(currentFolder!)
        let alert = UIAlertController(title: "Set Playlist Root Folder", message: "Makes folder \"" + path + "\" the root folder for this Playlist screen, so that the rest of your account cannot be browsed from this view.  Subfolders of this folder can be browsed.  It cannot be changed unless you log out and log in again, or the path is no longer available (eg. by moving or renaming it in the cloud).", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Yes set it", style: .default, handler:
            { (UIAlertAction) -> () in self.SetAsPlaylistFolder() }));

        alert.addAction(UIAlertAction(title: "Never mind", style: .cancel));

        self.present(alert, animated: false, completion: nil)
    }
    
    func SetAsPlaylistFolder()
    {
        app().playlistBrowseFolder = nil;
        let path = app().nodePath(currentFolder!)
        let _ = app().storageModel.storeSettingFile(leafname : "playlistPath", content: path);
        // TODO: for writable folder links, this, for sessions, mega().nodePath()
        if let playlistPath = app().storageModel.loadSettingFile(leafname: "playlistPath") {
            app().playlistBrowseFolder = mega().node(forPath: playlistPath)
        }
        load(node: rootFolder());
    }
    
    @objc func checkBoxAction(_ sender: UIButton)
    {
        if sender.isSelected
        {
            sender.isSelected = false
            let btnImage    = UIImage(systemName: "checkmark.circle")!
            sender.setBackgroundImage(btnImage, for: UIControl.State())
        }else {
            sender.isSelected = true
            let btnImage    = UIImage(systemName: "circle")!
            sender.setBackgroundImage(btnImage, for: UIControl.State())
        }
    }
    
    let extractTagsOverwritesExistingTagsCheckbox = ContextMenuCheckbox("Overwrite existing tags", false);
    let extractTagsProcessSubfolders = ContextMenuCheckbox("Process all subfolders", true);

    func ExtractTitleArtistBPM()
    {

        let alert = UIAlertController(title: "Extract Title/Artist/BPM", message: "This operation will try to extract the song track Title, Artist, and BPM from tags in the song files in this folder (and optionally folders below), for those song files that are downloaded already.", preferredStyle: .alert)
        
//        let btnImage    = UIImage(systemName: "checkmark.circle")!
//        let imageButton : UIButton = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
//        imageButton.setBackgroundImage(btnImage, for: UIControl.State())
//        imageButton.addTarget(self, action: #selector(checkBoxAction(_:)), for: .touchUpInside)
//        alert.view.addSubview(imageButton)

        alert.addTextField( configurationHandler: { newTextField in
            self.extractTagsOverwritesExistingTagsCheckbox.takeOverTextField(newTextField: newTextField)
        });
        alert.addTextField( configurationHandler: { newTextField in
            self.extractTagsProcessSubfolders.takeOverTextField(newTextField: newTextField)
        });

        alert.addAction(UIAlertAction(title: "Extract now", style: .default, handler: {
            (UIAlertAction) -> () in ExtractAndApplyTags(
                self.currentFolder!,
                recursive: self.extractTagsProcessSubfolders.flag,
                overwriteExistingTags: self.extractTagsOverwritesExistingTagsCheckbox.flag,
                uic: self);() }));

//        alert.addAction(UIAlertAction(title: "Extract here and all subfolders", style: .default, handler:
//            { (UIAlertAction) -> () in RecursiveExtractAndApplyTags(self.currentFolder!, recursive: true, uic: self); }));

        alert.addAction(UIAlertAction(title: "Never mind", style: .cancel));

        self.present(alert, animated: false, completion: nil)
    }

    func nodeListToNodeArray(list : MEGANodeList?) -> [MEGANode]
    {
        var nodes : [MEGANode] = [];
        if (list != nil) {
            for i in 0..<list!.size.intValue {
                nodes.append(list!.node(at: i))
            }
        }
        return nodes;
    }

    func QueueAll()
    {
        var v : [MEGANode] = [];
        for n in nodeArray {
            app().storageModel.loadSongsFromNodeRecursive(node: n, &v);
        }
        app().playQueue.queueSongs(nodes: v)
    }

    func ShuffleQueueAll()
    {
        var v : [MEGANode] = [];
        for n in nodeArray {
            app().storageModel.loadSongsFromNodeRecursive(node: n, &v);
        }
        app().playQueue.queueSongs(nodes: shuffleArray(&v));
    }

    func checkFiltered(_ n : MEGANode) -> Bool
    {
        var select = false;
        if (n.name.lowercased().contains(filterSearchString.lowercased()))
        {
            select = true;
        }
        if (n.customTitle != nil && !select)
        {
            select = n.customTitle!.lowercased().contains(filterSearchString.lowercased())
        }
        if (n.customArtist != nil && !select)
        {
            select = n.customArtist!.lowercased().contains(filterSearchString.lowercased())
        }
        if (n.customNotes != nil && !select)
        {
            select = n.customNotes!.lowercased().contains(filterSearchString.lowercased())
        }
        if (n.customBPM != nil && !select)
        {
            select = n.customBPM!.lowercased().contains(filterSearchString.lowercased())
        }
        if (!filterIncludeDownloaded.flag && select)
        {
            if (app().storageModel.fileDownloadedByType(n))
            {
                select = false;
            }
        }
        else if (!filterIncludeNonDownloaded.flag && select)
        {
            if (!app().storageModel.fileDownloadedByType(n))
            {
                select = false;
            }
        }
        return select;
    }
    
    func AddFilteredNodes(parent : MEGANode)
    {
        let list = mega().children(forParent: parent, order: 1);
        for i in 0..<list.size.intValue {
            let n = list.node(at: i);
            if (filtering && n?.type != MEGANodeType.file)
            {
                AddFilteredNodes(parent: n!);
            }
            else if (!filtering || checkFiltered(n!))
            {
                nodeArray.append(n!)

                if (isPlaylists() && n!.name.hasSuffix(".playlist")) {
                    _ = app().storageModel.startDownloadIfAbsent(node: n!);
                }

            }
        }
    }
    
    func browseToFolder(_ node : MEGANode)
    {
        showHideFilterElements(filter: false);
        load(node: node);
    }
    
    func browseToParent(_ node : MEGANode)
    {
        showHideFilterElements(filter: false);
        load(node: mega().parentNode(for: node));
        redraw()
        hilight(node: node);
    }
    
    func hilight(node: MEGANode)
    {
        var row = 0;
        for n in nodeArray {
            if n.handle == node.handle { break }
            row += 1;
        }
        if (row < nodeArray.count)
        {
            if viewIfLoaded?.window != nil {
                tableView.selectRow(at: IndexPath(row: row, section: 0), animated: true, scrollPosition: .middle)
            }
            else
            {
                selectRowOnAppear = row;
            }
        }
    }
    
    func load(node : MEGANode?)
    {
        if node != nil && rootFolder() != nil {
            let np = app().nodePath(node!);
            let rp = app().nodePath(rootFolder()!);
            if !np.hasPrefix(rp) { return; }
        }
        currentFolder = node;
        nodeArray = [];

        var text : String? = nil;

        if (currentFolder == nil && !isPlaylists() && app().musicBrowseFolder != nil) {
            currentFolder = app().musicBrowseFolder;
            text = "/";
        }

        if (currentFolder == nil && isPlaylists() && app().playlistBrowseFolder != nil) {
            currentFolder = app().playlistBrowseFolder;
            text = "/";
        }

        if (currentFolder == nil && app().loginState.accountByFolderLink) {
            currentFolder = mega().rootNode;
            text = "/";
        }
    
        if (currentFolder != nil) {
            AddFilteredNodes(parent: currentFolder!);
            text = app().nodePath(currentFolder!);
        }
        
        if (currentFolder == nil && app().loginState.accountBySession) {
            if (mega().rootNode != nil) {
                text = "<Your Account>";
                nodeArray.append(mega().rootNode!);
                let shares = mega().inSharesList(MEGASortOrderType.alphabeticalAsc)
                for i in 0..<shares.size.intValue {
                    if let n = mega().node(forHandle: shares.share(at: i).nodeHandle) {
                        nodeArray.append(n);
                    }
                }
            }
        }

        if (folderPathLabelCtrl != nil)
        {
            folderPathLabelCtrl.text = text == nil ? "" : text;
        }
        tableView.reloadData();
    }
    
    var nodesChanged: Bool = false;
    var folderChanged: Bool = false;
    
    func nodesChanging(_ node: MEGANode)
    {
        if (replaceNodeIn(node, &nodeArray)) {
            nodesChanged = true;
            if (node.isRemoved() || (currentFolder != nil && node.parentHandle != currentFolder!.handle))
            {
                folderChanged = true;
            }
        }
        if (currentFolder != nil &&
           (currentFolder!.handle == node.parentHandle ||
            currentFolder!.handle == node.handle))
        {
            folderChanged = true;
            if (currentFolder!.handle == node.handle)
            {
                currentFolder = node;
            }
        }
    }
    func nodesFinishedChanging()
    {
        if (folderChanged)
        {
            load(node: currentFolder);
        }
        else if (nodesChanged)
        {
            redraw();
        }
        nodesChanged = false;
        folderChanged = false;
    }
    
    func loadParentFolder()
    {
        if (currentFolder != nil && currentFolder != rootFolder())
        {
            browseToParent(currentFolder!);
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
        if isPlaylists() {
            return app().playlistBrowseFolder;
        } else {
            return app().musicBrowseFolder;
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
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
        return nodeArray.count;
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let node = indexPath.row < nodeArray.count ? nodeArray[indexPath.row] : nil;

        var cell : UITableViewCell?
        
        if (node != nil && (node!.type == MEGANodeType.folder || !showingTrackNames))
        {
            cell = tableView.dequeueReusableCell(withIdentifier: "FolderCell", for: indexPath)
            cell!.textLabel?.text = node!.name + (node!.type == MEGANodeType.folder ? "/" : "");
        }
        else
        {
            cell = tableView.dequeueReusableCell(withIdentifier: filtering ? "MusicCellWithNotes" : "MusicCell", for: indexPath)
            if (node != nil)
            {
                if let mCell = cell as? TableViewMusicCellWithNotes {
                    mCell.populateFromNode(node!);
                    mCell.notesLabel?.text = app().nodePathBetween(currentFolder, node!);
                }
                else if let mCell = cell as? TableViewMusicCell {
                    mCell.populateFromNode(node!);
                }
            }
        }

        return cell!
    }
    
    override func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let node = indexPath.row < nodeArray.count ? nodeArray[indexPath.row] : nil;
        return node == nil || node!.isFolder() || !showingTrackNames || !filtering ? 43.5 : 70;
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        if (self.presentedViewController != nil) {
            // it was a tap-hold for menu
            return;
        }

        tableView.deselectRow(at: indexPath, animated: false)
        if (indexPath.row < nodeArray.count)
        {
            let node = nodeArray[indexPath.row]
            if (node.type == MEGANodeType.folder || node.type == MEGANodeType.root)
            {
                DispatchQueue.main.async( execute: { self.load(node: node) } );
            }
            else if (node.type == MEGANodeType.file && node.name.hasSuffix(".playlist"))
            {
                let vc = self.storyboard?.instantiateViewController(identifier: "Playlist") as! PlaylistTVC
                vc.playlistToLoad = node;
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return true;
    }
    
    override func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
    }
    
//    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
//        let node = nodeArray[indexPath.row];
//        let action = UIContextualAction(style: .normal, title: "Add to swiped-right set", handler:
//            {   (ac: UIContextualAction, view:UIView, success: (Bool)->Void) in
//                app().AddSwipedRightNode(node: node)
//                tableView.reloadData();
//            })
//        action.backgroundColor = .green
//        let v = UISwipeActionsConfiguration(actions: [action]);
//        v.performsFirstActionWithFullSwipe = true;
//        return v;
//    }
    
    override func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool
    {
        // long press to show menu for song
        if (indexPath.row < nodeArray.count)
        {
            let node = nodeArray[indexPath.row];
            
            let alert = UIAlertController(title: nil, message: "Song actions", preferredStyle: .alert)
            
            if app().playQueue.isPlayable(node, orMightContainPlayable: true) {
                alert.addAction(menuAction_playNext(node));
                alert.addAction(menuAction_playLast(node));
            }
            if app().playQueue.isPlayable(node, orMightContainPlayable: false) {
                alert.addAction(menuAction_songInfo(node, viewController: self));
            }
            if app().playQueue.isArtwork(node) && app().storageModel.thumbnailDownloaded(node) {
                alert.addAction(UIAlertAction(title: "Set as artwork for songs in this folder", style: .default, handler:
                      { (UIAlertAction) -> () in self.setArtworkForSongsInFolder(node); }));
            }
            if (filtering) {
                alert.addAction(menuAction_songBrowseTo(node, viewController: self));
            }
            if (app().playlistBrowseFolder != nil && app().playQueue.isPlayable(node, orMightContainPlayable: false)) {
                alert.addAction(menuAction_addToPlaylistInFolder_recents(node, viewController: self));
            }
            alert.addAction(UIAlertAction(title: "Never mind", style: .cancel));
            self.present(alert, animated: false, completion: nil)
        }
        
        return false;
    }
    
    func redraw()
    {
        tableView.reloadData();
    }

    
    func setArtworkForSongsInFolder(_ node : MEGANode)
    {
        if (!app().loginState.online)
        {
            let alert = UIAlertController(title: "Please go online first", message: "Setting artwork for files requires being online", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel));
            self.present(alert, animated: false, completion: nil)
            return;
        }
        
        if let parent = mega().parentNode(for: node) {
        
            if let thumbnailFile = app().storageModel.thumbnailPath(node: node) {
                let list = mega().children(forParent: parent, order: 1);
                for i in 0..<list.size.intValue {
                    if let n = list.node(at: i) {
                        if (app().playQueue.isPlayable(n, orMightContainPlayable: false))
                        {
                            mega().setThumbnailNode(n, sourceFilePath: thumbnailFile, delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in
                                app().storageModel.megaDelegate.onThumbnailUpdate(node: node)
                            } ));
                        }
                    }
                }
            }
        }
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
