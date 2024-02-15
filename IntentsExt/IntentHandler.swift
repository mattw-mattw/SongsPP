//
//  IntentHandler.swift
//  IntentsExt
//
//  Created by Matt Weir on 20/05/22.
//  Copyright © 2022 mattweir. All rights reserved.
//

import Intents

class IntentHandler: INExtension, INPlayMediaIntentHandling {
    
    
    func resolvePlayShuffled(for intent: INPlayMediaIntent, with completion: @escaping (INBooleanResolutionResult) -> Void) {
        completion(INBooleanResolutionResult.success(with: true));
    }
    
    func resolveMediaItems(for intent: INPlayMediaIntent) async -> [INPlayMediaMediaItemResolutionResult] {
        return [INPlayMediaMediaItemResolutionResult.unsupported(forReason: .unsupportedMediaType)];
//        INMediaItemResolutionResult
//        INMediaItem
    }

    func handle(intent: INPlayMediaIntent, completion: @escaping (INPlayMediaIntentResponse) -> Void) {
        completion(INPlayMediaIntentResponse(code: .continueInApp, userActivity: NSUserActivity(activityType: "Play mad world")));
    }
    
    override func handler(for intent: INIntent) -> Any {
        // This is the default implementation.  If you want different objects to handle different intents,
        // you can override this and return the handler you want for that particular intent.
        
        return self
    }
    
}
