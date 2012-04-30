//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2012 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import "OCMockClassObject.h"

#import "OCPartialMock.h"


@interface OCPartialMockClassObject : OCMockClassObject <OCPartialMock>

- (void)setupClass:(Class)aClass;

@end
