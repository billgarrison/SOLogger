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
	NSData *dataFromTempFile;
	BOOL dataIsAvailableFromTempFile;
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
	logger = [[SOLogger alloc] initWithFacility:facility options:0];
	[facility release];
}

- (void) tearDown;
{
	[logger release];
	[dataFromTempFile release]; 
	
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

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tempFileHasData:) name:NSFileHandleDataAvailableNotification object:tempFileHandle];
	[tempFileHandle waitForDataInBackgroundAndNotifyForModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
	
	NSDate *fireDate = [[NSDate alloc] initWithTimeIntervalSinceNow:0.75];
	[[NSRunLoop currentRunLoop] runUntilDate:fireDate];

	[logger addFileDescriptor:tempFD];
	NSString *testLogMessage = [NSString stringWithString:@"Frankie Goes to Hollywood"];
	[logger info:testLogMessage];
	
	[[NSRunLoop currentRunLoop] run];
	
	ReleaseAndNil( tempFileHandle );
}

- (void) tempFileHasData:(NSNotification *) note;
{
	LOG_ENTRY;
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleDataAvailableNotification object:nil];
	
	dataIsAvailableFromTempFile = YES;
	
	NSFileHandle *fh = [note object];
	dataFromTempFile = [[fh readDataToEndOfFile] retain];
	
	// Expect std error to contain the logged message
	NSString *testLogMessage = [NSString stringWithString:@"Frankie Goes to Hollywood"];
	NSData *expectedData = [testLogMessage dataUsingEncoding:NSUTF8StringEncoding];
	NSData *actualData = dataFromTempFile;
	NSRange foundRange = [actualData rangeOfData:expectedData options:0 range:NSMakeRange(0, [actualData length])];
	STAssertTrue( foundRange.length != 0, @"postcondition violated" );
	
	LOG_EXIT;
}
@end
