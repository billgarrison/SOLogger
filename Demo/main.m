// SOLogger Demo

#import <Foundation/Foundation.h>
#import "SOLogger/SOLogger.h"

#define LogEntering(logger) [logger debug:@"Entering method %s", __PRETTY_FUNCTION__]
#define LogExiting(logger) [logger debug:@"Exiting method %s", __PRETTY_FUNCTION__]

@interface ASLLoggerDemo : NSObject
{
    SOLogger *logger;
    NSFileHandle *externalLogFile;
}

@end

@implementation ASLLoggerDemo 

- (id) init;
{
    self = [super init];
    if (!self) return nil;
    
    logger = [[SOLogger loggerForFacility:@"com.example.ASLLoggerDemo" options:SOLoggerDefaultASLOptions] retain];
    
    NSMutableArray *pathComponents = [[NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES) mutableCopy] autorelease];
    [pathComponents addObject:@"ASLDemoLog.txt"];
    NSString *logFilePath = [NSString pathWithComponents:pathComponents]; 
    
    // Create the external logging file.
    [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
    
    externalLogFile = [[NSFileHandle fileHandleForWritingAtPath:logFilePath] retain];
    assert( externalLogFile != nil );
    
    [logger addFileDescriptor:[externalLogFile fileDescriptor]];
    
    return self;
}

- (void) dealloc;
{
    [externalLogFile closeFile];
    [externalLogFile release], externalLogFile = nil;
    
    [logger release], logger = nil;
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
    LogEntering(logger);
    
    [logger debug:@"Debug: A debugging note on: %@", [NSDate date]];
    [logger info:@"Info: We just did something."];
    [logger notice:@"Notice: That's going to leave a mark"];
    [logger performSelectorInBackground:@selector(notice:) withObject:@"Notice: From a background thread"];
    [logger warning:@"Warning"];
    [logger critical:@"Critical!"];
    [logger alert:@"Alert!"];
    [logger panic:@"Panic!"];
    
    LogExiting(logger);
}

- (void) demoLogToSeparateFiles;
{
    LogEntering(logger);
    
    size_t templateLen = 80;
    char *template = malloc(templateLen);
    assert( template != NULL );
    memset(template, 0,templateLen);
    strlcpy(template, "/tmp/sologgerTestXXXX.log", templateLen);
    
    int logFileDescriptor = mkstemps(template, 4);
    if ( logFileDescriptor == -1 ) {
        [logger alert:@"Can't open temp logging file: %d, %s", errno, strerror(errno)];
        return;
    }
    
    // Add the file descriptor of the additional logging file to the logger's client.
    [logger addFileDescriptor:logFileDescriptor];
    
    [logger info:@"abc123"];
    
    [logger removeFileDescriptor:logFileDescriptor];
    
    LogExiting(logger);
}

- (void) demoUnicodeLogging
{
    /* Expect this bunch of Unicode to display properly in the database and stderr */
    [logger notice:@"Some Unicode ⌥⌦⌘⑩"];
}

- (void) demoSeverityFiltering
{
    LogEntering(logger);
    
    /* Prevent messages lower than CRITICAL form being logged. */
    [logger setSeverityFilterMask: ASL_FILTER_MASK_UPTO (ASL_LEVEL_CRIT)];
    
    [logger critical:@"Starting %s", __FUNCTION__];
    
    /* These will not log to the ASL database, but will log to stderr */
    [logger debug:@"Debug"];
    [logger info:@"Info"];
    [logger notice:@"Notice"];
    [logger warning:@"Warning"];
    
    /* These messages will log to the console AND stderr */
    [logger critical:@"Critical!"];
    [logger alert:@"Alert!"];
    [logger panic:@"Panic!"];
    [logger critical:@"Finishing %s", __FUNCTION__];
    
    [logger setSeverityFilterMask: ASL_FILTER_MASK_UPTO (ASL_LEVEL_NOTICE)];
    
    LogExiting(logger);
}

@end


int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    // insert code here...
    NSLog(@"Hello, World!");
    
    ASLLoggerDemo *demo = [ASLLoggerDemo new];
    
    [demo demoLogToSeparateFiles];
    [demo testInfoMessage];
    [demo testLogInBackgroundThread];
    [demo testMyLog];
    [demo demoSeverityFiltering];
    [demo demoUnicodeLogging];
    
    // Drive the runloop for a bit so that we can get log messages that the ASLClients in background threads have cleaned up.
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
    
    [demo release];
    
    [pool drain];
    return 0;
}



