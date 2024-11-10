//
//  SongsCpp.m
//  Songs++
//
//  Created by Matt Weir on 14/03/21.
//  Copyright © 2021 mattweir. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SongsCpp.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation-deprecated-sync"
#pragma clang diagnostic ignored "-Wdocumentation"

#include "taglib/tag.h"
#include "taglib/fileref.h"
#include "taglib/tpropertymap.h"

#include "/Users/matt/repos/sdk/include/mega/filesystem.h"
#include "/Users/matt/repos/sdk/include/mega/posix/megafs.h"

#include "megaapi.h"

#include <copyfile.h>
#include <fts.h>
#include <stdio.h>

#pragma clang diagnostic pop

using namespace std;
using namespace mega;

const std::vector<std::string> playableExtensions { ".mp3", ".m4a", ".aac", ".wav", ".flac", ".aiff", ".au", ".pcm", ".ac3", ".aa", ".aax" };
const std::vector<std::string> artworkExtensions= { ".jpg", ".jpeg", ".png", ".bmp" };

bool isPlayable(const string& s)
{
    for (auto& pe : playableExtensions)
    {
        if (s.size() < pe.size()) continue;
        if (0 == strcasecmp(s.c_str() + s.size() - pe.size(), pe.c_str())) { return true; }
    }
    return false;
}

bool isArtwork(const string& s)
{
    for (auto& pe : artworkExtensions)
    {
        if (s.size() < pe.size()) continue;
        if (0 == strcasecmp(s.c_str() + s.size() - pe.size(), pe.c_str())) { return true; }
    }
    return false;
}

template <>
std::unique_ptr<DIR>::~unique_ptr()
{
    if (get()) ::closedir(release());
}

typedef pair<string, bool> StrB;
enum scanActionType { BothPresent, LeftPresent, RightPresent};

struct scanAction {
    LocalPath lhsPath;
    LocalPath rhsPath;
    bool lhsFolder;
    bool rhsFolder;
    scanActionType at;
};

class ScanDisplayPaths {
    std::list<string> scanPath;
    std::list<string> copyPath;
    std::mutex m;
public:
    vector<string> scanPaths() { lock_guard<mutex> g(m); return vector<string>(scanPath.begin(), scanPath.end()); }
    vector<string> copyPaths() { lock_guard<mutex> g(m); return vector<string>(copyPath.begin(), copyPath.end()); }
    void addScan(string s) { lock_guard<mutex> g(m); scanPath.emplace_back(std::move(s)); }
    void addCopy(string s) { lock_guard<mutex> g(m); copyPath.emplace_back(std::move(s)); }
    void removeScan(const string& s) { lock_guard<mutex> g(m); for (auto i = scanPath.begin(); i != scanPath.end(); ++i)  if (*i == s) { scanPath.erase(i); return; } }
    void removeCopy(const string& s) { lock_guard<mutex> g(m); for (auto i = copyPath.begin(); i != copyPath.end(); ++i)  if (*i == s) { copyPath.erase(i); return; } }
} scanDisplayPaths;

class scanQueue
{
    std::mutex m;
    std::condition_variable v;
    std::list<scanAction> q;
    string finalErr;
    size_t pushDirCount = 0;
    size_t popDirCount = 0;
    size_t completeDirCount = 0;
    size_t pushFileCount = 0;
    size_t popFileCount = 0;
    size_t skippedCopyCount = 0;
    size_t completeCopyCount = 0;

public:
    bool exit = false;
    std::vector<std::thread> threadVec;
    
    void getCounts(size_t& scanWait, size_t& scanDone, size_t& copyWait, size_t& copySkipped, size_t& copyDone)
    {
        lock_guard<mutex> g(m);
        scanWait = pushDirCount - popDirCount;
        scanDone = completeDirCount;
        copyWait = pushFileCount - popFileCount;
        copySkipped = skippedCopyCount;
        copyDone = completeCopyCount;
    }
    
    bool pop(scanAction& p)
    {
        bool ret = false;
        {
            std::unique_lock<mutex> g(m);
            v.wait(g, [this, &p, &ret](){
                if (exit) return true;
                if (q.empty()) return false;
                p = q.front();
                q.pop_front();
                ret = true;
                (p.lhsFolder ? popDirCount : popFileCount) += 1;
                return true;
            });
        }
        if (ret) v.notify_all();
        return ret;
    }
    
    void push(scanAction&& p)
    {
        {
            std::unique_lock<mutex> g(m);
            q.push_back(std::move(p));
            (p.lhsFolder ? pushDirCount : pushFileCount) += 1;
        }
        v.notify_all();
    }
    
    void fail(string err)
    {
        std::unique_lock<mutex> g(m);
        finalErr = err;
        exit = true;
    }
    
    void completedOne(bool folder, bool skipped)
    {
        {
            std::unique_lock<mutex> g(m);
            (folder ? completeDirCount : (skipped ? skippedCopyCount : completeCopyCount)) += 1;
        }
        v.notify_all();
    }
    
    bool isFinished()
    {
        std::unique_lock<mutex> g(m);
        if (exit) return true;
        if (completeDirCount >= pushDirCount && (skippedCopyCount + completeCopyCount) >= pushFileCount) return true;
        return false;
    }

    bool cancel()
    {
        std::unique_lock<mutex> g(m);
        exit = true;
        if (finalErr.empty()) finalErr = "cancelled";
        return true;
    }

    string shutdown()
    {
        exit = true;
        v.notify_all();
        for (auto& t : threadVec) { t.join(); }
        threadVec.clear();
        return finalErr;
    }
    
    struct SongTags {
        std::string path, title, artist, bpm, thumb, duration;
    };
    
    std::mutex songTagsMutex;
    std::vector<SongTags> songTags;
    std::map<string, string> newJpegFileThumbsByPath;
};

string errText(int e)
{
    return to_string(e) + " (" + strerror(e) + ")";
}

bool scanOneFolder(LocalPath path, std::vector<StrB>& leafs, string& err)
{
    errno = 0;
    int n = 0;
    unique_ptr<DIR> dp(opendir(path.toPath().c_str()));
    if (!dp) 
    {
        auto e = errText(errno);
        err = "Error " + e + " opening folder to scan at: " + path.toPath();
        return false;
    }
    while (dirent* d = ::readdir(dp.get()))
    {
        ScopedLengthRestore restore(path);

        if (*d->d_name != '.' || (d->d_name[1] && (d->d_name[1] != '.' || d->d_name[2])))
        {
            if (strcmp(d->d_name, ".DS_Store") == 0) continue;
            if (strcmp(d->d_name, "desktop.ini") == 0) continue;
            if (d->d_type == DT_DIR)
            {
                leafs.emplace_back(string(d->d_name), true);
                FileSystemAccess::normalize(&leafs.back().first);
            }
            else if (d->d_type == DT_REG)
            {
                leafs.emplace_back(string(d->d_name), false);
                FileSystemAccess::normalize(&leafs.back().first);
            }
            ++n;
        }
    }
    if (errno)
    {
        auto e = errText(errno);
        err = "Error " + e + " during scan of: " + path.toPath();
        if (n)
        {
            err += " after already scanning "+ std::to_string(n) + "entries";
        }
        return false;
    }
    return true;
}

bool scan(LocalPath lhsPath, LocalPath rhsPath, string& err, scanQueue& sq)
{
    bool ret = false;
    PosixFileSystemAccess fsa;
    
    std::vector<pair<string, bool>> leafs1;
    std::vector<pair<string, bool>> leafs2;

    scanDisplayPaths.addScan(lhsPath.leafName().toPath());
    
    if (scanOneFolder(lhsPath, leafs1, err) &&
        scanOneFolder(rhsPath, leafs2, err))
    {
        ret = true;
        std::sort(leafs1.begin(), leafs1.end(), [](StrB& a, StrB& b){ return compareUtf(a.first, false, b.first, false, false) < 0; });
        std::sort(leafs2.begin(), leafs2.end(), [](StrB& a, StrB& b){ return compareUtf(a.first, false, b.first, false, false) < 0; });
        
        size_t i = 0, j = 0;
        
        for (;;) {
            StrB* ileaf = i < leafs1.size() ? &leafs1[i] : nullptr;
            StrB* jleaf = j < leafs2.size() ? &leafs2[j] : nullptr;
            int cmp = 0;
            if (ileaf && jleaf) {
                cmp = compareUtf(ileaf->first, false, jleaf->first, false, false);
                if (cmp < 0) { jleaf = nullptr; }
                else if (cmp > 0) { ileaf = nullptr; }
            }
            if (!ileaf && !jleaf) { break; }
            
            ScopedLengthRestore restore1(lhsPath);
            ScopedLengthRestore restore2(rhsPath);
            
            lhsPath.appendWithSeparator(LocalPath::fromPath((ileaf ? ileaf->first : jleaf->first), fsa), true);
            rhsPath.appendWithSeparator(LocalPath::fromPath((jleaf ? jleaf->first : ileaf->first), fsa), true);
            
            if (ileaf && jleaf) {
                
                i += 1;
                j += 1;
                
                sq.push(scanAction{lhsPath, rhsPath, ileaf->second, jleaf->second, BothPresent});
            }
            else if (ileaf) {
                i += 1;
                sq.push(scanAction{lhsPath, rhsPath, ileaf->second, false, LeftPresent});
            }
            else if (jleaf) {
                j += 1;
                sq.push(scanAction{lhsPath, rhsPath, false, jleaf->second, RightPresent});
            }
            else {
                break;
            }
        }
    }
    scanDisplayPaths.removeScan(lhsPath.leafName().toPath());
    return ret;
}

@implementation SongsCPP

std::string tmpPath;
+ (void)SetTmpPath:(NSString *)filePath {
    tmpPath = [filePath UTF8String];
}
    
std::string thumbPath;
+ (void)SetThumbPath:(NSString *)filePath {
    thumbPath = [filePath UTF8String];
}
    
+ (bool)GetSongProperties:(NSString *)filePath title:(NSString **)title artist:(NSString **)artist bpm:(NSString **)bpm {

    try {
        TagLib::FileRef f([filePath UTF8String]);
        
        if (!f.isNull() && f.tag()) {
            
            TagLib::Tag* tag = f.tag();
            
            *title = [[NSString alloc]initWithUTF8String:tag->title().toCString(true)];
            *artist = [[NSString alloc]initWithUTF8String:tag->artist().toCString(true)];

            TagLib::PropertyMap tags = f.file()->properties();
            auto it = tags.find("BPM");
            if (it != tags.end()) {
                for (auto& s : it->second) *bpm = [[NSString alloc]initWithUTF8String:s.toCString(true)];
            }
            return true;
        }
    } catch (...) {
        
    }
    return false;
}

int recursive_delete(const char *dir)
{
    char *files[] = { (char*)dir, NULL };

    // FTS_NOCHDIR  - Avoid changing cwd, which could cause unexpected behavior
    //                in multithreaded programs
    // FTS_PHYSICAL - Don't follow symlinks. Prevents deletion of files outside
    //                of the specified directory
    // FTS_XDEV     - Don't cross filesystem boundaries
    FTS *ftsp = fts_open(files, FTS_NOCHDIR | FTS_PHYSICAL | FTS_XDEV, NULL);
    if (!ftsp) {
        return errno;
    }

    FTSENT *curr;
    while ((curr = fts_read(ftsp))) {
        switch (curr->fts_info) {
        case FTS_NS:
        case FTS_DNR:
        case FTS_ERR:
             fts_close(ftsp);
             return curr->fts_errno;

        case FTS_DC:
        case FTS_DOT:
        case FTS_NSOK:
            // Not reached unless FTS_LOGICAL, FTS_SEEDOT, or FTS_NOSTAT were passed to fts_open()
            break;

        case FTS_D:
            // wait for post-order
            break;

        case FTS_DP:
        case FTS_F:
        case FTS_SL:
        case FTS_SLNONE:
        case FTS_DEFAULT:
            if (remove(curr->fts_accpath) < 0) {
                int e = errno;
                fts_close(ftsp);
                return e;
            }
            break;
        }
    }
    
    fts_close(ftsp);
    return 0;
}

shared_ptr<scanQueue> curScan;

::mega::MegaApi thumbnailSdk("appKey");
static atomic<int> tmpJpg {0};

NSString *
objcString(char const *s)
{
  return [NSString stringWithCString:s encoding:NSUTF8StringEncoding];
}

class myMIS : public MegaInputStream
{
public:
    int64_t size;
    ifstream ifs;

    myMIS(const char* filename)
        : ifs(filename, ios::binary)
    {
        ifs.seekg(0, ios::end);
        size = ifs.tellg();
        ifs.seekg(0, ios::beg);
    }
    virtual int64_t getSize() { return size; }

    virtual bool read(char *buffer, size_t size) {
        if (buffer)
        {
            ifs.read(buffer, size);
        }
        else
        {
            ifs.seekg(size, ios::cur);
        }
        return !ifs.fail();
    }
};

bool generateThumbnailAndFingerprint(const std::string& pictureFile, std::string& fp_str)
{
    std::string thumbnailJpg = tmpPath + "/" + std::to_string(++tmpJpg) + "-thumb.jpg";
    if (!thumbnailSdk.createThumbnail(pictureFile.c_str(), thumbnailJpg.c_str()))
    {
        return false;
    }

    myMIS mfis(thumbnailJpg.c_str());
    unique_ptr<char[]> fp(thumbnailSdk.getFingerprint(&mfis, 0)); // strip out fingerprint's date
    if (fp)
    {
        std::string fpJpg = thumbPath + "/" + fp.get() + ".jpg";
        rename(thumbnailJpg.c_str(), fpJpg.c_str());
        fp_str = fp.get();
        return true;
    }
    unlink(thumbnailJpg.c_str());
    return false;
}

+ (bool)genImageThumbnailAndFingerprint:(NSString *)path :(NSString **)thumb
{
    string fp_str;
    bool b = generateThumbnailAndFingerprint([path UTF8String], fp_str);
    if (b)
    {
        *thumb = [[NSString alloc]initWithUTF8String:fp_str.c_str()];
    }
    return b;
}

void doCopyFile(const scanAction& op, scanQueue& sq, bool extractTags)
{
    scanDisplayPaths.addCopy(op.lhsPath.leafName().toPath());
    
    copyfile_state_t cfs = ::copyfile_state_alloc();
    auto cfe = copyfile(op.lhsPath.toPath().c_str(), op.rhsPath.toPath().c_str(), cfs, COPYFILE_DATA | COPYFILE_STAT);
    copyfile_state_free(cfs);

    scanDisplayPaths.removeCopy(op.lhsPath.leafName().toPath());

    if (cfe)
    {
        if (cfe == -1) cfe = errno;
        
        sq.fail("Error " + errText(cfe) + " copying  " + op.lhsPath.leafName().toPath());
    }
    else if (extractTags && isPlayable(op.rhsPath.toPath()))
    {
        try {
            TagLib::FileRef f(op.rhsPath.toPath().c_str());
            
            if (!f.isNull() && f.tag()) {
                
                TagLib::Tag* tag = f.tag();
                
                
                scanQueue::SongTags t;
                
                t.path = op.rhsPath.toPath().c_str();
                t.title = tag->title().toCString(true);
                t.artist = tag->artist().toCString(true);
                
                if (op.rhsPath.toPath().find(".m4a") == std::string::npos)
                {
                    // bit crashy for m4a
                    TagLib::PropertyMap tags = f.file()->properties();
                    auto it = tags.find("BPM");
                    if (it != tags.end()) {
                        for (auto& s : it->second) {
                            t.bpm = s.toCString(true);
                        }
                    }
                }
                
                if (auto ap = f.file()->audioProperties())
                {
                    if (auto sec = ap->lengthInSeconds())
                    {
                        t.duration = to_string(sec/60) + ":";
                        sec = sec - (sec/60)*60;
                        if (sec < 10) t.duration += "0";
                        t.duration += to_string(sec);
                    }
                }
                
                auto imageList = tag->complexProperties("PICTURE");
                
                for (auto i = imageList.begin(); i != imageList.end(); ++i)
                {
                    auto it1 = i->find("mimeType");
                    auto it2 = i->find("pictureType");
                    auto it3 = i->find("data");
                    if (it1 != i->end() && it2 != i->end() && it3 != i->end() &&
                        it1->second.toString().toCString() == string("image/jpeg") &&
                        it2->second.toString().toCString() == string("Front Cover"))
                    {
                        bool ok = true;
                        auto v = it3->second.toByteVector(&ok);
                        
                        if (ok)
                        {
                            std::string tempName = tmpPath + "/" + std::to_string(++tmpJpg) + ".jpg";
                            std::ofstream f(tempName, ios::binary);
                            f.write(v.data(), v.size());
                            f.close();
                            
                            string fp;
                            if (generateThumbnailAndFingerprint(tempName, fp))
                            {
                                t.thumb = string(fp);
                            }
                            unlink(tempName.c_str());
                        }
                    }
                }
                std::lock_guard<std::mutex> g(sq.songTagsMutex);
                sq.songTags.push_back(t);
            }
        } catch (...) {
            
        }
    }
    else if (extractTags && isArtwork(op.rhsPath.toPath()))
    {
        std::string thumbnailJpg = tmpPath + "/" + std::to_string(++tmpJpg) + "-thumb.jpg";
        thumbnailSdk.createThumbnail(op.rhsPath.toPath().c_str(), thumbnailJpg.c_str());
        myMIS mfis(thumbnailJpg.c_str());
        unique_ptr<char[]> fp(thumbnailSdk.getFingerprint(&mfis, 0));  // strip out fingerprint's date
        if (fp)
        {
            std::string fpJpg = thumbPath + "/" + fp.get() + ".jpg";
            rename(thumbnailJpg.c_str(), fpJpg.c_str());

            std::lock_guard<std::mutex> g(sq.songTagsMutex);
            
            auto parent = op.rhsPath;
            PosixFileSystemAccess fsa;
            if (auto index = parent.getLeafnameByteIndex(fsa))
            {
                parent.truncate(index);
                parent.trimNonDriveTrailingSeparator();
                sq.newJpegFileThumbsByPath[parent.toPath()] = string(fp.get());
            }
        }
        else
        {
            unlink(thumbnailJpg.c_str());
        }
    }
}

+ (bool)StartScanDoubleDirs:(NSString *)lhsPath rhs:(NSString *)rhsPath removeUnmatchedOnRight:(bool)removeUnmatchedOnRight compareMtimeForCopy:(bool)compareMtimeForCopy extractTags:(bool)extractTags {
    
    PosixFileSystemAccess fsa;
    
    auto a = LocalPath::fromPath([lhsPath UTF8String], fsa);
    auto b = LocalPath::fromPath([rhsPath UTF8String], fsa);
    string err;
    
    curScan.reset(new scanQueue);
    curScan->push(scanAction{a, b, true, true, BothPresent});
    
    for (int i = 0; i < 5; ++i)
    {
        curScan->threadVec.emplace_back(std::thread([sq = curScan, removeUnmatchedOnRight, compareMtimeForCopy, extractTags](){
            scanAction op;
            while (sq->pop(op))
            {
                bool copied = false;
                switch (op.at)
                {
                    case BothPresent:
                        if (op.lhsFolder && op.rhsFolder)
                        {
                            string err;
                            if (!scan(op.lhsPath, op.rhsPath, err, *sq))
                            {
                                sq->fail(err);
                            }
                        }
                        else if (!op.lhsFolder && !op.rhsFolder)
                        {
                            if (compareMtimeForCopy)
                            {
                                struct stat lhs_stat, rhs_stat;
                                if (0 != stat(op.lhsPath.toPath().c_str(), &lhs_stat) ||
                                    0 != stat(op.rhsPath.toPath().c_str(), &rhs_stat))
                                {
                                    auto e = errText(errno);
                                    sq->fail("Error " + e + " getting modified time for  " + op.rhsPath.leafName().toPath());
                                }
                                else if (lhs_stat.st_mtimespec.tv_sec > rhs_stat.st_mtimespec.tv_sec)
                                {
                                    doCopyFile(op, *sq, extractTags);
                                    copied = true;
                                }
                            }
                            else
                            {
                                // skip existing files without checking anything
                            }
                        }
                        else {
                            sq->fail("File/Folder mismatch at " + op.lhsPath.leafName().toPath());
                        }
                        break;
                        
                    case LeftPresent:
                        if (op.lhsFolder)
                        {
                            string err;
                            //mode_t _ = umask(0);  // bits that would be auto-removed
                            bool mkdir_success = !mkdir(op.rhsPath.toPath().c_str(), 0x1FF);//0777);
                            //umask(mode);
                            
                            if (!mkdir_success)
                            {
                                auto e = errText(errno);
                                sq->fail("Error " + e + " creating folder  " + op.rhsPath.leafName().toPath());
                            }
                            else if (!scan(op.lhsPath, op.rhsPath, err, *sq))
                            {
                                sq->fail(err);
                            }
                        }
                        else
                        {
                            doCopyFile(op, *sq, extractTags);
                            copied = true;
                        }
                        break;
                        
                    case RightPresent:
                        if (removeUnmatchedOnRight)
                        {
                            if (op.rhsFolder)
                            {
                                int err = recursive_delete(op.rhsPath.toPath().c_str());
                                if (err)
                                {
                                    sq->fail("Error " + errText(err) + " removing folder " + op.rhsPath.leafName().toPath());
                                }
                            }
                            else if (0 != unlink(op.rhsPath.toPath().c_str()))
                            {
                                auto e = errText(errno);
                                sq->fail("Error " + e + " removing " + op.rhsPath.leafName().toPath());
                            }
                        }
                        break;
                        
                }
                sq->completedOne(op.lhsFolder, !copied);
            }
        }));
    }
    return true;
}

+ (bool)isFinishedScanDoubleDirs {
    return curScan ? curScan->isFinished() : true;
}

+ (bool)ShutdownScanDoubleDirs:(NSString **)err {
    if (curScan && !curScan->isFinished()) curScan->cancel();
    string finalErr = curScan ? curScan->shutdown() : "";
    //curScan.reset();
    *err = [[NSString alloc]initWithUTF8String:finalErr.c_str()];
    return finalErr.empty();
}
    
+ (NSMutableArray*)currentScanPaths {
    
    NSMutableArray *fileNames = [NSMutableArray array];
    
    auto v = scanDisplayPaths.scanPaths();
    for (auto& s : v)
    {
        [fileNames addObject: [NSString stringWithUTF8String:s.c_str()]];
    }
    return fileNames;
}

+ (NSMutableArray*)currentCopyPaths {
    
    NSMutableArray *fileNames = [NSMutableArray array];
    
    auto v = scanDisplayPaths.copyPaths();
    for (auto& s : v)
    {
        [fileNames addObject: [NSString stringWithUTF8String:s.c_str()]];
    }
    return fileNames;
}

+ (void)scanCopyCounts:(NSInteger *)scanWaiting :(NSInteger *)scanDone :(NSInteger *)copyWaiting :(NSInteger *)copySkipped :(NSInteger *)copyDone {
    if (curScan)
    {
        size_t a, b, c, d, e;
        curScan->getCounts(a, b, c, d, e);
        *scanWaiting = a;
        *scanDone = b;
        *copyWaiting = c;
        *copySkipped = d;
        *copyDone = e;
    }
}

+ (bool)getNextTagSet:(NSString **)path :(NSString **)title :(NSString **)artist :(NSString **)bpm :(NSString **)thumb :(NSString **)duration {
    if (!curScan || curScan->songTags.empty()) return false;
    auto& t = curScan->songTags.back();
    *path = [[NSString alloc]initWithUTF8String:t.path.c_str()];
    *title = [[NSString alloc]initWithUTF8String:t.title.c_str()];
    *artist = [[NSString alloc]initWithUTF8String:t.artist.c_str()];
    *bpm = [[NSString alloc]initWithUTF8String:t.bpm.c_str()];
    *thumb = [[NSString alloc]initWithUTF8String:t.thumb.c_str()];
    *duration = [[NSString alloc]initWithUTF8String:t.duration.c_str()];
    curScan->songTags.pop_back();
    return true;
}

+ (bool)getNextFolderThumb:(NSString **)path :(NSString **)thumb
{
    if (!curScan || curScan->newJpegFileThumbsByPath.empty()) return false;
    auto it = curScan->newJpegFileThumbsByPath.begin();
    *path = [[NSString alloc]initWithUTF8String:it->first.c_str()];
    *thumb = [[NSString alloc]initWithUTF8String:it->second.c_str()];
    curScan->newJpegFileThumbsByPath.erase(it);
    return true;
}

@end



