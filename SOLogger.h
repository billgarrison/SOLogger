//
//  SOASLogger.h
//
//  Copyright 2009 Standard Orbit Software, LLC. All rights reserved.
//
//  $Rev$
//  $LastChangedBy$
//  $LastChangedDate$

#import <Foundation/Foundation.h>
#include <asl.h>

@class SOASLClient;

@interface SOLogger : NSObject {
		NSString *myFacility;
		uint32_t myClientOptions;
		NSMutableArray *myMirrorFileDescriptors;
}

@property (nonatomic, readonly) NSString *facility; /**< The identifier of the facility associated with this logger. */
@property (nonatomic, assign) uint32_t clientOptions; /**< A bitflag of ASL options that will be passed to the <tt>asl_open</tt> function. */
@property (nonatomic, readonly) NSMutableArray *mirrorFileDescriptors; /** Array of file descriptors (as NSNumber) to which messages will be echoed. */

#pragma mark -
#pragma mark Creation

/**
 Factory method for creating an open ASL logger.
 \param facility The identifier of the facility associated with this logger.  Pass nil and the messages are logged to @"com.apple.console".
 \param options A bitflag of ASL options that will be passed to the <tt>asl_open</tt> function.
 */
+ (SOLogger *) loggerForFacility:(NSString *)facility options:(uint32_t)options;

/**
 \param facility The facility for which this logger will be logging.  Recommended that you use a reverse-DNS style naming scheme to avoid name collisions. Pass nil and the messages are logged to @"com.apple.console".
 \param options Bitflag specifying ASL options.  Of most utility is the ASL_OPT_STDERR flag.
 The facility can be used to identify the application or a particular subsystem within the application.  Messages are tagged with this facility identifier when added to the ASL database.  The option <tt>ASL_OPT_STDERR</tt> configures the logger to echo logged messages to stderr; required to see log messages in the Xcode console.
 \sa <tt>man 3 asl</tt> for documentation on the function <tt>asl_open</tt> for the available option flags.
 */
- (id) initWithFacility:(NSString *)facility options:(uint32_t)options;

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
 \return The ASLClient instance in use on the current thread.  Every thread will have its own independent ASLClient instance.
 */
- (SOASLClient *) ASLClient;

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

