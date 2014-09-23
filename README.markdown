# SOLogger

SOLogger is a Cocoa API on top of the Apple System Logging (ASL) service.

SOLogger

  * provides methods for logging formatted messages at the various severity levels supported by ASL (e.g. Info, Warning, Debug)
  * supports mirroring logged messages to additional file, pipe, or socket descriptors.
  * supports logging from background threads using the recommended practice of an independent ASL client handle per thread.
  * compatible with both ARC-enabled and manually managed projects.

Peter Hosey has written an excellent series of blog articles on ASL. [You should read them, starting here](https://web.archive.org/web/20130512060103/http://boredzo.org/blog/archives/2008-01-20/why-asl, "Why ASL?"). These articles inspired me to put together SOLogger. Or look at the [man page](http://developer.apple.com/library/mac/#documentation/Darwin/Reference/ManPages/man3/asl.3.html).

## Features

### Severity Levels

SOLogger provides methods for logging formatted message at various severity levels.


    - (void) debug:(NSString *)format, ...;
	- (void) info:(NSString *)format, ...;
	- (void) notice:(NSString *)format, ...;
	- (void) warning:(NSString *)format, ...;
	- (void) error:(NSString *)format, ...;
	- (void) critical:(NSString *)format, ...;
	- (void) alert:(NSString *)format, ...;
	- (void) panic:(NSString *)format, ...;	


### Multiple Loggers

If you'd like to do separate logging from subsystems of your application, you can use multiple SOLoggers configured with their own unique facility.

	
	@interface MyNetworkOperation()
	@property (nonatomic, readonly) SOLogger *operationLog;
	@end

	@implementation MyNetworkOperation
	- (id) init
	{
		self = [super init];
		operationLog = [[SOLogger alloc] initWithFacility:@"com.mycompany.myapp.MyNetworkOperation" options:SOLoggerDefaultASLOptions];
	    [operationLog setSeverityFilterMask: ASL_FILTER_MASK_UPTO(ASL_LEVEL_DEBUG)];
		return self;
	}

	- (void) dealloc
	{
		[operationLog info:@"Deallocating operation: <%@ %p>", NSStringFromClass([self class]), self];
		[operationLog release]; operationLog = nil;
		[super dealloc];
	}

	- (void) cancel
	{
		[operationLog info:@"Canceling operation %@", self];
		[super cancel];
	}

	- (void) main
	{
		[operationLog info:@"Starting operation %@", self];
	
		....
	
		[operationLog info:@"Finishing operation %@", self];
	}

	@end

### Mirrored Logging To External Files

SOLogger provides `-addDescriptor:` to take advantage of ASL's mirrored logging capability. You can add POSIX file descriptors (including pipes or sockets) to the logger and each of which will get copies of all logged messages.

E.g. Log to a file on the user's desktop as well as the ASL system database:


	SOLogger *logger = ...;

	/* Create a path to the desktop log file. */

	NSString *desktopFilePath = [NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES) lastObject];
	desktopFilePath = [desktopFilePath stringByAddingPathComponent:@"MyGreatAppDesktop.log"];

	/* Open the external log file for appending, creating if necessary, resetting to zero if existing. */

	int fileDescriptor = open ([desktopFilePath fileSystemRepresentation], O_CREAT|O_APPEND|O_TRUNC, 644);

	if (fileDescriptor != -1) 
	{
		[logger addDescriptor:fileDescriptor];
	}

	/* Messages between panic and notice levels are logged to both the file and the ASL database. */

	[logger alert:@"It's the end of the world as we know it, and I feel fine."];

	/* Messages at info and debug levels are logged only to the external file. 
	   With default ASL/syslog configuration, ASL filters these messages out of the database. 
	*/
	
	[logger debug:@"Oh my Gods! That was close."];
	


### Multithreaded Logging

A single SOLogger instance can be used to log from any thread. Documentation recommends that every thread logging to ASL should use its own ASL connection. SOLogger implements this practice transparently.


	SOLogger *logger = ...;

	dispatch_async (dispatch_get_main_queue() ^{
		[logger info:@"Hello from the main thread: %p, %p", [NSThread currentThread], [logger aslclientRef]];
	});

	/* Log messages from background queue with the same logger. */

	dispatch_async (dispatch_get_global_queue(0,0) ^{
		[logger info:@"Buenos noches from a lonely background thread: %p, %p", [NSThread currentThread], [logger aslclientRef]];
	});	

	/* logger provides a dedicated aslclient to each thread that uses it */



### Severity Filtering

ASL filters messages to the system log by severity. By default, the ASL service filter prevents DEBUG and INFO level messages. You can change the severity filtering through the `-setSeverityFilterMask:` method.

E.g. To enable all message levels to be logged in ASL for debug builds:

	SOLogger *logger = ...;

	#if DEBUG
		[logger setSeverityFilterMask: ASL_FILTER_MASK_UPTO (ASL_LEVEL_DEBUG)];
		
		/* SOLogger will now send any logged message to stderr and the Xcode console log. */
	#end
	
	
#### Wrestling with syslog

See the wiki.

### Access to the ASL client handle

You can access the ASL client handle via the `-aslclientRef` method. Each SOLogger provides `aslclient` to each thread that access it.

E.g. to search the system log for all messages sent by "MyApp":

	SOLogger *logger = ...;
	
	/* Query the ASL database for all messages sent by "MyApp" */

	aslmsg query = asl_new (ASL_TYPE_QUERY);
	asl_set_query (query, ASL_KEY_SENDER, "MyApp", ASL_QUERY_OP_EQUAL);
	
	aslresponse response = asl_search ([logger aslclientRef], query);

	/* Iterate all messages in found matching the query */

	aslmsg msg = aslresponse_next(response);
	while (msg)
	{
	
		/* Iterate message keys, extract value, do something interesting... */
	
		for (int keyIndex = 0; ; keyIndex++)
		{		
			const char *key = asl_key (message, keyIndex);
			if (key == NULL) break;

			const char *value = asl_get (msg, key);
		
			...
		}
	
		msg = aslresponse_next (response);
	}
	aslresponse_free (response);
	asl_free(query);


### Caveats And Other Things to Know

#### Managing External Logging Descriptors

ASL and SOLogger leave to the caller to managing the life and death of external descriptors used for logging. ASL simply adds and removes descriptors to an internal list that will receive copies of all messages. The caller must have opened any descriptors for writing before adding them to the logger. The caller must also take care of closing any descriptors when appropriate.

#### ASL Filtering to External Log Descriptors

ASL applies no filtering on messages to external descriptors. The severity filtering mask is ignored. The logger sends all messages to the external descriptors.

ASL logs messages to external descriptors in a fixed format used by syslog with safe encoding style turned on. This format cannot be modified.

### Logging Macros

It can be convenient to define some macros around the SOLogger severity level methods to modify logging behavior. You might want to add your own prefix string to messages at particular severity levels. You might also want to replace SOLogger with another logging solution in your app sometime down the road. Defining your own logging macros can make this easier.

E.g. You want to prefix all DEBUG level log messages to include file and line location.

In your project's prefix header, you could do something like the following:

	extern SOLogger *gLogger;

	#define LOG_ERROR(format, ...) [gLogger error:format, ##__VA_ARGS__]
	#define LOG_WARNING(format, ...) [gLogger warning:format, ##__VA_ARGS__]
	#define LOG_INFO(format, ...) [gLogger info:format, ##__VA_ARGS__]
	#define LOG_NOTICE(format, ...) [gLogger notice:format, ##__VA_ARGS__]
	#define LOG_CRITICAL(format, ...) [gLogger critical:format, ##__VA_ARGS__]
	#define LOG_PANIC(format, ...) [gLogger panic:format, ##__VA_ARGS__]

	#define LOG_DEBUG(format, ...) \
	do { \
		NSMutableString *message = [NSMutableString stringWithFormat:@"%s:%d", __PRETTY_FUNCTION__, __LINE__]; \
		[message appendFormat:format, ##__VA_ARGS__]; \
		[gLogger debug:@"%@", message]; \
	} while(0);	


## Installation

For Mac OS X and iOS projects

  1. Add these files to your project:

		SOLogger.h
		SOLogger.m
	
  1. Include "SOLogger.h" in your project's prefix header file.
  1. Then initialize an SOLogger instance wherever you want to logging.

## Creating a Shared Application Logger

For a shared application-wide logger, add SOLogger as an application-wide global variable.

In your prefix header, add this declaration.
	
	extern SOLogger *gLogger;

In your application delegate's implementation file, instantiate the global in your `+initialize` method.

	@implementation AppDelegate
		
	+ (void) initialize
	{		
		NSString *appBundleID = [[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleIdentifierKey];
		gLogger = [[SOLogger alloc] initWithFacility:appBundleID options:SOLoggerDefaultOptions];
	}

	...

	@end
	
Whenever you want to log a message, invoke an SOLogger method on the gLogger global variable.

	- (void) someMethod
	{
		[gLogger debug:@"Entering %s", __FUNCTION__];
	
		...
	
		[gLogger info:@"I'm doing some stuff: %@", someStuff];
	}

## Compatibility

SOLogger v2 is compatible with iOS 4 or greater, and Mac OS X 10.6 or greater. 
Requires clang compiler. ARC-compatible.

## License

Use it, hack it, share it, but give me some love.

<a rel="license" href="http://creativecommons.org/licenses/by-sa/3.0/"><img alt="Creative Commons License" style="border-width:0" src="http://i.creativecommons.org/l/by-sa/3.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-sa/3.0/">Creative Commons Attribution-ShareAlike 3.0 Unported License</a>.
