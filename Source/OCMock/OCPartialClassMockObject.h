//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2012 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import "OCMockObject.h"

#import "OCPartialMock.h"

/**
 Partial class mocks allow functionality to be stubbed out across
 ALL instances of a class. They are to be used, instead of partial object mocks,
 where the identities of individual instances are unknown or unimportant.

 They differ from the other partial object mock types, and from class mocks,
 in that they cannot be used directly, as instances of the mocked class.
 This is because there is no single "real object" to which to forward unrecorded
 invocations and "andForwardToRealObject"-handled invocations from a
 directly-used mock.
 */
@interface OCPartialClassMockObject : OCMockObject <OCPartialMock>

/**
 Creates a partial mock for a class.
 
 The mock may be used to stub out functionality across ALL instances of the class.
 
 @warning The mock may not be used directly, as an instance of the mocked class. 
 The stubbed methods should rather be invoked by using actual instances of the
 mocked class.
 @warning A given class can be partially-mocked by only one mock at a time.
 
 @param aClass The class to partially mock.
 @return An partial mock for the specified class.
 @throws NSInternalInconsistencyException If the class is already being partially-mocked.
 */
- (instancetype)initWithClass:(Class)aClass;

@end
