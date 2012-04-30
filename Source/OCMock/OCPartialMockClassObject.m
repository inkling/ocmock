//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2012 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <objc/runtime.h>
#import <objc/message.h>
#import "OCPartialMockRecorder.h"
#import "OCPartialMockClassObject.h"


@implementation OCPartialMockClassObject

#pragma mark  Mock table

static NSMutableDictionary *mockTable;

+ (void)initialize
{
	if(self == [OCPartialMockClassObject class])
		mockTable = [[NSMutableDictionary alloc] init];
}

+ (void)rememberMock:(OCPartialMockClassObject *)mock forClass:(Class)aClass
{
	[mockTable setObject:[NSValue valueWithNonretainedObject:mock] forKey:[NSValue valueWithNonretainedObject:aClass]];
}

+ (void)forgetMockForClass:(Class)aClass
{
	[mockTable removeObjectForKey:[NSValue valueWithNonretainedObject:aClass]];
}

+ (OCPartialMockClassObject *)existingMockForClass:(Class)aClass
{
	OCPartialMockClassObject *mock = [[mockTable objectForKey:[NSValue valueWithNonretainedObject:aClass]] nonretainedObjectValue];
	if(mock == nil)
		[NSException raise:NSInternalInconsistencyException format:@"No mock for class %p", aClass];
	return mock;
}


#pragma mark  Initialisers, description, accessors, etc.

- (id)initWithClass:(Class)aClass
{
	[super init];
	mockedClass = aClass;
	[[self class] rememberMock:self forClass:aClass];
    [self setupClass:aClass];
	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"OCPartialMockClassObject[%@]", NSStringFromClass(mockedClass)];
}

- (Class)mockedClass
{
	return mockedClass;
}

- (id)realObject {
    return mockedClass;
}

- (void)stopMocking
{
    
}

- (void)setupClass:(Class)aClass
{
	Method myForwardInvocationMethod = class_getInstanceMethod([self class], @selector(forwardInvocationForRealObject:));
	IMP myForwardInvocationImp = method_getImplementation(myForwardInvocationMethod);
	const char *forwardInvocationTypes = method_getTypeEncoding(myForwardInvocationMethod);
    Class metaClass = objc_getMetaClass(class_getName(aClass));
	class_replaceMethod(metaClass, @selector(forwardInvocation:), myForwardInvocationImp, forwardInvocationTypes);
}
    
- (void)setupForwarderForSelector:(SEL)selector
{
	Method originalMethod = class_getClassMethod(mockedClass, selector);
    Class metaClass = objc_getMetaClass(class_getName(mockedClass));
    
    // We must wish to handle invocations of selector ourselves,
    // which we do by replacing the originalMethod's implementation
    // with the runtime forwarding function _objc_msgForward(_stret).
    char *methodReturnType = method_copyReturnType(originalMethod);
    BOOL methodReturnsStruct = (methodReturnType && (strlen(methodReturnType) > 0) && methodReturnType[0] == '{');
    free(methodReturnType);
    IMP forwarderImp = (methodReturnsStruct ? (IMP)_objc_msgForward_stret : (IMP)_objc_msgForward);
	IMP originalImp = class_replaceMethod(metaClass, method_getName(originalMethod), forwarderImp, method_getTypeEncoding(originalMethod)); 
#pragma unused (originalImp)
    
//	SEL aliasSelector = NSSelectorFromString([OCMRealMethodAliasPrefix stringByAppendingString:NSStringFromSelector(selector)]);
//	class_addMethod(subclass, aliasSelector, originalImp, method_getTypeEncoding(originalMethod));
}

- (void)forwardInvocationForRealObject:(NSInvocation *)anInvocation
{
	// in here "self" is a reference to the real class, not the mock
	OCPartialMockClassObject *mock = [OCPartialMockClassObject existingMockForClass:(Class)self];
	if([mock handleInvocation:anInvocation] == NO)
		[NSException raise:NSInternalInconsistencyException format:@"Ended up in subclass forwarder for %@ with unstubbed method %@",
		 [self class], NSStringFromSelector([anInvocation selector])];
}


#pragma mark  Proxy API

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	return [mockedClass methodSignatureForSelector:aSelector];
}

- (BOOL)respondsToSelector:(SEL)selector
{
    return [mockedClass respondsToSelector:selector];
}


#pragma mark  Overrides

- (id)getNewRecorder
{
	return [[[OCPartialMockRecorder alloc] initWithSignatureResolver:self] autorelease];
}

- (void)handleUnRecordedInvocation:(NSInvocation *)anInvocation {
    [anInvocation invokeWithTarget:mockedClass];
}

@end
