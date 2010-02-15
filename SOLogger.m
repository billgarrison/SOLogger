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

// Key used to retrieve the current thread's ASLClient instance from its threadInfo dictionary.
static NSString * const ASLClientsKey = @"SOASLClients";

@interface SOLogger()
- (NSMutableDictionary *) currentThreadASLClientsMapping;
@end

@implementation SOLogger

#pragma mark -
#pragma mark Creation

+ (SOLogger *) loggerForFacility:(NSString *)facility options:(uint32_t)options;
{
	SOLogger *logger = [[[SOLogger alloc] initWithFacility:facility options:options] autorelease];
	return logger;
}

- (id) initWithFacility:(NSString *)facility options:(uint32_t)options;
{
	self = [super init];
	if ( self ) {
		myFacility = [facility copy];
		myASLClientOptions = options;
		myFileDescriptors = [NSMutableArray new];
	}
	return self;
}

- (id) init;
{
	return [self initWithFacility:nil options:SOLoggerDefaultASLOptions];
}

- (void) dealloc;
{		
	[myFacility release]; myFacility = nil;
	
	myMainASLClient = nil;
	
	[super dealloc];
}


#pragma mark -
#pragma mark Additional Logging Files

- (void) addFileDescriptor:(int)fd;
{
	[myFileDescriptors addObject:[NSNumber numberWithInt:fd]];
	
	// As a side effect, throw out this logger's ASLClient instance from the current thread info.  It will be reconstructed with the now-updated set of file descriptors on its next access.
	[[self currentThreadASLClientsMapping] removeObjectForKey:[NSValue valueWithNonretainedObject:self]];
}


- (void) removeFileDescriptor:(int)fd;
{
	[myFileDescriptors removeObject:[NSNumber numberWithInt:fd]];
	
	// As a side effect, throw out this logger's ASLClient instance from the current thread info.  It will be reconstructed with the now-updaed set of file descriptors on its next access.
	[[self currentThreadASLClientsMapping] removeObjectForKey:[NSValue valueWithNonretainedObject:self]];
}

#pragma mark -
#pragma mark Logging

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

- (void) notice:(NSString *)text, ...;
{
	va_list arglist;
	va_start (arglist, text);
	[self messageWithLevel:ASL_LEVEL_NOTICE prefix:nil suffix:nil message:text arguments:arglist];
	va_end (arglist);
}

- (void) warning:(NSString *)text, ...;
{
	va_list arglist;
	va_start (arglist, text);
	[self messageWithLevel:ASL_LEVEL_WARNING prefix:nil suffix:nil message:text arguments:arglist];
	va_end (arglist);
}

- (void) error:(NSString *)text, ...;
{
	va_list arglist;
	va_start (arglist, text);
	[self messageWithLevel:ASL_LEVEL_ERR prefix:nil suffix:nil message:text arguments:arglist];
	va_end (arglist);
}

- (void) alert:(NSString *)text, ...;
{
	va_list arglist;
	va_start (arglist, text);
	[self messageWithLevel:ASL_LEVEL_ALERT prefix:nil suffix:nil message:text arguments:arglist];
	va_end (arglist);
}

- (void) critical:(NSString *)text, ...;
{
	va_list arglist;
	va_start (arglist, text);
	[self messageWithLevel:ASL_LEVEL_CRIT prefix:nil suffix:nil message:text arguments:arglist];
	va_end (arglist);
}

- (void) panic:(NSString *)text, ...;
{
	va_list arglist;
	va_start (arglist, text);
	[self messageWithLevel:ASL_LEVEL_EMERG prefix:nil suffix:nil message:text arguments:arglist];
	va_end (arglist);
}

#pragma mark -
#pragma mark Logging Primitives

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
	
	SOASLClient *client = [self currentThreadASLClient];
	assert( [client isOpen] );
	
	NSMutableString *constructedMessage = [NSMutableString string];
	if ( prefix ) [constructedMessage appendString:prefix];		
	[constructedMessage appendString:message];
	if ( suffix ) [constructedMessage appendString:suffix];
	
	aslmsg msg = asl_new(ASL_TYPE_MSG);
	
	const char *normalizedFacility = self.facility ? [self.facility UTF8String] : "com.apple.console";
	asl_set( msg, ASL_KEY_FACILITY, normalizedFacility);
	
	asl_log([client asl_client], msg, aslLevel, "%s", [constructedMessage UTF8String]);
	
	asl_free( msg );
	
#if SOASLLOGGER_DEBUG
	NSThread *currentThread = [NSThread currentThread];
	NSLog(@"%@ on %@ thread %@", client, ([currentThread isEqual:[NSThread mainThread]] ? @"main" : @"background"), currentThread);
#endif
	
	[pool release];
}


#pragma mark -
#pragma mark Properties

@synthesize facility = myFacility;
@synthesize ASLClientOptions = myASLClientOptions;
@synthesize additionalFileDescriptors = myFileDescriptors;

- (SOASLClient *) mainASLClient;
{
	if ( myMainASLClient == nil ) {
		[self performSelectorOnMainThread:@selector(ASLClient:) withObject:nil waitUntilDone:YES];
	}
	
	return [[myMainASLClient retain] autorelease];
}

// Return an ASL client connection that we should be using for the current thread. 
- (SOASLClient *) currentThreadASLClient;
{
	// Pull the dictionary of cached ASL clients from the thread info dictionary.  We're looking in this dictionary for the ASLClient associated with our logger.
	if ( [self currentThreadASLClientsMapping] == nil ) 
	{
		// Install an empty mutable dictionary into this thread's info dictionary under the key ASLClientsKey.  This dictionary holds the mapping between a Logger and its associated ASLClient.
		[[[NSThread currentThread] threadDictionary] setObject: [NSMutableDictionary dictionary] forKey:ASLClientsKey];
	}
	
	// Pull out the ASLClient associated with this logger instance.
	SOASLClient *thisThreadASLClient = [[self currentThreadASLClientsMapping] objectForKey:[NSValue valueWithNonretainedObject:self]];
	
	if ( thisThreadASLClient == nil ) 
	{
		
		// Create a new ASLClient instance and install it in the thread's cache of ASL clients.
		
		thisThreadASLClient = [[[SOASLClient alloc] init] autorelease];
		
		// Lock us down while we access the logger's ivars.
		@synchronized(self) 
		{
			// Open the client before adding file descriptors; a valid asl_client connection be exist first.
			[thisThreadASLClient openForFacility:[self facility] options:[self ASLClientOptions]];
			
			// Pass on the logger's current set of file descriptors to this new ASL client instance.
			for ( NSNumber *descriptor in [self additionalFileDescriptors] ) {
				[thisThreadASLClient addLoggingDescriptor:[descriptor intValue]];
			}
		}
		
#if DEBUG
		asl_set_filter([thisThreadASLClient asl_client], ASL_FILTER_MASK_UPTO(ASL_LEVEL_DEBUG));
#endif
		
		// Stash the new ASL client in this thread's info dictionary; each thread in play needs to have an independent asl_client connection.
		[[self currentThreadASLClientsMapping] setObject:thisThreadASLClient forKey:[NSValue valueWithNonretainedObject:self]];
		
		// Update the myMainASLClient weak reference, if we've been invoked on the main thread.
		if ( [NSThread isMainThread] ) {
			myMainASLClient = thisThreadASLClient;
		}
	}
	
	return [[thisThreadASLClient retain] autorelease];
}

#pragma mark -
#pragma mark Internal

// Within each thread's threadDictionary, we maintain another dictionary the maps an SOASLCLient to a logger.  This method returns that logger->ASLClient dictionary from our thread.
- (NSMutableDictionary *) currentThreadASLClientsMapping;
{
	return [[[NSThread currentThread] threadDictionary] objectForKey:ASLClientsKey];
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



