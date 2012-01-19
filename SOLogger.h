/*
	SOLogger
	Copyright Standard Orbit Software, LLC. All rights reserved.
	License at the bottom of the file.
*/

#import <Foundation/Foundation.h>
#include <asl.h>

/** SOLogger implements a Cocoa API for logging messages using the Apple System Logging (ASL) service.

## Features

- methods for logging formatted messages at the various severity levels.
- logs messages simultaneously to additional file, pipe, and socket descriptors.
- can use a single logger from multiple threads.

## SOLogger and Threads

An SOLogger interacts with the ASL service through a separate connection per thread. The connection is opened using [asl_open()](x-man-page://asl "asl(3)") and configured with the logger's current severity filtering mask and list of additional logging descriptors.

When -severityFilterMask or -additionalDescriptors is changed on the logger, all associated ASL connections are also updated.


*/

extern uint32_t SOLoggerDefaultASLOptions;

@interface SOLogger : NSObject 
{
@private
    NSString *_facility;
    uint32_t _ASLOptions;
    int _severityFilterMask;
    NSMutableSet *_extraLoggingDescriptors;
    NSCache *_ASLClientCache;
}

#pragma mark -
#pragma mark Creation

/** @name Initialization */

/** Designated initializer

The facility can be used to identify the application or a particular subsystem within the application. Messages are tagged with this facility identifier when added to the ASL database. The value should be unique to your application to avoid name collisions with other loggers. Apple suggests using a reverse-DNS style naming scheme. 
 
The option ASL_OPT_STDERR configures the logger to echo all messages to stderr. 

@warning NOTE: this required to see log messages in the Xcode console.

Use the constant `SOLoggerDefaultASLOptions` for a reasonable combination of Apple System Logging options. Currently defined as: 

	ASL_OPT_NO_DELAY | ASL_OPT_STDERR | ASL_OPT_NO_REMOTE

See `asl_open()` in [asl(3)](x-man-page://asl "asl(3)")
 for documentation on the available option flags.

@param facility The facility for which this logger will be logging. Pass nil to use ASL defaults.
@param options Bitflag specifying ASL connection options. Of most utility is the ASL_OPT_STDERR flag.
 */
- (id) initWithFacility:(NSString *)facility options:(uint32_t)options;

#pragma mark -
#pragma mark ASL Primitives

/** @name ASL primitive */

/** asl client handle
 
Every thread has its own connection to the ASL service. This method returns the asl client handle appropriate for use with the calling thread. This value can be passed to other ASL API where an aslclient reference is required.

@return The aslclient reference for the calling thread.
 */
- (aslclient) aslclientRef;

#pragma mark -
#pragma mark Logging Convenience Methods

/** @name Logging messages */

/** Log a debug level message.

In the default syslog configuration, debug- and info-level messages are filtered out the ASL database. They will be logged to stderr and also to any additional file descriptors attached to the logger.

@param message The message text. Accepts all formatting specifiers available to NSString.
@param ... A comma-separated list of arguments to substitute into format.
 This is the least severe message level.
 */
- (void) debug:(NSString *)message, ...;

/** Log an info level message.

In the default syslog configuration, debug- and info-level messages are filtered out the ASL database. They will be logged to stderr and also to any additional file descriptors attached to the logger.

@param message The message text. Accepts all formatting specifiers available to NSString.
@param ... A comma-separated list of arguments to substitute into format.
 */
- (void) info:(NSString *)message, ...;

/** Log a notice level message.

 In the default syslog configuration, this is the lowest severity level to be logged in the ASL database.

 @param message The message.  Accepts all formatting specifiers available to NSString.
@param ... A comma-separated list of arguments to substitute into format.
 */
- (void) notice: (NSString *) message, ...;

/** Log a warning level message.

NSLog() messages are written to the system log at the ASL warning level.

 @param message The message.  Accepts all formatting specifiers available to NSString.
@param ... A comma-separated list of arguments to substitute into format.
 */
- (void) warning: (NSString *) message, ...;

/** Log an error level message.

 @param message The message.  Accepts all formatting specifiers available to NSString.
@param ... A comma-separated list of arguments to substitute into format.
 */
- (void) error: (NSString *) message, ...;

/** Log an alert level message.
 @param message The message.  Accepts all formatting specifiers available to NSString.
@param ... A comma-separated list of arguments to substitute into format.
 */
- (void) alert: (NSString *) message, ...;

/** Log a critical level message.
 @param message The message.  Accepts all formatting specifiers available to NSString.
@param ... A comma-separated list of arguments to substitute into format.
 */
- (void) critical: (NSString *) message, ...;

/** Log a panic or emergency level message.

This is the highest severity level message.

 @param message The message.  Accepts all formatting specifiers available to NSString.
@param ... A comma-separated list of arguments to substitute into format.
 */
- (void) panic: (NSString *) message, ...;

#pragma mark -
#pragma mark Logging Primitives

/** Logs a message with the given level.

ASL severity levels, from least to most severe: 

* ASL_LEVEL_DEBUG
* ASL_LEVEL_INFO
* ASL_LEVEL_NOTICE
* ASL_LEVEL_WARNING
* ASL_LEVEL_ERR
* ASL_LEVEL_CRIT
* ASL_LEVEL_ALERT
* ASL_LEVEL_EMERG

@param aslLevel The [asl(3)](x-man-page://asl "asl(3)")
 severity level of the message. 
@param format The text of the message. Accepts all formatting specifiers available to NSString.
@param arguments A list of arguments to substitute into format.
*/
- (void) logWithLevel:(int)aslLevel format:(NSString *)format arguments:(va_list)arguments;


#pragma mark -
#pragma mark Additional Logging Files

/** @name Logging to external files */

/** Add an external descriptor to the logger.

Adds the given descriptor to the logger's list of external descriptors that will receive copies of logged messages. The descriptor may point to a file, pipe, or socket.

ASL performs no severity level filtering on messages sent to external descriptors, including standard error. External descriptors will receive copies all messages logged.

@warning **Note:** External logging descriptors are not automatically opened when added. The caller is responsible for preparing any descriptor for writing before adding to the logger.

@param descriptor The POSIX file descriptor.
@see additionalDescriptors
*/
- (void) addDescriptor:(int)descriptor;

/** Remove an external descriptor from the logger.

Removes the given file descriptor from the logger's list of external descriptors receiving messages. 
 
When the logger is deallocated, all external descriptor are automatically removed. You only need to call this method when removing an external descriptor adhoc.

@warning **Note:** External logging descriptors are not automatically closed when removed. The caller is responsible for closing all external file descriptors.

@param descriptor The POSIX file descriptor.
@see additionalDescriptors
*/
- (void) removeDescriptor:(int)descriptor;

#pragma mark -
#pragma mark Properties

/** @name Properties */

/** The facility identifier.
 
Use facility to give the logger a name.
If you're using a dedicated logger for a subsystem, you might name the subsystem, using that name as the logger's facility value.

Recommended practice is to follow a "reverse DNS notation" style for facility names to avoid namespace collection in ASL among other loggers.
 */
@property (nonatomic, readonly) NSString *facility;

/** ASL connection options.

The options value used when opening a connection to the ASL service via asl_open(). The value is a bitwise OR of the following:

ASL_OPT_STDERR
: Also log messages to stderr (required for viewing messages in Xcode console).

ASL_OPT_NO_DELAY
: Connect immediately to the ASL service.

ASL_OPT_NO_REMOTE
: Ignore any remote severity level filtering settings, using only our own severityFilterMask value for filtering.
 */
@property (nonatomic, readonly) uint32_t options;

/** The logger's set of registered external logging descriptors.

Each descriptor is represented as an NSNumber.
@see addDescriptor:
@see removeDescriptor:
 */
@property (nonatomic, readonly) NSSet *additionalDescriptors; 


/** The logger's severity level filtering mask.

 A mask value defining a filter of messages to be sent to the ASL database by their severity level. Use the [asl(3)](x-man-page://asl "asl(3)")
 macro `ASL_FILTER_MASK_UPTO()` to obtain an appropriate filtering mask value.
 
**Examples**

To configure the logger to limit logging of messages to a range of the most severe up to the NOTICE level:
 
    [logger setSeverityFilterMask: ASL_FILTER_MASK_UPTO (ASL_LEVEL_NOTICE)]`
 
 To log messages with all severity levels from emergency to debug:
 
    [logger setSeverityFilterMask: ASL_FILTER_MASK_UPTO (ASL_LEVEL_DEBUG)];
 
 To filter messages to include only errors and more severe levels:
 
    [logger setSeverityFilterMask: ASL_FILTER_MASK_UPTO (ASL_LEVEL_ERROR)]; 
 */
@property (nonatomic, assign) int severityFilterMask;

@end

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

