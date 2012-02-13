//
//  UsefulMacros.h
//
//  Created on 12/23/09.
//  Copyright 2010 Standard Orbit Software, LLC. All rights reserved.
//	LICENSE <http://creativecommons.org/licenses/BSD/>
//

#if DEBUG
// For debug builds (DEBUG=1), define a method entry logging convenience
#define LOG_ENTRY	NSLog(@"Entering %s", __PRETTY_FUNCTION__);
#define LOG_EXIT	NSLog(@"Exiting %s", __PRETTY_FUNCTION__);

#else
// For release builds, no extra logging.
#define LOG_ENTRY
#define LOG_EXIT
#endif // DEBUG

// Release and nil the given ivar
#define ReleaseAndNil(ivar) [ivar release], ivar = nil;

// Macro for logging boolean values.
#define StringFromBool(x) ((x ? @"YES" : @"NO"))

// Macro for assertions assuring there's always something useful logged to the console.
#define ASSERT( condition ) NSAssert (condition, [NSString stringWithUTF8String:"assert (" #condition ") failed"])

// Macro for checking IB variable connections.
#define AssertIBConnection( ivar ) NSAssert (ivar != nil, [NSString stringWithUTF8String:"IBOutlet " #ivar " not connected in IB"]);

// Macro for testing nil or empty strings.
#define IsEmptyString( string ) ((string == nil) || [string isEqualToString:@""])
