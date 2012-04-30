//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2012 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import "OCMockClassObject.h"

@implementation OCMockClassObject

- (id)initWithClass:(Class)aClass
{
	[super init];
	mockedClass = aClass;
    return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"OCMockClassObject[%@]", NSStringFromClass(mockedClass)];
}

- (Class)mockedClass
{
	return mockedClass;
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

@end
