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
	BOOL hasClientMappingsDictionary;
	BOOL hasASLClientForLogger;
	BOOL hasDistinctClientFromLoggerMainASLClient;
}
@property (nonatomic, readonly) BOOL hasClientMappingsDictionary;
@property (nonatomic, readonly) BOOL hasASLClientForLogger;
@property (nonatomic, readonly) BOOL hasDistinctClientFromLoggerMainASLClient;
@end

@implementation BackgroundMessageThread

@synthesize hasClientMappingsDictionary, hasASLClientForLogger, hasDistinctClientFromLoggerMainASLClient;

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
	ReleaseAndNil( myLogger );
	[super dealloc];
}

- (void) main;
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	
	LOG_ENTRY;
	
	ASSERT( myLogger != nil );
	
	[myLogger info:@"Everyone Loves Hugo"];
	
	// Verify that the client mappings dictionary is present and contains a reasonable value.
	
	NSMutableDictionary *clientMappings = [[self threadDictionary] objectForKey:@"SOASLClients"];
	hasClientMappingsDictionary = ( clientMappings != nil );
	
	SOASLClient *backgroundASLClient = [clientMappings objectForKey:[NSValue valueWithNonretainedObject:myLogger]];
	hasASLClientForLogger = (backgroundASLClient != nil );
	
	hasDistinctClientFromLoggerMainASLClient = (backgroundASLClient != [myLogger mainASLClient]);
	
	LOG_EXIT;
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
	ReleaseAndNil( logger1 );
	ReleaseAndNil( logger2 );
	
	[super tearDown];
}

#pragma mark -
#pragma mark Tests

- (void) testMainThreadDictionaryContainsTwoLoggerClients;
{
	[logger1 info:@"Aloha"];
	[logger2 info:@"From Hawaii"];
	
	NSMutableDictionary *clientMappings = [[[NSThread mainThread] threadDictionary] objectForKey:@"SOASLClients"];
	STAssertNotNil( clientMappings, @"postcondition violated");
	
	SOASLClient *logger1ASLClient = [clientMappings objectForKey:[NSValue valueWithNonretainedObject:logger1]];
	SOASLClient *logger2ASLClient = [clientMappings objectForKey:[NSValue valueWithNonretainedObject:logger2]];
	
	// Expect the mappings dictionary contains two distinct ASLClient instances (one for logger1, one for logger2 )
	STAssertTrue( logger1ASLClient != logger2ASLClient, @"postcondition violated" );
	
	// Expect the mapped logger1 ASL client to match what we know as the logger1 mainASLClient
	STAssertTrue( logger1ASLClient == [logger1 mainASLClient], @"postcondition violated" );
	
	// Expect the mapped logger2 ASL client to match what we know as the logger2 mainASLClient
	STAssertTrue( logger2ASLClient == [logger2 mainASLClient], @"postcondition violated" );
}

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
	
	STAssertTrue( [backgroundMessageThread hasClientMappingsDictionary], @"postcondition violated" );
	STAssertTrue( [backgroundMessageThread hasASLClientForLogger], @"postcondition violated" );
	STAssertTrue( [backgroundMessageThread hasDistinctClientFromLoggerMainASLClient], @"postcondition violated" );

}
@end

#pragma mark -



