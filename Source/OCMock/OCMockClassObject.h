//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2012 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import "OCMockObject.h"

@interface OCMockClassObject : OCMockObject 
{
    Class	mockedClass;
}

- (id)initWithClass:(Class)aClass;

- (Class)mockedClass;

@end
