//
//  SOLogger.h
//
//  Copyright 2009 Standard Orbit Software, LLC. All rights reserved.
//
//  $Rev$
//  $LastChangedBy$
//  $LastChangedDate$

/**
 SOLogger implements a high-level Cocoa API for logging messages using the Apple System Logging (ASL) service.
 
 Features:
 - provides methods for logging formatted messages at the various severity levels supported by ASL.
 - supports adding additional file descriptors to receive logged messages.
 - supports logging from background threads using the recommended practice of an independent asl_client connection per thread.
 
 SOLogger and Threads
 
 Each SOLogger instance uses an SOASLClient instance to interact with the ASL service, one SOASLClient for each thread.  The SOASLClient is configured with the logger's facility, client options, and list of additional file descriptors. 
 
 That ASLClient instance in the #NSThread::threadInfo dictionary under the key #ASLClientKey.  Each thread's ASLClient instance is configured using the SOLogger's current property values.  For any given new thread, the ASLClient instance is lazily created by the #ASLClient method, stored in the thread's threadInfo dictionary, and reused as configured for the life of the thread.
 
 
 
 Known Issues
  
 After modifying the logger's file descriptor list, the current thread and all future threads will get an ASLClient instance configured with this now-updated file descriptors list.  ASLClient instances in other concurrently existing threads are *not* updated.  It is possible for two long-running threads to have ASLClients with different file descriptor lists.
 
 I don't anticipate that this behavior will cause a problem in practice.  I'm noting it here, though, so that you're aware of it.
 
 */

#import <Foundation/Foundation.h>
#import "SOASLClient.h"
#include <asl.h>

/**
 \const SOLoggerDefaultASLOptions A convenient constant specifying a reasonable combintation of Apple System Logging options.
 Currently defined as ASL_OPT_NO_DELAY | ASL_OPT_STDERR | ASL_OPT_NO_REMOTE.
 */
extern uint32_t SOLoggerDefaultASLOptions;

@interface SOLogger : NSObject 
{
@private
	NSString *myFacility;
	uint32_t myASLClientOptions;
	NSMutableArray *myFileDescriptors;
	
	SOASLClient *myMainASLClient;
}

#pragma mark -
#pragma mark Creation

/**
 Factory method for creating an open ASL logger.
 \param facility The identifier of the facility associated with this logger.  Pass nil and the messages are logged to @"com.apple.console".
 \param options A bitflag of ASL options that will be passed to the <tt>asl_open</tt> function.
 */
+ (SOLogger *) loggerForFacility:(NSString *)facility options:(uint32_t)options;

/**
 \brief Designated initializer
 \param facility The facility for which this logger will be logging.  Recommended that you use a reverse-DNS style naming scheme to avoid name collisions. Pass nil and the messages are logged to @"com.apple.console".
 \param options Bitflag specifying ASL options.  Of most utility is the ASL_OPT_STDERR flag.
 The facility can be used to identify the application or a particular subsystem within the application.  Messages are tagged with this facility identifier when added to the ASL database.  The option <tt>ASL_OPT_STDERR</tt> configures the logger to echo logged messages to stderr; required to see log messages in the Xcode console.
 \sa <tt>man 3 asl</tt> for documentation on the function <tt>asl_open</tt> for the available option flags.
 */
- (id) initWithFacility:(NSString *)facility options:(uint32_t)options;


#pragma mark -
#pragma mark Additional Logging Files

/**
 \brief Add a file descriptor to the logger.
 \param fd The file descriptor.
 
 ASL allows additional file descriptors to be added to a logging client, each getting sent a copy of the logged message.  The file descriptor must be open for writing.
 */
- (void) addFileDescriptor:(int)fd;

/**
 \brief Remove a file descriptor from the logger.
 \param fd The file descriptor.
 
 Remove the given file descriptor from the logger's list of additional file descriptors receiving messages.  You only need to call this method to remove a file descriptor at runtime before the logger is deallocated.
 */
- (void) removeFileDescriptor:(int)fd;

#pragma mark -
#pragma mark Logging Convenience Methods

/**
 \brief Log a debug level message.
 \param message The message.  Accepts all formatting specifiers available to NSString.
 In the default syslog configuration, debug- and info-level messages are not logged to the ASL database.  They are logged to stderr and any additional file descriptors attached to the logger.
 */
- (void) debug:(NSString *)message, ...;

/**
 \brief Log a debug level message.
 \param message The message.  Accepts all formatting specifiers available to NSString.
 In the default syslog configuration, debug- and info-level messages are not logged to the ASL database.  They are logged to stderr and any additional file descriptors attached to the logger.
 */
- (void) info:(NSString *)message, ...;

/**
 \brief Log a notice level message.
 \param message The message.  Accepts all formatting specifiers available to NSString.
 In the default syslog configuration, this is the lowest level message to be logged in the ASL database.
 */
- (void) notice:(NSString *)message, ...;

/**
 \brief Log a warning level message.
 \param message The message.  Accepts all formatting specifiers available to NSString.
 */
- (void) warning:(NSString *)message, ...;

/**
 \brief Log an error level message.
 \param message The message.  Accepts all formatting specifiers available to NSString.
 */
- (void) error:(NSString *)message, ...;

/**
 \brief Log an alert level message.
 \param message The message.  Accepts all formatting specifiers available to NSString.
 */
- (void) alert:(NSString *)message, ...;

/**
 \brief Log a critical level message.
 \param message The message.  Accepts all formatting specifiers available to NSString.
 */
- (void) critical:(NSString *)message, ...;

/**
 \brief Log a panic or emergency level message.
 \param message The message.  Accepts all formatting specifiers available to NSString.
 This is the highest level message.
 */
- (void) panic:(NSString *)message, ...;

#pragma mark -
#pragma mark Logging Primitives

/**
 \brief Logs a message with the given level, prefix and/or suffix string.
 \param aslLevel The severity level of the message. From least to most severe: ASL_LEVEL_DEBUG, ASL_LEVEL_INFO, ASL_LEVEL_NOTICE, ASL_LEVEL_WARNING, ASL_LEVEL_ERR, ASL_LEVEL_CRIT, ASL_LEVEL_ALERT, ASL_LEVEL_EMERG.
 \param prefix A string to prefix to the message text.
 \param suffix A string to suffix to the message text.
 \param text The text of the message. Accepts all formatting specifiers available to NSString.
 \sa <tt>man 3 asl</tt>
 */
- (void) messageWithLevel:(int)aslLevel prefix:(NSString *)prefix suffix:(NSString *)suffix message:(NSString *)text, ...;

/**
 \brief Logs a message with the given level, prefix and/or suffix string.
 \param aslLevel The severity level of the message.
 \param text The text of the message. Accepts all formatting specifiers available to NSString.
 \param arguments A va_list of formatting arguments to the message.
 */
- (void) messageWithLevel:(int)aslLevel prefix:(NSString *)prefix suffix:(NSString *)suffix message:(NSString *)text arguments:(va_list)argList;

/**
 \return The ASLClient instance in use on the current thread.  Every new thread is ensured to use an independent ASLClient instance.
 */
- (SOASLClient *) currentThreadASLClient;

#pragma mark -
#pragma mark Properties

/**
 The identifier of the facility with which this logger is associated.  The facility value is established at initialization and cannot be changed.
 */
@property (nonatomic, readonly) NSString *facility;

/**
 The ASL options that will be configured into the logger's ASLClient instance.  By default, #SOLoggerDefaultASLOptions will be used on new ASL connections.
 */
@property (nonatomic, assign) uint32_t ASLClientOptions;

/**
 Array of the additional file descriptors (as NSNumber) to be added to the ASL client connection.
 When a logger's ASLClient instance is created, it is configured to also send messages to this list of file descriptors.
 */
@property (nonatomic, readonly) NSMutableArray *additionalFileDescriptors; 

/**
Reference to the ASLClient used by the logger on the main thread.
The logger will use separate ASLClient instances on each thread under which it executes.  For each new thread, its ASLClient will be a copy of the main thread's ASLClient.
*/
@property (nonatomic, readonly) SOASLClient *mainASLClient;

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

