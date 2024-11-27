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
import Intents

let playableExtensions = [ ".mp3", ".m4a", ".aac", ".wav", ".flac", ".aiff", ".au", ".pcm", ".ac3", ".aa", ".aax"];
let artworkExtensions = [ ".jpg", ".jpeg", ".png", ".bmp"];

func isPlayable(_ n : Path, orMightContainPlayable : Bool) -> Bool
{
    if orMightContainPlayable {
        if !n.isFolder &&
            n.relativePath.hasSuffix(".playlist") { return true; }
        if n.isFolder { return true; }
    }
    if (!n.isFolder) {
        let name = n.relativePath.lowercased();
        for ext in playableExtensions {
            if name.hasSuffix(ext) { return true; }
        }
    }
    return false;
}

func isArtwork(_ n : Path) -> Bool
{
    if (!n.isFolder) {
        let name = leafName(n).lowercased()
        for ext in artworkExtensions {
            if name.hasSuffix(ext) { return true; }
        }
    }
    return false;
}

func loadFileAsJSON(filename : String) -> Any?
{
    do
    {
        let content = try String(contentsOf: URL(fileURLWithPath: filename), encoding: .utf8);
        let contentData = content.data(using: .utf8);
        return try JSONSerialization.jsonObject(with: contentData!, options: []);
    }
    catch {
    }
    return nil;
}

func getPlaylistFileAsJSON(_ filename: Path, editedIfAvail: Bool) throws -> Any
{
    assert(editedIfAvail ? filename.rt == .PlaylistRoot && !filename.isFolder : true);
    var f = filename;
    if editedIfAvail {
        if FileManager.default.fileExists(atPath: filename.edited().fullPath()) {
            f = filename.edited();
        }
    }
    let content = try String(contentsOf: URL(fileURLWithPath: f.fullPath()), encoding: .utf8);
    let contentData = content.data(using: .utf8);
    return try JSONSerialization.jsonObject(with: contentData!, options: []);
}

func loadSongsFromPlaylistRecursive(json: Any, _ v : inout [Path], recurse: Bool, filterIntent: INPlayMediaIntent?)
{
    if let array = json as? [Any] {
        for object in array {
            if let attribs = object as? [String : String] {
                if let p = attribs["npath"] {
                    v.append(Path(rp: p, r: Path.RootType.MusicSyncFolder, f: false))
                }
            }
//                if let attribs = object as? [String : Any] {
//                    if let handleStr = attribs["h"] {
//                        var node = mega().node(forHandle: MEGASdk.handle(forBase64Handle: handleStr as! String));
//                        if (node == nil)
//                        {
//                            // Maybe the node was replaced with a new version, see if there's something at the old path
//                            if let lkpath = attribs["lkpath"] {
//                                node = mega().node(forPath: lkpath as! String);
//                            }
//                        }
//                        if (node != nil) {
//                            loadSongsFromNodeRecursive(node: node!, &v, recurse: recurse, filterIntent: filterIntent);
//                        }
//                    }
//                }
        }
    }
}

func loadSongsFromPathRecursive(n: Path, _ v : inout [Path], recurse: Bool, filterIntent: INPlayMediaIntent?, loadPlaylists: Bool) throws
{
    if (filterIntent != nil)
    {
        if (n.isFolder && leafName(n) == "old-playlist-versions") {
            return;
        }
        if (matchNodeOnIntent(n, filterIntent: filterIntent!))
        {
            v.append(n);
            return;
        }
    }

    if (n.isFolder)
    {
        let leafs = try n.contentsOfDirectory();
        for l in leafs
        {
            if (recurse || !l.isFolder) {
                try loadSongsFromPathRecursive(n: l, &v, recurse: recurse, filterIntent: filterIntent, loadPlaylists: loadPlaylists);
            }
        }
    }
    else if (n.hasSuffix(".playlist"))// && globals.storageModel.fileDownloadedByNH(node))
    {
        if (recurse && loadPlaylists) {
            let json = try getPlaylistFileAsJSON(n, editedIfAvail: true);
            loadSongsFromPlaylistRecursive(json: json, &v, recurse: recurse, filterIntent: filterIntent);
        }
    }
    else if isPlayable(n, orMightContainPlayable: false)
    {
        if (filterIntent == nil) { v.append(n) }
    }
}

func matchNodeOnIntent(_ n : Path, filterIntent: INPlayMediaIntent) -> Bool
{
    switch (filterIntent.mediaSearch?.mediaType) {
    case .playlist:
        if (n.isFolder || !n.hasSuffix(".playlist")) {
            return false;
        }
    case .song:
        if (n.isFolder || !isPlayable(n, orMightContainPlayable: false)) {
            return false;
        }
    case .album:
        if (!n.isFolder) {
            return false;
        }
    case .music:
        // this case seems to be used for "all songs"
        return !n.isFolder &&
        isPlayable(n, orMightContainPlayable: false);
    case .unknown:
        break;
        
    default:
        return false;
    }
    
    if (!isPlayable(n, orMightContainPlayable: true))
    {
        return false;
    }
    
    if let searchStr = filterIntent.mediaSearch?.mediaName?.lowercased() {
        
        let name = n
        if (name.relativePath.lowercased().contains(searchStr)) { return true };
        
        let ct = n // todo: lookup , get title etc
            if ct.relativePath.lowercased().contains(searchStr) { return true };
        
        return false;
    }
    return true;
}
class FolderManager
{
    var alreadyCreatedFolders : Set<String> = [];

    func assureFolderExists(_ url : String, doneName : String) -> Bool
    {
        if (doneName != "" && alreadyCreatedFolders.contains(doneName)) { return true; }
        do {
            if !FileManager.default.fileExists(atPath: url) {
                try FileManager.default.createDirectory(atPath: url, withIntermediateDirectories: true, attributes: nil);
            }
            var urv = URLResourceValues();
            urv.isExcludedFromBackup = true;
            var attribUrl = URL(fileURLWithPath: url)
            try attribUrl.setResourceValues(urv);
            alreadyCreatedFolders.insert(doneName);
        }
        catch
        {
            print("directory does not exist and could not be created or could not be set non-backup: \(url)")
            return false;
        }
        return true;
    }
    
    func storageBasePath() -> String
    {
        // choosing applicationSupportDirectory means the files will not be accessible from other apps,
        // won't be removed by the system (unlike cache directories) and we can set flags to prevent
        // the files being synced by iTunes or iCloud.
        // https://developer.apple.com/library/archive/qa/qa1719/_index.html
        let folderUrls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask);
        let p = folderUrls[0].standardizedFileURL.path;
        _ = assureFolderExists(p, doneName: "base");
        return p;
    }
    
    func settingsPath() -> String
    {
        let p = storageBasePath() + "/settings";
        _ = assureFolderExists(p, doneName: "settings");
        return p;
    }

    func tmpFolderPath() -> String
    {
        let p = storageBasePath() + "/tmp";
        _ = assureFolderExists(p, doneName: "tmp");
        return p;
    }

    func syncFolderPath() -> String
    {
       
        let p = storageBasePath() + "/sync";
        _ = assureFolderExists(p, doneName: "sync")
        _ = assureFolderExists(p + "/songs++index", doneName: "songs++index")
        _ = assureFolderExists(p + "/songs++index/thumb", doneName: "thumb")
        _ = assureFolderExists(p + "/songs++index/playlist", doneName: "playlist")
        return p;
    }
};

class Path
{
    var relativePath : String = "";
    var isFolder : Bool = false;
    
    static var folderManager = FolderManager()
    
    enum RootType {
        case MusicSyncFolder
        case PlaylistRoot
        case ThumbFile
        case ThumbFolderRoot
        case IndexFile
        case IndexFileUpdates
        case IndexFolder
        case Settings
        case ExternalPath
        case TmpFolder
    }
    
    var rt : RootType = RootType.MusicSyncFolder;
    
    func fullPath() -> String
    {
        switch (rt) {
        case .MusicSyncFolder : return Path.folderManager.syncFolderPath() + "/" + relativePath;
        case .PlaylistRoot : return Path.folderManager.syncFolderPath() + "/songs++index/playlist/" + relativePath;
        case .ThumbFile : return Path.folderManager.syncFolderPath() + "/songs++index/thumb/" + relativePath + ".jpg";
        case .ThumbFolderRoot : return Path.folderManager.syncFolderPath() + "/songs++index/thumb";
        case .IndexFile: return  Path.folderManager.syncFolderPath() + "/songs++index/songs++index.json";
        case .IndexFileUpdates: return  Path.folderManager.syncFolderPath() + "/songs++index/songs++index.updates.json";
        case .IndexFolder: return  Path.folderManager.syncFolderPath() + "/songs++index";
        case .Settings: return  Path.folderManager.settingsPath() + "/" + relativePath;
        case .ExternalPath: return relativePath;
        case .TmpFolder: return Path.folderManager.tmpFolderPath();
        }
    }
    
    static func == (lhs : Path, rhs : Path) -> Bool
    {
        return lhs.rt == rhs.rt && lhs.relativePath == rhs.relativePath;
    }
    static func != (lhs : Path, rhs : Path) -> Bool
    {
        return lhs.rt != rhs.rt || lhs.relativePath != rhs.relativePath;
    }

    init(rp : String, r : RootType, f : Bool)
    {
        rt = r;
        relativePath = rp;
        isFolder = f;
        
        if (relativePath.hasPrefix("/music/music/"))
        {
            relativePath = String(relativePath.suffix(from: relativePath.index(relativePath.startIndex, offsetBy: 13)))
        }
        
        while (relativePath.first == "/") { relativePath.removeFirst(); }
    }
    
    func hasSuffix(_ s: String) -> Bool
    {
        return relativePath.hasSuffix(s);
    }
    
    func edited() -> Path
    {
        let p = Path(rp: relativePath, r: rt, f: isFolder);
//        if !p.hasSuffix(".edited") {
//            p.relativePath.append(".edited");
//        }
        return p;
    }

    func contentsOfDirectory() throws -> [Path]
    {
        var result : [Path] = [];
        let leafs = try FileManager.default.contentsOfDirectory(atPath: fullPath());
        for l in leafs
        {
            if !l.hasSuffix(".edited") && 
                l != "songs++index"
            {
                result.append(drillInto(entry: l))
            }
        }
        result.sort(by: { (a:Path, b:Path) -> Bool in
            return a.relativePath < b.relativePath;
        })
        return result;
    }
    
    func drillInto(entry : String) -> Path
    {
        let p = Path(rp: relativePath, r: rt, f: true);
        if (p.relativePath.last != nil && p.relativePath.last != "/") { p.relativePath.append("/"); }
        p.relativePath += entry;
        while (p.relativePath.last == "/") { p.relativePath.removeLast(); }
        p.isFolder = pathIsFolder(p.fullPath())
        return p;
    }
    
    func parentFolder() -> Path
    {
        let last = URL(fileURLWithPath: relativePath).lastPathComponent
        let p = Path(rp: relativePath, r: rt, f: true);
        p.relativePath.removeLast(last.count);
        if (p.relativePath.last == "/") { p.relativePath.removeLast(); }
        return p;
    }
}

func leafName(_ n : String) -> String
{
    return URL(fileURLWithPath: n).lastPathComponent
}
func leafName(_ n : Path) -> String
{
    return URL(fileURLWithPath: n.relativePath).lastPathComponent
}


func parentFolder(_ n : String) -> String
{
    let last = URL(fileURLWithPath: n).lastPathComponent
    var p = n;
    p.removeLast(last.count);
    if (p.last == "/") { p.removeLast(); }
    return p;
}

func pathIsFolder(_ p : String) -> Bool
{
    var resultStorage: ObjCBool = false;
    FileManager.default.fileExists(atPath: p, isDirectory: &resultStorage)
    return resultStorage.boolValue;
}

class ProgressSpinner {

    var busyControl : UIAlertController? = nil;
    var parentView : UIViewController? = nil;
    let spinnerIndicator = UIActivityIndicatorView(style: .large)
    
    var errorMessage : String = "";
    
    init(uic : UIViewController?, title : String, message : String)
    {
        parentView = uic;
        busyControl = UIAlertController(title: title, message: "\n\n\n" + message, preferredStyle: .alert)
        spinnerIndicator.center = CGPoint(x: 135.0, y: 65.5)
        spinnerIndicator.color = UIColor.blue
        spinnerIndicator.startAnimating()
        busyControl!.view.addSubview(spinnerIndicator)
        if (parentView != nil)
        {
            parentView!.present(busyControl!, animated: false, completion: nil)
        }
        print( "spinner starts: " + title + " " + message);
    }

    func updateMessage(_ message : String)
    {
        busyControl!.message = "\n\n\n" + message;
        print( "spinner update: " + message);
    }
    
    func updateTitleMessage(_ title : String, _ message : String)
    {
        busyControl!.title = title;
        busyControl!.message = "\n\n\n" + message;
        print( "spinner update: " + title + " " + message);
    }
    
    func setErrorMessage(_ err : String)
    {
        errorMessage = err;
        print( "spinner error message set: " + errorMessage);
    }
    
    func dismiss()
    {
        if (parentView != nil)
        {
            self.busyControl!.dismiss(animated: true);
        }
        print( "spinner dismissed");
    }
    
    func dismissOrReportError(success : Bool)
    {
        if (success)
        {
            dismiss();
        }
        else
        {
            spinnerIndicator.removeFromSuperview();
            busyControl!.title = "An Error Occurred";
            busyControl!.message = errorMessage;
            busyControl!.addAction(UIAlertAction(title: "Ok", style: .cancel));
            print ("spinner reports error for user to ack: " + errorMessage);
        }
    }
}

class IntentHandler: NSObject, INPlayMediaIntentHandling {
    
    
    func resolvePlayShuffled(for intent: INPlayMediaIntent, with completion: @escaping (INBooleanResolutionResult) -> Void) {
        // determines whether to shuffle the results
        completion(INBooleanResolutionResult.success(with: intent.playShuffled != nil &&  intent.playShuffled!));
    }
    
    func getNodesForPlayIntent(intent: INPlayMediaIntent, resolutionResult : inout INPlayMediaMediaItemResolutionResult?) -> [Path]
    {
        if (intent.mediaSearch == nil)
        {
            print("No search criteria provided in Intent.")
            resolutionResult = INPlayMediaMediaItemResolutionResult(mediaItemResolutionResult: INMediaItemResolutionResult.unsupported())
            return [];
        }
        
        if let searchStr = intent.mediaSearch!.mediaName {
            print("Searching songs/playlists to match media intent string: " + searchStr)
            print("For media type: ")
            print(intent.mediaSearch!.mediaType)
        }
        
        print("Full intent media search object:");
        print(intent.mediaSearch!);

        let isPlaylists = intent.mediaSearch!.mediaType == .playlist;
        let searchLocation = isPlaylists ?
            Path(rp: "", r: Path.RootType.PlaylistRoot, f: true) :
            Path(rp: "", r: Path.RootType.MusicSyncFolder, f: true);
        
//        if (searchLocation == nil)
//        {
//            resolutionResult = INPlayMediaMediaItemResolutionResult.unsupported(forReason: .restrictedContent)
//            return [];
//        }
        
        var v : [Path] = [];
        v.reserveCapacity(10000);
        
        switch (intent.mediaSearch!.mediaType) {
        case .album, .playlist, .song, .music, .unknown:
            do {
                try loadSongsFromPathRecursive(n: searchLocation, &v, recurse: true, filterIntent: intent, loadPlaylists: isPlaylists);
            }
            catch {
            }
        default:
            if resolutionResult != nil {
                resolutionResult = INPlayMediaMediaItemResolutionResult.unsupported(forReason: .unsupportedMediaType)
            }
        }

        if v.isEmpty && resolutionResult != nil {
            resolutionResult = INPlayMediaMediaItemResolutionResult(mediaItemResolutionResult: INMediaItemResolutionResult.unsupported())
        }
	
        return v;
    }

    
// Well, it seems to be more responsive with this function missing anyway.
// No need to announce the song we are about to play
//
//    // because we seem to have lifetime issues, crashing a few seconds
//    // after the function exits, with 6k+ stack frames, same number as elements in the arrays
//    var resolveMediaItemsTesult : [INMediaItem] = [];
//    var resolveMediaItemsFoundNodes : [MEGANode] = [];
//
//    func resolveMediaItems(for intent: INPlayMediaIntent) async -> [INPlayMediaMediaItemResolutionResult] {
//        print("handler-resolveMediaItems")
//
//        if (!globals.loginState.accountByFolderLink) {
//            if (!globals.loginState.accountBySession) {
//                return [INPlayMediaMediaItemResolutionResult.unsupported(forReason: .loginRequired)];
//            }
//        }
//
//        var ret : INPlayMediaMediaItemResolutionResult? = INPlayMediaMediaItemResolutionResult.unsupported();
//
//        resolveMediaItemsFoundNodes = getNodesForPlayIntent(intent: intent, resolutionResult: &ret);
//
//        resolveMediaItemsTesult = [];
//        resolveMediaItemsTesult.reserveCapacity(10000);
//
//        for n in resolveMediaItemsFoundNodes {
//
//            let vname = n.customTitle ?? n.name;
//            if (vname == nil) { continue; }
//
//            resolveMediaItemsTesult.append(INMediaItem(identifier: n.base64Handle, title: vname!, type: .song, artwork: nil, artist: n.customArtist))
//        }
//
//        return INPlayMediaMediaItemResolutionResult.successes(with: resolveMediaItemsTesult);
//    }

    func handle(intent: INPlayMediaIntent) async -> INPlayMediaIntentResponse
    {
        print("handler-INPlayMediaIntent. intent is");
        print(intent);

        var dummy : INPlayMediaMediaItemResolutionResult? = INPlayMediaMediaItemResolutionResult.unsupported();

        let foundNodes = getNodesForPlayIntent(intent: intent, resolutionResult: &dummy);

        // load the content of playlists, albums, etc
        var expanded : [Path] = [];

        for n in foundNodes {
            do {
                try loadSongsFromPathRecursive(n: n, &expanded, recurse: true, filterIntent: nil, loadPlaylists: true);
            }
            catch {
            }
        }

        if (intent.playShuffled != nil && intent.playShuffled!)
        {
            expanded = shuffleArray(&expanded);
        }

        if (expanded.count >= 1)
        {
            let rightNowNode = expanded[0];
            expanded.remove(at: 0)

            DispatchQueue.main.asyncAfter(deadline: .now()) {
                globals.playQueue.playRightNow(rightNowNode);
            }
        }

        if (expanded.count >= 1)
        {
            let aaa = expanded;
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                globals.playQueue.queueSongs(front: true, songs: aaa, uic: app().playQueueTVC!, reportQueueLimit: false, loadPlaylists: false);
            }
        }

        return INPlayMediaIntentResponse(code: .success, userActivity: nil);
    }

    
}

class Globals
{
    // things that may be accessed by the App UI or from independent threads with no UI.
    
//    var mega : MEGASdk? = nil;
//    var loginState = LoginState();
    var playQueue = PlayQueue();
    var storageModel = StorageModel();

//    var musicBrowseFolder : MEGANode? = nil;
//    var playlistBrowseFolder : MEGANode? = nil;

    func clear()
    {
        playQueue.clear();
    }
    
    init()
    {
        var tmpPath : String = "";
        tmpPath = Path(rp: "", r: .IndexFolder, f: true).fullPath();
        SongsCPP.setTmpPath(tmpPath);

        var thumbPath : String = "";
        thumbPath = Path(rp: "", r: .ThumbFolderRoot, f: true).fullPath();
        SongsCPP.setThumbPath(thumbPath);
    }

}

var globals = Globals();

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    var player : AVPlayer? = nil;
    
    var intentHandler : IntentHandler = IntentHandler();
    
    func setupRemoteTransportControls() {
        // Get the shared MPRemoteCommandCenter
        let commandCenter = MPRemoteCommandCenter.shared()

        // Add handler for Play Command
        commandCenter.playCommand.addTarget { [unowned self] event in
            if self.player!.rate == 0.0 {
                self.player!.play()
                return .success
            }
            return .commandFailed
        }

        // Add handler for Pause Command
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            if self.player!.rate == 1.0 {
                self.player!.pause()
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.nextTrackCommand.addTarget { event in
            return globals.playQueue.goNextTrack() ? .success : .commandFailed;
        }

        commandCenter.previousTrackCommand.addTarget { event in
            return globals.playQueue.goSongStartOrPrevTrack() ? .success : .commandFailed;
        }

    }
    
    func setupNowPlaying(n: Path?) {
        
        let attr = n == nil ? nil : globals.storageModel.lookupSong(n!);
        
        if attr != nil {	
        
            let title : String? = attr!["title"] ?? "<title>";
            let artist : String? = attr!["artist"] ?? "";
            
            var image : UIImage? = nil;
            if let thumb = attr!["thumb"]
            {
                image = UIImage(contentsOfFile: Path(rp: thumb, r: .ThumbFile, f: false).fullPath());
//                if (globals.storageModel.thumbnailDownloaded(node)) {
//                    if let path = 	thumbnailPath(node: node) {
//                        image = UIImage(contentsOfFile: path);
//                    }
//                }
            }
            
            var nowPlayingInfo = [String : Any]()
            nowPlayingInfo[MPMediaItemPropertyTitle] = title!;
            nowPlayingInfo[MPMediaItemPropertyArtist] = artist!;
            if image != nil { nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image!.size) { size in return image! } }
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = "0:00";
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = attr!["durat"];
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
        else {
            var nowPlayingInfo = [String : Any]()
            nowPlayingInfo[MPMediaItemPropertyTitle] = "";
            nowPlayingInfo[MPMediaItemPropertyArtist] = "";
            nowPlayingInfo[MPMediaItemPropertyArtwork] = nil;
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0;
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = 0;
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
    }
    
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        player = globals.playQueue.player
        
        do {
//            try AVAudioSessionPatch.setSession(AVAudioSession.sharedInstance(), category: .playback, with: [.defaultToSpeaker, .mixWithOthers])
//            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default, options: [.mixWithOthers, .allowAirPlay])
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback);
            //, mode: AVAudioSession.Mode.default, options: [.mixWithOthers, .allowAirPlay])
////            print("Playback OK")
            try AVAudioSession.sharedInstance().setActive(true)
            
            setupRemoteTransportControls()
//            setupNowPlaying();
// //           print("Session is Active")
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback);
//
//
            application.beginReceivingRemoteControlEvents();
        } catch {
            print(error)
        }
        
        return true
    }

    @objc func mediaDidEnd(notification: NSNotification)
    {
        globals.playQueue.onSongFinishedPlaying();
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        NotificationCenter.default.addObserver(self, selector: #selector(mediaDidEnd), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil);

//        let dummySpinner = ProgressSpinner(uic: nil, title: "Resuming offline", message: "");
//        globals.loginState.goOffline(spinner: dummySpinner, onFinish: {b in });

        return true
    }
    
    func application(_ application : UIApplication, handlerFor intent : INIntent) -> Any?
    {
        print("application-handlerFor intent")
        return intentHandler;
    }
    
    func application(_ application: UIApplication, handle intent: INIntent, completionHandler: @escaping (INIntentResponse) -> Void) {
        print("application-intent")
        //let ir = INIntentResponse();
        //completionHandler(ir);
//        if let playIntent = intent as? INPlayMediaIntent {
//            let mi = playIntent.mediaItems;
//            let mi2 = playIntent.mediaSearch;
//        }
        let v = INIntentResponse();
        v.userActivity = NSUserActivity(activityType: "play me");
        completionHandler(v);
    }
    
    func application(_ application: UIApplication, willContinueUserActivityWithType userActivityType: String) -> Bool {
        print("application-willContinueUserActivityWithType")
        return true;
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        print("application-useractivity")
        return true;
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        
        globals.playQueue.saveQueueAndHistory(shuttingDown: false);
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        globals.playQueue.saveQueueAndHistory(shuttingDown: true);
    }
      
    var nodeForBrowseFirstLoad : Path? = nil;
    
    var playQueueTVC : PlayQueueTVC? = nil;
    var browseMusicTVC : BrowseTVC? = nil;
    var browsePlaylistsTVC : BrowseTVC? = nil;
    var playlistTVC : PlaylistTVC? = nil;
    
    var tabBarContoller : MainTabBarController? = nil;
    
    var explanatoryText : String = "";
    
    var recentPlaylists : [Path] = [];
    
    func clear()
    {
        // get back to on-start state
        globals.clear()

        nodeForBrowseFirstLoad = nil;
        if playQueueTVC != nil { playQueueTVC!.clear(); }
        if browseMusicTVC != nil { browseMusicTVC!.clear(); }
        if browsePlaylistsTVC != nil { browsePlaylistsTVC!.clear(); }
        explanatoryText = "";
        recentPlaylists = [];
    }

//    func downloadProgress(nodeHandle : UInt64, percent : NSNumber )
//    {
//        if (playQueueTVC != nil)
//        {
//            let n = globals.mega!.node(forHandle: nodeHandle)
//            if (n != nil && n!.fingerprint != nil) {
//                playQueueTVC!.downloadProgress(fingerprint: n!.fingerprint!, percent: percent);
//            }
//        }
//    }
    
    var swipeRightPlaysSong : Bool = true;
    
//    func AddSwipedRightNode(node: MEGANode)
//    {
//        if (swipeRightPlaysSong) { playQueue.queueSong(node: node);}
//        else { swipedRightSet.append(node); }
//    }
    
//    func nodePathBetween(_ a: MEGANode?, _ b: MEGANode) -> String
//    {
//        let textb = SongsPlusPlus.mega().nodePath(for: b) ?? "";
//        let texta = a == nil ? "": (SongsPlusPlus.mega().nodePath(for: a!) ?? "");
//        if (texta == textb)
//        {
//            return "/";
//        }
//        else if (textb.hasPrefix(texta))
//        {
//            if (texta == "/") { return textb; }
//            return String(textb.dropFirst(texta.count));
//        }
//        return textb;
//    }
//
//    func nodePath(_ node: MEGANode) -> String
//    {
//        return nodePathBetween(SongsPlusPlus.mega().rootNode, node);
//    }


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

var accountFolderDoneAlready = false;
//
//func mega(using fileManager : FileManager = .default) -> MEGASdk {
//    
//    if (globals.mega == nil)
//    {
//        let path = globals.storageModel.accountPath() + "/";
//        globals.mega = MEGASdk.init(appKey: "dWRWmTiJ", userAgent: "Songs++ " + deviceName(), basePath: path)!;
////        globals.mega!.add(globals.storageModel.transferDelegate);
////        globals.mega!.add(globals.storageModel.megaDelegate);
//        globals.mega!.platformSetRLimitNumFile(50000);
//    }
//    return globals.mega!;
//}

//func megaGetLatestFileRevision(_ node : MEGANode?) -> MEGANode?
//{
//    // check if playlist is updated
//    // also check if it even still exists
//    var n = mega().node(forHandle: node!.handle);
//    while (n != nil) {
//        let p = mega().parentNode(for: n!);
//        if (p == nil)
//        {
//            n = nil;
//            break;
//        }
//        if p!.type != .file { break; }
//        n = p;
//    }
//    return n;
//}
//
//func megaGetContainingFolder(_ node : MEGANode?) -> MEGANode?
//{
//    var n = megaGetLatestFileRevision(node);
//    if (n != nil) { n = mega().parentNode(for: n!); }
//    if (n != nil && n!.type == .file) { n = nil; }
//    return n;
//}

func shuffleArray(_ a : inout [Path]) -> [Path]
{
    var newQueue : [Path] = []
    while a.count > 0 {
        let row = Int.random(in: 0..<a.count)
        newQueue.append(a[row])
        a.remove(at: row)
    }
    return newQueue;
}

func reportMessageWithTitle(uic : UIViewController, messageTitle : String, message : String, continuation : (() -> Void)? = nil)
{
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
        let alert = UIAlertController(title: messageTitle, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .cancel));
        uic.present(alert, animated: false, completion: continuation)
    }
}
func reportMessage(uic : UIViewController, message : String, continuation : (() -> Void)? = nil)
{
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .cancel));
        uic.present(alert, animated: false, completion: continuation)
    }
}

func menuAction_playRightNow(_ n : Path) -> UIAlertAction
{
    return UIAlertAction(title: "Play right now", style: .default, handler:
        { (UIAlertAction) -> () in globals.playQueue.playRightNow(n); });
}

func menuAction_playNext(_ n : Path, uic : UIViewController, loadPlaylists : Bool) -> UIAlertAction
{
    return UIAlertAction(title: "Play next", style: .default, handler:
                            { (UIAlertAction) -> () in globals.playQueue.queueSong(front: true, song: n, uic: uic, loadPlaylists: loadPlaylists); });
}

func menuAction_playLast(_ n : Path, uic : UIViewController, loadPlaylists : Bool) -> UIAlertAction
{
    UIAlertAction(title: "Play last", style: .default, handler:
                    { (UIAlertAction) -> () in globals.playQueue.queueSong(front: false, song: n, uic: uic, loadPlaylists: loadPlaylists); });
}

func menuAction_songInfo(_ node : Path, viewController : UIViewController) -> UIAlertAction
{
    return UIAlertAction(title: "Info...", style: .default, handler:
        { (UIAlertAction) -> () in
            let vc = app().playQueueTVC?.storyboard?.instantiateViewController(identifier: "EditSongVC") as! EditSongVC;
            vc.node = node;
            viewController.navigationController?.pushViewController(vc, animated: true)
        });
}

func menuAction_songBrowseTo(_ n : Path, viewController : UIViewController) -> UIAlertAction
{
    return UIAlertAction(title: "Browse to", style: .default, handler:
        { (UIAlertAction) -> () in
            app().nodeForBrowseFirstLoad = n;
            app().tabBarContoller?.selectedIndex = 1;
            app().browseMusicTVC?.browseToParent(n);
        });
}

func menuAction_neverMind() -> UIAlertAction
{
    return UIAlertAction(title: "Never mind", style: .cancel);
}

func menuAction_addToPlaylistInFolder_recents(_ nn : Path, viewController : UIViewController) -> UIAlertAction
{
    return UIAlertAction(title: "Add to Playlist...", style: .default, handler:
        { (UIAlertAction) -> () in
            let alert = UIAlertController(title: nil, message: "Add to Recent Playlist", preferredStyle: .alert)
            
            for i in 0..<app().recentPlaylists.count {
                
                // check if playlist is updated
                let n = app().recentPlaylists[i];
                //if (n == nil) { continue; }
                
                alert.addAction(menuAction_addToPlaylistExact(playlistPath: n, songToAdd: nn, viewController: viewController));
            }
        alert.addAction(menuAction_addToPlaylistInFolder(nn, overrideName: "Select from all Playlists...", playlistChooseFolder: Path(rp: "", r: .PlaylistRoot, f: true), viewController: viewController));
            alert.addAction(menuAction_neverMind());
            viewController.present(alert, animated: false, completion: nil)
        });
}

func menuAction_addToPlaylistInFolder(_ song : Path, overrideName : String?, playlistChooseFolder : Path, viewController : UIViewController) -> UIAlertAction
{
    return UIAlertAction(title: overrideName != nil ? overrideName : leafName(playlistChooseFolder) + "/ ..."	, style: .default, handler:
                            { (UIAlertAction) -> () in do
        {
            let alert = UIAlertController(title: nil, message: "Add to Playlist", preferredStyle: .alert)
            
            let leafs = try playlistChooseFolder.contentsOfDirectory();
            
            for l in leafs {
                if (!l.isFolder && l.relativePath.hasSuffix(".playlist"))
                {
                    alert.addAction(menuAction_addToPlaylistExact(playlistPath: l, songToAdd: song, viewController: viewController));
                }
                else if (l.isFolder)
                {
                    alert.addAction(menuAction_addToPlaylistInFolder(song, overrideName: nil, playlistChooseFolder: l, viewController: viewController));
                }
            }
            alert.addAction(menuAction_neverMind());
            viewController.present(alert, animated: false, completion: nil)
        }
        catch {
            reportMessage(uic: viewController, message: "Failed to get dir content: \(error)")
        }
            
    });
}

func menuAction_addToPlaylistExact(playlistPath : Path, songToAdd: Path, viewController : UIViewController) -> UIAlertAction
{
    return UIAlertAction(title: leafName(playlistPath) , style: .default, handler:
        { (UIAlertAction) -> () in
            
//            var uploadFolder = mega().parentNode(for: playlistNode);
//            while (uploadFolder != nil && uploadFolder!.type == .file)
//            {
//                uploadFolder = mega().parentNode(for: uploadFolder!);
//            }
//            if (uploadFolder == nil) { return; }

        do {
            let json = try getPlaylistFileAsJSON(playlistPath, editedIfAvail: true);
            
            var songs : [Path] = [];
            loadSongsFromPlaylistRecursive(json: json, &songs, recurse: true, filterIntent: nil);
            songs.append(songToAdd);
            
            let s = globals.playQueue.songArrayToJSON(optionalExtraFirstNode: nil, array: songs);
            
            let url = URL(fileURLWithPath: playlistPath.edited().fullPath());
            try! s.write(to: url, atomically: true, encoding: .utf8)
            
            for i in 0..<app().recentPlaylists.count {
                if (app().recentPlaylists[i] == playlistPath) {
                    app().recentPlaylists.remove(at: i);
                    break;
                }
            }
            while (app().recentPlaylists.count > 5)
            {
                app().recentPlaylists.remove(at: 5);
            }
            app().recentPlaylists.insert(playlistPath, at: 0);
        }
        catch {
            reportMessage(uic: viewController, message: "Failed to load: \(error)")
        }
    });
}

func ExtractAndApplyTags(_ n : Path, overwriteExistingTags : Bool, countProcessed : inout Int, countNotDownloaded : inout Int, countNoTags : inout Int, countUpdated : inout Int) -> Bool
{
    if (!isPlayable(n, orMightContainPlayable: false))
    { return true; }
    
    let songPath = n; //globals.storageModel.songFingerprintPath(node: node);
    //if (songPath == nil) { return false; }

    if !FileManager.default.fileExists(atPath: songPath.fullPath())
    { countNotDownloaded += 1; return false; }
    
    var title : NSString? = nil;
    var artist : NSString? = nil;
    var bpm : NSString? = nil;

    countProcessed += 1;
    
    if (SongsCPP.getSongProperties(songPath.fullPath(), title: &title, artist: &artist, bpm: &bpm))
    {
        if (title == nil && artist == nil && bpm == nil)
        {
            countNoTags += 1;
        }
        
//        if (title != nil)
//        {
//            if (node.customTitle == nil || (node.customTitle != String(title!) && overwriteExistingTags))
//            {
//                mega().setCustomNodeAttribute(node, name: "title", value: String(title!), delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in }));
//                countUpdated += 1;
//            }
//        }
//        if (artist != nil)
//        {
//            if (node.customArtist == nil || (node.customArtist != String(artist!) && overwriteExistingTags))
//            {
//                mega().setCustomNodeAttribute(node, name: "artist", value: String(artist!), delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in }));
//                countUpdated += 1;
//            }
//        }
//        if (bpm != nil)
//        {
//            if (node.customBPM == nil || (node.customBPM != String(bpm!) && overwriteExistingTags))
//            {
//                mega().setCustomNodeAttribute(node, name: "BPM", value: String(bpm!), delegate: MEGARequestOneShot(onFinish: { (e: MEGAError) -> Void in }));
//                countUpdated += 1;
//            }
//        }
    }
    else
    {
        countNoTags += 1;
    }
    return true;
}

func ExtractAndApplyTagsRecurse(_ node : String, recursive : Bool, overwriteExistingTags: Bool, countProcessed : inout Int, countNotDownloaded : inout Int, countNoTags : inout Int, countUpdated : inout Int)
{
//    if (node.type != .file)
//    {
//        let list = mega().children(forParent: node, order: 1);
//        for i in 0..<list.size.intValue {
//            if let n = list.node(at: i) {
//                if (n.type == .file)
//                {
//                    _ = ExtractAndApplyTags(n, overwriteExistingTags: overwriteExistingTags, countProcessed: &countProcessed, countNotDownloaded: &countNotDownloaded, countNoTags: &countNoTags, countUpdated: &countUpdated);
//                }
//                else if (recursive)
//                {
//                    ExtractAndApplyTagsRecurse(n, recursive: recursive, overwriteExistingTags: overwriteExistingTags, countProcessed: &countProcessed, countNotDownloaded: &countNotDownloaded, countNoTags: &countNoTags, countUpdated: &countUpdated);
//                }
//            }
//        }
//    }
}

func ExtractAndApplyTags(_ n : String, recursive : Bool, overwriteExistingTags: Bool, uic : UIViewController)
{
//    if (CheckOnlineOrWarn("Please go online first so the file attributes can be updated in MEGA", uic: uic))
//    {
        var countProcessed = 0;
        var countNotDownloaded = 0;
        var countNoTags = 0;
        var countUpdated = 0;
    
    // todo: update index file
        ExtractAndApplyTagsRecurse(n, recursive: recursive, overwriteExistingTags: overwriteExistingTags, countProcessed: &countProcessed, countNotDownloaded: &countNotDownloaded, countNoTags: &countNoTags, countUpdated: &countUpdated);
        var message = "Processed " + String(countProcessed) + " files.";
        if (countNotDownloaded > 0)
        {
            message += " " + String(countNotDownloaded) + " were skipped as they have not been downloaded yet.";
        }
        if (countNoTags > 0)
        {
            message += " " + String(countNoTags) + " had no Title/Artist/BPM tags.";
        }
        if (overwriteExistingTags)
        {
            message += " Set or updated " + String(countUpdated) + " fields that were new or different.";
        }
        else
        {
            message += " Set " + String(countUpdated) + " fields that had not been set yet.";
        }
        reportMessage(uic: uic, message: message);
//    }
}



