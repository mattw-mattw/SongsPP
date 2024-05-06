//
//  SongsCpp.m
//  Songs++
//
//  Created by Matt Weir on 14/03/21.
//  Copyright © 2021 mattweir. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SongsCPP : NSObject {}

+ (bool)GetSongProperties:(NSString *)filePath title:(NSString **)title artist:(NSString **)artist bpm:(NSString **)bpm ;
+ (bool)StartScanDoubleDirs:(NSString *)lhsPath rhs:(NSString *)rhsPath removeUnmatchedOnRight:(bool)removeUnmatchedOnRight;
+ (bool)isFinishedScanDoubleDirs;
+ (bool)ShutdownScanDoubleDirs:(NSString **)err;
+ (NSMutableArray*)currentScanPaths;
+ (NSMutableArray*)currentCopyPaths;
+ (void)scanCopyCounts:(NSInteger *)scanWaiting :(NSInteger *)scanDone :(NSInteger *)copyWaiting :(NSInteger *)copyDone;

@end
