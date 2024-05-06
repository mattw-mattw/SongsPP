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
        imageButton.addTarget(self, action: #selector(self.toggleCheckbox(_:)), for: .touchUpInside)

        newTextField.leftView = imageButton;
        newTextField.leftViewMode = .always;
        
        newTextField.delegate = self;
    }
    
    @objc func toggleCheckbox(_ textField: UITextField) {
        flag = !flag;
        imageButton.isEnabled = true;
        imageButton.isSelected = flag;
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool
    {
        return false;
    }
}

class BrowseTVC: UITableViewController, UITextFieldDelegate {

    var nodeArray : [Path] = [];
    var currentFolder : Path? = nil;
    
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
            if !app().nodeForBrowseFirstLoad!.isFolder {
                browseToParent(app().nodeForBrowseFirstLoad!);
            } else {
                browseToFolder(app().nodeForBrowseFirstLoad!);
            }
        }
        else {
            load(rootFolder());
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
        
//        // in case cache was wiped
//        if (isPlaylists())
//        {
//            for n in nodeArray {
//                if n.name != nil &&
//                   n.name!.hasSuffix(".playlist")
//                {
//                    _ = globals.storageModel.startDownloadIfAbsent(node: n);
//                }
//            }
//        }
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

//            if globals.loginState.accountBySession && !isPlaylists() && globals.musicBrowseFolder == nil
//                && mega().rootNode != nil && currentFolder! != globals.storageModel.musicFolder
//            {
//                alert.addAction(UIAlertAction(title: "Set as the top available folder...", style: .default, handler:
//                    { (UIAlertAction) -> () in self.CheckSetAsWritableFolderLink() }));
//            }
//
//            if !isPlaylists() && globals.musicBrowseFolder == nil {
//                alert.addAction(UIAlertAction(title: "Set as the Music Folder...", style: .default, handler:
//                    { (UIAlertAction) -> () in self.CheckSetAsMusicFolder() }));
//            }
//            if isPlaylists() && globals.playlistBrowseFolder == nil {
//                alert.addAction(UIAlertAction(title: "Set as the Playlist Folder...", style: .default, handler:
//                    { (UIAlertAction) -> () in self.CheckSetAsPlaylistFolder() }));
//            }
        
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
        load(currentFolder);
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
    
//    func CheckSetAsWritableFolderLink()
//    {
//        let path = app().nodePath(currentFolder!)
//        let alert = UIAlertController(title: "Writable Folder Link", message: "Convert from logging in to your whole account to logging in to just this folder: \"" + path + "\". This action will create a Writable Folder Link for this folder, and the app will log into that link instead of your full account.  Use this function on a folder containing your Music and Playlists.  The rest of your account will no longer be loaded by this app, saving resources and improving privacy and convenience.  You can still select subfolders for Music and Playlists afterward.", preferredStyle: .alert)
//        
//        alert.addAction(UIAlertAction(title: "Switch login to a Folder Link here", style: .default, handler:
//            { (UIAlertAction) -> () in self.SetAsWritableFolderLink()}));
//
//        alert.addAction(UIAlertAction(title: "Never mind", style: .cancel));
//
//        self.present(alert, animated: false, completion: nil)
//    }
//    
//    func SetAsWritableFolderLink()
//    {
//        if (!globals.loginState.online)
//        {
//            let alert = UIAlertController(title: "Please go online first", message: "Creating a writable folder link requires being online", preferredStyle: .alert)
//            alert.addAction(UIAlertAction(title: "OK", style: .cancel));
//            self.present(alert, animated: false, completion: nil)
//            return;
//        }
//        
//        let spinner = ProgressSpinner(uic: self, title: "Writable Folder Link", message: "");
//
//        globals.loginState.convertToWritableFolderLink(spinner: spinner, currentFolder!,
//            onFinish: { (success) in
//                spinner.dismissOrReportError(success: success)
//            });
//    }
//    
//    func CheckSetAsMusicFolder()
//    {
//        let path = app().nodePath(currentFolder!)
//        let alert = UIAlertController(title: "Set Music Root Folder", message: "Makes folder \"" + path + "\" the root folder for this Music screen, so that the rest of your account cannot be browsed from this view.  Subfolders of this folder can be browsed.  It cannot be changed unless you log out and log in again, or the path is no longer available (eg. by moving or renaming it in the cloud).", preferredStyle: .alert)
//        
//        alert.addAction(UIAlertAction(title: "Yes set it", style: .default, handler:
//            { (UIAlertAction) -> () in self.SetAsMusicFolder() }));
//
//        alert.addAction(UIAlertAction(title: "Never mind", style: .cancel));
//
//        self.present(alert, animated: false, completion: nil)
//    }
//    
//    func SetAsMusicFolder()
//    {
//        globals.musicBrowseFolder = nil;
//        let path = app().nodePath(currentFolder!)
//        let _ = globals.storageModel.storeSettingFile(leafname : "musicPath", content: path);
//        if let musicPath = globals.storageModel.loadSettingFile(leafname: "musicPath") {
//            globals.musicBrowseFolder = mega().node(forPath: musicPath)
//        }
//        load(node: rootFolder());
//    }
//
//    func CheckSetAsPlaylistFolder()
//    {
//        let path = app().nodePath(currentFolder!)
//        let alert = UIAlertController(title: "Set Playlist Root Folder", message: "Makes folder \"" + path + "\" the root folder for this Playlist screen, so that the rest of your account cannot be browsed from this view.  Subfolders of this folder can be browsed.  It cannot be changed unless you log out and log in again, or the path is no longer available (eg. by moving or renaming it in the cloud).", preferredStyle: .alert)
//        
//        alert.addAction(UIAlertAction(title: "Yes set it", style: .default, handler:
//            { (UIAlertAction) -> () in self.SetAsPlaylistFolder() }));
//
//        alert.addAction(UIAlertAction(title: "Never mind", style: .cancel));
//
//        self.present(alert, animated: false, completion: nil)
//    }
//    
//    func SetAsPlaylistFolder()
//    {
//        globals.playlistBrowseFolder = nil;
//        let path = app().nodePath(currentFolder!)
//        let _ = globals.storageModel.storeSettingFile(leafname : "playlistPath", content: path);
//        // for writable folder links, this, for sessions, mega().nodePath()
//        if let playlistPath = globals.storageModel.loadSettingFile(leafname: "playlistPath") {
//            globals.playlistBrowseFolder = mega().node(forPath: playlistPath)
//        }
//        load(node: rootFolder());
//    }
    
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
//todo
//        alert.addAction(UIAlertAction(title: "Extract now", style: .default, handler: {
//            (UIAlertAction) -> () in ExtractAndApplyTags(
//                self.currentFolder!,
//                recursive: self.extractTagsProcessSubfolders.flag,
//                overwriteExistingTags: self.extractTagsOverwritesExistingTagsCheckbox.flag,
//                uic: self);() }));

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
        var v : [Path] = [];
        do {
            for n in nodeArray {
                try loadSongsFromPathRecursive(n: n, &v, recurse: true, filterIntent: nil);
            }
        }
        catch {
            reportMessage(uic: self, message: "Error getting all: \(error)")
        }
        globals.playQueue.queueSongs(front: false, songs: v, uic: self, reportQueueLimit: true)
    }

    func ShuffleQueueAll()
    {
        var v : [Path] = [];
        do
        {
            for n in nodeArray {
                try loadSongsFromPathRecursive(n: n, &v, recurse: true, filterIntent: nil);
            }
        }
        catch {
            reportMessage(uic: self, message: "Error getting all: \(error)")
        }
        globals.playQueue.queueSongs(front: false, songs: shuffleArray(&v), uic: self, reportQueueLimit: true);
    }

    func checkFiltered(_ n : Path) -> Bool
    {
        if (leafName(n).lowercased().contains(filterSearchString.lowercased()))
        {
            return true;
        }
        if let attr = globals.storageModel.lookupSong(n) {
            if let t = attr["title"] {
                if t.lowercased().contains(filterSearchString.lowercased()) { return true; }
            }
            if let t = attr["artist"] {
                if t.lowercased().contains(filterSearchString.lowercased()) { return true; }
            }
            if let t = attr["notes"] {
                if t.lowercased().contains(filterSearchString.lowercased()) { return true; }
            }
            if let t = attr["title"] {
                if t.lowercased().contains(filterSearchString.lowercased()) { return true; }
            }
            if let t = attr["title"] {
                if t.lowercased().contains(filterSearchString.lowercased()) { return true; }
            }
        }
        return false;
    }
    
    func AddFilteredNodes(parent : Path) throws
    {
        let leafs = try parent.contentsOfDirectory();
        for l in leafs
        {
            if (filtering && l.isFolder)
            {
                try AddFilteredNodes(parent: l);
            }
            else if (!filtering || checkFiltered(l))
            {
                nodeArray.append(l)
            }
        }
//        let list = mega().children(forParent: parent, order: 1);
//        for i in 0..<list.size.intValue {
//            let n = list.node(at: i);
//            if (filtering && n?.type != MEGANodeType.file)
//            {
//                AddFilteredNodes(parent: n!);
//            }
//            else if (!filtering || checkFiltered(n!))
//            {
//                nodeArray.append(n!)
//
////                if (isPlaylists() &&
////                    n!.name != nil &&
////                    n!.name!.hasSuffix(".playlist")) {
////                    _ = globals.storageModel.startDownloadIfAbsent(node: n!);
////                }
//
//            }
//        }
    }
    
    func browseToFolder(_ n : Path)
    {
        showHideFilterElements(filter: false);
        load(n);
    }
    
    func browseToParent(_ n : Path)
    {
        showHideFilterElements(filter: false);
        load(n.parentFolder());
        redraw()
        hilight(h: n);
    }
    
    func hilight(h: Path)
    {
        var row = 0;
        for n in nodeArray {
            if n == h { break }
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
    
    func load(_ n : Path?)
    {
//        if node != nil && rootFolder() != nil {
//            let np = app().nodePath(node!);
//            let rp = app().nodePath(rootFolder()!);
//            if !np.hasPrefix(rp) { return; }
//        }
        currentFolder = n;
        nodeArray = [];

        var text : String? = n?.relativePath;

//        if (currentFolder == nil && !isPlaylists() && globals.musicFolder != nil) {
//            currentFolder = globals.musicBrowseFolder;
//            text = "/";
//        }
//
//        if (currentFolder == nil && isPlaylists() && globals.playlistBrowseFolder != nil) {
//            currentFolder = globals.playlistBrowseFolder;
//            text = "/";
//        }
//
//        if (currentFolder == nil && globals.loginState.accountByFolderLink) {
//            currentFolder = mega().rootNode;
//            text = "/";
//        }
    
        if (currentFolder != nil) {
            do {
                try AddFilteredNodes(parent: currentFolder!);
            }
            catch {
                reportMessage(uic: self, message: "Load failed: \(error)")
            }
            text = currentFolder?.relativePath;
        }
        
//        if (currentFolder == nil && globals.loginState.accountBySession) {
//            if (mega().rootNode != nil) {
//                text = "<Your Account>";
//                nodeArray.append(mega().rootNode!);
//                let shares = mega().inSharesList(.defaultAsc)
//                for i in 0..<shares.size.intValue {
//                    if let n = mega().node(forHandle: shares.share(at: i).nodeHandle) {
//                        nodeArray.append(n);
//                    }
//                }
//            }
//        }

        if (folderPathLabelCtrl != nil)
        {
            folderPathLabelCtrl.text = text == nil ? "" : text;
        }
        tableView.reloadData();
    }
    
    var nodesChanged: Bool = false;
    var folderChanged: Bool = false;
    
//    func nodesChanging(_ node: MEGANode)
//    {
//        if (replaceNodeIn(node, &nodeArray)) {
//            nodesChanged = true;
//            if (node.isRemoved() || (currentFolder != nil && node.parentHandle != currentFolder!.handle))
//            {
//                folderChanged = true;
//            }
//        }
//        if (currentFolder != nil &&
//           (currentFolder!.handle == node.parentHandle ||
//            currentFolder!.handle == node.handle))
//        {
//            folderChanged = true;
//            if (currentFolder!.handle == node.handle)
//            {
//                currentFolder = node;
//            }
//        }
//    }
    
//    func nodesFinishedChanging()
//    {
//        if (folderChanged)
//        {
//            load(node: currentFolder);
//        }
//        else if (nodesChanged)
//        {
//            redraw();
//        }
//        nodesChanged = false;
//        folderChanged = false;
//    }
    
    func loadParentFolder()
    {
        if (currentFolder != nil && currentFolder! != rootFolder())
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
    
    func rootFolder() -> Path
    {
        if isPlaylists() {
            return Path(rp: "", r: Path.RootType.PlaylistRoot, f: true);
        } else {
            return Path(rp: "", r: Path.RootType.MusicRoot, f: true);
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
        
        let n = indexPath.row < nodeArray.count ? nodeArray[indexPath.row] : nil;
        let isFolder = n == nil ? false : n!.isFolder;
        
        var cell : UITableViewCell?
        
        if (n != nil && (isFolder || !showingTrackNames))
        {
            cell = tableView.dequeueReusableCell(withIdentifier: "FolderCell", for: indexPath)
            cell!.textLabel?.text = leafName(n!) + (isFolder ? "/" : "");
        }
        else
        {
            cell = tableView.dequeueReusableCell(withIdentifier: filtering ? "MusicCellWithNotes" : "MusicCell", for: indexPath)
            if (n != nil)
            {
                let songAttr = globals.storageModel.lookupSong(n!);
                
                if let mCell = cell as? TableViewMusicCellWithNotes {
                    mCell.populateFromSongAttr(songAttr ?? [:]);
                    mCell.notesLabel?.text = n!.parentFolder().relativePath;
                }
                else if let mCell = cell as? TableViewMusicCell {
                    mCell.populateFromSongAttr(songAttr ?? [:]);
                }
            }
        }

        return cell!
    }
    
    override func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let n = indexPath.row < nodeArray.count ? nodeArray[indexPath.row] : nil;
        return n == nil || n!.isFolder || !showingTrackNames || !filtering ? 43.5 : 70;
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        if (self.presentedViewController != nil) {
            // it was a tap-hold for menu
            return;
        }

        tableView.deselectRow(at: indexPath, animated: false)
        if (indexPath.row < nodeArray.count)
        {
            let n = nodeArray[indexPath.row];
            if (n.isFolder)
            {
                DispatchQueue.main.async( execute: { self.load(n) } );
            }
            else if (n.hasSuffix(".playlist"))
            {
                let vc = self.storyboard?.instantiateViewController(identifier: "Playlist") as! PlaylistTVC
                vc.playlistToLoad = n;
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
            
            if isPlayable(node, orMightContainPlayable: true) {
                alert.addAction(menuAction_playNext(node, uic: self));
                alert.addAction(menuAction_playLast(node, uic: self));
            }
            if isPlayable(node, orMightContainPlayable: false) {
                alert.addAction(menuAction_songInfo(node, viewController: self));
            }
            if isArtwork(node) {
                alert.addAction(UIAlertAction(title: "Set as artwork for songs in this folder", style: .default, handler:
                      { (UIAlertAction) -> () in self.setArtworkForSongsInFolder(node); }));
            }
            if (filtering) {
                alert.addAction(menuAction_songBrowseTo(node, viewController: self));
            }
            if (//globals.playlistBrowseFolder != nil && 
                isPlayable(node, orMightContainPlayable: false)) {
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

 // todo
    func setArtworkForSongsInFolder(_ node : Path)
    {
//        if (!globals.loginState.online)
//        {
//            let alert = UIAlertController(title: "Please go online first", message: "Setting artwork for files requires being online", preferredStyle: .alert)
//            alert.addAction(UIAlertAction(title: "OK", style: .cancel));
//            self.present(alert, animated: false, completion: nil)
//            return;
//        }
//        
//        if let parent = mega().parentNode(for: node) {
//        
//            if let thumbnailFile = globals.storageModel.thumbnailPath(node: node) {
//                let list = mega().children(forParent: parent, order: 1);
//                for i in 0..<list.size.intValue {
//                    if let n = list.node(at: i) {
//                        if (isPlayable(n, orMightContainPlayable: false))
//                        {
//                            mega().setThumbnailNode(n, sourceFilePath: thumbnailFile, delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in
//                                globals.storageModel.megaDelegate.onThumbnailUpdate(node: node)
//                            } ));
//                        }
//                    }
//                }
//            }
//        }
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
