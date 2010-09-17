//
//  MultipleLoggerTests.m
//  SOLogger
//
//  Copyright 2010 Standard Orbit Software, LLC. All rights reserved.
//
// $Revision$
// $Author$
// $Date$

#pragma mark -

@interface MultipleLoggerTests : SenTestCase
{
    SOLogger *logger1, *logger2;
}
@end

@implementation MultipleLoggerTests

#pragma mark -
#pragma mark Tests

- (void) testMultipleLoggersInSingleThreadHaveDistinctASLClients
{
    // Test on main thread
    STAssertTrue ([NSThread isMainThread], @"precondition violated");
    
    logger1 = [[SOLogger alloc] initWithFacility:@"Test Logger 1" options:SOLoggerDefaultASLOptions];
    logger2 = [[SOLogger alloc] initWithFacility:@"Test Logger 2" options:SOLoggerDefaultASLOptions];

    SOASLConnection *connection1 = [logger1 ASLConnection];
    SOASLConnection *connection2 = [logger2 ASLConnection];
    
    // logger1 and logger2 should have distinct ASL connections on any given thread.
    STAssertNotNil (connection1, @"postconditiion violated");
    STAssertNotNil (connection2, @"postcondition violated");
    STAssertTrue (connection1 != connection2, @"postcondition violated");
}

#pragma mark -
#pragma mark Fixture

- (void) setUp;
{
    [super setUp];
}

- (void) tearDown;
{
    ReleaseAndNil (logger1);
    ReleaseAndNil (logger2);
    
    [super tearDown];
}
@end

