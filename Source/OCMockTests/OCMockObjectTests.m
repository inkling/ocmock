//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2004-2010 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <OCMock/OCMock.h>
#import "OCMockObjectTests.h"

// --------------------------------------------------------------------------------------
//	Helper classes and protocols for testing
// --------------------------------------------------------------------------------------

@protocol TestProtocol
- (int)primitiveValue;
@optional
- (id)objectValue;
@end

@protocol ProtocolWithTypeQualifierMethod
- (void)aSpecialMethod:(byref in void *)someArg;
@end


@interface TestClassThatCallsSelf : NSObject
- (NSString *)method1;
- (NSString *)method2;
- (NSString *)method3:(NSString *)foo;
@end

@implementation TestClassThatCallsSelf

- (NSString *)method1
{
	id retVal = [self method2];
	return retVal;
}

- (NSString *)method2
{
	return @"Foo";
}

- (NSString *)method3:(NSString *)foo {
    return [foo uppercaseString];
}

@end


@interface TestClassWithClassMethod : NSObject

+ (NSString *)method1;
+ (NSString *)method2;

@end

@implementation TestClassWithClassMethod

+ (NSString *)method1
{
    return @"Foo";
}

+ (NSString *)method2 {
    return [self method1];
}

@end


@interface TestObserver	: NSObject
{
	@public
	NSNotification *notification;
}

@end

@implementation TestObserver

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[notification release];
	[super dealloc];
}

- (void)receiveNotification:(NSNotification *)aNotification
{
	notification = [aNotification retain];
}

@end

static NSString *TestNotification = @"TestNotification";


@interface TestProxyClass : NSProxy

- (instancetype)initWithObject:(id)object;
- (NSString *)proxyMethod;

@end

@implementation TestProxyClass
{
    id _object;
}

- (instancetype)initWithObject:(id)object
{
    // no [super init], as we don't descend from NSObject
    _object = [object retain];
    return self;
}

- (void)dealloc {
    [_object release];
    [super dealloc];
}

- (NSString *)proxyMethod
{
    return @"foo";
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
    return [_object respondsToSelector:aSelector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel
{
    return [_object methodSignatureForSelector:sel];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    [invocation invokeWithTarget:_object];
}

@end

// --------------------------------------------------------------------------------------
//  setup
// --------------------------------------------------------------------------------------


@implementation OCMockObjectTests

- (void)setUp
{
	mock = [OCMockObject mockForClass:[NSString class]];
}


// --------------------------------------------------------------------------------------
//	accepting stubbed methods / rejecting methods not stubbed
// --------------------------------------------------------------------------------------

- (void)testAcceptsStubbedMethod
{
	[[mock stub] lowercaseString];
	[mock lowercaseString];
}

- (void)testRaisesExceptionWhenUnknownMethodIsCalled
{
	[[mock stub] lowercaseString];
	STAssertThrows([mock uppercaseString], @"Should have raised an exception.");
}


- (void)testAcceptsStubbedMethodWithSpecificArgument
{
	[[mock stub] hasSuffix:@"foo"];
	[mock hasSuffix:@"foo"];
}


- (void)testAcceptsStubbedMethodWithConstraint
{
	[[mock stub] hasSuffix:[OCMArg any]];
	[mock hasSuffix:@"foo"];
	[mock hasSuffix:@"bar"];
}

#if NS_BLOCKS_AVAILABLE

- (void)testAcceptsStubbedMethodWithBlockArgument
{
	mock = [OCMockObject mockForClass:[NSArray class]];
	[[mock stub] indexesOfObjectsPassingTest:[OCMArg any]];
	[mock indexesOfObjectsPassingTest:^(id obj, NSUInteger idx, BOOL *stop) { return YES; }];
}


- (void)testAcceptsStubbedMethodWithBlockConstraint
{
	[[mock stub] hasSuffix:[OCMArg checkWithBlock:^(id value) { return [value isEqualToString:@"foo"]; }]];

	STAssertNoThrow([mock hasSuffix:@"foo"], @"Should not have thrown a exception");   
	STAssertThrows([mock hasSuffix:@"bar"], @"Should have thrown a exception");   
}
	
#endif

- (void)testAcceptsStubbedMethodWithNilArgument
{
	[[mock stub] hasSuffix:nil];
	
	[mock hasSuffix:nil];
}

- (void)testRaisesExceptionWhenMethodWithWrongArgumentIsCalled
{
	[[mock stub] hasSuffix:@"foo"];
	STAssertThrows([mock hasSuffix:@"xyz"], @"Should have raised an exception.");
}


- (void)testAcceptsStubbedMethodWithScalarArgument
{
	[[mock stub] stringByPaddingToLength:20 withString:@"foo" startingAtIndex:5];
	[mock stringByPaddingToLength:20 withString:@"foo" startingAtIndex:5];
}


- (void)testRaisesExceptionWhenMethodWithOneWrongScalarArgumentIsCalled
{
	[[mock stub] stringByPaddingToLength:20 withString:@"foo" startingAtIndex:5];
	STAssertThrows([mock stringByPaddingToLength:20 withString:@"foo" startingAtIndex:3], @"Should have raised an exception.");	
}

- (void)testAcceptsStubbedMethodWithPointerArgument
{
	NSError *error;
	BOOL yes = YES;
	[[[mock stub] andReturnValue:OCMOCK_VALUE(yes)] writeToFile:OCMOCK_ANY atomically:YES encoding:NSMacOSRomanStringEncoding error:&error];
	
	STAssertTrue([mock writeToFile:@"foo" atomically:YES encoding:NSMacOSRomanStringEncoding error:&error], nil);
}

- (void)testAcceptsStubbedMethodWithAnyPointerArgument
{
	BOOL yes = YES;
	NSError *error;
	[[[mock stub] andReturnValue:OCMOCK_VALUE(yes)] writeToFile:OCMOCK_ANY atomically:YES encoding:NSMacOSRomanStringEncoding error:[OCMArg anyPointer]];
	
	STAssertTrue([mock writeToFile:@"foo" atomically:YES encoding:NSMacOSRomanStringEncoding error:&error], nil);
}

- (void)testRaisesExceptionWhenMethodWithWrongPointerArgumentIsCalled
{
	NSString *string;
	NSString *anotherString;
	NSArray *array;
	
	[[mock stub] completePathIntoString:&string caseSensitive:YES matchesIntoArray:&array filterTypes:OCMOCK_ANY];
	
	STAssertThrows([mock completePathIntoString:&anotherString caseSensitive:YES matchesIntoArray:&array filterTypes:OCMOCK_ANY], nil);
}

- (void)testAcceptsStubbedMethodWithVoidPointerArgument
{
	mock = [OCMockObject mockForClass:[NSMutableData class]];
	[[mock stub] appendBytes:NULL length:0];
	[mock appendBytes:NULL length:0];
}


- (void)testRaisesExceptionWhenMethodWithWrongVoidPointerArgumentIsCalled
{
	mock = [OCMockObject mockForClass:[NSMutableData class]];
	[[mock stub] appendBytes:"foo" length:3];
	STAssertThrows([mock appendBytes:"bar" length:3], @"Should have raised an exception.");
}


- (void)testAcceptsStubbedMethodWithPointerPointerArgument
{
	NSError *error = nil;
	[[mock stub] initWithContentsOfFile:@"foo.txt" encoding:NSASCIIStringEncoding error:&error];	
	[mock initWithContentsOfFile:@"foo.txt" encoding:NSASCIIStringEncoding error:&error];
}


- (void)testRaisesExceptionWhenMethodWithWrongPointerPointerArgumentIsCalled
{
	NSError *error = nil, *error2;
	[[mock stub] initWithContentsOfFile:@"foo.txt" encoding:NSASCIIStringEncoding error:&error];	
	STAssertThrows([mock initWithContentsOfFile:@"foo.txt" encoding:NSASCIIStringEncoding error:&error2], @"Should have raised.");
}


- (void)testAcceptsStubbedMethodWithStructArgument
{
    NSRange range = NSMakeRange(0,20);
	[[mock stub] substringWithRange:range];
	[mock substringWithRange:range];
}


- (void)testRaisesExceptionWhenMethodWithWrongStructArgumentIsCalled
{
    NSRange range = NSMakeRange(0,20);
    NSRange otherRange = NSMakeRange(0,10);
	[[mock stub] substringWithRange:range];
	STAssertThrows([mock substringWithRange:otherRange], @"Should have raised an exception.");	
}


- (void)testCanPassMocksAsArguments
{
	id mockArg = [OCMockObject mockForClass:[NSString class]];
	[[mock stub] stringByAppendingString:[OCMArg any]];
	[mock stringByAppendingString:mockArg];
}

- (void)testCanStubWithMockArguments
{
	id mockArg = [OCMockObject mockForClass:[NSString class]];
	[[mock stub] stringByAppendingString:mockArg];
	[mock stringByAppendingString:mockArg];
}

- (void)testRaisesExceptionWhenStubbedMockArgIsNotUsed
{
	id mockArg = [OCMockObject mockForClass:[NSString class]];
	[[mock stub] stringByAppendingString:mockArg];
	STAssertThrows([mock stringByAppendingString:@"foo"], @"Should have raised an exception.");
}

- (void)testRaisesExceptionWhenDifferentMockArgumentIsPassed
{
	id expectedArg = [OCMockObject mockForClass:[NSString class]];
	id otherArg = [OCMockObject mockForClass:[NSString class]];
	[[mock stub] stringByAppendingString:otherArg];
	STAssertThrows([mock stringByAppendingString:expectedArg], @"Should have raised an exception.");	
}


// --------------------------------------------------------------------------------------
//	returning values from stubbed methods
// --------------------------------------------------------------------------------------

- (void)testReturnsStubbedReturnValue
{
	id returnValue;  

	[[[mock stub] andReturn:@"megamock"] lowercaseString];
	returnValue = [mock lowercaseString];
	
	STAssertEqualObjects(@"megamock", returnValue, @"Should have returned stubbed value.");
	
}

- (void)testReturnsStubbedIntReturnValue
{
    int expectedValue = 42;
	[[[mock stub] andReturnValue:OCMOCK_VALUE(expectedValue)] intValue];
	int returnValue = [mock intValue];
    
	STAssertEquals(expectedValue, returnValue, @"Should have returned stubbed value.");
}

- (void)testRaisesWhenBoxedValueTypesDoNotMatch
{
    double expectedValue = 42;
	[[[mock stub] andReturnValue:OCMOCK_VALUE(expectedValue)] intValue];
    
	STAssertThrows([mock intValue], @"Should have raised an exception.");
}

- (void)testReturnsStubbedNilReturnValue
{
	[[[mock stub] andReturn:nil] uppercaseString];
	
	id returnValue = [mock uppercaseString];
	
	STAssertNil(returnValue, @"Should have returned stubbed value, which is nil.");
}


// --------------------------------------------------------------------------------------
//	raising exceptions, posting notifications, etc.
// --------------------------------------------------------------------------------------

- (void)testRaisesExceptionWhenAskedTo
{
	NSException *exception = [NSException exceptionWithName:@"TestException" reason:@"test" userInfo:nil];
	[[[mock expect] andThrow:exception] lowercaseString];
	
	STAssertThrows([mock lowercaseString], @"Should have raised an exception.");
}

- (void)testPostsNotificationWhenAskedTo
{
	TestObserver *observer = [[[TestObserver alloc] init] autorelease];
	[[NSNotificationCenter defaultCenter] addObserver:observer selector:@selector(receiveNotification:) name:TestNotification object:nil];
	
	NSNotification *notification = [NSNotification notificationWithName:TestNotification object:self];
	[[[mock stub] andPost:notification] lowercaseString];
	
	[mock lowercaseString];
	
	STAssertNotNil(observer->notification, @"Should have sent a notification.");
	STAssertEqualObjects(TestNotification, [observer->notification name], @"Name should match posted one.");
	STAssertEqualObjects(self, [observer->notification object], @"Object should match posted one.");
}

- (void)testPostsNotificationInAddtionToReturningValue
{
	TestObserver *observer = [[[TestObserver alloc] init] autorelease];
	[[NSNotificationCenter defaultCenter] addObserver:observer selector:@selector(receiveNotification:) name:TestNotification object:nil];
	
	NSNotification *notification = [NSNotification notificationWithName:TestNotification object:self];
	[[[[mock stub] andReturn:@"foo"] andPost:notification] lowercaseString];
	
	STAssertEqualObjects(@"foo", [mock lowercaseString], @"Should have returned stubbed value.");
	STAssertNotNil(observer->notification, @"Should have sent a notification.");
}


- (NSString *)valueForString:(NSString *)aString andMask:(NSStringCompareOptions)mask
{
	return [NSString stringWithFormat:@"[%@, %d]", aString, mask];
}

- (void)testCallsAlternativeMethodAndPassesOriginalArgumentsAndReturnsValue
{
	[[[mock stub] andCall:@selector(valueForString:andMask:) onObject:self] commonPrefixWithString:@"FOO" options:NSCaseInsensitiveSearch];
	
	NSString *returnValue = [mock commonPrefixWithString:@"FOO" options:NSCaseInsensitiveSearch];
	
	STAssertEqualObjects(@"[FOO, 1]", returnValue, @"Should have passed and returned invocation.");
}

#if NS_BLOCKS_AVAILABLE

- (void)testCallsBlockWhichCanSetUpReturnValue
{
	void (^theBlock)(NSInvocation *) = ^(NSInvocation *invocation) 
		{
			NSString *value;
			[invocation getArgument:&value atIndex:2];
			value = [NSString stringWithFormat:@"MOCK %@", value];
			[invocation setReturnValue:&value];
		};
		
	[[[mock stub] andDo:theBlock] stringByAppendingString:[OCMArg any]];
		
	STAssertEqualObjects(@"MOCK foo", [mock stringByAppendingString:@"foo"], @"Should have called block.");
	STAssertEqualObjects(@"MOCK bar", [mock stringByAppendingString:@"bar"], @"Should have called block.");
}

#endif

- (void)testThrowsWhenTryingToUseForwardToRealObjectOnNonPartialMock
{
	STAssertThrows([[[mock expect] andForwardToRealObject] method2], @"Should have raised and exception.");
}

- (void)testForwardsToRealObjectWhenSetUpAndCalledOnMock
{
	TestClassThatCallsSelf *realObject = [[[TestClassThatCallsSelf alloc] init] autorelease];
	mock = [OCMockObject partialMockForObject:realObject];

	[[[mock expect] andForwardToRealObject] method2];
	STAssertEquals(@"Foo", [mock method2], @"Should have called method on real object.");

	[mock verify];
}

- (void)testForwardsToRealObjectWhenSetUpAndCalledOnRealObject
{
	TestClassThatCallsSelf *realObject = [[[TestClassThatCallsSelf alloc] init] autorelease];
	mock = [OCMockObject partialMockForObject:realObject];
	
	[[[mock expect] andForwardToRealObject] method2];
	STAssertEquals(@"Foo", [realObject method2], @"Should have called method on real object.");
	
	[mock verify];
}

- (void)testForwardsToRealObjectWhenSetUpAndCalledOnClassObjectMock {
    mock = [OCMockObject partialMockForClassObject:[TestClassWithClassMethod class]];
    
	[[[mock expect] andForwardToRealObject] method1];
	STAssertEqualObjects(@"Foo", [mock method1], @"Should have called method on real object.");
    [mock verify];
}

- (void)testForwardsToRealObjectWhenSetUpAndCalledOnClass {
    mock = [OCMockObject partialMockForClassObject:[TestClassWithClassMethod class]];
    
	[[[mock expect] andForwardToRealObject] method1];
	STAssertEqualObjects(@"Foo", [TestClassWithClassMethod method1], @"Should have called method on class object.");
    [mock verify];
}

// Because partial class mocks have no single "real object" to which to forward
// unrecorded and "andForwardToRealObject"-handled invocations,
// they may not be used directly, as instances of the mocked class
// (in contrast to regular class mocks, and the other partial mock object types).
- (void)testThrowsWhenTryingToSetUpAndCallOnPartialClassMock {
	mock = [OCMockObject partialMockForClass:[TestClassThatCallsSelf class]];
	[[[mock stub] andReturn:@"hi"] method1];
	STAssertThrows([mock method1], @"Should have raised an exception.");
}

// Note that in this test, vs. the previous one, the mock is *indirectly* handling the invocation.
- (void)testForwardsToRealObjectWhenSetUpAndCalledOnInstance {
    TestClassThatCallsSelf *realObject = [[[TestClassThatCallsSelf alloc] init] autorelease];
	mock = [OCMockObject partialMockForClass:[TestClassThatCallsSelf class]];

	[[[mock expect] andForwardToRealObject] method2];
	STAssertEquals(@"Foo", [realObject method2], @"Should have called method on real object.");

	[mock verify];
}

// --------------------------------------------------------------------------------------
//	returning values in pass-by-reference arguments
// --------------------------------------------------------------------------------------

- (void)testReturnsValuesInPassByReferenceArguments
{
	NSString *expectedName = [NSString stringWithString:@"Test"];
	NSArray *expectedArray = [NSArray array];
	
	[[mock expect] completePathIntoString:[OCMArg setTo:expectedName] caseSensitive:YES 
						 matchesIntoArray:[OCMArg setTo:expectedArray] filterTypes:OCMOCK_ANY];
	
	NSString *actualName = nil;
	NSArray *actualArray = nil;
	[mock completePathIntoString:&actualName caseSensitive:YES matchesIntoArray:&actualArray filterTypes:nil];

	STAssertNoThrow([mock verify], @"An unexpected exception was thrown");
	STAssertEqualObjects(expectedName, actualName, @"The two string objects should be equal");
	STAssertEqualObjects(expectedArray, actualArray, @"The two array objects should be equal");
}


// --------------------------------------------------------------------------------------
//	accepting expected methods
// --------------------------------------------------------------------------------------

- (void)testAcceptsExpectedMethod
{
	[[mock expect] lowercaseString];
	[mock lowercaseString];
}


- (void)testAcceptsExpectedMethodAndReturnsValue
{
	id returnValue;

	[[[mock expect] andReturn:@"Objective-C"] lowercaseString];
	returnValue = [mock lowercaseString];

	STAssertEqualObjects(@"Objective-C", returnValue, @"Should have returned stubbed value.");
}


- (void)testAcceptsExpectedMethodsInRecordedSequence
{
	[[mock expect] lowercaseString];
	[[mock expect] uppercaseString];
	
	[mock lowercaseString];
	[mock uppercaseString];
}


- (void)testAcceptsExpectedMethodsInDifferentSequence
{
	[[mock expect] lowercaseString];
	[[mock expect] uppercaseString];
	
	[mock uppercaseString];
	[mock lowercaseString];
}


// --------------------------------------------------------------------------------------
//	verifying expected methods
// --------------------------------------------------------------------------------------

- (void)testAcceptsAndVerifiesExpectedMethods
{
	[[mock expect] lowercaseString];
	[[mock expect] uppercaseString];
	
	[mock lowercaseString];
	[mock uppercaseString];
	
	[mock verify];
}


- (void)testRaisesExceptionOnVerifyWhenNotAllExpectedMethodsWereCalled
{
	[[mock expect] lowercaseString];
	[[mock expect] uppercaseString];
	
	[mock lowercaseString];
	
	STAssertThrows([mock verify], @"Should have raised an exception.");
}

- (void)testAcceptsAndVerifiesTwoExpectedInvocationsOfSameMethod
{
	[[mock expect] lowercaseString];
	[[mock expect] lowercaseString];
	
	[mock lowercaseString];
	[mock lowercaseString];
	
	[mock verify];
}


- (void)testAcceptsAndVerifiesTwoExpectedInvocationsOfSameMethodAndReturnsCorrespondingValues
{
	[[[mock expect] andReturn:@"foo"] lowercaseString];
	[[[mock expect] andReturn:@"bar"] lowercaseString];
	
	STAssertEqualObjects(@"foo", [mock lowercaseString], @"Should have returned first stubbed value");
	STAssertEqualObjects(@"bar", [mock lowercaseString], @"Should have returned seconds stubbed value");
	
	[mock verify];
}

- (void)testReturnsStubbedValuesIndependentOfExpectations
{
	[[mock stub] hasSuffix:@"foo"];
	[[mock expect] hasSuffix:@"bar"];
	
	[mock hasSuffix:@"foo"];
	[mock hasSuffix:@"bar"];
	[mock hasSuffix:@"foo"]; // Since it's a stub, shouldn't matter how many times we call this
	
	[mock verify];
}

-(void)testAcceptsAndVerifiesMethodsWithSelectorArgument
{
	[[mock expect] performSelector:@selector(lowercaseString)];
	[mock performSelector:@selector(lowercaseString)];
	[mock verify];
}


// --------------------------------------------------------------------------------------
//	ordered expectations
// --------------------------------------------------------------------------------------

- (void)testAcceptsExpectedMethodsInRecordedSequenceWhenOrderMatters
{
	[mock setExpectationOrderMatters:YES];
	
	[[mock expect] lowercaseString];
	[[mock expect] uppercaseString];
	
	STAssertNoThrow([mock lowercaseString], @"Should have accepted expected method in sequence.");
	STAssertNoThrow([mock uppercaseString], @"Should have accepted expected method in sequence.");
}

- (void)testRaisesExceptionWhenSequenceIsWrongAndOrderMatters
{
	[mock setExpectationOrderMatters:YES];
	
	[[mock expect] lowercaseString];
	[[mock expect] uppercaseString];
	
	STAssertThrows([mock uppercaseString], @"Should have complained about wrong sequence.");
}

- (void)testAcceptsExpectedMethodsInRecordedSequenceOnMultipleObjects
{
    id mockOne = [OCMockObject mockForClass:[NSString class]];
    id mockTwo = [OCMockObject mockForClass:[NSString class]];

    OCMExpectationSequencer *sequencer = [OCMExpectationSequencer sequencerWithMocks:@[ mockOne, mockTwo ]];

	[[mockOne expect] lowercaseString];
	[[mockTwo expect] uppercaseString];

    STAssertNoThrow([mockOne lowercaseString], @"Should have accepted expected method in sequence.");
    STAssertNoThrow([mockTwo uppercaseString], @"Should have accepted expected method in sequence.");

    STAssertNoThrow([sequencer verify], @"Should have verified sequence.");

    // Note that it's still possible to verify individual mocks' expectations.
    STAssertNoThrow([mockOne verify], @"Should have verified expectations.");
}

- (void)testRaisesExceptionWhenSequenceOnMultipleObjectsIsWrong
{
    id mockOne = [OCMockObject mockForClass:[NSString class]];
    id mockTwo = [OCMockObject mockForClass:[NSString class]];

    OCMExpectationSequencer *sequencer = [OCMExpectationSequencer sequencerWithMocks:@[ mockOne, mockTwo ]];
    #pragma unused (sequencer)

	[[mockOne expect] lowercaseString];
	[[mockTwo expect] uppercaseString];

	STAssertThrows([mock uppercaseString], @"Should have complained about wrong sequence.");
}

- (void)testRaisesAnExceptionWhenTryingToSimultaneouslySequenceMock
{
    id mockOne = [OCMockObject mockForClass:[NSString class]];
    id mockTwo = [OCMockObject mockForClass:[NSString class]];
    id mockThree = [OCMockObject mockForClass:[NSString class]];

    OCMExpectationSequencer *sequencer = [OCMExpectationSequencer sequencerWithMocks:@[ mockOne, mockTwo ]];
    #pragma unused (sequencer)

    STAssertThrows([OCMExpectationSequencer sequencerWithMocks:(@[ mockTwo, mockThree ])],
                   @"Should have raised an exception because mockTwo was going to be sequenced by two different sequencers.");
}

// --------------------------------------------------------------------------------------
//	explicitly rejecting methods (mostly for nice mocks, see below)
// --------------------------------------------------------------------------------------

- (void)testThrowsWhenRejectedMethodIsCalledOnNiceMock
{
	mock = [OCMockObject niceMockForClass:[NSString class]];
	
	[[mock reject] uppercaseString];
	STAssertThrows([mock uppercaseString], @"Should have complained about rejected method being called.");
}

- (void)testThrowsWhenRejectedMethodIsCalledOnSequencedMocks
{
    id mockOne = [OCMockObject mockForClass:[NSString class]];
    id mockTwo = [OCMockObject mockForClass:[NSString class]];
    OCMExpectationSequencer *sequencer = [OCMExpectationSequencer sequencerWithMocks:@[ mockOne, mockTwo ]];

	[[mockOne reject] uppercaseString];
	STAssertThrows([mockOne uppercaseString], @"Should have complained about rejected method being called.");

    STAssertThrows([mockOne verify], @"Should have reraised the exception.");
    STAssertThrows([sequencer verify], @"Should have reraised the exception.");
}

// --------------------------------------------------------------------------------------
//	protocol mocks
// --------------------------------------------------------------------------------------

- (void)testCanMockFormalProtocol
{
	mock = [OCMockObject mockForProtocol:@protocol(NSLocking)];
	[[mock expect] lock];
	
	[mock lock];
	
	[mock verify];
}

- (void)testSetsCorrectNameForProtocolMockObjects
{
	mock = [OCMockObject mockForProtocol:@protocol(NSLocking)];
	STAssertEqualObjects(@"OCMockObject[NSLocking]", [mock description], @"Should have returned correct description.");
}

- (void)testRaisesWhenUnknownMethodIsCalledOnProtocol
{
	mock = [OCMockObject mockForProtocol:@protocol(NSLocking)];
	STAssertThrows([mock lowercaseString], @"Should have raised an exception.");
}

- (void)testConformsToMockedProtocol
{
	mock = [OCMockObject mockForProtocol:@protocol(NSLocking)];
	STAssertTrue([mock conformsToProtocol:@protocol(NSLocking)], nil);
}

- (void)testRespondsToValidProtocolRequiredSelector
{
	mock = [OCMockObject mockForProtocol:@protocol(TestProtocol)];	
    STAssertTrue([mock respondsToSelector:@selector(primitiveValue)], nil);
}

- (void)testRespondsToValidProtocolOptionalSelector
{
	mock = [OCMockObject mockForProtocol:@protocol(TestProtocol)];	
    STAssertTrue([mock respondsToSelector:@selector(objectValue)], nil);
}

- (void)testDoesNotRespondToInvalidProtocolSelector
{
	mock = [OCMockObject mockForProtocol:@protocol(TestProtocol)];	
    STAssertFalse([mock respondsToSelector:@selector(fooBar)], nil);
}


// --------------------------------------------------------------------------------------
//	nice mocks don't complain about unknown methods
// --------------------------------------------------------------------------------------

- (void)testReturnsDefaultValueWhenUnknownMethodIsCalledOnNiceClassMock
{
	mock = [OCMockObject niceMockForClass:[NSString class]];
	STAssertNil([mock lowercaseString], @"Should return nil on unexpected method call (for nice mock).");	
	[mock verify];
}

- (void)testRaisesAnExceptionWhenAnExpectedMethodIsNotCalledOnNiceClassMock
{
	mock = [OCMockObject niceMockForClass:[NSString class]];	
	[[[mock expect] andReturn:@"HELLO!"] uppercaseString];
	STAssertThrows([mock verify], @"Should have raised an exception because method was not called.");
}

- (void)testReturnDefaultValueWhenUnknownMethodIsCalledOnProtocolMock
{
	mock = [OCMockObject niceMockForProtocol:@protocol(TestProtocol)];
	STAssertTrue(0 == [mock primitiveValue], @"Should return 0 on unexpected method call (for nice mock).");
	[mock verify];
}

- (void)testRaisesAnExceptionWenAnExpectedMethodIsNotCalledOnNiceProtocolMock
{
	mock = [OCMockObject niceMockForProtocol:@protocol(TestProtocol)];	
	[[mock expect] primitiveValue];
	STAssertThrows([mock verify], @"Should have raised an exception because method was not called.");
}


// --------------------------------------------------------------------------------------
//	partial mocks forward unknown methods to a real instance or class
// --------------------------------------------------------------------------------------

- (void)testStubsMethodsOnPartialMock
{
	TestClassThatCallsSelf *foo = [[[TestClassThatCallsSelf alloc] init] autorelease];
	mock = [OCMockObject partialMockForObject:foo];
	[[[mock stub] andReturn:@"hi"] method1];
	STAssertEqualObjects(@"hi", [mock method1], @"Should have returned stubbed value");
}

- (void)testStubsMethodOnPartialClassObjectMock
{
    mock = [OCMockObject partialMockForClassObject:[TestClassWithClassMethod class]];
    
	[[[mock stub] andReturn:@"TestFoo"] method1];
	STAssertEqualObjects(@"TestFoo", [TestClassWithClassMethod method1], @"Should have stubbed method.");
}

- (void)testStubsMethodOnPartialClassMock
{
	TestClassThatCallsSelf *foo = [[[TestClassThatCallsSelf alloc] init] autorelease];
	mock = [OCMockObject partialMockForClass:[TestClassThatCallsSelf class]];
	[[[mock stub] andReturn:@"hi"] method1];
	STAssertEqualObjects(@"hi", [foo method1], @"Should have returned stubbed value");
}

- (void)testRaisesAnExceptionWhenTryingToSimultaneouslyMockClassObject
{
    mock = [OCMockObject partialMockForClassObject:[TestClassWithClassMethod class]];
    STAssertThrows([OCMockObject partialMockForClassObject:[TestClassWithClassMethod class]], @"Should have raised an exception.");
}

- (void)testRaisesAnExceptionWhenTryingToSimultaneouslyMockClass
{
    mock = [OCMockObject partialMockForClass:[TestClassThatCallsSelf class]];
    STAssertThrows([OCMockObject partialMockForClass:[TestClassThatCallsSelf class]], @"Should have raised an exception.");
}

//- (void)testStubsMethodsOnPartialMockForTollFreeBridgedClasses
//{
//	mock = [OCMockObject partialMockForObject:[NSString stringWithString:@"hello"]];
//	[[[mock stub] andReturn:@"hi"] uppercaseString];
//	STAssertEqualObjects(@"hi", [mock uppercaseString], @"Should have returned stubbed value");
//}

- (void)testForwardsUnstubbedMethodsCallsToRealObjectOnPartialMock
{
	TestClassThatCallsSelf *foo = [[[TestClassThatCallsSelf alloc] init] autorelease];
	mock = [OCMockObject partialMockForObject:foo];
	STAssertEqualObjects(@"Foo", [mock method2], @"Should have returned value from real object.");
}

- (void)testForwardsUnstubbedMethodsCallsToRealObjectOnPartialClassObjectMock
{
    mock = [OCMockObject partialMockForClassObject:[TestClassWithClassMethod class]];
    
	STAssertEqualObjects(@"Foo", [TestClassWithClassMethod method1], @"Should have returned value from real object.");
}

//- (void)testForwardsUnstubbedMethodsCallsToRealObjectOnPartialMockForTollFreeBridgedClasses
//{
//	mock = [OCMockObject partialMockForObject:[NSString stringWithString:@"hello2"]];
//	STAssertEqualObjects(@"HELLO2", [mock uppercaseString], @"Should have returned value from real object.");
//}

- (void)testStubsMethodOnRealObjectReference
{
	TestClassThatCallsSelf *realObject = [[[TestClassThatCallsSelf alloc] init] autorelease];
	mock = [OCMockObject partialMockForObject:realObject];
	[[[mock stub] andReturn:@"TestFoo"] method1];
	STAssertEqualObjects(@"TestFoo", [realObject method1], @"Should have stubbed method.");
}

#if TARGET_OS_IPHONE
- (void)testStubsMethodOnRealObjectReferenceReturningStruct
{
    UIScreen *mainScreen = [UIScreen mainScreen];
    mock = [OCMockObject partialMockForObject:mainScreen];
    CGRect desiredBounds = (CGRect){0.0f,0.0f,320.0f,480.0f};
    [(UIScreen *)[[mock stub] andReturnValue:OCMOCK_VALUE(desiredBounds)] bounds];
    
    CGRect expectedBounds = desiredBounds;
    CGRect bounds = [mainScreen bounds];
    STAssertTrue(CGRectEqualToRect(bounds, expectedBounds),@"Should have returned stubbed value.");
    
    [mock stopMocking];
}
#endif

- (void)testRestoresObjectWhenStopped
{
	TestClassThatCallsSelf *realObject = [[[TestClassThatCallsSelf alloc] init] autorelease];
	mock = [OCMockObject partialMockForObject:realObject];
	[[[mock stub] andReturn:@"TestFoo"] method2];
	STAssertEqualObjects(@"TestFoo", [realObject method2], @"Should have stubbed method.");
	[mock stopMocking];
	STAssertEqualObjects(@"Foo", [realObject method2], @"Should have 'unstubbed' method.");
}

- (void)testRestoresClassObjectWhenStopped
{
    mock = [OCMockObject partialMockForClassObject:[TestClassWithClassMethod class]];
	[[[mock stub] andReturn:@"TestFoo"] method1];
	STAssertEqualObjects(@"TestFoo", [TestClassWithClassMethod method1], @"Should have stubbed method.");
    [mock stopMocking];
	STAssertEqualObjects(@"Foo", [TestClassWithClassMethod method1], @"Should have 'unstubbed' method.");
}

- (void)testRestoresClassWhenStopped
{
    mock = [OCMockObject partialMockForClass:[TestClassThatCallsSelf class]];
    [[[mock stub] andReturn:@"TestFoo"] method1];
    TestClassThatCallsSelf *instance = [[[TestClassThatCallsSelf alloc] init] autorelease];
    STAssertEqualObjects(@"TestFoo", [instance method1], @"Should have stubbed method.");
    [mock stopMocking];
	STAssertEqualObjects(@"Foo", [instance method1], @"Should have 'unstubbed' method.");
}

- (void)testCallsToSelfInRealObjectAreShadowedByPartialMock
{
	TestClassThatCallsSelf *foo = [[[TestClassThatCallsSelf alloc] init] autorelease];
	mock = [OCMockObject partialMockForObject:foo];
	[[[mock stub] andReturn:@"FooFoo"] method2];
	STAssertEqualObjects(@"FooFoo", [mock method1], @"Should have called through to stubbed method.");
}

- (void)testCallsToSelfInClassObjectAreShadowedByClassObjectMock
{
    mock = [OCMockObject partialMockForClassObject:[TestClassWithClassMethod class]];
	[[[mock stub] andReturn:@"TestFoo"] method1];
	STAssertEqualObjects(@"TestFoo", [TestClassWithClassMethod method2], @"Should called through to stubbed method.");
}

- (void)testCallsToSelfInClassAreShadowedByClassMock
{
    TestClassThatCallsSelf *foo = [[[TestClassThatCallsSelf alloc] init] autorelease];
	mock = [OCMockObject partialMockForClass:[TestClassThatCallsSelf class]];
	[[[mock stub] andReturn:@"FooFoo"] method2];
	STAssertEqualObjects(@"FooFoo", [foo method1], @"Should have called through to stubbed method.");
}

- (NSString *)differentMethodInDifferentClass
{
	return @"swizzled!";
}

- (void)testImplementsMethodSwizzling
{
	// using partial mocks and the indirect return value provider
	TestClassThatCallsSelf *foo = [[[TestClassThatCallsSelf alloc] init] autorelease];
	mock = [OCMockObject partialMockForObject:foo];
	[[[mock stub] andCall:@selector(differentMethodInDifferentClass) onObject:self] method1];
	STAssertEqualObjects(@"swizzled!", [foo method1], @"Should have returned value from different method");
}


- (void)aMethodWithVoidReturn
{
}

- (void)testMethodSwizzlingWorksForVoidReturns
{
	TestClassThatCallsSelf *foo = [[[TestClassThatCallsSelf alloc] init] autorelease];
	mock = [OCMockObject partialMockForObject:foo];
	[[[mock stub] andCall:@selector(aMethodWithVoidReturn) onObject:self] method1];
	STAssertNoThrow([foo method1], @"Should have worked.");
}



// --------------------------------------------------------------------------------------
//	class object mocks allow stubbing/expecting on class objects
// --------------------------------------------------------------------------------------

- (void)testClassObjectMockAcceptsStubbedMethod
{
    mock = [OCMockObject mockForClassObject:[TestClassWithClassMethod class]];
	[[mock stub] method1];
	[mock method1];
}

- (void)testClassObjectMockRaisesExceptionWhenUnknownMethodIsCalled
{
    mock = [OCMockObject mockForClassObject:[TestClassWithClassMethod class]];
	[[mock stub] method1];
	STAssertThrows([mock method2], @"Should have raised an exception.");
}

- (void)testClassObjectMockAcceptsExpectedMethod
{
    mock = [OCMockObject mockForClassObject:[TestClassWithClassMethod class]];
	[[mock expect] method1];
	[mock method1];
}

- (void)testClassObjectMockAcceptsExpectedMethodAndReturnsValue
{
	id returnValue;
    
    mock = [OCMockObject mockForClassObject:[TestClassWithClassMethod class]];
	[[[mock expect] andReturn:@"Objective-C"] method1];
	returnValue = [mock method1];
    
	STAssertEqualObjects(@"Objective-C", returnValue, @"Should have returned stubbed value.");
}

- (void)testClassObjectMockAcceptsAndVerifiesExpectedMethods
{
    mock = [OCMockObject mockForClassObject:[TestClassWithClassMethod class]];
	[[mock expect] method1];
	[[mock expect] method2];
	
	[mock method1];
	[mock method2];
	
	[mock verify];
}

- (void)testMockReturnsDefaultValueWhenUnknownMethodIsCalledOnNiceClassObjectMock
{
	mock = [OCMockObject niceMockForClassObject:[TestClassWithClassMethod class]];
	STAssertNil([mock method1], @"Should return nil on unexpected method call (for nice mock).");	
	[mock verify];
}

- (void)testMockRaisesAnExceptionWhenAnExpectedMethodIsNotCalledOnNiceClassObjectMock
{
	mock = [OCMockObject niceMockForClassObject:[TestClassWithClassMethod class]];
	[[[mock expect] andReturn:@"HELLO!"] method1];
	STAssertThrows([mock verify], @"Should have raised an exception because method was not called.");
}

// --------------------------------------------------------------------------------------
//	mocks should honour the NSObject contract, etc.
// --------------------------------------------------------------------------------------

- (void)testRespondsToValidSelector
{
	STAssertTrue([mock respondsToSelector:@selector(lowercaseString)], nil);
}

- (void)testDoesNotRespondToInvalidSelector
{
	STAssertFalse([mock respondsToSelector:@selector(fooBar)], nil);
}

- (void)testCanStubValueForKeyMethod
{
	id returnValue;
	
	mock = [OCMockObject mockForClass:[NSObject class]];
	[[[mock stub] andReturn:@"SomeValue"] valueForKey:@"SomeKey"];
	
	returnValue = [mock valueForKey:@"SomeKey"];
	
	STAssertEqualObjects(@"SomeValue", returnValue, @"Should have returned value that was set up.");
}

- (void)testWorksWithTypeQualifiers
{
	id myMock = [OCMockObject mockForProtocol:@protocol(ProtocolWithTypeQualifierMethod)];
	
	STAssertNoThrow([[myMock expect] aSpecialMethod:"foo"], @"Should not complain about method with type qualifiers.");
	STAssertNoThrow([myMock aSpecialMethod:"foo"], @"Should not complain about method with type qualifiers.");
}

// --------------------------------------------------------------------------------------
//  proxies can be mocked too
// --------------------------------------------------------------------------------------

- (void)testMockForProxyClassAcceptsStubbedMethod
{
    id proxyMock = [OCMockObject mockForClass:[TestProxyClass class]];
	[[proxyMock stub] initWithObject:[OCMArg any]];
	[proxyMock initWithObject:nil];
}

- (void)testMockForProxyClassRaisesExceptionWhenUnknownMethodIsCalled
{
    id proxyMock = [OCMockObject mockForClass:[TestProxyClass class]];
	[[proxyMock stub] initWithObject:[OCMArg any]];
	STAssertThrows([mock proxyMethod], @"Should have raised an exception.");
}

- (void)testStubsMethodsOnPartialMockForProxy
{
	TestClassThatCallsSelf *foo = [[[TestClassThatCallsSelf alloc] init] autorelease];
    id fooProxy = [[[TestProxyClass alloc] initWithObject:foo] autorelease];
	mock = [OCMockObject partialMockForObject:fooProxy];
	[[[mock stub] andReturn:@"hi"] proxyMethod];
	STAssertEqualObjects(@"hi", [mock proxyMethod], @"Should have returned stubbed value");
}

- (void)testStubsMethodOnProxyReference
{
	TestClassThatCallsSelf *foo = [[[TestClassThatCallsSelf alloc] init] autorelease];
    id fooProxy = [[[TestProxyClass alloc] initWithObject:foo] autorelease];
	mock = [OCMockObject partialMockForObject:fooProxy];
	[[[mock stub] andReturn:@"TestFoo"] proxyMethod];
	STAssertEqualObjects(@"TestFoo", [fooProxy proxyMethod], @"Should have stubbed method.");
}

// This test is to show that partial mocks for proxies
// can only stub methods defined on the proxies, not methods on the proxied objects.
- (void)testCannotStubProxiedMethod
{
    TestClassThatCallsSelf *foo = [[[TestClassThatCallsSelf alloc] init] autorelease];
    id fooProxy = [[[TestProxyClass alloc] initWithObject:foo] autorelease];
	mock = [OCMockObject partialMockForObject:fooProxy];
	STAssertThrows([[mock stub] method1], @"Should have raised an exception.");
    STAssertNoThrow([[mock stub] proxyMethod], @"Should not have raised an exception.");
}

- (void)testStubbingDoesNotDisturbProxying
{
	TestClassThatCallsSelf *foo = [[[TestClassThatCallsSelf alloc] init] autorelease];
    id fooProxy = [[[TestProxyClass alloc] initWithObject:foo] autorelease];
	mock = [OCMockObject partialMockForObject:fooProxy];
	[[mock stub] proxyMethod];

    STAssertNoThrow([fooProxy method1], @"Should not complain about normal use of proxy.");
    STAssertEqualObjects([fooProxy method1], @"Foo", @"Should return normal response of proxied object.");
}

- (void)testForwardsUnstubbedMethodsCallsToProxyOnPartialMock
{
	TestClassThatCallsSelf *foo = [[[TestClassThatCallsSelf alloc] init] autorelease];
    id fooProxy = [[[TestProxyClass alloc] initWithObject:foo] autorelease];
	mock = [OCMockObject partialMockForObject:fooProxy];
	STAssertEqualObjects(@"foo", [mock proxyMethod], @"Should have returned value from real object.");
}

- (void)testForwardsToProxyWhenSetUpAndCalledOnMock
{
	TestClassThatCallsSelf *foo = [[[TestClassThatCallsSelf alloc] init] autorelease];
    id fooProxy = [[[TestProxyClass alloc] initWithObject:foo] autorelease];
	mock = [OCMockObject partialMockForObject:fooProxy];

	[[[mock stub] andForwardToRealObject] proxyMethod];
	STAssertEquals(@"foo", [mock proxyMethod], @"Should have called method on real object.");
}

- (void)testForwardsToProxyWhenSetUpAndCalledOnProxy
{
	TestClassThatCallsSelf *foo = [[[TestClassThatCallsSelf alloc] init] autorelease];
    id fooProxy = [[[TestProxyClass alloc] initWithObject:foo] autorelease];
	mock = [OCMockObject partialMockForObject:fooProxy];

	[[[mock expect] andForwardToRealObject] proxyMethod];
	STAssertEquals(@"foo", [fooProxy proxyMethod], @"Should have called method on real object.");
}

- (void)testRestoresProxyWhenStopped
{
	TestClassThatCallsSelf *foo = [[[TestClassThatCallsSelf alloc] init] autorelease];
    id fooProxy = [[[TestProxyClass alloc] initWithObject:foo] autorelease];
	mock = [OCMockObject partialMockForObject:fooProxy];
	[[[mock stub] andReturn:@"TestFoo"] proxyMethod];
	STAssertEqualObjects(@"TestFoo", [fooProxy proxyMethod], @"Should have stubbed method.");
	[mock stopMocking];
	STAssertEqualObjects(@"foo", [fooProxy proxyMethod], @"Should have 'unstubbed' method.");
}

// --------------------------------------------------------------------------------------
//  some internal tests
// --------------------------------------------------------------------------------------

- (void)testReRaisesFailFastExceptionsOnVerify
{
	@try
	{
		[mock lowercaseString];
	}
	@catch(NSException *exception)
	{
		// expected
	}
	STAssertThrows([mock verify], @"Should have reraised the exception.");
}

- (void)testReRaisesRejectExceptionsOnVerify
{
	mock = [OCMockObject niceMockForClass:[NSString class]];
	[[mock reject] uppercaseString];
	@try
	{
		[mock uppercaseString];
	}
	@catch(NSException *exception)
	{
		// expected
	}
	STAssertThrows([mock verify], @"Should have reraised the exception.");
}


- (void)testCanCreateExpectationsAfterInvocations
{
	[[mock expect] lowercaseString];
	[mock lowercaseString];
	[mock expect];
}


- (void)testForwardsStubbedButNonmatchingMethodCallsToRealObjectWhenSetUpAndCalledOnMock
{
	TestClassThatCallsSelf *foo = [[[TestClassThatCallsSelf alloc] init] autorelease];
	mock = [OCMockObject partialMockForObject:foo];
    [[[mock stub] andReturn:@"BAR"] method3:@"foo"];
    
    STAssertEqualObjects(@"BAR", [mock method3:@"foo"], @"Should have stubbed method.");
    
    STAssertNoThrow([mock method3:@"baz"], @"Should not have thrown an exception.");
    STAssertEqualObjects(@"BAZ", [mock method3:@"baz"], @"Should have called method on real object.");
}

- (void)testForwardsStubbedButNonmatchingMethodCallsToRealObjectWhenSetUpAndCalledOnRealObject
{
	TestClassThatCallsSelf *foo = [[[TestClassThatCallsSelf alloc] init] autorelease];
	mock = [OCMockObject partialMockForObject:foo];
    [[[mock stub] andReturn:@"BAR"] method3:@"foo"];

    STAssertEqualObjects(@"BAR", [foo method3:@"foo"], @"Should have stubbed method.");

    STAssertNoThrow([foo method3:@"baz"], @"Should not have thrown an exception.");
    STAssertEqualObjects(@"BAZ", [foo method3:@"baz"], @"Should have called method on real object.");
}

- (void)testForwardsStubbedButNonmatchingMethodCallsToRealObjectWhenSetUpAndCalledOnInstance
{
	TestClassThatCallsSelf *foo = [[[TestClassThatCallsSelf alloc] init] autorelease];
	mock = [OCMockObject partialMockForClass:[TestClassThatCallsSelf class]];
    [[[mock stub] andReturn:@"BAR"] method3:@"foo"];

    STAssertEqualObjects(@"BAR", [foo method3:@"foo"], @"Should have stubbed method.");

    STAssertNoThrow([foo method3:@"baz"], @"Should not have thrown an exception.");
    STAssertEqualObjects(@"BAZ", [foo method3:@"baz"], @"Should have called method on real object.");
}


- (void)testForwardsToMockWhenSetUpAndCalledOnMock
{
	TestClassThatCallsSelf *foo = [[[TestClassThatCallsSelf alloc] init] autorelease];
	id partialMock = [OCMockObject partialMockForObject:foo];
    id partialMockMock = [OCMockObject partialMockForObject:partialMock];

	[[[partialMockMock expect] andForwardToRealObject] expect];
    [[[partialMock expect] andForwardToRealObject] method1];
    STAssertNoThrow([partialMockMock verify], @"Should have called -expect on real object.");

    STAssertEqualObjects(@"Foo", [foo method1], @"Should have called method on real object.");
    STAssertNoThrow([partialMock verify], @"Should have called method on real object.");
}

@end
