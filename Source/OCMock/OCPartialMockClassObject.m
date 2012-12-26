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
    OCPartialMockClassObject *existingMock = [[mockTable objectForKey:[NSValue valueWithNonretainedObject:aClass]] nonretainedObjectValue];
    if (existingMock != nil) {
        [NSException raise:NSInternalInconsistencyException format:@"Class %@ is already being mocked.", NSStringFromClass(aClass)];
    }
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
		[NSException raise:NSInternalInconsistencyException format:@"No mock for class %@", NSStringFromClass(aClass)];
	return mock;
}


#pragma mark  Initialisers, description, accessors, etc.

- (id)initWithClass:(Class)aClass
{
	[super initWithClass:aClass];
    [[self class] rememberMock:self forClass:aClass];
    [self setupClass:aClass];
	return self;
}

- (void)dealloc
{
	if(mockedClass != nil)
		[self stopMocking];
	[super dealloc];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"OCPartialMockClassObject[%@]", NSStringFromClass(mockedClass)];
}

- (id)realObject {
    return mockedClass;
}

- (void)stopMocking
{
    // We set the implementations of all the mocked methods back to the originals.
    // We detect which methods were mocked, and retrieve the original IMPs,
    // by looking through the metaClass' methods for names prefixed with our alias.
    Class metaClass = objc_getMetaClass(class_getName(mockedClass));
    unsigned int numMethods;
    Method *methodList = class_copyMethodList(metaClass, &numMethods);
    for (int methodIndex = 0; methodIndex < numMethods; methodIndex++) {
        Method method = methodList[methodIndex];
        SEL methodSelector = method_getName(method);
        NSString *methodName = NSStringFromSelector(methodSelector);
        
        if ([methodName hasPrefix:OCMRealMethodAliasPrefix]) {
            NSString *mockedMethodName = [methodName substringFromIndex:[OCMRealMethodAliasPrefix length]];
            SEL mockedMethodSelector = NSSelectorFromString(mockedMethodName);
            IMP originalImp = method_getImplementation(method);
            class_replaceMethod(metaClass, mockedMethodSelector, originalImp, method_getTypeEncoding(method));
        }
    }
    free(methodList);
    
    // Note: The runtime doesn't support us removing the aliased methods 
    // from the mocked class, so we can't completely clean up here.
    // But it'll be ok if we mock this class again – 
    // class_addMethod will just return NO when we try to "re-add" the aliased methods.
    
    [[self class] forgetMockForClass:mockedClass];
    mockedClass = NULL;
}

// Route forwardInvocation: to ourselves so we get a chance
// to handle recorded invocations on the mocked class.
- (void)setupClass:(Class)aClass
{
    SEL forwardInvocationSel = @selector(forwardInvocation:);
    Method originalForwardInvocationMethod = class_getInstanceMethod(aClass, forwardInvocationSel);
    IMP originalForwardInvocationImp = method_getImplementation(originalForwardInvocationMethod);

	Method myForwardInvocationMethod = class_getInstanceMethod([self class], @selector(forwardInvocationForRealObject:));
	IMP myForwardInvocationImp = method_getImplementation(myForwardInvocationMethod);
	const char *forwardInvocationTypes = method_getTypeEncoding(myForwardInvocationMethod);
    Class metaClass = objc_getMetaClass(class_getName(aClass));
	class_replaceMethod(metaClass, forwardInvocationSel, myForwardInvocationImp, forwardInvocationTypes);

    // Add an aliased method to save the original IMP
    // so that we can reset forwardInvocation:'s implementation
    // when we stop mocking.
    NSString *aliasForwardInvocationName = [OCMRealMethodAliasPrefix stringByAppendingString:NSStringFromSelector(forwardInvocationSel)];
	SEL aliasForwardInvocationSel = NSSelectorFromString(aliasForwardInvocationName);
	class_addMethod(aClass, aliasForwardInvocationSel, originalForwardInvocationImp, method_getTypeEncoding(originalForwardInvocationMethod));
}
    
- (void)setupForwarderForSelector:(SEL)selector
{
	Method originalMethod = class_getClassMethod(mockedClass, selector);
    IMP originalImp = method_getImplementation(originalMethod);
    Class metaClass = objc_getMetaClass(class_getName(mockedClass));
    
    // We must wish to handle invocations of selector ourselves,
    // which we do by replacing the originalMethod's implementation
    // with the runtime forwarding function _objc_msgForward(_stret).
    char *methodReturnType = method_copyReturnType(originalMethod);
    BOOL methodReturnsStruct = (methodReturnType && (strlen(methodReturnType) > 0) && methodReturnType[0] == '{');
    free(methodReturnType);
    IMP forwarderImp = (methodReturnsStruct ? (IMP)_objc_msgForward_stret : (IMP)_objc_msgForward);
	class_replaceMethod(metaClass, method_getName(originalMethod), forwarderImp, method_getTypeEncoding(originalMethod)); 
    
    // We add an aliased method to save the original IMP 
    // so that methods can be forwarded to the class object
    // and so that we can reset the method's implementation 
    // when we stop mocking.
	SEL aliasSelector = NSSelectorFromString([OCMRealMethodAliasPrefix stringByAppendingString:NSStringFromSelector(selector)]);
	class_addMethod(metaClass, aliasSelector, originalImp, method_getTypeEncoding(originalMethod));
}

- (void)forwardInvocationForRealObject:(NSInvocation *)anInvocation
{
	// in here "self" is a reference to the real class, not the mock
	OCPartialMockClassObject *mock = [OCPartialMockClassObject existingMockForClass:(Class)self];
	if([mock handleInvocation:anInvocation] == NO)
		[NSException raise:NSInternalInconsistencyException format:@"Ended up in forwarder for %@ with unstubbed method %@",
		 [self class], NSStringFromSelector([anInvocation selector])];
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
