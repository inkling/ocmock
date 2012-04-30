//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2009 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import "OCClassMockObject.h"
#import "OCPartialMock.h"

@interface OCPartialMockObject : OCClassMockObject <OCPartialMock>
{
	NSObject	*realObject;
}

- (id)initWithObject:(NSObject *)anObject;
- (void)setupSubclassForObject:(id)anObject;

@end
