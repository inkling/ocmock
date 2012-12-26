//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2012 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import "OCMockObject.h"

#import "OCPartialMock.h"

@interface OCPartialClassMockObject : OCMockObject <OCPartialMock>

- (instancetype)initWithClass:(Class)aClass;

@end
