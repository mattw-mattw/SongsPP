//
//  AVAudioSessionPatch.h
//  just-exploring-3
//
//  Created by Admin on 13/11/2019.
//  Copyright © 2019 mattweir. All rights reserved.
//

#ifndef AVAudioSessionPatch_h
#define AVAudioSessionPatch_h

@import AVFoundation;

NS_ASSUME_NONNULL_BEGIN

@interface AVAudioSessionPatch : NSObject

+ (BOOL)setSession:(AVAudioSession *)session category:(AVAudioSessionCategory)category withOptions:(AVAudioSessionCategoryOptions)options error:(__autoreleasing NSError **)outError;

@end

NS_ASSUME_NONNULL_END

#endif /* AVAudioSessionPatch_h */
