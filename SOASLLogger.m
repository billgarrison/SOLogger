//
//  SOASLLogger.m
//
//  Copyright 2009 Standard Orbit Software, LLC. All rights reserved.
//
//  $Rev$
//  $LastChangedBy$
//  $LastChangedDate$

#import "SOASLLogger.h"
#import "SOASLClient.h"

@implementation SOASLLogger

@synthesize facility = myFacility;
@synthesize clientOptions = myClientOptions;
@synthesize mirrorFileDescriptors = myMirrorFileDescriptors;

#pragma mark -
#pragma mark Creation

+ (SOASLLogger *) loggerForFacility:(NSString *)facility options:(uint32_t)options;
{
		SOASLLogger *logger = [[[SOASLLogger alloc] initWithFacility:facility options:options] autorelease];
		return logger;
}

- (id) initWithFacility:(NSString *)facility options:(uint32_t)options;
{
		self = [super init];
		if ( self ) {
				myFacility = [facility copy];
				myClientOptions = options;
				myMirrorFileDescriptors = [NSMutableArray new];
		}
		return self;
}

- (void) dealloc;
{		
		[myFacility release]; 
		myFacility = nil;
		
		[myMirrorFileDescriptors release];
		myMirrorFileDescriptors = nil;
				
		[super dealloc];
}

// Get the ASL client connection that we should be using for the current thread. 
- (SOASLClient *) ASLClient;
{
		// We use the NSThread threadDictionary to cache an instance of our ASLClient cover object.  When the thread is released, the ASLClient deallocs, taking care of closing out the client connection.
		
		NSMutableDictionary *threadInfo = [[NSThread currentThread] threadDictionary];
		SOASLClient *cachedASLClient = [threadInfo objectForKey:@"SOASLClient"];
		if ( cachedASLClient == nil ) {
				
				// Create a new ASLClient instance and cache it in the current thread's dictionary.
				cachedASLClient = [[SOASLClient alloc] init];
				
				// Pass on the set of file descriptors to which this client should also be mirroring log messages.
				for ( NSNumber *descriptor in self.mirrorFileDescriptors ) {
						[cachedASLClient addLoggingDescriptor:descriptor];
				}
				
				[cachedASLClient openForFacility:self.facility options:self.clientOptions];
				
#if DEBUG
				asl_set_filter([cachedASLClient aslclient], ASL_FILTER_MASK_UPTO(ASL_LEVEL_DEBUG));
#endif
				
				[threadInfo setObject:cachedASLClient forKey:@"ASLClient"];
				
				[cachedASLClient release];
		}
		
		return cachedASLClient;
}

- (void) debug:(NSString *)text, ...;
{
		va_list arglist;
		va_start (arglist, text);
		[self messageWithLevel:ASL_LEVEL_DEBUG prefix:nil suffix:nil message:text arguments:arglist];
		va_end (arglist);
}

- (void) info:(NSString *)text, ...;
{
		va_list arglist;
		va_start (arglist, text);
		[self messageWithLevel:ASL_LEVEL_INFO prefix:nil suffix:nil message:text arguments:arglist];
		va_end (arglist);
}


- (void) messageWithLevel:(int)aslLevel prefix:(NSString *)prefix suffix:(NSString *)suffix message:(NSString *)text, ...;
{
		va_list arglist;
		va_start (arglist, text);
		[self messageWithLevel:aslLevel prefix:prefix suffix:suffix message:text arguments:arglist];
		va_end (arglist);
}


- (void) messageWithLevel:(int)aslLevel prefix:(NSString *)prefix suffix:(NSString *)suffix message:(NSString *)text arguments:(va_list)argList;
{
		NSAutoreleasePool *pool = [NSAutoreleasePool new];
		
		NSString *message =  [[[NSString alloc] initWithFormat: text arguments: argList] autorelease];
		
		SOASLClient *client = [self ASLClient];
		assert( [client isOpen] );
		
		//NSLog(@"client: %@ on thread %@", client, [NSThread currentThread]);
		
		NSMutableString *constructedMessage = [NSMutableString string];
		if ( prefix ) [constructedMessage appendString:prefix];		
		[constructedMessage appendString:message];
		if ( suffix ) [constructedMessage appendString:suffix];
		
		aslmsg msg = asl_new(ASL_TYPE_MSG);
		
		const char *normalizedFacility = self.facility ? [self.facility UTF8String] : "com.apple.console";
		asl_set( msg, ASL_KEY_FACILITY, normalizedFacility);

		int didLog = asl_log([client aslclient], msg, aslLevel, "%s", [constructedMessage UTF8String]);
		
		asl_free( msg );
		
		assert( didLog == 0);
		
		[pool release];
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



