# SOLogger

SOLogger is a Cocoa API on top of the Apple System Logging (ASL) service.

SOLogger

  * provides methods for logging formatted messages at the various severity levels supported by ASL (e.g. Info, Warning, Debug)
  * supports mirroring logged messages to additional file, pipe, or socket descriptors.
  * supports logging from background threads using the recommended practice of an independent ASL client handle per thread.

Peter Hosey has written an excellent series of blog articles on ASL. [You should read them, starting here](http://boredzo.org/blog/archives/2008-01-20/why-asl, "Why ASL?"). These articles inspired me to put together SOLogger. Or look at the [man page](http://developer.apple.com/library/mac/#documentation/Darwin/Reference/ManPages/man3/asl.3.html).

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


	extern SOLogger *gLogger;
	
	@interface MyNetworkOperation()
	@property (nonatomic, readonly) SOLogger *operationLog;
	@end

	@implementation MyNetworkOperation
	- (id) init
	{
		self = [super init];
		operationLog = [[SOLogger alloc] initWithFacility:@"com.mycompany.MyNetworkOperation" options:SOLoggerDefaultASLOptions];
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
	
		...
	
		[gLogger info:@"This message goes to the global logger."];
	
		....
	
		[operationLog info:@"Finishing operation %@", self];
	}

	@end

### Mirrored Logging To External Files

SOLogger provides `-addFileDescriptor:` to let you take advantage of ASL's mirrored logging capability. You can add POSIX file descriptors (including pipes or sockets) to the logger, each of which will get copies of all logged messages.

E.g. To log to a file on the user's desktop as well as the ASL system database:


	SOLogger *logger = ...;
	int logfileDescriptor = -1;

	/* Create a path to the desktop log file. */

	NSMutableArray *pathComponents = [[NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES) mutableCopy] autorelease];
	[pathComponents addObject:@"MyGreatAppDesktopLogFile.txt"];
	NSString *logFilePath = [NSString pathWithComponents:pathComponents]; 

	/* Open the external log file for appending, creating if necessary, resetting to zero if existing. */

	logfileDescriptor = open ([logFilePath fileSystemRepresentation], O_CREAT|O_APPEND|O_TRUNC, 644);

	if (logfileDescriptor != -1) 
	{
		[logger addFileDescriptor:logfileDescriptor];
	}

	/* Any subsequently logged messages go to both the log file and ASL */

	[logger panic:@"It's the end of the world as we know it, and I feel fine."];



### Multithreaded Logging

A single SOLogger instance can be used to log from multiple threads. ASL documentation recommends that a separate ASL connection be used from each thread sending messages to the service. SOLogger implements this practice transparently. Every thread on which a given SOLogger is sending a message gets its own connection to the ASL server. That connection is automatically closed when the thread exits.


	SOLogger *logger = ...;

	dispatch_async (dispatch_get_main_queue() ^{
		[logger info:@"Hello from the main thread: %@, %@", [NSThread currentThread], [logger ASLConnection]];
	});

	/* Log messages from 5 background threads */

	for (int i = 0; i < 5; i++) 
	{
		dispatch_async (dispatch_get_global_queue() ^{
			[logger info:@"Buenos noches from a lonely background thread: %@, %@", [NSThread currentThread], [logger ASLConnection]];
		});	
	}


Each thread uses its own ASLConnection instance to message the ASL server. ASLConnection is a wrapper around the ASL client handle, `aslclient`.

### Severity Filtering

ASL filters messages to the system log by severity. The default filter prevents DEBUG and INFO messages from being sent to the ASL database. You can change the severity filtering through the `-setSeverityFilterMask:` method.

E.g. To enable all messages to be sent to the system log for debug builds:

	SOLogger *logger = ...;

	#if DEBUG
		[logger setSeverityFilterMask: ASL_FILTER_MASK_UPTO (ASL_LEVEL_DEBUG)];
	#end

### Access to the ASL client handle

You can access the ASL client handle via the `[ASLConnection aslclientRef]` method. Each SOLogger has one ASLConnection instance per thread. The main thread's ASLConnection instance can always be obtained using the `mainThreadASLConnection` method, or just by invoking `-ASLConnection` from the main thread.

E.g. to search the system log for all messages sent by "MyApp":

	SOLogger *logger = ...;

	aslclient clientHandle = [[logger ASLConnection] aslclientRef];
	<strong></strong>
	/* Query the ASL database for all messages sent by "MyApp" */

	aslmsg query = asl_new (ASL_TYPE_QUERY);
	asl_set_query (query, ASL_KEY_SENDER, "MyApp", ASL_QUERY_OP_EQUAL);
	aslresponse response = asl_search (clientHandle, query);

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

ASL and SOLogger leave to the caller the responsibility for managing the life and death of external descriptors used for logging. The caller must have opened any descriptors before adding them to the logger. The caller must also take care of closing any descriptors after they are no longer used for logging. This generally means that you will need to maintain references to external descriptors somewhere, either as raw POSIX descriptors or as `NSFileHandle`s.

ASL filters messages to external descriptors differently than to the ASL database. Messages to ASL are filtered by severity level, with the default being that only messages of level NOTICE and above are sent to the ASL server; DEBUG and INFO level messages are filtered out. However, messages to external descriptors are not subject to filtering: the logger sends every message to the external descriptors.

ASL logs messages to external descriptors in a fixed format used by syslog with safe encoding style turned on. This format cannot be modified.

### Macros

It can be convenient to define some macros around the SOLogger severity level methods to modify logging behavior. E.g. to log messages that include file and line location.

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

For Mac OS X, SOLogger builds as a framework. 

  1. Manually build the _SOLogger_ target or add the SOLogger project to your own as a dependent Xcode project.
  1. Add the `SOLogger` framework to your project.
  1. Add `<SOLogger/SOLogger.h>` to your project's prefix header file.

For iOS,

  1. Add the files below to your project:
  1. Include "SOLogger.h" in your project's prefix header file.


	SOLogger.h
	SOLogger.m
	ASLConnection.h
	ASLConnection.m


Then initialize an SOLogger instance wherever you want to logging.

## Shared Application Logger

For a shared application-wide logger, add SOLogger as an application-wide global variable.

In your prefix header, add this declaration.
	
	extern SOLogger *gLogger;

In your application delegate's implementation file, instantiate the global in your `+initialize` method.

	@implementation AppDelegate

	+ (void) initialize
	{
		gLogger = [[SOLogger alloc] init];
	}

	...

	@end

Whenever you want to log a message, invoke an SOLogger method on the gLogger variable.

	- (void) someMethod
	{
		[gLogger debug:@"Entering %s", __FUNCTION__];
	
		...
	
		[gLogger info:@"I'm doing some stuff: %@", someStuff];
	}

## Compatibility

SOLogger is compatible with iOS 4 and Mac OS X 10.4 or greater.

## License

Use it, hack it, share it, but give me some love.

<a rel="license" href="http://creativecommons.org/licenses/by-sa/3.0/"><img alt="Creative Commons License" style="border-width:0" src="http://i.creativecommons.org/l/by-sa/3.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-sa/3.0/">Creative Commons Attribution-ShareAlike 3.0 Unported License</a>.