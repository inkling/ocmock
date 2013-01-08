//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2012 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import "OCMockClassObject.h"

#import "OCPartialMock.h"

/**
 OCPartialMockClassObject behaves and is used just like OCPartialMockObject, 
 but for classes rather than instances of classes. It allows class methods 
 to be partially mocked.
 
 @warning A given class object can be partially-mocked by only one mock at a time.
 */
@interface OCPartialMockClassObject : OCMockClassObject <OCPartialMock>

- (void)setupClass:(Class)aClass;

@end
