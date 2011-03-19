//
//  SOASLogger.h
//
//  Copyright 2009 Standard Orbit Software, LLC. All rights reserved.
//
//  $Rev$
//  $LastChangedBy$
//  $LastChangedDate$

/**
 SOLogger implements a Cocoa API for logging messages using the Apple System Logging (ASL) service.
 
 Features:
 - provides methods for logging formatted messages at the various severity levels supported by ASL.
 - supports adding additional file descriptors to receive logged messages.
 - supports logging from background threads using the recommended practice of an independent ASL client handle per thread.
 
 SOLogger and Threads
 
 An SOLogger uses an ASLConnection to interact with the ASL service, one ASLConnection per active thread.  A thread's ASLConnection instance is stored in the NSThread#threadDictionary dictionary, under the key SOLogger#ASLConnectionKey.  At the time of creation, an ASLConnection is configured with the logger's facility, client options, and list of additional logging descriptors. 
 
 All ASLConnection instances live only as long as their associated threads. Consequently, the main thread's ASLConnection instance exists for the life of the application.  ASLConnections on secondary threads will have varying lifetimes.
 
 Known Issues
 
 After modifying a logger's file descriptor list, the main thread's ASLConnection is always updated. If the logger's descriptor list is modified from a secondary thread, that thread's ASLConnection is also updated.  All subsequent logger  threads will inherit the logger's updated descriptors list. Any other concurrently running logger threads are unaffected and unaware of the change in the descriptor list.
 
 Given this behavior, it is possible in any two long-running threads using the same SOLogger instance for their ASLConnections to become out of sync with respect their list of logging descriptors.  I do not anticipate that this behavior will cause a problem in common usage.  I'm noting it here, though, so that you're aware of the behavior.
 
 The same caveat applies to modifying a logger's severity filtering mask. The main thread's ASLConnection filtering mask is always updated. If -setSeverityFilterMask is invoked on a secondary thread, that thread's ASLConnection is also updated. Any subsequent logger threads will inherit the logger's filtering mask.  All other concurrently running logger threads are unaffected and unaware of the change in filtering mask.
 */

#import <Foundation/Foundation.h>
#include <asl.h>

/**
 \const SOLoggerDefaultASLOptions A convenient constant specifying a reasonable combintation of Apple System Logging options.
 Currently defined as ASL_OPT_NO_DELAY | ASL_OPT_STDERR | ASL_OPT_NO_REMOTE.
 */
extern uint32_t SOLoggerDefaultASLOptions;

@class ASLConnection;

@interface SOLogger : NSObject 
{
@private
    NSString *__facility;
    uint32_t __ASLOptions;
    int __ASLFilterMask;
    NSMutableArray *__extraLoggingDescriptors;
    ASLConnection *__mainThreadASLConnection;
    NSString *__perLoggerASLConnectionKey;
}

#pragma mark -
#pragma mark Creation

/**
 Factory method for creating an open ASL logger.
 \param facility The identifier of the facility associated with this logger.  Pass nil and the messages are logged under @"com.apple.console".
 \param options A bitflag of ASL options that will be passed to the <tt>asl_open</tt> function.
 */
+ (SOLogger *) loggerForFacility:(NSString *)facility options:(uint32_t)options;

/**
 \brief Designated initializer
 \param facility The facility for which this logger will be logging.  Recommended that you use a reverse-DNS style naming scheme to avoid name collisions. Pass nil and the messages are logged under @"com.apple.console".
 \param options Bitflag specifying ASL options. Of most utility is the ASL_OPT_STDERR flag.
 
 The facility can be used to identify the application or a particular subsystem within the application.  Messages are tagged with this facility identifier when added to the ASL database.  The option <tt>ASL_OPT_STDERR</tt> configures the logger to echo logged messages to stderr; this required to see log messages in the Xcode console.
 \sa <tt>man 3 asl</tt> for documentation on the function <tt>asl_open</tt> for the available option flags.
 */
- (id) initWithFacility:(NSString *)facility options:(uint32_t)options;

#pragma mark -
#pragma mark Additional Logging Files

/**
 \brief Add an external logging descriptor to the logger.
 \param fd The descriptor.
 
 ASL allows additional file descriptors to be added to a logging client, with each a copy of the logged message. The file descriptor must already be open for writing.
 
 Adding a file descriptor to the logger has the following effects in multi-threaded operation:
 1. On the current thread (the thread on which #addFileDescriptor has been received), that thread's ASLConnection is updated with the modified set of file descriptors.
 2. Any new thread that uses the receiver will inherit the modified set of additional file descriptors.
 3. All other existing threads that have ASLConnection instances will be unaware of the new file description addition.
 
 The expected normal use case is that -addFileDescriptor will be called from the main thread.
 When invoked from the main thread, the logger's main thread ASLConnection is updated to reflect the additional file descriptor.  
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
- (void) debug: (NSString *) message, ...;

/**
 \brief Log a debug level message.
 \param message The message.  Accepts all formatting specifiers available to NSString.
 In the default syslog configuration, debug- and info-level messages are not logged to the ASL database.  They are logged to stderr and any additional file descriptors attached to the logger.
 */
- (void) info: (NSString *) message, ...;

/**
 \brief Log a notice level message.
 \param message The message.  Accepts all formatting specifiers available to NSString.
 In the default syslog configuration, this is the lowest level message to be logged in the ASL database.
 */
- (void) notice: (NSString *) message, ...;

/**
 \brief Log a warning level message.
 \param message The message.  Accepts all formatting specifiers available to NSString.
 */
- (void) warning: (NSString *) message, ...;

/**
 \brief Log an error level message.
 \param message The message.  Accepts all formatting specifiers available to NSString.
 */
- (void) error: (NSString *) message, ...;

/**
 \brief Log an alert level message.
 \param message The message.  Accepts all formatting specifiers available to NSString.
 */
- (void) alert: (NSString *) message, ...;

/**
 \brief Log a critical level message.
 \param message The message.  Accepts all formatting specifiers available to NSString.
 */
- (void) critical: (NSString *) message, ...;

/**
 \brief Log a panic or emergency level message.
 \param message The message.  Accepts all formatting specifiers available to NSString.
 This is the highest level message.
 */
- (void) panic: (NSString *) message, ...;

#pragma mark -
#pragma mark Logging Primitives

/**
 \brief Logs a message with the given level.
 \param aslLevel The severity level of the message. From least to most severe: ASL_LEVEL_DEBUG, ASL_LEVEL_INFO, ASL_LEVEL_NOTICE, ASL_LEVEL_WARNING, ASL_LEVEL_ERR, ASL_LEVEL_CRIT, ASL_LEVEL_ALERT, ASL_LEVEL_EMERG.
 \param format The text of the message. Accepts all formatting specifiers available to NSString.
 \sa <tt>man 3 asl</tt>
 */

- (void) logWithLevel:(int)aslLevel format:(NSString *)format arguments:(va_list)arguments;


/**
 \return The ASLClient instance in use on the current thread.  Every thread will have its own independent ASLClient instance.
 */
- (ASLConnection *) ASLConnection;

#pragma mark -
#pragma mark Properties

/**
 The identifier of the facility with which this logger is associated.  The facility value is established at initialization and cannot be changed.
 */
@property (nonatomic, readonly) NSString *facility;

/**
 The ASL options that will be configured into the logger's ASLConnection instance.  By default, #SOLoggerDefaultASLOptions will be used on new ASL connections.
 */
@property (nonatomic, assign) uint32_t connectionOptions;

/**
 The severity filtering mask that ASL will apply to messages sent to the ASL system log. The default filter mask excludes messages with DEBUG and INFO level severity from being sent to the ASL system log.
 */
@property (nonatomic, assign) int severityFilterMask;

/**
 Array of the additional file descriptors (as NSNumber) to be added to the ASL client connection.
 When a logger's ASLClient instance is created, it is configured to also send messages to this list of file descriptors.
 */
@property (nonatomic, readonly) NSArray *additionalFileDescriptors; 

/**
 \return The ASLClient associated with the main thread.
 */
@property (nonatomic, readonly) ASLConnection *mainThreadASLConnection;


/**
 A dictionary key that is unique per logger instance for storing the logger's ASLConnection instance in a thread's threadDictionary.
 
 To enable multiple SOLoggers to be tracked in a given thread, each per-thread ASLConnection must be stored uniquely in the thread's threadInfo dictionary.
 
 We generate a dictionary key of the form ASLConnectionForLogger<memory address of the SOLogger>.
 E.g. For an SOLogger instance at 0x3238493, the per-logger ASL connection key for accessing the threadInfo dictionary will be @"ASLConnectionForLogger0x3238493"
 
 This unique key allows a single thread's threadDictionary to track 2 or more SOLoggers.
 For example:
 SOLogger *logger1 = ...; // Address at 0x3238493
 SOLogger *logger2 = ...; // Address at 0x3238600
 
 On the main thread, the ASLConnection for each logger will be stored in the thread's threadDictionary under ASLConnectionForLogger0x3238493 and ASLConnectionForLogger0x3238600. These keys will be used to uniquely store each logger's ASLConnection in any thread's info dictionary.
 */
@property (nonatomic, readonly) NSString *ASLConnectionKey;

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

