//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2012 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import "OCPartialClassMockObject.h"
#import "OCPartialMockRecorder.h"

#import <objc/runtime.h>
#import <objc/message.h>

@implementation OCPartialClassMockObject {
    Class _mockedClass;
}

#pragma mark  Mock table

static NSMutableDictionary *mockTable;

+ (void)initialize
{
	if(self == [OCPartialClassMockObject class])
		mockTable = [[NSMutableDictionary alloc] init];
}

+ (void)rememberMock:(OCPartialClassMockObject *)mock forClass:(Class)aClass
{
    OCPartialClassMockObject *existingMock = [[mockTable objectForKey:[NSValue valueWithNonretainedObject:aClass]] nonretainedObjectValue];
    if (existingMock != nil) {
        [NSException raise:NSInternalInconsistencyException format:@"Class %@ is already being mocked.", NSStringFromClass(aClass)];
    }
	[mockTable setObject:[NSValue valueWithNonretainedObject:mock] forKey:[NSValue valueWithNonretainedObject:aClass]];
}

+ (void)forgetMockForClass:(Class)aClass
{
	[mockTable removeObjectForKey:[NSValue valueWithNonretainedObject:aClass]];
}

+ (OCPartialClassMockObject *)existingMockForClass:(Class)aClass
{
	OCPartialClassMockObject *mock = [[mockTable objectForKey:[NSValue valueWithNonretainedObject:aClass]] nonretainedObjectValue];
	if(mock == nil)
		[NSException raise:NSInternalInconsistencyException format:@"No mock for class %@", NSStringFromClass(aClass)];
	return mock;
}


#pragma mark - Initialisers, description, accessors, etc.

- (instancetype)initWithClass:(Class)aClass
{
    self = [super init];
    if (self) {
        [[self class] rememberMock:self forClass:aClass];
        [self setupClass:aClass];
        _mockedClass = aClass;
    }
    return self;
}

- (void)dealloc
{
    if (_mockedClass) [self stopMocking];
    [super dealloc];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"OCPartialClassMockObject[%@]", NSStringFromClass(_mockedClass)];
}

#pragma mark - Mock configuration

- (id)realObject {
    // A partial class mock doesn't represent one particular object.
    // This is why we cannot allow direct use of partial class mocks:
    // because we would not be able to forward unrecorded and "andForwardToRealObject"-handled
    // methods invoked directly on a partial class mock.
    return nil;
}

- (void)stopMocking
{
    // We set the implementations of all the mocked methods back to the originals.
    // We detect which methods were mocked, and retrieve the original IMPs,
    // by looking through the class' methods for names prefixed with our alias.
    unsigned int numMethods;
    Method *methodList = class_copyMethodList(_mockedClass, &numMethods);
    for (int methodIndex = 0; methodIndex < numMethods; methodIndex++) {
        Method method = methodList[methodIndex];
        SEL methodSelector = method_getName(method);
        NSString *methodName = NSStringFromSelector(methodSelector);

        if ([methodName hasPrefix:OCMRealMethodAliasPrefix]) {
            NSString *mockedMethodName = [methodName substringFromIndex:[OCMRealMethodAliasPrefix length]];
            SEL mockedMethodSelector = NSSelectorFromString(mockedMethodName);
            IMP originalImp = method_getImplementation(method);
            class_replaceMethod(_mockedClass, mockedMethodSelector, originalImp, method_getTypeEncoding(method));
        }
    }
    free(methodList);

    // Note: The runtime doesn't support us removing the aliased methods
    // from the mocked class, so we can't completely clean up here.
    // But it'll be ok if we mock this class again –
    // class_addMethod will just return NO when we try to "re-add" the aliased methods.

    [[self class] forgetMockForClass:_mockedClass];
    _mockedClass = NULL;
}

// Route forwardInvocation: to ourselves so we get a chance
// to handle recorded invocations on instances of the mocked class.
- (void)setupClass:(Class)aClass
{
    SEL methodSignatureSel = @selector(methodSignatureForSelector:);
    Method realMethodSignatureMethod = class_getInstanceMethod(aClass, methodSignatureSel);
    IMP realMethodSignatureImp = method_getImplementation(realMethodSignatureMethod);

    SEL forwardInvocationSel = @selector(forwardInvocation:);
    Method originalForwardInvocationMethod = class_getInstanceMethod(aClass, forwardInvocationSel);
    IMP originalForwardInvocationImp = method_getImplementation(originalForwardInvocationMethod);

    // Route -methodSignatureForSelector: to ourselves
    // so that we'll provide an appropriate signature for a stubbed method
    // that is invoked on the real object, even if the real object is a proxy
    // (which would normally only provide signatures for methods of the object it was proxying).
    Method myMethodSignatureMethod = class_getInstanceMethod([self class], @selector(methodSignatureForSelectorForRealObject:));
    IMP myMethodSignatureImp = method_getImplementation(myMethodSignatureMethod);
    const char *methodSignatureTypes = method_getTypeEncoding(myMethodSignatureMethod);
    class_addMethod(aClass, methodSignatureSel, myMethodSignatureImp, methodSignatureTypes);

    // Add an aliased method to save the real -methodSignatureForSelector: IMP
    // so that we can allow the real object to provide signatures for some methods
    // (see -methodSignatureForSelectorForRealObject:).
    NSString *aliasMethodSignatureName = [OCMRealMethodAliasPrefix stringByAppendingString:NSStringFromSelector(methodSignatureSel)];
    SEL aliasMethodSignatureSel = NSSelectorFromString(aliasMethodSignatureName);
    class_addMethod(aClass, aliasMethodSignatureSel, realMethodSignatureImp, method_getTypeEncoding(realMethodSignatureMethod));

    // Route -forwardInvocation: to ourselves so we get a chance
    // to handle recorded invocations on the mocked object.
	Method myForwardInvocationMethod = class_getInstanceMethod([self class], @selector(forwardInvocationForRealObject:));
	IMP myForwardInvocationImp = method_getImplementation(myForwardInvocationMethod);
	const char *forwardInvocationTypes = method_getTypeEncoding(myForwardInvocationMethod);
	class_replaceMethod(aClass, forwardInvocationSel, myForwardInvocationImp, forwardInvocationTypes);

    // Add an aliased method to save the original IMP
    // so that we can reset forwardInvocation:'s implementation
    // when we stop mocking, also so that we can allow real objects to handle
    // forwardInvocation: if we don't.
    NSString *aliasForwardInvocationName = [OCMRealMethodAliasPrefix stringByAppendingString:NSStringFromSelector(forwardInvocationSel)];
	SEL aliasForwardInvocationSel = NSSelectorFromString(aliasForwardInvocationName);
	class_addMethod(aClass, aliasForwardInvocationSel, originalForwardInvocationImp, method_getTypeEncoding(originalForwardInvocationMethod));
}

- (void)setupForwarderForSelector:(SEL)selector
{
	Method originalMethod = class_getInstanceMethod(_mockedClass, selector);
    IMP originalImp = method_getImplementation(originalMethod);

    // We must wish to handle invocations of selector ourselves,
    // which we do by replacing the originalMethod's implementation
    // with the runtime forwarding function _objc_msgForward(_stret).
    // We will receive the invocations because we route forwardInvocation: to ourselves above.
#if defined(__arm64__)
    IMP forwarderImp = _objc_msgForward;
#else
    char *methodReturnType = method_copyReturnType(originalMethod);
    BOOL methodReturnsStruct = (methodReturnType && (strlen(methodReturnType) > 0) && methodReturnType[0] == '{');
    free(methodReturnType);
    IMP forwarderImp = (methodReturnsStruct ? (IMP)_objc_msgForward_stret : (IMP)_objc_msgForward);
#endif
	class_replaceMethod(_mockedClass, method_getName(originalMethod), forwarderImp, method_getTypeEncoding(originalMethod));

    // We add an aliased method to save the original IMP
    // so that methods can be forwarded to instances
    // and so that we can reset the method's implementation
    // when we stop mocking.
    NSString *aliasSelectorName = [OCMRealMethodAliasPrefix stringByAppendingString:NSStringFromSelector(selector)];
	SEL aliasSelector = NSSelectorFromString(aliasSelectorName);
	class_addMethod(_mockedClass, aliasSelector, originalImp, method_getTypeEncoding(originalMethod));
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
	// in here "self" is a reference to a real object, not the mock
	OCPartialClassMockObject *mock = [OCPartialClassMockObject existingMockForClass:[self class]];
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
            [NSException raise:NSInternalInconsistencyException
                        format:@"Ended up in forwarder for %@ with unstubbed method %@",
                                 // we use [self description] because NSProxy does not implement the methods required to format self
                                [self description], NSStringFromSelector([anInvocation selector])];
        }
    }
}

#pragma mark - Proxy API

// we report responding to the mocked class' instance-method selectors,
// and return valid signatures for those methods, for the benefit of the framework
// (e.g. the mock recorder),
// but prevent direct use of the mock as an instance of the mocked class (see -realObject, above)
// by overriding -forwardInvocation: to throw an exception.

- (BOOL)respondsToSelector:(SEL)aSelector {
    // we use the runtime here because we want the response of the mocked class itself,
    // not, if it is a proxy, the response of the class it is proxying
    return class_respondsToSelector(_mockedClass, aSelector);
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    // we use the runtime here because we want the response of the mocked class itself,
    // not, if it is a proxy, the response of the class it is proxying
    Method method = class_getInstanceMethod(_mockedClass, aSelector);
    return [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    [NSException raise:NSInternalInconsistencyException
                format:@"Unrecognized message sent to %@: %@. Possible attempt to set-up and call method on partial class mock directly.",
                         // we use [self description] because NSProxy does not implement the methods required to format self
                        [self description], NSStringFromSelector([invocation selector])];
}

#pragma mark Overrides

- (id)getNewRecorder
{
	return [[[OCPartialMockRecorder alloc] initWithSignatureResolver:self] autorelease];
}

@end
