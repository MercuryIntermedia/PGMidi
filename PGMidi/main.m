//
//  main.m
//  PGMidi
//
//  Created by Demetri Miller on 3/16/15.
//
//

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
#import <UIKit/UIKit.h>

int main(int argc, char *argv[])
{
    @autoreleasepool {
        int retVal = UIApplicationMain(argc, argv, nil, nil);
        return retVal;
    }
}

#else

#import <Cocoa/Cocoa.h>
int main(int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}

#endif
