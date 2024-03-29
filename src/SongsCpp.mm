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


class scanQueue
{
    std::mutex m;
    std::condition_variable v;
    std::list<scanAction> q;
    string finalErr;
    size_t pushCount = 0;
    size_t popCount = 0;
    size_t completeCount = 0;
    
public:
    bool exit = false;
    
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
                popCount += 1;
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
            pushCount += 1;
        }
        v.notify_all();
    }
    
    void fail(string err)
    {
        std::unique_lock<mutex> g(m);
        finalErr = err;
        exit = true;
    }
    
    void completedOne()
    {
        {
            std::unique_lock<mutex> g(m);
            completeCount += 1;
        }
        v.notify_all();
    }
    
    string waitFinish()
    {
        std::unique_lock<mutex> g(m);
        v.wait(g, [this](){
            if (exit) return true;
            if (completeCount >= pushCount) return true;
            return false;
        });
        exit = true;
        v.notify_all();
        return finalErr;
    }
};


bool scanOneFolder(LocalPath path, std::vector<StrB>& leafs, string& err)
{
    unique_ptr<DIR> dp(opendir(path.toPath().c_str()));
    if (!dp) 
    {
        auto e = errno;
        err = "Error " + std::to_string(e) + " at " + path.toPath();
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
        }
    }
    return true;
}

bool scan(LocalPath lhsPath, LocalPath rhsPath, string& err, scanQueue& sq)
{
    PosixFileSystemAccess fsa;
    
    std::vector<pair<string, bool>> leafs1;
    std::vector<pair<string, bool>> leafs2;

    if (!scanOneFolder(lhsPath, leafs1, err)) return false;
    if (!scanOneFolder(rhsPath, leafs2, err)) return false;

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
            StrB* ileaf3 = i < leafs1.size() ? &leafs1[i] : nullptr;
            StrB* jleaf3 = j < leafs2.size() ? &leafs2[j] : nullptr;
            
            i += 1;
            sq.push(scanAction{lhsPath, rhsPath, ileaf->second, false, LeftPresent});
        }
        else if (jleaf) {
            
            StrB* ileaf2 = i < leafs1.size() ? &leafs1[i] : nullptr;
            StrB* jleaf2 = j < leafs2.size() ? &leafs2[j] : nullptr;
            
            j += 1;
            sq.push(scanAction{lhsPath, rhsPath, false, jleaf->second, RightPresent});
        }
        else {
            break;
        }
    }
    return true;
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



+ (bool)ScanDoubleDirs:(NSString *)lhsPath rhs:(NSString *)rhsPath {

    PosixFileSystemAccess fsa;

    auto a = LocalPath::fromPath([lhsPath UTF8String], fsa);
    auto b = LocalPath::fromPath([rhsPath UTF8String], fsa);
    string err;
    
    scanQueue sq;
    sq.push(scanAction{a, b, true, true, BothPresent});
    
    std::vector<std::thread> threadVec;
    for (int i = 0; i < 20; ++i)
    {
        threadVec.emplace_back(std::thread([&sq](){
            scanAction op;
            while (sq.pop(op))
            {
                switch (op.at)
                {
                    case BothPresent:
                        if (op.lhsFolder && op.rhsFolder)
                        {
                            string err;
                            if (!scan(op.lhsPath, op.rhsPath, err, sq))
                            {
                                sq.fail(err);
                            }
                        }
                        else if (!op.lhsFolder && !op.rhsFolder)
                        {
                            // skip existing files
                        }
                        else {
                            sq.fail("File/Folder mismatch at " + op.lhsPath.toPath() + " " + op.rhsPath.toPath());
                        }
                        break;
                        
                    case LeftPresent:
                        if (op.lhsFolder)
                        {
                            string err;
                            mode_t mode = umask(0);  // bits that would be auto-removed
                            bool mkdir_success = !mkdir(op.rhsPath.toPath().c_str(), 0777);
                            //umask(mode);
                            
                            if (!mkdir_success)
                            {
                                auto e = errno;
                                sq.fail("Error " + std::to_string(e) + " creating folder  " + op.rhsPath.toPath());
                            }
                            else if (!scan(op.lhsPath, op.rhsPath, err, sq))
                            {
                                sq.fail(err);
                            }
                        }
                        else
                        {
                            copyfile_state_t cfs = ::copyfile_state_alloc();
                            auto cfe = copyfile(op.lhsPath.toPath().c_str(), op.rhsPath.toPath().c_str(), cfs, COPYFILE_DATA | COPYFILE_STAT);
                            copyfile_state_free(cfs);

                            if (cfe)
                            {
                                auto e = errno;
                                sq.fail("Error " + std::to_string(cfe) + " " + std::to_string(e) + " copying  " + op.lhsPath.toPath() + " to " + op.rhsPath.toPath());
                            }
                        }
                        break;
                        
                    case RightPresent:
                        break;
                        
                }
                sq.completedOne();
            }
        }));
    }
    
    string finalErr = sq.waitFinish();

    for (auto& t : threadVec) { t.join(); }

    return finalErr.empty();
}
    


@end



