//
//  MultipleLoggerTests.m
//  SOLogger
//
//  Copyright 2010 Standard Orbit Software, LLC. All rights reserved.
//
// $Revision$
// $Author$
// $Date$

/*
 BackgroundMessageThread is a simple NSThread subclass to gather test info from the running of an SOLogger logging method on a background thread.
 We capture values in the ivars that can be tested after the thread has executed.  A thread's threadDictionary is cleaned up immediately after the thread finishes execution.  We need to test that particular values are being store in the threadDictionary during execution.  This NSThread subclass allows this to happen.
 */
@interface BackgroundMessageThread : NSThread
{
    SOLogger *myLogger;
    SOASLClient *myASLClient;
    BOOL hasASLClientForLogger;
    BOOL hasDistinctASLClientFromMainThreadClient;
}
@property (nonatomic, readonly) BOOL hasASLClientForLogger;
@property (nonatomic, readonly) BOOL hasDistinctASLClientFromMainThreadClient;
@property (nonatomic, retain) SOASLClient *backgroundThreadASLClient;
@end

@implementation BackgroundMessageThread

@synthesize hasASLClientForLogger, hasDistinctASLClientFromMainThreadClient;
@synthesize backgroundThreadASLClient = myASLClient;

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
    ReleaseAndNil (myASLClient);
    ReleaseAndNil (myLogger);
    [super dealloc];
}

- (void) main;
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
        
    ASSERT (myLogger != nil);
    // Log a message
    [myLogger alert:@"Everyone Loves Hugo"];
    
    // Capture some diagnostic info that will be tested after the thread has completed its run.
    
    myASLClient = [[[self threadDictionary] objectForKey: [myLogger ASLClientKey]] retain];
    hasASLClientForLogger = (myASLClient != nil );
    hasDistinctASLClientFromMainThreadClient = (myASLClient != [myLogger mainThreadASLClient]);
    
    [pool release];
}

@end

#pragma mark -


@interface MultipleLoggerTests : SenTestCase
{
    SOLogger *logger1, *logger2;
}
@end

@implementation MultipleLoggerTests

#pragma mark -
#pragma mark Fixture

- (void) setUp;
{
    [super setUp];
    
    logger1 = [[SOLogger alloc] initWithFacility:@"Test Logger 1" options:SOLoggerDefaultASLOptions];
    logger2 = [[SOLogger alloc] initWithFacility:@"Test Logger 2" options:SOLoggerDefaultASLOptions];
    
}

- (void) tearDown;
{
    ReleaseAndNil (logger1);
    ReleaseAndNil (logger2);
    
    [super tearDown];
}

#pragma mark -
#pragma mark Tests

- (void) testLoggerUsesDistinctASLClientsPerThread;
{
    [logger1 info:@"Lost Season 2"];
    
    BackgroundMessageThread *backgroundMessageThread = [[BackgroundMessageThread alloc] initWithLogger:logger1];
    [backgroundMessageThread start];
    
    // Drive the runloop and wait for the background thread to finish
    do {
        NSDate *fireDate = [[NSDate alloc] initWithTimeIntervalSinceNow:0.25];
        [[NSRunLoop currentRunLoop] runUntilDate:fireDate];
        [fireDate release];
    } while ( ![backgroundMessageThread isFinished] ) ;
    
    STAssertTrue( [backgroundMessageThread hasASLClientForLogger], @"postcondition violated" );
    STAssertTrue( [backgroundMessageThread hasDistinctASLClientFromMainThreadClient], @"postcondition violated" );
    
}

- (void) testMultipleLoggersCanShareMainThread;
{
    // Test on main thread
    STAssertTrue ([NSThread isMainThread], @"precondition violated");
    
    // logger1 and logger2 should have distinct ASLClients on any given thread.
    SOASLClient *logger1Client = [logger1 ASLClient];
    SOASLClient *logger2Client = [logger2 ASLClient];
    
    STAssertTrue (logger1Client != logger2Client, @"postcondition violated");
}

@end

