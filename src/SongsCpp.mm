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

#pragma clang diagnostic pop

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

@end



