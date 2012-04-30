//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2012 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <Foundation/Foundation.h>


static NSString *const OCMRealMethodAliasPrefix = @"ocmock_replaced_";


@protocol OCPartialMock <NSObject>

- (id)realObject;

- (void)stopMocking;

- (void)setupForwarderForSelector:(SEL)selector;

@end
