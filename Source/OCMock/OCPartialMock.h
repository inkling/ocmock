//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2012 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <Foundation/Foundation.h>


static NSString *const OCMRealMethodAliasPrefix = @"ocmock_replaced_";


@protocol OCPartialMock <NSObject>

/** Returns the real object represented by the partial mock. */
- (id)realObject;

/** Directs the partial mock to stop mocking the real object. */
- (void)stopMocking;

/**
 For internal use only:
 Directs the partial mock to start handling invocations of the given selector
 on the real object.
 */
- (void)setupForwarderForSelector:(SEL)selector;

@end
