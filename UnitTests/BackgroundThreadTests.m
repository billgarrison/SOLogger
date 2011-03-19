//
//  BackgroundThreadTests.m
//  SOLogger
//
//  Created by StdOrbit on 9/16/10.
//  Copyright 2010 Standard Orbit Software, LLC. All rights reserved.
//

/*
 BackgroundMessageThread is a simple NSThread subclass to gather test info from the running of an SOLogger logging method on a background thread.
 A thread's threadDictionary is cleaned up immediately after the thread finishes execution. 
 But we need to test that particular values are being stored in the threadDictionary during execution.
 This NSThread subclass captures threadDictionary values into ivars that can be tested after the thread has executed.  
 */

@interface BackgroundMessageThread : NSThread
{
	SOLogger *myLogger;
	ASLConnection *myASLConnection;
}
@property (nonatomic, readonly) ASLConnection *ASLConnection;
@end

@implementation BackgroundMessageThread
@synthesize ASLConnection = myASLConnection;

- (id) initWithLogger:(SOLogger *)logger
{
	self = [super init];
	if (!self) return nil;
	
	myLogger = [logger retain];
	return self;
}

- (void) dealloc
{
	ReleaseAndNil (myASLConnection);
	ReleaseAndNil (myLogger);
	[super dealloc];
}

- (void) main
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	
	/* Log a message from this background thread */
	
	[myLogger warning:@"Everyone Loves Hugo on thread %@", [NSThread currentThread]];
	
	/* Capture the ASLConnection for testing after thread execution. */
	
	myASLConnection = [[[self threadDictionary] objectForKey:[myLogger ASLConnectionKey]] retain];
	
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
	
	BackgroundMessageThread *thread1 = [[[BackgroundMessageThread alloc] initWithLogger:logger1] autorelease];
	[thread1 start];
	
	BackgroundMessageThread *thread2 = [[[BackgroundMessageThread alloc] initWithLogger:logger1] autorelease];
	[thread2 start];
	
	// Drive the runloop and wait for the background threads to finish
	do {
		NSDate *fireDate = [[NSDate alloc] initWithTimeIntervalSinceNow:0.25];
		[[NSRunLoop currentRunLoop] runUntilDate:fireDate];
		[fireDate release];
	} while ( ![thread1 isFinished] && ![thread2 isFinished] );
	
	STAssertNotNil ([thread1 ASLConnection], @"postcondition violated" );
	STAssertTrue ([thread1 ASLConnection] != [logger1 mainThreadASLConnection], @"background thread should have had distinct ASLConnection from main thread." );
	
	STAssertNotNil ([thread2 ASLConnection], @"postcondition violated");
	STAssertTrue ([thread2 ASLConnection] != [logger1 mainThreadASLConnection], @"background thread should have had distinct ASLConnection from main thread." );

	STAssertTrue ([thread1 ASLConnection] != [thread2 ASLConnection], @"background threads should have had distinct ASLConnections");
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
