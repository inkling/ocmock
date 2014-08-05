//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2009 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import "OCMBoxedReturnValueProvider.h"

#import "NSValue+OCMAdditions.h"

@implementation OCMBoxedReturnValueProvider

- (void)handleInvocation:(NSInvocation *)anInvocation
{
    const char *returnType = [[anInvocation methodSignature] methodReturnType];
    NSUInteger returnTypeSize = [[anInvocation methodSignature] methodReturnLength];
    char valueBuffer[returnTypeSize];
    NSValue *returnValueAsNSValue = (NSValue *)returnValue;

    if(strcmp(returnType, [(NSValue *)returnValue objCType]) == 0) {
        [returnValueAsNSValue getValue:valueBuffer];
        [anInvocation setReturnValue:valueBuffer];
    } else if([returnValueAsNSValue getBytes:valueBuffer objCType:returnType]) {
        [anInvocation setReturnValue:valueBuffer];
    } else {
        [NSException raise:NSInvalidArgumentException
                    format:@"Return value cannot be used for method; method signature declares '%s' but value is '%s'.", returnType, [returnValueAsNSValue objCType]];
    }
}

@end
