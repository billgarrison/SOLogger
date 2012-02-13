//
//  MultipleLoggerTests.m
//  SOLogger
//
//  Copyright 2010 Standard Orbit Software, LLC. All rights reserved.
//

#import "SOLogger.h"

#pragma mark -

@interface MultipleLoggerTests : SenTestCase
{
    SOLogger *logger1, *logger2;
}
@end

@implementation MultipleLoggerTests

#pragma mark -
#pragma mark Tests

- (void) testSingleLoggerUsesDistinctASLClientPerThread;
{  
    STAssertTrue ([NSThread isMainThread], @"test is not running on the main thread, and that is highly irregular.");
    
	logger1 = [[SOLogger alloc] initWithFacility:@"Test Logger 1" options:SOLoggerDefaultASLOptions];	
    aslclient mainThreadClient = [logger1 aslclientRef];
    
    __block aslclient backgroundClient1 = NULL;
    __block aslclient backgroundClient2 = NULL;
    
    dispatch_group_t group = dispatch_group_create();
    
    /* Spawn two jobs on the background queues to obtain their per-thread aslclient. Each low, default, and high priority global queues use different threads. 
     Wait for the background blocks to finish executing, then assert test conditions.
     */
    
    dispatch_group_async (group, dispatch_get_global_queue (DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [logger1 notice:@"%s", _cmd];
        backgroundClient1 = [logger1 aslclientRef];
    });
    
    dispatch_group_async (group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [logger1 notice:@"%s", _cmd];
        backgroundClient2 = [logger1 aslclientRef];
    });
    
    dispatch_group_wait (group, dispatch_time (DISPATCH_TIME_NOW,  NSEC_PER_SEC * 2));
    dispatch_release (group); group = NULL;
    
	STAssertTrue (backgroundClient1 != NULL, @"postcondition violated" );
	STAssertTrue (backgroundClient1 != mainThreadClient, @"background thread should have had distinct aslclient from main thread." );
	
	STAssertTrue (backgroundClient2 != NULL, @"postcondition violated");
	STAssertTrue (backgroundClient2 != mainThreadClient, @"background thread should have had distinct aslclient from main thread." );
    
    STAssertTrue (backgroundClient2 != backgroundClient1, @"each background thread should have had distinct aslclients");
}

- (void) testMultipleLoggersAreIndependentWithinSingleThread
{
    /*
     Expectation: two loggers, each used on the same thread, use distinct aslclients.
     */
    
    // We should be running on main thread here
    STAssertTrue ([NSThread isMainThread], @"precondition violated");
    
    logger1 = [[SOLogger alloc] initWithFacility:@"Test Logger 1" options:SOLoggerDefaultASLOptions];
    logger2 = [[SOLogger alloc] initWithFacility:@"Test Logger 2" options:SOLoggerDefaultASLOptions];
    
    // logger1 and logger2 should have distinct ASL connections on any given thread.

    STAssertTrue ([logger1 aslclientRef] != NULL, @"postcondition violated");
    STAssertTrue ([logger2 aslclientRef] != NULL, @"postcondition violated");
    STAssertTrue ([logger1 aslclientRef] != [logger2 aslclientRef], @"postcondition violated"); 
}

- (void) testLoggersAreIndependentBetweenThreads
{
    /*
     Expectation: two loggers, each used in different threads, have distinct aslclients.
     */
    
    logger1 = [[SOLogger alloc] initWithFacility:@"Test Logger 1" options:SOLoggerDefaultASLOptions];
    
    // We should be running on main thread here
    STAssertTrue ([NSThread isMainThread], @"precondition violated");   
    
    aslclient mainThreadClient = [logger1 aslclientRef];
    STAssertTrue (mainThreadClient != NULL, @"postcondition violated" );

    
    /* Spawn block on the background queue to obtain the per-thread aslclient. 
     Wait for the background blocs to finish executing, then assert test conditions.
     */
    __block aslclient backgroundClient1 = NULL;
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_async (group, dispatch_get_global_queue (DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        logger2 = [[SOLogger alloc] initWithFacility:@"Test Logger 2" options:SOLoggerDefaultASLOptions];
        [logger2 notice:@"%s", _cmd];
        backgroundClient1 = [logger2 aslclientRef];
    });
    dispatch_group_wait (group, dispatch_time (DISPATCH_TIME_NOW,  NSEC_PER_SEC * 2));
    dispatch_release (group); group = NULL;

    STAssertTrue (backgroundClient1 != NULL, @"postcondition violated" );
	STAssertTrue (backgroundClient1 != mainThreadClient, @"background thread should have had distinct aslclient from main thread." );
}

#pragma mark -
#pragma mark Fixture

- (void) setUp;
{
    [super setUp];
}

- (void) tearDown;
{
    ReleaseAndNil (logger1);
    ReleaseAndNil (logger2);
    
    [super tearDown];
}
@end

