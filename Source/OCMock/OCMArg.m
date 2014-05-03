//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2009-2010 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <objc/runtime.h>
#import <OCMock/OCMArg.h>
#import <OCMock/OCMConstraint.h>
#import "OCMPassByRefSetter.h"
#import "OCMConstraint.h"

@implementation OCMArg

+ (id)any
{
	return [OCMAnyConstraint constraint];
}

+ (void *)anyPointer
{
	return (void *)0x01234567;
}

+ (char *)anyCString
{
    return "1234567";
}

+ (SEL)anySelector {
    return _cmd;
}

+ (id)isNil
{
	return [OCMIsNilConstraint constraint];
}

+ (id)isNotNil
{
	return [OCMIsNotNilConstraint constraint];
}

+ (id)isNotEqual:(id)value
{
	OCMIsNotEqualConstraint *constraint = [OCMIsNotEqualConstraint constraint];
	constraint->testValue = value;
	return constraint;
}

+ (id)checkWithSelector:(SEL)selector onObject:(id)anObject
{
	return [OCMConstraint constraintWithSelector:selector onObject:anObject];
}

#if NS_BLOCKS_AVAILABLE

+ (id)checkWithBlock:(BOOL (^)(id))block 
{
	return [[[OCMBlockConstraint alloc] initWithConstraintBlock:block] autorelease];
}

#endif

+ (id *)setTo:(id)value
{
	return (id *)[[[OCMPassByRefSetter alloc] initWithValue:value] autorelease];
}

+ (id)resolveSpecialValues:(NSValue *)value
{
	const char *type = [value objCType];
	if(type[0] == '^')
	{
		void *pointer = [value pointerValue];
		if(pointer == (void *)0x01234567)
			return [OCMArg any];
        if((pointer != NULL) && strcmp(pointer, "1234567") == 0) // Potentially unsafe because strcmp() will read 8 bytes from an unknown address, but
            return [OCMArg any];                                 // pointers returned by Apple's malloc() should work because they are 16-byte aligned.
		if((pointer != NULL) && (object_getClass((id)pointer) == [OCMPassByRefSetter class]))
			return (id)pointer;
        if(pointer == @selector(anySelector))
            return [OCMArg any];
	}
	return value;
}

@end
