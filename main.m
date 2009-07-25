#import <Foundation/Foundation.h>
#import "SOLogger/SOLogger.h"

#define LogEnteringMethod(logger) [logger debug:@"Entering method %s", __PRETTY_FUNCTION__]
#define LogExitingMethod(logger) [logger debug:@"Exiting method %s", __PRETTY_FUNCTION__]

@interface ASLLoggerDemo : NSObject
{
		SOLogger *logger;
		NSFileHandle *mirrorLogFile;
}

@end

@implementation ASLLoggerDemo 

- (id) init;
{
		self = [super init];
		if ( self ) {
				logger = [[SOLogger loggerForFacility:@"com.example.ASLLoggerDemo" options:ASL_OPT_NO_DELAY | ASL_OPT_STDERR | ASL_OPT_NO_REMOTE] retain];
				
				NSMutableArray *pathComponents = [[NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES) mutableCopy] autorelease];
				[pathComponents addObject:@"ASLDemoLog.txt"];
				NSString *logFilePath = [NSString pathWithComponents:pathComponents]; 
				
				// Create the file if it doesn't exist.
				if ( NO == [[NSFileManager defaultManager] fileExistsAtPath:logFilePath] ) {
						[[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
				}
				
				mirrorLogFile = [[NSFileHandle fileHandleForWritingAtPath:logFilePath] retain];
				assert( mirrorLogFile != nil );
				
				[logger.mirrorFileDescriptors addObject:[NSNumber numberWithInteger:[mirrorLogFile fileDescriptor]]];
		}
		return self;
}

- (void) dealloc;
{
		[mirrorLogFile closeFile];
		[mirrorLogFile release];
		mirrorLogFile = nil;
		
		[logger release]; logger = nil;
		[super dealloc];
}

- (void) testInfoMessage;
{
		[logger info:@"This is an information message at %@", [NSDate date]];
}

- (void) testLogInBackgroundThread;
{
		[logger performSelectorInBackground:@selector(info:) withObject:[NSString stringWithFormat:@"A message from a background thread at %@", [NSDate date]]];
}

- (void) testMyLog;
{
		LogEnteringMethod(logger);
		
		[logger debug:@"A debugging note on: %@", [NSDate date]];
		[logger info:@"We just did something."];
		[logger notice:@"That's going to leave a mark"];
		[logger performSelectorInBackground:@selector(notice:) withObject:@"From a background thread"];
		[logger warning:@"WTF?"];
		[logger alert:@"WTF!"];
		[logger critical:@"OMG"];
		[logger panic:@"OMG WTF!"];
		
		LogExitingMethod(logger);
}

@end


int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
				
    // insert code here...
    NSLog(@"Hello, World!");
		
		ASLLoggerDemo *demo = [ASLLoggerDemo new];
		
		[demo testInfoMessage];
		[demo testLogInBackgroundThread];
		[demo testMyLog];
		
		// Drive the runloop for a bit so that we can get log messages that the ASLClients in background threads have cleaned up.
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
		
		[demo release];
		
		[pool drain];
		return 0;
}



