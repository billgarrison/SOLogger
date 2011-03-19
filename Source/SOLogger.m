//
//  SOASLLogger.m
//
//  Copyright 2009 Standard Orbit Software, LLC. All rights reserved.
//
//  $Rev$
//  $LastChangedBy$
//  $LastChangedDate$

#import "SOLogger.h"
#import "ASLConnection.h"

uint32_t SOLoggerDefaultASLOptions = ASL_OPT_NO_DELAY | ASL_OPT_STDERR | ASL_OPT_NO_REMOTE;

@implementation SOLogger

@synthesize facility = __facility;
@synthesize connectionOptions = __ASLOptions;
@synthesize ASLConnectionKey = __perLoggerASLConnectionKey;
@synthesize severityFilterMask = __ASLFilterMask;

#pragma mark -
#pragma mark Creation

+ (SOLogger *) loggerForFacility:(NSString *)facility options:(uint32_t)options
{
	SOLogger *logger = [[[SOLogger alloc] initWithFacility:facility options:options] autorelease];
	return logger;
}

- (id) initWithFacility:(NSString *)facility options:(uint32_t)options;
{
	self = [super init];
	if ( self ) {
		__facility = [facility copy];
		__ASLOptions = options;
		__ASLFilterMask = ASL_FILTER_MASK_UPTO (ASL_LEVEL_NOTICE);
		__extraLoggingDescriptors = [[NSMutableArray alloc] init];
		__perLoggerASLConnectionKey = [[NSString alloc] initWithFormat:@"%@ForLogger%p", NSStringFromClass([ASLConnection class]), self];
	}
	return self;
}

- (id) init
{
	return [self initWithFacility:nil options:SOLoggerDefaultASLOptions];
}

- (void) dealloc
{		
	[[[NSThread currentThread] threadDictionary] removeObjectForKey: __perLoggerASLConnectionKey];
	[__perLoggerASLConnectionKey release], __perLoggerASLConnectionKey = nil;
	[__facility release], __facility = nil;
	[__extraLoggingDescriptors release], __extraLoggingDescriptors = nil;
	[super dealloc];
}

#pragma mark -
#pragma mark Logging

- (void) debug: (NSString *) format, ...
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
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	ASLConnection *connection = [self ASLConnection];
	
	assert ([connection isOpen]);
	assert (aslLevel >= ASL_LEVEL_EMERG || aslLevel <= ASL_LEVEL_DEBUG);
	assert (format != nil);
	
	aslmsg msg = asl_new (ASL_TYPE_MSG);    
	const char *normalizedFacility = self.facility ? [self.facility UTF8String] : "com.apple.console";
	asl_set (msg, ASL_KEY_FACILITY, normalizedFacility);
	
	/* asl_log() does not handle the %@ format specifier, so process the format and arguments into an NSString first. */
	
	NSString *text = [[[NSString alloc] initWithFormat:format arguments:arguments] autorelease];
	
	/* Log the text as UTF-8 string */
	asl_log ([connection aslclientRef], msg, aslLevel, "%s", [text UTF8String]);
	
	// Cleanup
	asl_free (msg);
	
#if SOASLLOGGER_DEBUG
	NSThread *currentThread = [NSThread currentThread];
	NSLog (@"%@ on %@ thread %@", client, ([currentThread isEqual:[NSThread mainThread]] ? @"main" : @"background"), currentThread);
#endif
	
	[pool drain];
}

#pragma mark -
#pragma mark Additional Logging Descriptors

- (void) addFileDescriptor:(int)descriptor
{
	@synchronized (__extraLoggingDescriptors)
	{
		[__extraLoggingDescriptors addObject:[NSNumber numberWithInt:descriptor]];
		
		/* Add the new descriptor to the current thread's ASL connection. */
		
		[[self ASLConnection] addLoggingDescriptor:descriptor];
		
		/* Also update the main thread ASL connection, if necessary. */
		
		if ( ![NSThread isMainThread]) 
		{
			[[self mainThreadASLConnection] addLoggingDescriptor:descriptor];
		}
	}
}


- (void) removeFileDescriptor:(int)descriptor
{
	@synchronized (__extraLoggingDescriptors) 
	{
		[__extraLoggingDescriptors removeObject:[NSNumber numberWithInt:descriptor]];
		
		/* Remove the descriptor from the current thread's ASL connection */
		
		[[self ASLConnection] removeLoggingDescriptor:descriptor];
		
		/* Also update the main thread ASL connection, if necessary. */
		
		if ( ![NSThread isMainThread]) 
		{
			[[self mainThreadASLConnection] removeLoggingDescriptor:descriptor];
		}
	}
}

#pragma mark -
#pragma mark Accessors

- (void) setSeverityFilterMask:(int)newMask
{
	/* Update the severity filtering on the current ASL connection, which could belong to a background thread. */
		
	asl_set_filter ([[self ASLConnection] aslclientRef], newMask);
	
	/* Update the main thread's ASL connection also */
	
	if ( ![NSThread isMainThread] )
	{
		asl_set_filter ([[self mainThreadASLConnection] aslclientRef], newMask);
	}
}

/* Return the ASL connection that we should be using for the current thread. */

- (ASLConnection *) ASLConnection
{
	// We use the NSThread threadDictionary to cache an instance of our ASLClient cover object.  When the thread is released, the ASLClient deallocs, taking care of closing out the client connection.
	
	NSMutableDictionary *threadInfo = [[NSThread currentThread] threadDictionary];
	assert (threadInfo != nil);
	
	ASLConnection *connection = [threadInfo objectForKey: __perLoggerASLConnectionKey];
	
	if (connection == nil)
	{
		/* 
		 Create a new ASL connection instance and cache it in the current thread's dictionary.
		 Each thread in play needs to have an independent asl_client connection.
		 The per-logger-key enables a single thread to have multiple loggers in play.
		 */
		connection = [[[ASLConnection alloc] init] autorelease];
		[threadInfo setObject:connection forKey: __perLoggerASLConnectionKey];
		
		/* Configure the severity filtering level */
		asl_set_filter ([connection aslclientRef], __ASLFilterMask);
		
		/* Open the connection before adding file descriptors; a valid asl_client handle must exist first */
		[connection openForFacility:self.facility options:self.connectionOptions];
		
		/* Pass on the set of additional file descriptors to which the logger should be sending messages */
		for (NSNumber *descriptor in self.additionalFileDescriptors)
		{
			[connection addLoggingDescriptor:[descriptor intValue]];
		}
		
#if DEBUG
		/* When DEBUG is set, reset filtering so that all messages are logged, including DEBUG level one. */
		asl_set_filter ([connection aslclientRef], ASL_FILTER_MASK_UPTO(ASL_LEVEL_DEBUG));
#endif
	}
	
	/* Capture a weak reference to the main thread's ASL connection so that we can make it generally available via -mainThreadASLConnection. -mainThreadASLConnection is primarily used for unit testing, but might be otherwise useful to callers.
	 */
	if ([NSThread isMainThread] && !__mainThreadASLConnection)
	{
		__mainThreadASLConnection = connection;
	}
	
	return [[connection retain] autorelease];
}

- (NSArray *) additionalFileDescriptors 
{
	NSArray *immutable = nil;
	@synchronized (__extraLoggingDescriptors) {
		immutable = [NSArray arrayWithArray: __extraLoggingDescriptors];
	}
	return immutable;
}

- (ASLConnection *) mainThreadASLConnection
{
	if (__mainThreadASLConnection == nil) 
	{
		[self performSelectorOnMainThread:@selector(ASLConnection) withObject:nil waitUntilDone:YES];
	}
	
	return [[__mainThreadASLConnection retain] autorelease];
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



