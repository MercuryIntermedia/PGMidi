//
//  MidiMonitor_OSXTests.m
//  MidiMonitor-OSXTests
//
//  Created by Demetri Miller on 3/16/15.
//
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

@interface MidiMonitor_OSXTests : XCTestCase

@end

@implementation MidiMonitor_OSXTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    XCTAssert(YES, @"Pass");
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
