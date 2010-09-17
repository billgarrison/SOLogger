//
//  SOASLLogger.m
//
//  Copyright 2009 Standard Orbit Software, LLC. All rights reserved.
//
//  $Rev$
//  $LastChangedBy$
//  $LastChangedDate$

#import "SOLogger.h"
#import "SOASLClient.h"

uint32_t SOLoggerDefaultASLOptions = ASL_OPT_NO_DELAY | ASL_OPT_STDERR | ASL_OPT_NO_REMOTE;

static NSString * const ASLClientKey = @"SOASLClient";

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
        myClientOptions = options;
        myAdditionalFileDescriptors = [NSMutableArray new];
        myPerLoggerASLClientKey = [[NSString alloc] initWithFormat:@"%@ForLogger%p", ASLClientKey, self];
    }
    return self;
}

- (id) init;
{
    return [self initWithFacility:nil options:SOLoggerDefaultASLOptions];
}

- (void) dealloc;
{		
    [myPerLoggerASLClientKey release]; myPerLoggerASLClientKey = nil;
    [myFacility release]; myFacility = nil;
    [myAdditionalFileDescriptors release]; myAdditionalFileDescriptors = nil;
    [super dealloc];
}

// Return an ASL client connection that we should be using for the current thread. 
- (SOASLClient *) ASLClient;
{
    // We use the NSThread threadDictionary to cache an instance of our ASLClient cover object.  When the thread is released, the ASLClient deallocs, taking care of closing out the client connection.
    
    NSMutableDictionary *threadInfo = [[NSThread currentThread] threadDictionary];
    assert (threadInfo != nil);
    
    SOASLClient *cachedASLClient = [threadInfo objectForKey: myPerLoggerASLClientKey];
    
    if (cachedASLClient == nil) {
        
        // Create a new ASLClient instance and cache it in the current thread's dictionary.
        cachedASLClient = [[[SOASLClient alloc] init] autorelease];
        
        // Stash the ASL client in this thread's info dictionary; each thread in play needs to have an independent asl_client connection.
        [threadInfo setObject:cachedASLClient forKey: myPerLoggerASLClientKey];
        
        // Open the client before adding file descriptors; a valid asl_client connection be exist first.
        [cachedASLClient openForFacility:self.facility options:self.clientOptions];
        
        // Pass on the set of additional file descriptors to which the logger should be sending messages
        for (NSNumber *descriptor in self.additionalFileDescriptors) {
            [cachedASLClient addLoggingDescriptor:[descriptor intValue]];
        }
        
#if DEBUG
        asl_set_filter ([cachedASLClient asl_client], ASL_FILTER_MASK_UPTO(ASL_LEVEL_DEBUG));
#endif
    }
    
    // Capture a weak reference to the main thread's ASLClient.  This enables the main thread's ASLClient instance to be available via -mainThreadASLClient; primarily helps with unit testing, but might be otherwise useful.
    if ((myMainThreadASLClient == nil) && [NSThread isMainThread]) {
        myMainThreadASLClient = cachedASLClient;
    }
    
    return [[cachedASLClient retain] autorelease];
}

#pragma mark -
#pragma mark Logging

- (void) debug: (NSString *) format, ...;
{
    va_list arglist;    
    va_start (arglist, format);
    [self logWithLevel:ASL_LEVEL_DEBUG format:format arguments:arglist];
    va_end (arglist);
}

- (void) info: (NSString *) format, ...;
{
    va_list arglist;
    va_start (arglist, format);
    [self logWithLevel:ASL_LEVEL_INFO format:format arguments:arglist];
    va_end (arglist);
}

- (void) notice: (NSString *) format, ...;
{
    va_list arglist;
    va_start (arglist, format);
    [self logWithLevel:ASL_LEVEL_NOTICE format:format arguments:arglist];
    va_end (arglist);
}

- (void) warning: (NSString *) format, ...;
{
    va_list arglist;
    va_start (arglist, format);
    [self logWithLevel:ASL_LEVEL_WARNING format:format arguments:arglist];
    va_end (arglist);
}

- (void) error: (NSString *) format, ...;
{
    va_list arglist;
    va_start (arglist, format);
    [self logWithLevel:ASL_LEVEL_ERR format:format arguments:arglist];
    va_end (arglist);
}

- (void) alert: (NSString *) format, ...;
{
    va_list arglist;
    va_start (arglist, format);
    [self logWithLevel:ASL_LEVEL_ALERT format:format arguments:arglist];
    va_end (arglist);
}

- (void) critical: (NSString *) format, ...;
{
    va_list arglist;
    va_start (arglist, format);
    [self logWithLevel:ASL_LEVEL_CRIT format:format arguments:arglist];
    va_end (arglist);
}

- (void) panic: (NSString *) format, ...;
{
    va_list arglist;
    va_start (arglist, format);
    [self logWithLevel:ASL_LEVEL_EMERG format:format arguments:arglist];
    va_end (arglist);
}

#pragma mark -
#pragma mark Logging Primitives

- (void) logWithLevel:(int)aslLevel format:(NSString *)format arguments:(va_list)arguments
{
    SOASLClient *client = [self ASLClient];
    
    assert ([client isOpen]);
    assert (aslLevel >= ASL_LEVEL_EMERG || aslLevel <= ASL_LEVEL_DEBUG);
    assert (format != nil);
    
    aslmsg msg = asl_new(ASL_TYPE_MSG);    
    const char *normalizedFacility = self.facility ? [self.facility UTF8String] : "com.apple.console";
    asl_set (msg, ASL_KEY_FACILITY, normalizedFacility);
    
    // The format value will likely include the %@ directive, which asl_log() does not handle. So process the format and arguments into an NSString first.
    NSString *text = [[NSString alloc] initWithFormat:format arguments:arguments];
    
    // Log the text as UTF-8 string.
    asl_log ([client asl_client], msg, aslLevel, "%s", [text UTF8String]);
    
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
        // As a side effect, throw out this logger's ASLClient instance from the current thread info.  It will be reconstructed with the now-updated set of file descriptors on its next access.
        [[self ASLClient] addLoggingDescriptor:fileDescriptor];
    }
}


- (void) removeFileDescriptor:(int)fd;
{
    @synchronized (myAdditionalFileDescriptors) {
        [myAdditionalFileDescriptors removeObject:[NSNumber numberWithInt:fd]];
        
        // As a side effect, throw out this logger's ASLClient instance from the current thread info.  It will be reconstructed with the now-updaed set of file descriptors on its next access.
        [[self ASLClient] removeLoggingDescriptor:fd];
    }
}

#pragma mark -
#pragma mark Properties

@synthesize facility = myFacility;
@synthesize clientOptions = myClientOptions;
@synthesize ASLClientKey = myPerLoggerASLClientKey;

- (NSArray *) additionalFileDescriptors 
{
    NSArray *immutableCopy = nil;
    @synchronized (myAdditionalFileDescriptors) {
        immutableCopy = [NSArray arrayWithArray: myAdditionalFileDescriptors];
    }
    return immutableCopy;
}

- (SOASLClient *) mainThreadASLClient
{
    if (myMainThreadASLClient == nil) {
        [self performSelectorOnMainThread:@selector(ASLClient) withObject:nil waitUntilDone:YES];
    }

    return [[myMainThreadASLClient retain] autorelease];
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



