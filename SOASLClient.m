//
//  SOASLClient.m
//
//  Copyright 2009 Standard Orbit Software, LLC. All rights reserved.
//
//  $Rev$
//  $LastChangedBy$
//  $LastChangedDate$

#import "SOASLClient.h"

@implementation SOASLClient
@synthesize aslclient = myClientConnection;
@dynamic loggingDescriptors;

#pragma mark -
#pragma mark Creation

+ (SOASLClient *) client;
{
		return [[[SOASLClient alloc] init] autorelease];
}

- (id) init;
{
		self = [super init];
		if ( self ) {
				myClientConnection = NULL;
				myMirroredFileDescriptors = [NSMutableArray new];
		}
		
		return self;
}

- (void) dealloc;
{		
		// Ensure that the client connection is closed.
		[self close];
		
		[myMirroredFileDescriptors release];
		myMirroredFileDescriptors = nil;
		
#if SOASLCLIENT_DEBUG
		NSThread *currentThread = [NSThread currentThread];
		NSLog(@"Deallocating %@ on %@ thread %@", self, ([currentThread isEqual:[NSThread mainThread]] ? @"main" : @"background"), currentThread);	
#endif
		
		[super dealloc];
}

#pragma mark -
#pragma mark 


- (void) openForFacility:(NSString *)facility options:(uint32_t)options;
{
		if ( myClientConnection ) return; // Already open.
		
		// If no facility is specified, use "com.apple.console"
		const char *normalizedFacility = facility ? [facility UTF8String] : "com.apple.console";
		
		myClientConnection = asl_open( NULL /*ident*/, normalizedFacility, options );

}

- (BOOL) isOpen;
{
		return (myClientConnection != NULL);
}

- (void) close;
{		
		if ( [self isOpen] ) {
//				
//				for ( NSNumber *descriptor in self.mirrorFileDescriptors ) {
//						NSLog(@"removing mirrored file descriptor %@", descriptor );
//						asl_remove_log_file( myClientConnection, [descriptor integerValue] );
//				}
				
				[myMirroredFileDescriptors removeAllObjects];
				
				asl_close( myClientConnection );
				myClientConnection = NULL;
		}
}

#pragma mark -
#pragma mark Logging Streams

- (BOOL) addLoggingDescriptor:(NSNumber *)descriptor;
{
		BOOL success = (0 == asl_add_log_file( myClientConnection, [descriptor integerValue] ) );
		if ( success ) {
				[myMirroredFileDescriptors addObject:descriptor];
		}
		return success;
}

- (BOOL) removeLoggingDescriptor:(NSNumber *)descriptor;
{
		BOOL success = (0 == asl_remove_log_file( myClientConnection, [descriptor integerValue] ) );
		if ( success ) {
				[myMirroredFileDescriptors removeObject:descriptor];
		}
		return success;
}

- (NSArray *) loggingDescriptors;
{
		return [NSArray arrayWithArray:myMirroredFileDescriptors];
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

