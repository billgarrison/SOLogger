//
//  BackgroundThreadTests.m
//  SOLogger
//
//  Created by StdOrbit on 9/16/10.
//  Copyright 2010 Standard Orbit Software, LLC. All rights reserved.
//

/*
 BackgroundMessageThread is a simple NSThread subclass to gather test info from the running of an SOLogger logging method on a background thread.
 We capture values in the ivars that can be tested after the thread has executed.  A thread's threadDictionary is cleaned up immediately after the thread finishes execution.  We need to test that particular values are being store in the threadDictionary during execution.  This NSThread subclass allows this to happen.
 */
@interface BackgroundMessageThread : NSThread
{
    SOLogger *myLogger;
    SOASLConnection *myASLConnection;
}
@property (nonatomic, retain) SOASLConnection *ASLConnection;
@end

@implementation BackgroundMessageThread
@synthesize ASLConnection = myASLConnection;

- (id) initWithLogger:(SOLogger *)logger;
{
    self = [super init];
    if ( self ) {
        myLogger = [logger retain];
    }
    return self;
}

- (void) dealloc;
{
    ReleaseAndNil (myASLConnection);
    ReleaseAndNil (myLogger);
    [super dealloc];
}

- (void) main;
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
    ASSERT (myLogger != nil);
    // Log a message
    [myLogger warning:@"Everyone Loves Hugo"];
    
    myASLConnection = [[[self threadDictionary] objectForKey: [myLogger ASLConnectionKey]] retain];
    
    [pool release];
}
@end

#pragma mark -

@interface BackgroundThreadTests : SenTestCase 
{
    SOLogger *logger1;
}
@end

@implementation BackgroundThreadTests

#pragma mark -
#pragma mark Tests

- (void) testLoggerUsesDistinctASLConnectionsPerThread;
{
    logger1 = [[SOLogger alloc] initWithFacility:@"Test Logger 1" options:SOLoggerDefaultASLOptions];
    [logger1 info:@"Lost Season 2"];
    
    BackgroundMessageThread *backgroundMessageThread = [[[BackgroundMessageThread alloc] initWithLogger:logger1] autorelease];
    [backgroundMessageThread start];
    
    // Drive the runloop and wait for the background thread to finish
    do {
        NSDate *fireDate = [[NSDate alloc] initWithTimeIntervalSinceNow:0.25];
        [[NSRunLoop currentRunLoop] runUntilDate:fireDate];
        [fireDate release];
    } while ([backgroundMessageThread isFinished] == NO);
    
    STAssertNotNil ([backgroundMessageThread ASLConnection], @"postcondition violated" );
    STAssertTrue ([backgroundMessageThread ASLConnection] != [logger1 mainThreadASLConnection], @"postcondition violated" );
}

- (void) testBackgroundThreadASLConnectionDeallocsAfterRun
{
    logger1 = [[SOLogger alloc] initWithFacility:@"Test Logger 1" options:SOLoggerDefaultASLOptions];
    STAssertNotNil (logger1, @"precondition violated");
    
    NSThread *thread = [[NSThread alloc] initWithTarget:logger1 selector:@selector(warning:) object:@"Bob's Your Uncle!"];
    [thread start];
    
    // Drive the runloop and wait for the background thread to finish
    do {
        NSDate *fireDate = [[NSDate alloc] initWithTimeIntervalSinceNow:0.25];
        [[NSRunLoop currentRunLoop] runUntilDate:fireDate];
        [fireDate release];
    } while ([thread isFinished] == NO);
    
    STAssertTrue ([[thread threadDictionary] count] == 0, @"postcondition violated");
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
    [super tearDown];
}

@end
