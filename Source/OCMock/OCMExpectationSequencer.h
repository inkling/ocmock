//
//  OCMExpectationSequencer.h
//  OCMock
//
//  Created by Jeffrey Wear on 12/27/12.
//  Copyright (c) 2012 Mulle Kybernetik. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 Whereas a single mock can only verify the order of messages it receives,
 an OCMExpectationSequencer can verify the order of messages received 
 by multiple mocks.
 
 After creating a sequencer, simply -expect and -reject invocations 
 on the sequenced mocks as normal. To verify the sequence, 
 call -verify on the sequencer rather than on the individual mocks.
 
 An OCMExpectationSequencer may be most useful when the sequenced mocks 
 are partial mocks, by allowing you to verify that their real objects 
 interact in a certain way.
 */
@interface OCMExpectationSequencer : NSObject

/**
 Begins sequencing expectations on the provided mocks.

 @warning A mock may participate in only one sequence at a time.

 @param mocks An array of mocks to sequence.
 @return A sequencer for the given mocks.
 */
+ (instancetype)sequencerWithMocks:(NSArray *)mocks;

/**
 Verifies the sequence of expectations on the mock.
 
 @throws NSInternalInconsistencyException if expected methods were not invoked,
 or if a rejected method was invoked.
 */
- (void)verify;

/**
 Stops sequencing the mocks.
 
 The sequencer automatically stops sequencing when deallocated,
 if it has not been previously directed to do so.
 */
- (void)stopSequencing;

@end
