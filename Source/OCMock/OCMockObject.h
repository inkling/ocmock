//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2004-2008 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <Foundation/Foundation.h>

@interface OCMockObject : NSProxy
{
	BOOL			isNice;
	BOOL			expectationOrderMatters;
	NSMutableArray	*recorders;
	NSMutableArray	*expectations;
	NSMutableArray	*rejections;
	NSMutableArray	*exceptions;
}

+ (id)mockForClass:(Class)aClass;
+ (id)mockForClassObject:(Class)aClass;
+ (id)mockForProtocol:(Protocol *)aProtocol;
+ (id)partialMockForObject:(NSObject *)anObject;
// note: there may only exist one partial class object mock
// for a given Class at any one time
+ (id)partialMockForClassObject:(Class)aClass;

// Partial class mocks are used to indirectly handle invocations
// on ALL instances of the mocked Class.
// They are to be used, instead of partial object mocks,
// where the identities of individual instances are unknown or unimportant.
//
// Partial class mocks may NOT be used directly--as instances of the mocked Class--
// because there is no single "real object" to which to forward unrecorded
// and "andForwardToRealObject"-handled invocations from a directly-used mock.

// There may only exist one partial class mock
// for a given Class at any one time.
+ (id)partialMockForClass:(Class)aClass;

+ (id)niceMockForClass:(Class)aClass;
+ (id)niceMockForClassObject:(Class)aClass;
+ (id)niceMockForProtocol:(Protocol *)aProtocol;

+ (id)observerMock;

- (id)init;

- (void)setExpectationOrderMatters:(BOOL)flag;

- (id)stub;
- (id)expect;
- (id)reject;

- (void)verify;

- (void)stopMocking;

// internal use only

- (id)getNewRecorder;
- (BOOL)handleInvocation:(NSInvocation *)anInvocation;
- (void)handleUnRecordedInvocation:(NSInvocation *)anInvocation;

@end
