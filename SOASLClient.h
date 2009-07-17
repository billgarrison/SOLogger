//
//  SOASLClient.h
//
//  Copyright 2009 Standard Orbit Software, LLC. All rights reserved.
//
//  $Rev$
//  $LastChangedBy$
//  $LastChangedDate$
//

#import <Foundation/Foundation.h>
#import <asl.h>

@interface SOASLClient : NSObject {
		aslclient myClientConnection;
		NSMutableArray *myMirroredFileDescriptors;
}

/** The ASL client connection that we are are covering. */
@property (nonatomic, readonly) aslclient asl_client;

/** Array of file descriptors (NSNumber) to which log messages are being mirrored. */
@property (nonatomic, readonly) NSArray *loggingDescriptors;

/**
 \return An autoreleased instance.  The client connection is not opened.
 */
+ (SOASLClient *) client;

/**
 \brief Open the ASL client connection.
 \param facility A reverse dot notation name for the facility for which this connection will be logging.
 \param options A bitflag of options to pass to the asl_open() function.
 \return YES if the connection was opened; NO otherwise.  clientConnection will be NULL until the connection is successfully opened.
 */
- (void) openForFacility:(NSString *)facility options:(uint32_t)options;

/**
 \brief Close the ASL client connection.
 If you don't do this explicitly, it will be done when the instance is deallocated.
 */
- (void) close;

/**
 \return YES if the client connection has been opened; NO if not.
 */
- (BOOL) isOpen;

#pragma mark -
#pragma mark Logging Streams

/**
 \brief Adds the file descriptor to the list of those who will receive mirror copies of all logged messages.
 \param descriptor The file descriptor.  Can refer to a file, pipe, or socket.
 \return YES if the descriptor was successfully added to the ASL client connection; NO otherwise.
 */
- (BOOL) addLoggingDescriptor:(NSNumber *)descriptor;

/**
 \brief Removes the file descriptor from the mirrored logging list.
 \param descriptor The file descriptor.  Can refer to a file, pipe, or socket.
 \return YES if the descriptor was successfully removed to the ASL client connection; NO otherwise.
 Closing an ASL client connection causes all added file descriptors to be removed.  Use this method to remove a mirrored log adhoc before close.
 */
- (BOOL) removeLoggingDescriptor:(NSNumber *)descriptor;

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


