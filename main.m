#import <Foundation/Foundation.h>
#import "SOASLLogger.h"

// Convenience macros for getting file name, line number, and function/method info into the log.

#define MyLogSuffix [NSString stringWithFormat:@" %s %@:%d ", __FUNCTION__, [[NSString stringWithFormat:@"%s", __FILE__] lastPathComponent], __LINE__ ]

#define MyLog( logger, level, text, ... ) \
[logger messageWithLevel:level prefix:nil suffix:MyLogSuffix message:text , ## __VA_ARGS__ ]

#define LogDebug( logger, message, ... ) MyLog( logger, ASL_LEVEL_DEBUG, message, ## __VA_ARGS__ )
#define LogInfo( logger, message, ... ) MyLog( logger, ASL_LEVEL_INFO, message, ## __VA_ARGS__ )
#define LogNotice( logger, message, ... ) MyLog( logger, ASL_LEVEL_NOTICE, message, ## __VA_ARGS__ )
#define LogWarn( logger, message, ... ) MyLog( logger, ASL_LEVEL_WARNING, message, ## __VA_ARGS__ )
#define LogError( logger, message, ... ) MyLog( logger, ASL_LEVEL_ERR, message, ## __VA_ARGS__ )
#define LogAlert( logger, message, ... ) MyLog( logger, ASL_LEVEL_ALERT, message, ## __VA_ARGS__ )
#define LogCritical( logger, message, ... ) MyLog( logger, ASL_LEVEL_CRIT, message, ## __VA_ARGS__ )
#define LogEmergency( logger, message, ... ) MyLog( logger, ASL_LEVEL_EMERG, message, ## __VA_ARGS__ )

#define LogEnteringMethod(logger) LogDebug(logger, @"Entering method")
#define LogExitingMethod(logger) LogDebug(logger, @"Exiting method")

@interface ASLLoggerDemo : NSObject
{
		SOASLLogger *logger;
		NSFileHandle *mirrorLogFile;
}
@end

@implementation ASLLoggerDemo 

- (id) init;
{
		self = [super init];
		if ( self ) {
				logger = [[SOASLLogger loggerForFacility:@"com.example.ASLLoggerDemo" options:ASL_OPT_STDERR | ASL_OPT_NO_REMOTE] retain];
				
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
		
		[logger release];
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
		
		LogDebug( logger, @"A debugging note on: %@", [NSDate date]);
		LogInfo( logger, @"We just did something." );
		LogNotice( logger, @"That's going to leave a mark");
		LogWarn( logger, @"WTF?");
		LogAlert( logger, @"WTF!");
		LogCritical( logger, @"OMG" );
		LogEmergency( logger, @"OMG WTF!");

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
		
		[demo release];
		
		[pool drain];
		return 0;
}



