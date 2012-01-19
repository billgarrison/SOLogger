// SOLogger Demo

#import <Foundation/Foundation.h>
#import <AppKit/NSWorkspace.h>
#import "SOLogger.h"

@interface SOLoggerDemo : NSObject
{
    SOLogger *logger;
    NSFileHandle *externalLogFile;
}

@end

@implementation SOLoggerDemo 

- (id) init;
{
    self = [super init];
    if (!self) return nil;
    
    logger = [[SOLogger alloc] initWithFacility:@"net.standardorbit.SOLoggerDemo" options:SOLoggerDefaultASLOptions];
    
    NSString *logfilePath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    if (logfilePath) logfilePath = [logfilePath stringByAppendingPathComponent:@"Logs"];
    if (logfilePath) logfilePath = [logfilePath stringByAppendingPathComponent:@"SOLoggerDemo.log"];
    
    if (logfilePath)
    {
        // Create the external logging file.
        [[NSFileManager defaultManager] createFileAtPath:logfilePath contents:nil attributes:nil];
        
        externalLogFile = [[NSFileHandle fileHandleForWritingAtPath:logfilePath] retain];
        assert( externalLogFile != nil );
        
        [logger addDescriptor:[externalLogFile fileDescriptor]];
    }
    
    /* Open Console.app to display the demo's log file. */
    
    [[NSWorkspace sharedWorkspace] openFile:logfilePath withApplication:@"Console.app"];
    
    return self;
}

- (void) dealloc;
{
    [externalLogFile closeFile];
    [externalLogFile release];
    externalLogFile = nil;
    
    [logger release];
    logger = nil;
    [super dealloc];
}

- (void) testInfoMessage;
{
    [logger info:@"This is an information message at %@", [NSDate date]];
}

- (void) testEmergencyMessage
{
    NSThread *currentThread = [NSThread currentThread];
    [logger panic:@"%s on %@ thread %@", __PRETTY_FUNCTION__, ([currentThread isEqual:[NSThread mainThread]] ? @"main" : @"background"), currentThread];
}

- (void) testCriticalMessage
{
    NSThread *currentThread = [NSThread currentThread];
    [logger critical:@"%s on %@ thread %@", __PRETTY_FUNCTION__, ([currentThread isEqual:[NSThread mainThread]] ? @"main" : @"background"), currentThread];   
}

- (void) testLogInBackgroundThread;
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSThread *backgroundThread = [NSThread currentThread];
        NSDictionary *threadDictionary = [backgroundThread threadDictionary];
        NSThread *mainThread = [NSThread mainThread];
        
        [logger notice:[NSString stringWithFormat:@"A message from the background thread:\ncurrent thread: %@\nmain thread: %@\n threadDictionary: %@", backgroundThread, mainThread, threadDictionary]];
    });
    
}

- (void) testMyLog;
{    
    LOG_ENTRY;
    
    [logger debug:@"Debug: A debugging note on: %@", [NSDate date]];
    [logger info:@"Info: We just did something."];
    [logger notice:@"Notice: That's going to leave a mark"];
    [logger performSelectorInBackground:@selector(notice:) withObject:@"Notice: From a background thread"];
    [logger warning:@"Warning"];
    [logger critical:@"Critical!"];
    [logger alert:@"Alert!"];
    [logger panic:@"Panic!"];
}

- (void) demoLogToSeparateFiles;
{
    LOG_ENTRY;
    
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
    [logger addDescriptor:logFileDescriptor];
    
    [logger notice:@"abc123"];
    
    [logger removeDescriptor:logFileDescriptor];
}

- (void) demoUnicodeLogging
{
    LOG_ENTRY;
    
    /* Expect this bunch of Unicode to display properly in the database and stderr */
    [logger notice:@"Some Unicode ⌥⌦⌘⑩"];
}

- (void) demoSeverityFiltering
{
    LOG_ENTRY;
    
    /* Prevent messages less than CRITICAL from being logged. */
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
    
}


- (void) testMultipleQueueLogging
{
    /* Make ASL believe that we really want all levels of message */
    
    [logger setSeverityFilterMask: ASL_FILTER_MASK_UPTO(ASL_LEVEL_DEBUG)];
    
    @autoreleasepool {
        
        /* Log from low priority queue */
        
        dispatch_async (dispatch_get_global_queue (DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            aslclient aslclient = [logger aslclientRef];
            
            NSString *threadDescription = [NSString stringWithFormat:@"%@ thread: %p", ([NSThread isMainThread] ? @"main" : @"background"), [NSThread currentThread]];
            NSString *message = [NSString stringWithFormat:@"Low priority queue: aslclient: %p; %@", aslclient, threadDescription];
            for (int level = ASL_LEVEL_ALERT; level <= ASL_LEVEL_DEBUG; level++)
            {
                [logger logWithLevel:level format:message arguments:NULL];
                [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
            }
        });
        
        /* Log from default priority queue */
        
        dispatch_async (dispatch_get_global_queue (DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            aslclient aslclient = [logger aslclientRef];
            
            NSString *threadDescription = [NSString stringWithFormat:@"%@ thread: %p", ([NSThread isMainThread] ? @"main" : @"background"), [NSThread currentThread]];
            NSString *message = [NSString stringWithFormat:@"Default priority queue: aslclient: %p; %@", aslclient, threadDescription];
            for (int level = ASL_LEVEL_ALERT; level <= ASL_LEVEL_DEBUG; level++)
            {
                [logger logWithLevel:level format:message arguments:NULL];
                [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
            }
        });
        
        /* Log from high priority queue */
        
        dispatch_async (dispatch_get_global_queue (DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            aslclient aslclient = [logger aslclientRef];
            
            NSString *threadDescription = [NSString stringWithFormat:@"%@ thread: %p", ([NSThread isMainThread] ? @"main" : @"background"), [NSThread currentThread]];
            NSString *message = [NSString stringWithFormat:@"High priority queue: aslclient: %p; %@", aslclient, threadDescription];
            
            for (int level = ASL_LEVEL_ALERT; level <= ASL_LEVEL_DEBUG; level++)
            {
                [logger logWithLevel:level format:message arguments:NULL];
                [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
            }
        });
        
        
        /* Log from main thread */
        
        aslclient aslclient = [logger aslclientRef];
        
        NSString *threadDescription = [NSString stringWithFormat:@"%@ thread: %p", ([NSThread isMainThread] ? @"main" : @"background"), [NSThread currentThread]];
        NSString *message = [NSString stringWithFormat:@"main queue: aslclient: %p; %@", aslclient, threadDescription];
        for (int level = ASL_LEVEL_ALERT; level <= ASL_LEVEL_DEBUG; level++)
        {
            [logger logWithLevel:level format:message arguments:NULL];
        }
    }
    
}

@end


int main (int argc, const char * argv[]) {
    
    @autoreleasepool 
    {
        SOLoggerDemo *demo = [SOLoggerDemo new];
        
        [demo demoLogToSeparateFiles];
        [demo testInfoMessage];
        [demo testEmergencyMessage];
        [demo testCriticalMessage];
        [demo testLogInBackgroundThread];
        [demo testMyLog];
        [demo demoSeverityFiltering];
        [demo demoUnicodeLogging];
        
        [demo testMultipleQueueLogging];
        
        // Drive the runloop for a bit so that we can get log messages that the ASLClients in background threads have cleaned up.
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
        
        [demo release];
        
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    }
    
    return 0;
}



