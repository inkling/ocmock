//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2010 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <objc/runtime.h>
#import "OCPartialMock.h"
#import "OCMRealObjectForwarder.h"


@implementation OCMRealObjectForwarder

- (void)handleInvocation:(NSInvocation *)anInvocation 
{
	id invocationTarget = [anInvocation target];
	SEL invocationSelector = [anInvocation selector];
	SEL aliasedSelector = NSSelectorFromString([OCMRealMethodAliasPrefix stringByAppendingString:NSStringFromSelector(invocationSelector)]);
	
	[anInvocation setSelector:aliasedSelector];
    // if the method has been invoked on a partial mock,
    // and the method isn't one of the mock's own methods
    // (as could be the case if the mock is itself being partially mocked)
    // we need to change the target to the mock's real object
    Class targetClass = object_getClass(invocationTarget);
	if(class_conformsToProtocol(targetClass, @protocol(OCPartialMock)) &&
       !class_respondsToSelector(targetClass, aliasedSelector))
	{
		[anInvocation setTarget:[(id<OCPartialMock>)invocationTarget realObject]];
	} 
	[anInvocation invoke];
}


@end
