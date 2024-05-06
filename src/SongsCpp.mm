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

#include <copyfile.h>	
#include <fts.h>

#pragma clang diagnostic pop

using namespace std;
using namespace mega;


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
    size_t completeFileCount = 0;

public:
    bool exit = false;
    std::vector<std::thread> threadVec;
    
    void getCounts(size_t& scanWait, size_t& scanDone, size_t& copyWait, size_t& copyDone)
    {
        lock_guard<mutex> g(m);
        scanWait = pushDirCount - popDirCount;
        scanDone = completeDirCount;
        copyWait = pushFileCount - popFileCount;
        copyDone = completeFileCount;
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
    
    void completedOne(bool folder)
    {
        {
            std::unique_lock<mutex> g(m);
            (folder ? completeDirCount : completeFileCount) += 1;
        }
        v.notify_all();
    }
    
    bool isFinished()
    {
        std::unique_lock<mutex> g(m);
        if (exit) return true;
        if (completeDirCount >= pushDirCount && completeFileCount >= pushFileCount) return true;
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
        return finalErr;
    }
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
    int ret = 0;

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

+ (bool)StartScanDoubleDirs:(NSString *)lhsPath rhs:(NSString *)rhsPath removeUnmatchedOnRight:(bool)removeUnmatchedOnRight {
    
    PosixFileSystemAccess fsa;
    
    auto a = LocalPath::fromPath([lhsPath UTF8String], fsa);
    auto b = LocalPath::fromPath([rhsPath UTF8String], fsa);
    string err;
    
    curScan.reset(new scanQueue);
    curScan->push(scanAction{a, b, true, true, BothPresent});
    
    for (int i = 0; i < 5; ++i)
    {
        curScan->threadVec.emplace_back(std::thread([sq = curScan, removeUnmatchedOnRight](){
            scanAction op;
            while (sq->pop(op))
            {
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
                            // skip existing files
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
                            scanDisplayPaths.addCopy(op.lhsPath.leafName().toPath());
                            
                            copyfile_state_t cfs = ::copyfile_state_alloc();
                            auto cfe = copyfile(op.lhsPath.toPath().c_str(), op.rhsPath.toPath().c_str(), cfs, COPYFILE_DATA | COPYFILE_STAT);
                            copyfile_state_free(cfs);

                            scanDisplayPaths.removeCopy(op.lhsPath.leafName().toPath());

                            if (cfe)
                            {
                                if (cfe == -1) cfe = errno;
                                
                                sq->fail("Error " + errText(cfe) + " copying  " + op.lhsPath.leafName().toPath());
                            }
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
                sq->completedOne(op.lhsFolder);
            }
        }));
    }
    return true;
}

+ (bool)isFinishedScanDoubleDirs {
    return curScan->isFinished();
}

+ (bool)ShutdownScanDoubleDirs:(NSString **)err {
    if (!curScan->isFinished()) curScan->cancel();
    string finalErr = curScan->shutdown();
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

+ (void)scanCopyCounts:(NSInteger *)scanWaiting :(NSInteger *)scanDone :(NSInteger *)copyWaiting :(NSInteger *)copyDone {
    if (curScan)
    {
        size_t a, b, c, d;
        curScan->getCounts(a, b, c, d);
        *scanWaiting = a;
        *scanDone = b;
        *copyWaiting = c;
        *copyDone = d;
    }
}

@end



