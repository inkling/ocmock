//
//  OCMExpectationSequencer.m
//  OCMock
//
//  Created by Jeffrey Wear on 12/27/12.
//  Copyright (c) 2012 Mulle Kybernetik. All rights reserved.
//

#import "OCMExpectationSequencer.h"
#import "OCPartialMockObject.h"
#import "OCMockRecorder.h"
#import "OCMArg.h"
#import "NSInvocation+OCMAdditions.h"

@implementation OCMExpectationSequencer {
    NSArray *_partialMocks;
    NSMutableArray *_recorders;
    NSMutableArray *_expectations;
    NSMutableArray *_rejections;
    NSMutableArray *_exceptions;
}

static NSMutableDictionary *__sequencerTable;

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sequencerTable = [[NSMutableDictionary alloc] init];
    });
}

+ (instancetype)sequencerWithMocks:(NSArray *)mocks {
    return [[[OCMExpectationSequencer alloc] initWithMocks:mocks] autorelease];
}

+ (void)rememberSequencer:(OCMExpectationSequencer *)sequencer forMock:(id)mock {
    OCMExpectationSequencer *existingSequencer = [[__sequencerTable objectForKey:[NSValue valueWithNonretainedObject:mock]] nonretainedObjectValue];
    if (existingSequencer) {
        // we use [mock description] because NSProxy does not implement the methods required to format itself
        [NSException raise:NSInternalInconsistencyException format:@"Mock %@ is already being sequenced.", [mock description]];
    }
    [__sequencerTable setObject:[NSValue valueWithNonretainedObject:sequencer] forKey:[NSValue valueWithNonretainedObject:mock]];
}

+ (void)forgetSequencerForMock:(id)mock {
    [__sequencerTable removeObjectForKey:[NSValue valueWithNonretainedObject:mock]];
}

- (instancetype)initWithMocks:(NSArray *)mocks {
    self = [super init];
    if (self) {
        [self beginSequencingMocks:mocks];
    }
    return self;
}

- (void)dealloc {
    if (_partialMocks) {
        [self stopSequencing];
    }
    [super dealloc];
}

- (void)verify {
	if ([_expectations count] == 1) {
		[NSException raise:NSInternalInconsistencyException format:@"%@: expected method was not invoked: %@",
         [self description], [[_expectations objectAtIndex:0] description]];
	}
	if ([_expectations count] > 0) {
		[NSException raise:NSInternalInconsistencyException format:@"%@ : %ju expected methods were not invoked: %@",
         [self description], (uintmax_t)[_expectations count], [self expectationsDescription]];
	}
    if ([_exceptions count] > 0)	{
		[[_exceptions objectAtIndex:0] raise];
	}
}

- (void)recordInvocation:(NSInvocation *)anInvocation {
	OCMockRecorder *recorder = nil;
	unsigned int			   i;

	for(i = 0; i < [_recorders count]; i++)
	{
		recorder = [_recorders objectAtIndex:i];
		if([recorder matchesInvocation:anInvocation])
			break;
	}

	if(i == [_recorders count])
		return;

	if([_rejections containsObject:recorder])
	{
		NSException *exception = [NSException exceptionWithName:NSInternalInconsistencyException reason:
								  [NSString stringWithFormat:@"%@: explicitly disallowed method invoked: %@", [self description],
								   [anInvocation invocationDescription]] userInfo:nil];
		[_exceptions addObject:exception];
		// Note that we do NOT raise the exception here, but let the sequenced mock do that
		// when it handles the invocation, after this method ends.
		// If we raised the exception here, the sequenced mock would not get to handle the invocation.
	}

	if([_expectations containsObject:recorder])
	{
        // expectation order matters for an expectation sequencer
        if([_expectations objectAtIndex:0] != recorder)
		{
			[NSException raise:NSInternalInconsistencyException	format:@"%@: unexpected method invoked: %@\n\texpected:\t%@",
			 [self description], [recorder description], [[_expectations objectAtIndex:0] description]];

		}
		[_expectations removeObject:recorder];
		[_recorders removeObjectAtIndex:i];
	}
}

- (NSString *)expectationsDescription {
    NSMutableString *descriptionString = [NSMutableString string];

	for (id recorder in _expectations) {
		[descriptionString appendFormat:@"\n\t \t%@", [recorder description]];
	}

	return descriptionString;
}

- (void)beginSequencingMocks:(NSArray *)mocks {
    NSAssert(!_partialMocks, @"Sequencer %@ has already begun sequencing mocks %@", [self description], mocks);

    _recorders = [[NSMutableArray alloc] init];
    _expectations = [[NSMutableArray alloc] init];
    _rejections = [[NSMutableArray alloc] init];
    _exceptions = [[NSMutableArray alloc] init];

    NSMutableArray *partialMocks = [NSMutableArray arrayWithCapacity:[mocks count]];
    for (id mock in mocks) {
        [[self class] rememberSequencer:self forMock:mock];

        id partialMockForMock = [[[OCPartialMockObject alloc] initWithObject:mock] autorelease];

        // set up expectation and rejection tracking on sequenced mocks
        OCMExpectationSequencer *__block __weak weakSelf = self;
        // forward to real object first, so that we can retrieve the returned recorder
        [[[[partialMockForMock stub] andForwardToRealObject] andDo:^(NSInvocation *invocation) {
            OCMockRecorder *recorder;
            [invocation getReturnValue:&recorder];
            [weakSelf->_recorders addObject:recorder];
            [weakSelf->_expectations addObject:recorder];
        }] expect];
        [[[[partialMockForMock stub] andForwardToRealObject] andDo:^(NSInvocation *invocation) {
            OCMockRecorder *recorder;
            [invocation getReturnValue:&recorder];
            [weakSelf->_recorders addObject:recorder];
            [weakSelf->_rejections addObject:recorder];
        }] reject];
        
        // and record their invocations
        // record the invocations first, before the mock possibly raises an exception
        [[[[partialMockForMock stub] andDo:^(NSInvocation *invocation) {
            NSInvocation *handledInvocation;
            [invocation getArgument:&handledInvocation atIndex:2];
            [weakSelf recordInvocation:handledInvocation];
        }] andForwardToRealObject] handleInvocation:OCMOCK_ANY];

        [partialMocks addObject:partialMockForMock];
    }
    
    _partialMocks = [partialMocks copy];
}

- (void)stopSequencing {
    for (id partialMock in _partialMocks) {
        id realMock = [[[partialMock realObject] retain] autorelease];
        [partialMock stopMocking];
        [[self class] forgetSequencerForMock:realMock];
    }
    [_partialMocks release]; _partialMocks = nil;
    [_recorders release]; _recorders = nil;
    [_expectations release]; _expectations = nil;
    [_rejections release]; _rejections = nil;
    [_exceptions release]; _exceptions = nil;
}

@end
