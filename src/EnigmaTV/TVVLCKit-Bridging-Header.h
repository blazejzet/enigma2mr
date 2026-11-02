//
//  TVVLCKit-Bridging-Header.h
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 16.01.2018.
//  Copyright © 2018 Blazej Zyglarski. All rights reserved.
//

#ifndef TVVLCKit_Bridging_Header_h
#define TVVLCKit_Bridging_Header_h
#import <TVVLCKit/TVVLCKit.h>
#include<ifaddrs.h>
#import <Foundation/Foundation.h>
#import <CloudKit/CloudKit.h>

/// The app's default CloudKit container, or nil when the build has no iCloud entitlement –
/// CloudKit then raises an Objective-C exception, which must be caught here: it cannot unwind
/// through Swift frames.
static inline CKContainer * _Nullable EnigmaDefaultCloudContainer(void) {
    @try {
        return [CKContainer defaultContainer];
    } @catch (NSException *exception) {
        NSLog(@"EnigmaTV: CloudKit unavailable (%@: %@)", exception.name, exception.reason);
        return nil;
    }
}

#endif /* TVVLCKit_Bridging_Header_h */
