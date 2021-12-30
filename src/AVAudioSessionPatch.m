//
//  AVAudioSessionPatch.m
//  SongMe
//
//  Created by Admin on 13/11/2019.
//  Copyright © 2019 mattweir. All rights reserved.
//

#import <Foundation/Foundation.h>


#import "AVAudioSessionPatch.h"

@implementation AVAudioSessionPatch

+ (BOOL)setSession:(AVAudioSession *)session category:(AVAudioSessionCategory)category withOptions:(AVAudioSessionCategoryOptions)options error:(__autoreleasing NSError **)outError {
    return [session setCategory:category withOptions:options error:outError];
}

@end
