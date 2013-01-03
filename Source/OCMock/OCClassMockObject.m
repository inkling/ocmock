//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2005-2008 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import "OCClassMockObject.h"
#import <objc/runtime.h>


@implementation OCClassMockObject

#pragma mark  Initialisers, description, accessors, etc.

- (id)initWithClass:(Class)aClass
{
	[super init];
	mockedClass = aClass;
	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"OCMockObject[%@]", NSStringFromClass(mockedClass)];
}

- (Class)mockedClass
{
	return mockedClass;
}


#pragma mark  Proxy API

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    // we use the runtime here because we want the response of the mocked class itself,
    // not, if it is a proxy, the response of the class it is proxying
    Method method = class_getInstanceMethod(mockedClass, aSelector);
    return [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
}

- (BOOL)respondsToSelector:(SEL)selector
{
    // we use the runtime here because we want the response of the mocked class itself,
    // not, if it is a proxy, the response of the class it is proxying
    return class_respondsToSelector(mockedClass, selector);
}

@end
