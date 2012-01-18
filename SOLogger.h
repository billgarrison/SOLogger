/*
	SOLogger
	Copyright Standard Orbit Software, LLC. All rights reserved.
	License at the bottom of the file.
*/

/**
 SOLogger implements a Cocoa API for logging messages using the Apple System Logging (ASL) service.
 
 Features:
 - provides methods for logging formatted messages at the various severity levels supported by ASL.
 - supports adding additional file descriptors to receive logged messages.
 - supports logging from background threads using the recommended practice of an independent asl_client connection per thread.
 
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

@interface SOLogger : NSObject 
{
@private
    NSString *_facility;
    uint32_t _ASLOptions;
    int _severityFilterMask;
    NSMutableSet *_extraLoggingDescriptors;
    NSString *_ASLClientForLoggerKey;
    NSCache *_ASLClientCache;
}

#pragma mark -
#pragma mark Creation

/**
 \brief Designated initializer
 \param facility The facility for which this logger will be logging.  Recommended that you use a reverse-DNS style naming scheme to avoid name collisions. Pass nil and the messages are logged under @"com.apple.console".
 \param options Bitflag specifying ASL options. Of most utility is the ASL_OPT_STDERR flag.
 
 The facility can be used to identify the application or a particular subsystem within the application.  Messages are tagged with this facility identifier when added to the ASL database. 
 
 The option <tt>ASL_OPT_STDERR</tt> configures the logger to echo all messages to stderr. NOTE: this required to see log messages in the Xcode console.
 \sa <tt>man 3 asl</tt> for documentation on the function <tt>asl_open</tt> for the available option flags.
 */
- (id) initWithFacility:(NSString *)facility options:(uint32_t)options;

#pragma mark -
#pragma mark Additional Logging Files

/**
 \brief Add an external logging descriptor to the logger.
 \param descriptor The descriptor.
 
 Adding a file descriptor to the logger has the following effects in multi-threaded operation:
 1. The calling thread's ASLConnection is updated with the modified set of file descriptors.
 2. If the calling thread is not the main thread, the main thread's ASLConnection will also be updated with the additional description.
 3. Any new thread that uses the logger will inherit the modified set of external file descriptors.
 4. All existing threads using the logger will be unaware of the new description addition.
*/
- (void) addDescriptor:(int)descriptor;

/**
 \brief Remove an external logging descriptor from the logger.
 \param descriptor The descriptor.
 
 Remove the given file descriptor from the logger's list of external descriptors receiving messages. 
 
 When the logger is deallocated, all external descriptor are automatically removed. You only need to call this method when removing an external descriptor at runtime, before the logger is deallocated.
 */
- (void) removeDescriptor:(int)fd;

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


#pragma mark -
#pragma mark Per Thread ASL Client

/**
 \return The asl client reference for the calling thread.
 
Every thread has its own connection to the ASL service. This method returns the low level aslclient reference appropriate for use on the calling thread.
 */
- (aslclient) aslclientRef;


#pragma mark -
#pragma mark Properties

/**
 The facility identifier with which messages are tagged. 
If you're using a dedicated logger for a subsystem, give the subsystem a name and use that as the facility identifier. 
 */
@property (nonatomic, readonly) NSString *facility;

/**
 The options configured into the logger's ASL service connection.
 */
@property (nonatomic, readonly) uint32_t connectionOptions;

/**
 The logger's set of registered external logging descriptors (as NSNumber).
 */
@property (nonatomic, readonly) NSSet *additionalDescriptors; 


/**
 A mask value defining a filter of messages to be sent to the ASL database by their severity level. Use the asl macro ASL_FILTER_MASK_UPTO to obtain an appropriate severity filtering level.
 
 E.g. to configure the logger to limit logging of messages to a range of the most severe up to the NOTICE level,
 
    [logger setSeverityFilterMask: ASL_FILTER_MASK_UPTO (ASL_LEVEL_NOTICE)];
 
 To log messages with any severity levels (i.e. from PANIC to DEBUG),
 
    [logger setSeverityFilterMask: ASL_FILTER_MASK_UPTO (ASL_LEVEL_DEBUG)];
 
 To filter messages to include only errors (no warnings, notices, info, or debug):
 
    [logger setSeverityFilterMask: ASL_FILTER_MASK_UPTO (ASL_LEVEL_ERROR)]; 
 */
@property (nonatomic, assign) int severityFilterMask;

/**
 The thread dictionary key for accessing the logger's per-thread ASLClient instance.
 
 We generate the dictionary key using this template: "ASLClientForLogger<memory address of the SOLogger instance>". E.g. for a logger at address 0x3238493, the dictionary key for accessing the thread dictionary will be @"ASLClientForLogger0x3238493"
 
 The dictionary key is constructed to uniquely identify a particular logger instance; this allows the thread dictionary to hold ASLConnection instances for multiple loggers at any given time.

 For example:

 SOLogger *logger1 = ...; // Address at 0x3238493
 SOLogger *logger2 = ...; // Address at 0x3238600
 
 // A thread dictionary for any given thread
 {
    ASLClientForLogger0x3238493 = // connection instance for this thread for logger 1;
    ASLClientForLogger0x3238600 = // connection instance for this thread for logger 2;
    ...
 }
 
 */
@property (nonatomic, readonly) NSString *ASLClientForLoggerKey;

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

