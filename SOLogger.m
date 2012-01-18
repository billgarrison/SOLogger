/*
 SOLogger
 Copyright Standard Orbit Software, LLC. All rights reserved.
 License at the bottom of the file.
 */

#import "SOLogger.h"
#import <asl.h>

#if SOLOGGER_DEBUG
static inline void LOG_ASLCLIENT(const char *where, aslclient ASLClient);
#endif

static NSString * const SOLoggerWillDieNotification = @"SOLoggerWillDie";
static NSString * const SOLoggerDidChangeSeverityFilterNotification = @"SOLoggerDidChangeSeverityFilter";
static NSString * const SOLoggerDidAddDescriptorNotification = @"SOLoggerDidAddDescriptor";
static NSString * const SOLoggerDidRemoveDescriptorNotification = @"SOLoggerDidRemoveDescriptor";

uint32_t SOLoggerDefaultASLOptions = ASL_OPT_NO_DELAY | ASL_OPT_STDERR | ASL_OPT_NO_REMOTE;

@class SOLogger;

@interface _SOASLClient : NSObject 
{
@private
	aslclient _aslclientRef;
}

- (id) initWithLogger:(SOLogger *)logger facility:(NSString *)facility options:(uint32_t)options;
- (aslclient) aslclientRef;
@end

@implementation _SOASLClient

- (id) initWithLogger:(SOLogger *)logger facility:(NSString *)facility options:(uint32_t)options 
{
	self = [super init];
	if (!self) return nil;
    
    if (logger == nil)
    {
        [self release];
        return nil;
    }
	//const char *normalizedFacility = (facility) ? [facility UTF8String] : "com.apple.console";
	
	_aslclientRef = asl_open (NULL /*ident*/, [facility UTF8String] , options);
    
    /* Register for logger notifications */
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didChangeSeverityFilter:) name:SOLoggerDidChangeSeverityFilterNotification object:logger];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didAddDescriptor:) name:SOLoggerDidAddDescriptorNotification object:logger];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRemoveDescriptor:) name:SOLoggerDidRemoveDescriptorNotification object:logger];
    
	return self;
}

- (id) init
{
    return [self initWithLogger:nil facility:nil options:0];
}

- (void) dealloc
{		
    /* Done with all notifications */
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
	// Ensure that the ASL connection is closed.
    if (_aslclientRef)
	{
		asl_close (_aslclientRef);
        _aslclientRef = NULL;
	}
    
#if SOLOGGER_DEBUG
    NSThread *currentThread = [NSThread currentThread];
    char *death_rattle = NULL;
    asprintf(&death_rattle, "Deallocating ASLClient %p on %s thread %p\n", self, ([currentThread isMainThread] ? "main" : "background"), currentThread);
	fprintf(stderr, "%s", death_rattle);
    fflush(stderr);
    if (death_rattle) free(death_rattle);
#endif
    
	[super dealloc];
}

- (aslclient) aslclientRef
{
    aslclient asl = NULL;
    @synchronized(self)
    {
        asl = _aslclientRef;
    }
    return asl;
}

- (void) didChangeSeverityFilter:(NSNotification *)note
{
    NSNumber *newMask = [[note userInfo] objectForKey:@"severityFilterMask"];
    if (newMask == nil) return;
    
    @synchronized(self)
    {
        asl_set_filter(_aslclientRef, [newMask intValue]);
    }
    
#if SOLOGGER_DEBUG
    LOG_ASLCLIENT(__PRETTY_FUNCTION__, _aslclientRef);
#endif
}

- (void) didAddDescriptor:(NSNotification *)note
{
    NSNumber *newDescriptor = [[note userInfo] objectForKey:@"descriptor"];
    if (newDescriptor == nil) return;
    
    @synchronized(self)
    {
        int err = asl_add_log_file(_aslclientRef, [newDescriptor intValue]);
        if (err != 0)
        {
            NSLog (@"asl_add_log_file() failed to add %d", [newDescriptor intValue]);
        }
    }
    
#if SOLOGGER_DEBUG
    LOG_ASLCLIENT(__PRETTY_FUNCTION__, _aslclientRef);
#endif
}

- (void) didRemoveDescriptor:(NSNotification *)note
{
    NSNumber *newDescriptor = [[note userInfo] objectForKey:@"descriptor"];
    if (newDescriptor == nil) return;
    
    @synchronized(self)
    {
        int err = asl_remove_log_file(_aslclientRef, [newDescriptor intValue]);
        if (err != 0)
        {
            NSLog (@"asl_remove_log_file() failed to remove %d", [newDescriptor intValue]);
        }
    }
    
#if SOLOGGER_DEBUG
    LOG_ASLCLIENT(__PRETTY_FUNCTION__, _aslclientRef);
#endif
}

@end

#pragma mark -

@implementation SOLogger

@synthesize facility = _facility;
@synthesize connectionOptions = _ASLOptions;
@synthesize ASLClientForLoggerKey =  _ASLClientForLoggerKey;
@synthesize severityFilterMask = _severityFilterMask;

#pragma mark -
#pragma mark Creation

- (id) initWithFacility:(NSString *)facility options:(uint32_t)options;
{
	self = [super init];
	if ( !self ) return nil;
    
    _facility = [facility copy];
    _ASLOptions = options;
    
    _extraLoggingDescriptors = [[NSMutableSet alloc] init];
    _ASLClientForLoggerKey = [[NSString alloc] initWithFormat:@"ASLClientForLogger%p", self];
    _ASLClientCache = [[NSCache alloc] init];
    
    /* If this is a debug build, set the default filtering to include everything. 
     Otherwise, default to logging all messages from PANIC up to NOTICE level, excluding INFO and DEBUG level messages.
     */
#if DEBUG
    _severityFilterMask = ASL_FILTER_MASK_UPTO (ASL_LEVEL_DEBUG);
#else
    _severityFilterMask = ASL_FILTER_MASK_UPTO (ASL_LEVEL_NOTICE);
#endif
    
	return self;
}

- (id) init
{
	return [self initWithFacility:nil options:SOLoggerDefaultASLOptions];
}

- (void) dealloc;
{    
    /* Broadcast to dependent ASL clients that we're going away */
    [[NSNotificationCenter defaultCenter] postNotificationName:SOLoggerWillDieNotification object:self];
    
    [_ASLClientCache release];
    _ASLClientCache = nil;
        
	[_ASLClientForLoggerKey release];
    _ASLClientForLoggerKey = nil;
    
	[_facility release];
    _facility = nil;
    
	[_extraLoggingDescriptors release];
    _extraLoggingDescriptors = nil;
    
#if SOLOGGER_DEBUG
	NSThread *currentThread = [NSThread currentThread];
	NSLog(@"Deallocating %@ on %@ thread %p", self, ([currentThread isMainThread] ? @"main" : @"background"), currentThread);	
#endif
    
	[super dealloc];
}

/* 
 Search the current thread's threadDictionary for a cached ASL client reference. Create and configure one if not found.
 */
- (aslclient) aslclientRef
{    
    NSString *threadKey = [NSString stringWithFormat:@"Thread%p", [NSThread currentThread]];
    _SOASLClient *ASLClient = [_ASLClientCache objectForKey:threadKey];

    /* If no ASL connection cached for this thread, create and configure one. */
    
    if (ASLClient == nil)
    {
#if SOLOGGER_DEBUG
        NSLog (@"%s creating new ASL client for thread %p for logger %@", __PRETTY_FUNCTION__, [NSThread currentThread], self);
#endif
        /* Create a new ASL client cover object */
        
        ASLClient = [[_SOASLClient alloc] initWithLogger:self facility:[self facility] options:[self connectionOptions]];
                
        if (ASLClient)
        {
            /* Cache the new ASL client
             */
            [_ASLClientCache setObject:ASLClient forKey:threadKey];
            [ASLClient release];

            /* Configure the connection's filter mask. 
             */
            asl_set_filter ([ASLClient aslclientRef], [self severityFilterMask]);
            
            // Pass on the set of external logging descriptors
            
            for (NSNumber *descriptor in [self additionalDescriptors])
            {
                int err = asl_add_log_file ([ASLClient aslclientRef], [descriptor intValue]);
                if (err != 0)
                {
                    NSLog (@"%@: asl_add_log_file() failed to add external logging descriptor: %d", self, [descriptor intValue]);
                }
            }
        }
    }
    
    aslclient aslclientRef = (ASLClient == nil) ? NULL : [ASLClient aslclientRef];
    
    return aslclientRef;
}


#pragma mark -
#pragma mark Logging

- (void) debug: (NSString *)format, ...;
{
    va_list arglist;    
    va_start (arglist, format);
    [self logWithLevel:ASL_LEVEL_DEBUG format:format arguments:arglist];
    va_end (arglist);
}

- (void) info: (NSString *)format, ...;
{
    va_list arglist;
    va_start (arglist, format);
    [self logWithLevel:ASL_LEVEL_INFO format:format arguments:arglist];
    va_end (arglist);
}

- (void) notice: (NSString *)format, ...;
{
    va_list arglist;
    va_start (arglist, format);
    [self logWithLevel:ASL_LEVEL_NOTICE format:format arguments:arglist];
    va_end (arglist);
}

- (void) warning: (NSString *)format, ...;
{
    va_list arglist;
    va_start (arglist, format);
    [self logWithLevel:ASL_LEVEL_WARNING format:format arguments:arglist];
    va_end (arglist);
}

- (void) error: (NSString *)format, ...;
{    
    va_list arglist;
    va_start (arglist, format);
    [self logWithLevel:ASL_LEVEL_ERR format:format arguments:arglist];
    va_end (arglist);
}

- (void) alert: (NSString *)format, ...;
{    
    va_list arglist;
    va_start (arglist, format);
    [self logWithLevel:ASL_LEVEL_ALERT format:format arguments:arglist];
    va_end (arglist);
}

- (void) critical: (NSString *)format, ...;
{    
    va_list arglist;
    va_start (arglist, format);
    [self logWithLevel:ASL_LEVEL_CRIT format:format arguments:arglist];
    va_end (arglist);
}

- (void) panic: (NSString *)format, ...;
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
    if (format == nil) return;
        
    aslclient asl = [self aslclientRef];
    
    if (asl == NULL)
    {
        NSLog (@"%s failed to get ASL client reference for this thread.", __PRETTY_FUNCTION__);
    }
    else
    {
        aslmsg msg = asl_new (ASL_TYPE_MSG);    
        asl_set (msg, ASL_KEY_FACILITY, [[self facility] UTF8String]);
        
        /* asl_log() does not handle the %@ format specifier, so process the format and arguments into an NSString first. */
        
        NSString *text = [[NSString alloc] initWithFormat:format arguments:arguments];
        
        /* Log the text as UTF-8 string */
        int err = asl_log (asl, msg, aslLevel, "%s", [text UTF8String]);
        if (err != 0)
        {
            NSLog (@"asl_log() failed to write the message: %@", text);
        }
        [text release];
        text = nil;
        
        // Cleanup
        asl_free (msg);
    }
}

#pragma mark -
#pragma mark Additional Logging Descriptors

- (NSSet *) additionalDescriptors 
{    
    NSSet *immutable = nil;
    @synchronized (_extraLoggingDescriptors) 
    {
        immutable = [NSSet setWithSet: _extraLoggingDescriptors];
    }
    return immutable;
}

- (void) addDescriptor:(int)fd
{
    @synchronized (_extraLoggingDescriptors)
    {
        NSNumber *descriptor = [NSNumber numberWithInt:fd];
        
        /* Add the new descriptor to the current thread's ASL connection. */
        
        aslclient asl = [self aslclientRef];
        if (asl)
        {
            /* Cache the descriptor in our private list */
            [_extraLoggingDescriptors addObject:descriptor];
            
            /* Broadcast the logger change to associated ASL clients. */
            [[NSNotificationCenter defaultCenter] postNotificationName:SOLoggerDidAddDescriptorNotification object:self userInfo:[NSDictionary dictionaryWithObject:descriptor forKey:@"descriptor"]];
        }
    }
}

- (void) removeDescriptor:(int)fd
{
    @synchronized (_extraLoggingDescriptors) 
    {
        /* Remove the descriptor from our private list, regardless of how things went with ASL. */
        
        NSNumber *descriptor = [NSNumber numberWithInt:fd];
        [_extraLoggingDescriptors removeObject:descriptor];
        
        /* Broadcast the logger change to associated ASL clients. */
        [[NSNotificationCenter defaultCenter] postNotificationName:SOLoggerDidRemoveDescriptorNotification object:self userInfo:[NSDictionary dictionaryWithObject:descriptor forKey:@"descriptor"]];
    }
}

#pragma mark -
#pragma mark Accessors

- (int) severityFilterMask
{
    int mask = 0;
    @synchronized (self)
    {
        mask = _severityFilterMask;
    }
    return mask;
}

- (void) setSeverityFilterMask:(int)newMask
{    
    @synchronized (self)
    {                
        _severityFilterMask = newMask;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:SOLoggerDidChangeSeverityFilterNotification object:self userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:newMask] forKey:@"severityFilterMask"]];
    }
}

@end

#if SOLOGGER_DEBUG
static inline void LOG_ASLCLIENT(const char *where, aslclient ASLClient)
{
    NSThread *currentThread = [NSThread currentThread];
    NSLog (@"%s aslclient %p on %@ thread %p", where, ASLClient, ([currentThread isEqual:[NSThread mainThread]] ? @"main" : @"background"), currentThread);
}
#endif


#pragma mark -
#pragma mark License

/*
 Copyright (c) 2009-2012, Standard Orbit Software, LLC. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 Neither the name of the Standard Orbit Software, LLC nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */



