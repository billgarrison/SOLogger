//
//  FileDescriptorLoggingTests.m
//  SOLogger
//
//  Copyright 2010 Standard Orbit Software, LLC. All rights reserved.
//

@interface FileDescriptorLoggingTests : SenTestCase
{
	SOLogger *logger;
	BOOL dataIsAvailableFromTempFile;
	BOOL dataIsAvailableFromStdError;
}
@end

@implementation FileDescriptorLoggingTests

#pragma mark -
#pragma mark Fixture

- (void) setUp;
{
	[super setUp];
	
	NSMutableString *facility = [NSMutableString string];
	[facility appendString:[[[NSBundle bundleForClass:[self class]] infoDictionary] objectForKey:@"CFBundleIdentifier"]];
	[facility appendFormat:@".%@", NSStringFromClass([self class])];
	logger = [[SOLogger alloc] initWithFacility:facility options:SOLoggerDefaultASLOptions];
}

- (void) tearDown;
{
	[logger release];
    logger = nil;
	
	// Use this method to clean up after any resource allocation done in -setUp.	
	[super tearDown];
}

#pragma mark -
#pragma mark Tests

- (void) testLogsToTempFile;
{
    /* Gyrations to use mkstemp() and a device-appropriate temporary directiory */
    
    NSString *tmpfileTemplate = [NSTemporaryDirectory() stringByAppendingPathComponent:@"tmpFileDescriptorLoggingTestsXXXX"];
	int templateLen = strlen([tmpfileTemplate UTF8String]);
	char *template = calloc(1, templateLen+1);
	strlcpy( template, [tmpfileTemplate UTF8String], templateLen );
	int tempFD = mkstemp(template);
	STAssertTrue( tempFD != -1, @"precondition violated" );
	
    /* Make file handle to read for message on the temp file in the background */
    
	NSFileHandle *tempFileHandle = [NSFileHandle fileHandleForReadingAtPath:[NSString stringWithUTF8String:template]];
	STAssertNotNil( tempFileHandle, @"precondition violated" );
    
	dataIsAvailableFromTempFile = NO;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tempFileHasData:) name:NSFileHandleDataAvailableNotification object:tempFileHandle];
	[tempFileHandle waitForDataInBackgroundAndNotify];

    /* Add the temp file's descriptor to the logger and fire off a message */
    
	[logger addDescriptor:tempFD];
	NSString *testLogMessage = [NSString stringWithString:@"Frankie Goes to Hollywood"];
	[logger info:testLogMessage];
	 
    /* Spin the runloop to allow background read on temp file handle to complete. Don't spin more than 2 seconds though */
    
    NSDate *timeout = [[[NSDate alloc] initWithTimeIntervalSinceNow:2.0] autorelease];
	do {
		NSDate *delta = [[NSDate alloc] initWithTimeIntervalSinceNow:0.25];
        if ([delta compare:timeout] == NSOrderedDescending) break;
		[[NSRunLoop currentRunLoop] runUntilDate:delta];
		[delta release];
	} while ( !dataIsAvailableFromTempFile );	
    
    /* Expect the external log file to contain the message we just sent through the logger */
    
	NSData *expectedData = [testLogMessage dataUsingEncoding:NSUTF8StringEncoding];
	NSData *actualData = [tempFileHandle readDataToEndOfFile];
	NSRange foundRange = [actualData rangeOfData:expectedData options:0 range:NSMakeRange(0, [actualData length])];
	STAssertTrue( foundRange.length != 0, @"postcondition violated" );
	
	close(tempFD);
    if (template != NULL) free(template);
}

// Handle the async wait-for-data request from -testLogsToTempFile
- (void) tempFileHasData:(NSNotification *) note;
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleDataAvailableNotification object:nil];
	dataIsAvailableFromTempFile = YES;
}
@end
