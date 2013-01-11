//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2005-2008 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import "OCClassMockObject.h"
#import "objc+OCMAdditions.h"
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
    const char *methodTypes = NULL;
    
    // we use the runtime here because we want the response of the mocked class itself,
    // not, if it is a proxy, the response of the class it is proxying
    Method method = class_getInstanceMethod(mockedClass, aSelector);

    if (method) {
        methodTypes = method_getTypeEncoding(method);
    } else {
        // perhaps this selector is a dynamic property's setter or getter
        // (whose implementation has not yet been added to the class)
        // if so, we can derive the type encoding from the property itself
        // this type encoding will not be as rich as that returned by method_getTypeEncoding
        // --lacking things like offsets and stack sizes--but it works
        objc_property_t property = ocm_class_getPropertyForSelector(mockedClass, aSelector);
        if (property) {
            BOOL methodIsSetter = [NSStringFromSelector(aSelector) hasSuffix:@":"];
            if (methodIsSetter) {
                methodTypes = ocm_property_getSetterTypeEncoding(property);
            } else {
                methodTypes = ocm_property_getGetterTypeEncoding(property);
            }
        }
    }

    return [NSMethodSignature signatureWithObjCTypes:methodTypes];
}

- (BOOL)respondsToSelector:(SEL)selector
{
    // we use the runtime here because we want the response of the mocked class itself,
    // not, if it is a proxy, the response of the class it is proxying
    if (class_respondsToSelector(mockedClass, selector)) return YES;

    // by default, classes only respond to selectors for which they have method implementations
    // but if the selector is a dynamic property's setter or getter,
    // its implementation may not have not yet been added to the class,
    // and we can still derive the type encoding (see above) to mock the property,
    // so we should return YES
    if (ocm_class_getPropertyForSelector(mockedClass, selector)) return YES;

    return NO;
}

@end
