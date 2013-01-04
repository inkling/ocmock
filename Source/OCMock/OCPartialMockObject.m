//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2009 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <objc/runtime.h>
#import <objc/message.h>
#import "OCPartialMockRecorder.h"
#import "OCPartialMockObject.h"


@interface OCPartialMockObject (Private)
- (void)forwardInvocationForRealObject:(NSInvocation *)anInvocation;
@end 


@implementation OCPartialMockObject


#pragma mark  Mock table

static NSMutableDictionary *mockTable;

+ (void)initialize
{
	if(self == [OCPartialMockObject class])
		mockTable = [[NSMutableDictionary alloc] init];
}

+ (void)rememberPartialMock:(OCPartialMockObject *)mock forObject:(id)anObject
{
	[mockTable setObject:[NSValue valueWithNonretainedObject:mock] forKey:[NSValue valueWithNonretainedObject:anObject]];
}

+ (void)forgetPartialMockForObject:(id)anObject
{
	[mockTable removeObjectForKey:[NSValue valueWithNonretainedObject:anObject]];
}

+ (OCPartialMockObject *)existingPartialMockForObject:(id)anObject
{
	OCPartialMockObject *mock = [[mockTable objectForKey:[NSValue valueWithNonretainedObject:anObject]] nonretainedObjectValue];
	if(mock == nil)
		[NSException raise:NSInternalInconsistencyException format:@"No partial mock for object %p", anObject];
	return mock;
}



#pragma mark  Initialisers, description, accessors, etc.

- (id)initWithObject:(NSObject *)anObject
{
	[super initWithClass:[anObject class]];
	realObject = [anObject retain];
	[[self class] rememberPartialMock:self forObject:anObject];
	[self setupSubclassForObject:realObject];
	return self;
}

- (void)dealloc
{
	if(realObject != nil)
		[self stopMocking];
	[super dealloc];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"OCPartialMockObject[%@]", NSStringFromClass(mockedClass)];
}

- (id)realObject
{
	return realObject;
}

- (void)stopMocking
{
	object_setClass(realObject, [self mockedClass]);
	[realObject release];
	[[self class] forgetPartialMockForObject:realObject];
	realObject = nil;
}


#pragma mark  Subclass management

- (void)setupSubclassForObject:(id)anObject
{
    Class realClass = [anObject class];

    SEL methodSignatureSel = @selector(methodSignatureForSelector:);
    Method realMethodSignatureMethod = class_getInstanceMethod(realClass, methodSignatureSel);
    IMP realMethodSignatureImp = method_getImplementation(realMethodSignatureMethod);

    SEL forwardInvocationSel = @selector(forwardInvocation:);
    Method realForwardInvocationMethod = class_getInstanceMethod(realClass, forwardInvocationSel);
    IMP realForwardInvocationImp = method_getImplementation(realForwardInvocationMethod);

    // Make the mocked object an instance of a new subclass of its real class
    // so that when we mock its methods we only affect it.
    double timestamp = [NSDate timeIntervalSinceReferenceDate];
    const char *className = [[NSString stringWithFormat:@"%@-%p-%f", realClass, anObject, timestamp] UTF8String];
    Class subclass = objc_allocateClassPair(realClass, className, 0);
    objc_registerClassPair(subclass);
    object_setClass(anObject, subclass);

    // Route -methodSignatureForSelector: to ourselves
    // so that we'll provide an appropriate signature for a stubbed method
    // that is invoked on the real object, even if the real object is a proxy
    // (which would normally only provide signatures for methods of the object it was proxying).
    Method myMethodSignatureMethod = class_getInstanceMethod([self class], @selector(methodSignatureForSelectorForRealObject:));
    IMP myMethodSignatureImp = method_getImplementation(myMethodSignatureMethod);
    const char *methodSignatureTypes = method_getTypeEncoding(myMethodSignatureMethod);
    class_addMethod(subclass, methodSignatureSel, myMethodSignatureImp, methodSignatureTypes);

    // Add an aliased method to save the real -methodSignatureForSelector: IMP
    // so that we can allow the real object to provide signatures for some methods
    // (see -methodSignatureForSelectorForRealObject:).
    NSString *aliasMethodSignatureName = [OCMRealMethodAliasPrefix stringByAppendingString:NSStringFromSelector(methodSignatureSel)];
    SEL aliasMethodSignatureSel = NSSelectorFromString(aliasMethodSignatureName);
    class_addMethod(subclass, aliasMethodSignatureSel, realMethodSignatureImp, method_getTypeEncoding(realMethodSignatureMethod));

    // Route -forwardInvocation: to ourselves so we get a chance
    // to handle recorded invocations on the mocked object.
    Method myForwardInvocationMethod = class_getInstanceMethod([self class], @selector(forwardInvocationForRealObject:));
    IMP myForwardInvocationImp = method_getImplementation(myForwardInvocationMethod);
    const char *forwardInvocationTypes = method_getTypeEncoding(myForwardInvocationMethod);
    class_addMethod(subclass, forwardInvocationSel, myForwardInvocationImp, forwardInvocationTypes);

    // Add an aliased method to save the real -forwardInvocation: IMP
    // so that we can allow the real object to handle forwardInvocation: if we don't.
    NSString *aliasForwardInvocationName = [OCMRealMethodAliasPrefix stringByAppendingString:NSStringFromSelector(forwardInvocationSel)];
    SEL aliasForwardInvocationSel = NSSelectorFromString(aliasForwardInvocationName);
    class_addMethod(subclass, aliasForwardInvocationSel, realForwardInvocationImp, method_getTypeEncoding(realForwardInvocationMethod));
}

- (void)setupForwarderForSelector:(SEL)selector
{
	Class subclass = [[self realObject] class];
	Method originalMethod = class_getInstanceMethod([subclass superclass], selector);
	IMP originalImp = method_getImplementation(originalMethod);

    // We must add an implementation of selector to our subclass
    // which will be called before the super (normal) class.
    // By using _objc_msgForward(_stret), we cause messages to be routed 
    // to forwardInvocation: (and thus forwardInvocationForRealObject:, 
    // from above) with a nicely packaged invocation.
    char *methodReturnType = method_copyReturnType(originalMethod);
    BOOL methodReturnsStruct = (methodReturnType && (strlen(methodReturnType) > 0) && methodReturnType[0] == '{');
    free(methodReturnType);
    IMP forwarderImp = (methodReturnsStruct ? (IMP)_objc_msgForward_stret : (IMP)_objc_msgForward);
	class_addMethod(subclass, method_getName(originalMethod), forwarderImp, method_getTypeEncoding(originalMethod)); 

	SEL aliasSelector = NSSelectorFromString([OCMRealMethodAliasPrefix stringByAppendingString:NSStringFromSelector(selector)]);
	class_addMethod(subclass, aliasSelector, originalImp, method_getTypeEncoding(originalMethod));
}

- (NSMethodSignature *)methodSignatureForSelectorForRealObject:(SEL)sel {
	// in here "self" is a reference to the real object, not the mock

    // if the real object is a proxy, we have to provide signatures
    // for the proxy's methods--when the proxy itself is being mocked--
    // and also allow the proxy to provide signatures for the methods that it's forwarding
    if ([self isProxy]) {
        // we'll first try to get a signature from the proxy itself,
        // using the runtime to bypass its forwarding
        Method method = class_getInstanceMethod(object_getClass(self), sel);
        if (method) {
            return [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
        }
    }

    // if we're here the real object either isn't a proxy,
    // or it's being asked for a signature for a method of the object it's proxying
    // either way now we return its default response for -methodSignatureForSelector:
    SEL methodSignatureSel = @selector(methodSignatureForSelector:);
    NSString *aliasMethodSignatureName = [OCMRealMethodAliasPrefix stringByAppendingString:NSStringFromSelector(methodSignatureSel)];
    SEL aliasMethodSignatureSel = NSSelectorFromString(aliasMethodSignatureName);
    return ((id(*)(id, SEL, SEL))objc_msgSend)(self, aliasMethodSignatureSel, sel);
}

- (void)forwardInvocationForRealObject:(NSInvocation *)anInvocation
{
	// in here "self" is a reference to the real object, not the mock
	OCPartialMockObject *mock = [OCPartialMockObject existingPartialMockForObject:self];
	if([mock handleInvocation:anInvocation] == NO) {
        SEL invocationSelector = [anInvocation selector];
        
        // try to let the real object handle the invocation, if it says it can.
        // two cases:
        //  1. this is a method of the real object (which we stubbed, but didn't handle
        //     because e.g. the arguments didn't match)
        if (class_respondsToSelector(object_getClass(self), invocationSelector)) {
            NSString *aliasInvocationName = [OCMRealMethodAliasPrefix stringByAppendingString:NSStringFromSelector(invocationSelector)];
            SEL aliasInvocationSelector = NSSelectorFromString(aliasInvocationName);
            [anInvocation setSelector:aliasInvocationSelector];
            [anInvocation invokeWithTarget:self];

        //  2. this a method the real object would have forwarded if we hadn't overridden
        //     its forwardInvocation:
        } else if ([self methodSignatureForSelector:invocationSelector]) {
            SEL forwardInvocationSel = @selector(forwardInvocation:);
            NSString *aliasForwardInvocationName = [OCMRealMethodAliasPrefix stringByAppendingString:NSStringFromSelector(forwardInvocationSel)];
            SEL aliasForwardInvocationSel = NSSelectorFromString(aliasForwardInvocationName);
            [self performSelector:aliasForwardInvocationSel withObject:anInvocation];
            
        } else {
            // no one handled the invocation
            [NSException raise:NSInternalInconsistencyException format:@"Ended up in subclass forwarder for %@ with unstubbed method %@",
             [self class], NSStringFromSelector([anInvocation selector])];
        }
    }
}



#pragma mark  Overrides

- (id)getNewRecorder
{
	return [[[OCPartialMockRecorder alloc] initWithSignatureResolver:self] autorelease];
}

- (void)handleUnRecordedInvocation:(NSInvocation *)anInvocation
{
	[anInvocation invokeWithTarget:realObject];
}


@end
