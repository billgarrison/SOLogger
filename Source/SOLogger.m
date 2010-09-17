//
//  SOASLLogger.m
//
//  Copyright 2009 Standard Orbit Software, LLC. All rights reserved.
//
//  $Rev$
//  $LastChangedBy$
//  $LastChangedDate$

#import "SOLogger.h"
#import "SOASLConnection.h"

uint32_t SOLoggerDefaultASLOptions = ASL_OPT_NO_DELAY | ASL_OPT_STDERR | ASL_OPT_NO_REMOTE;

@implementation SOLogger

#pragma mark -
#pragma mark Creation

+ (SOLogger *) loggerForFacility: (NSString *) facility options: (uint32_t) options;
{
    SOLogger *logger = [[[SOLogger alloc] initWithFacility:facility options:options] autorelease];
    return logger;
}

- (id) initWithFacility: (NSString *) facility options: (uint32_t) options;
{
    self = [super init];
    if ( self ) {
        myFacility = [facility copy];
        myASLOptions = options;
        myAdditionalFileDescriptors = [NSMutableArray new];
        myPerLoggerASLConnectionKey = [[NSString alloc] initWithFormat:@"%@ForLogger%p", NSStringFromClass([SOASLConnection class]), self];
    }
    return self;
}

- (id) init;
{
    return [self initWithFacility:nil options:SOLoggerDefaultASLOptions];
}

- (void) dealloc;
{		
    [[[NSThread currentThread] threadDictionary] removeObjectForKey: myPerLoggerASLConnectionKey];
    [myPerLoggerASLConnectionKey release]; myPerLoggerASLConnectionKey = nil;
    [myFacility release]; myFacility = nil;
    [myAdditionalFileDescriptors release]; myAdditionalFileDescriptors = nil;
    [super dealloc];
}

// Return the ASL connection that we should be using for the current thread. 
- (SOASLConnection *) ASLConnection;
{
    // We use the NSThread threadDictionary to cache an instance of our ASLClient cover object.  When the thread is released, the ASLClient deallocs, taking care of closing out the client connection.
    
    NSMutableDictionary *threadInfo = [[NSThread currentThread] threadDictionary];
    assert (threadInfo != nil);
    
    SOASLConnection *connection = [threadInfo objectForKey: myPerLoggerASLConnectionKey];
    
    if (connection == nil) {
        
        // Create a new ASL connection instance and cache it in the current thread's dictionary.
        connection = [[[SOASLConnection alloc] init] autorelease];
        
        // Stash the ASL connection in this thread's info dictionary; each thread in play needs to have an independent asl_client connection.
        [threadInfo setObject:connection forKey: myPerLoggerASLConnectionKey];
        
        // Open the connection before adding file descriptors; a valid asl_client connection be exist first.
        [connection openForFacility:self.facility options:self.connectionOptions];
        
        // Pass on the set of additional file descriptors to which the logger should be sending messages
        for (NSNumber *descriptor in self.additionalFileDescriptors) {
            [connection addLoggingDescriptor:[descriptor intValue]];
        }
        
#if DEBUG
        asl_set_filter ([connection ASLClient], ASL_FILTER_MASK_UPTO(ASL_LEVEL_DEBUG));
#endif
    }
    
    // Capture a weak reference to the main thread's ASL connection.  This enables the main thread connection instance to be available via -mainThreadASLConnection; primarily helps with unit testing, but might be otherwise useful.
    if ((myMainThreadASLConnection == nil) && [NSThread isMainThread]) {
        myMainThreadASLConnection = connection;
    }
    
    return [[connection retain] autorelease];
}

#pragma mark -
#pragma mark Logging

- (void) debug: (NSString *) format, ...;
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    va_list arglist;    
    va_start (arglist, format);
    [self logWithLevel:ASL_LEVEL_DEBUG format:format arguments:arglist];
    va_end (arglist);
    
    [pool drain];
}

- (void) info: (NSString *) format, ...;
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    va_list arglist;
    va_start (arglist, format);
    [self logWithLevel:ASL_LEVEL_INFO format:format arguments:arglist];
    va_end (arglist);

    [pool drain];
}

- (void) notice: (NSString *) format, ...;
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    va_list arglist;
    va_start (arglist, format);
    [self logWithLevel:ASL_LEVEL_NOTICE format:format arguments:arglist];
    va_end (arglist);

    [pool drain];
}

- (void) warning: (NSString *) format, ...;
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    va_list arglist;
    va_start (arglist, format);
    [self logWithLevel:ASL_LEVEL_WARNING format:format arguments:arglist];
    va_end (arglist);

    [pool drain];
}

- (void) error: (NSString *) format, ...;
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    va_list arglist;
    va_start (arglist, format);
    [self logWithLevel:ASL_LEVEL_ERR format:format arguments:arglist];
    va_end (arglist);

    [pool drain];
}

- (void) alert: (NSString *) format, ...;
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    va_list arglist;
    va_start (arglist, format);
    [self logWithLevel:ASL_LEVEL_ALERT format:format arguments:arglist];
    va_end (arglist);

    [pool drain];
}

- (void) critical: (NSString *) format, ...;
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    va_list arglist;
    va_start (arglist, format);
    [self logWithLevel:ASL_LEVEL_CRIT format:format arguments:arglist];
    va_end (arglist);

    [pool drain];
}

- (void) panic: (NSString *) format, ...;
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    va_list arglist;
    va_start (arglist, format);
    [self logWithLevel:ASL_LEVEL_EMERG format:format arguments:arglist];
    va_end (arglist);

    [pool drain];
}

#pragma mark -
#pragma mark Logging Primitives

- (void) logWithLevel:(int)aslLevel format:(NSString *)format arguments:(va_list)arguments
{
    SOASLConnection *connection = [self ASLConnection];
    
    assert ([connection isOpen]);
    assert (aslLevel >= ASL_LEVEL_EMERG || aslLevel <= ASL_LEVEL_DEBUG);
    assert (format != nil);
    
    aslmsg msg = asl_new(ASL_TYPE_MSG);    
    const char *normalizedFacility = self.facility ? [self.facility UTF8String] : "com.apple.console";
    asl_set (msg, ASL_KEY_FACILITY, normalizedFacility);
    
    // The format value will likely include the %@ directive, which asl_log() does not handle. So process the format and arguments into an NSString first.
    NSString *text = [[NSString alloc] initWithFormat:format arguments:arguments];
    
    // Log the text as UTF-8 string.
    asl_log ([connection ASLClient], msg, aslLevel, "%s", [text UTF8String]);
    
    // Cleanup
    asl_free (msg);
    [text release];
    
#if SOASLLOGGER_DEBUG
    NSThread *currentThread = [NSThread currentThread];
    NSLog (@"%@ on %@ thread %@", client, ([currentThread isEqual:[NSThread mainThread]] ? @"main" : @"background"), currentThread);
#endif
}

#pragma mark -
#pragma mark Additional Logging Files

- (void) addFileDescriptor:(int)fileDescriptor;
{
    @synchronized (myAdditionalFileDescriptors) {
        [myAdditionalFileDescriptors addObject:[NSNumber numberWithInt:fileDescriptor]];
        
        // Add the new descriptor to the current thread's ASL connection
        [[self ASLConnection] addLoggingDescriptor:fileDescriptor];
    }
}


- (void) removeFileDescriptor:(int)fd;
{
    @synchronized (myAdditionalFileDescriptors) {
        [myAdditionalFileDescriptors removeObject:[NSNumber numberWithInt:fd]];
        // Remove the descriptor from the current thread's ASL connection
        [[self ASLConnection] removeLoggingDescriptor:fd];
    }
}

#pragma mark -
#pragma mark Properties

@synthesize facility = myFacility;
@synthesize connectionOptions = myASLOptions;
@synthesize ASLConnectionKey = myPerLoggerASLConnectionKey;

- (NSArray *) additionalFileDescriptors 
{
    NSArray *immutableCopy = nil;
    @synchronized (myAdditionalFileDescriptors) {
        immutableCopy = [NSArray arrayWithArray: myAdditionalFileDescriptors];
    }
    return immutableCopy;
}

- (SOASLConnection *) mainThreadASLConnection
{
    if (myMainThreadASLConnection == nil) {
        [self performSelectorOnMainThread:@selector(ASLClient) withObject:nil waitUntilDone:YES];
    }

    return [[myMainThreadASLConnection retain] autorelease];
}
@end



#pragma mark -
#pragma mark License

/*
 Copyright (c) 2009, Standard Orbit Software, LLC. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 Neither the name of the Standard Orbit Software, LLC nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */



