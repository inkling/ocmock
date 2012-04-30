//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2012 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <OCMock/OCMockObject.h>

#import "OCPartialMock.h"


@interface OCPartialMockClassObject : OCMockObject <OCPartialMock>
{
	Class	mockedClass;
}

- (id)initWithClass:(Class)aClass;

- (Class)mockedClass;

- (void)setupClass:(Class)aClass;

@end
