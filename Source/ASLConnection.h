//
//  SOASLConnection.h
//
//  Copyright 2009 Standard Orbit Software, LLC. All rights reserved.
//
//  $Rev$
//  $LastChangedBy$
//  $LastChangedDate$
//

/**
 ASLConnection represents a connection to the ASL service.
 
 It carries a reference to an aslclient client handle.
 
 The primary purpose for this wrapper class is to enable proper use of ASL from multiple threads. Documentation (man 3 asl) states that there should be a separate aslclient client handle created for each thread that talks to the ASL service. SOLogger will automatically create an ASLConnection instance when needed for any thread to satisfy the one-aslclient-per-thread condition, storing it in that thread's -threadDictionary dictionary.
 */
#import <Foundation/Foundation.h>
#import <asl.h>

@interface ASLConnection : NSObject 
{
	aslclient __aslclientRef;
	NSMutableArray *__extraLoggingDescriptors;
}

/** The aslclient connection that we are wrapping. Will be NULL until the connection is opened. */
@property (nonatomic, readonly) aslclient aslclientRef;

/** Additional POSIX descriptors (of NSNumber) to which log messages will be sent. */
@property (nonatomic, readonly) NSArray *loggingDescriptors;

/**
 \return An autoreleased instance. The connection is not opened.
 */
+ (ASLConnection *) ASLConnection;

/**
 \brief Open the ASL client connection.
 \param facility The facility name under which this connection will be logging. Reverse dot notation is recommended to ensure uniqueness.
 \param options A bitflag of options to pass to the asl_open() function.
 \return YES if the connection was opened; NO otherwise.
 */
- (void) openForFacility: (NSString *) facility options: (uint32_t) options;

/**
 \brief Close the ASL client connection.
 The ASL connection will be closed implicitly when the instance is deallocated.
 */
- (void) close;

/**
 \return YES if the client connection has been opened; NO if not.
 */
- (BOOL) isOpen;

#pragma mark -
#pragma mark Logging Streams

/**
 \brief Adds the given descriptor to the list of those who will receive copies of all logged messages.
 \param descriptor The POSIX descriptor of the file, pipe, or socket to be added.
 \return YES if the descriptor was successfully added to the connection; NO otherwise.
 The descriptor is expected to have already been opened. ASL does not open or close the descriptor. The caller is expected to manage the opening and closing of any extra logging descriptors.
 */
- (BOOL) addLoggingDescriptor: (int)descriptor;

/**
 \brief Removes the descriptor from the mirrored logging list.
 \param descriptor The previously added descriptor.
 \return YES if the descriptor was successfully removed to the connection; NO otherwise.
 -close causes all added descriptors to be removed. Use this method to remove a particular descriptor before close.
 
 The descriptor is not closed when removed the list. The caller is expected to manage the opening and closing of any extra logging descriptors.

 */
- (BOOL) removeLoggingDescriptor: (int)descriptor;

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


