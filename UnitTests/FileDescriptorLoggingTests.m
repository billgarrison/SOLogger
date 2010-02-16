//
//  FileDescriptorLoggingTests.m
//  SOLogger
//
//  Copyright 2010 Standard Orbit Software, LLC. All rights reserved.
//
// $Revision$
// $Author$
// $Date$


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
	
	// Use this method to clean up after any resource allocation done in -setUp.	
	[super tearDown];
}

#pragma mark -
#pragma mark Tests

- (void) testLogsToTempFile;
{
	int templateLen = 80;
	char *template = calloc(1, templateLen);
	strlcpy( template, "/tmp/tmpFileDescriptorLoggingTestsXXXX", templateLen );
	int tempFD = mkstemp(template);
	STAssertTrue( tempFD != -1, @"precondition violated" );
	
	// Set up
	NSFileHandle *tempFileHandle = [NSFileHandle fileHandleForReadingAtPath:[NSString stringWithUTF8String:template]];
	STAssertNotNil( tempFileHandle, @"precondition violated" );

	dataIsAvailableFromTempFile = NO;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tempFileHasData:) name:NSFileHandleDataAvailableNotification object:tempFileHandle];
	[tempFileHandle waitForDataInBackgroundAndNotify];

	[logger addFileDescriptor:tempFD];
	NSString *testLogMessage = [NSString stringWithString:@"Frankie Goes to Hollywood"];
	[logger info:testLogMessage];
	
	do {
		NSDate *fireDate = [[NSDate alloc] initWithTimeIntervalSinceNow:0.25];
		[[NSRunLoop currentRunLoop] runUntilDate:fireDate];
		[fireDate release];
	} while ( !dataIsAvailableFromTempFile );
	
	// Expect std error to contain the logged message
	NSData *expectedData = [testLogMessage dataUsingEncoding:NSUTF8StringEncoding];
	NSData *actualData = [tempFileHandle readDataToEndOfFile];
	NSRange foundRange = [actualData rangeOfData:expectedData options:0 range:NSMakeRange(0, [actualData length])];
	STAssertTrue( foundRange.length != 0, @"postcondition violated" );
	
	close(tempFD);
}

// Handle the async wait-for-data request from -testLogsToTempFile
- (void) tempFileHasData:(NSNotification *) note;
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleDataAvailableNotification object:nil];
	dataIsAvailableFromTempFile = YES;
}
@end
