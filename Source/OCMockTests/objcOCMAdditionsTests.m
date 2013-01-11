//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2004-2013 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import "objcOCMAdditionsTests.h"
#import "objc+OCMAdditions.h"

@interface TestClassWithProperties : NSObject

@property (nonatomic, readwrite, strong)    NSString *readwriteProperty;
@property (nonatomic, readwrite, strong, setter = customSetReadwriteProperty:) NSString *readwritePropertyWithCustomSetter;
@property (nonatomic, readonly)             NSString *readonlyProperty;

@end

@implementation TestClassWithProperties
@dynamic readwriteProperty, readwritePropertyWithCustomSetter, readonlyProperty;
@end


@implementation objcOCMAdditionsTests

#pragma mark - ocm_class_getPropertyForSelector

- (void)testClass_getPropertyForSelectorReturnsNULLIfClassDoesNotDeclarePropertyWithMatchingSetterOrGetter {
    objc_property_t property = ocm_class_getPropertyForSelector([TestClassWithProperties class], @selector(otherProperty));
    STAssertTrue(property == NULL,
                 @"Should have returned NULL because -otherProperty is not a property getter (nor setter, obviously) for TestClassWithProperties.");
}

- (void)testClass_getPropertyForSelectorReturnsNULLIfClassIsNil {
    objc_property_t property = ocm_class_getPropertyForSelector(Nil, @selector(readwriteProperty));
    STAssertTrue(property == NULL,
                 @"Should have returned NULL because the class was Nil.");
}

- (void)testClass_getPropertyForSelectorReturnsNULLIfSelectorIsNULL {
    objc_property_t property = ocm_class_getPropertyForSelector([TestClassWithProperties class], NULL);
    STAssertTrue(property == NULL,
                 @"Should have returned NULL because the selector was NULL.");
}

- (void)testClass_getPropertyForSelectorReturnsExpectedGivenDefaultMethod {
    objc_property_t property = ocm_class_getPropertyForSelector([TestClassWithProperties class], @selector(setReadwriteProperty:));
    STAssertTrue(property != NULL,
                 @"Should have returned a valid property.");
    // must check != NULL here too or else property_getName will throw an exception
    STAssertTrue(property != NULL && strcmp(property_getName(property), "readwriteProperty") == 0,
                 @"Should have returned the @property readwriteProperty for its setter -setReadwriteProperty:");
}

- (void)testClass_getPropertyForSelectorReturnsExpectedGivenCustomMethod {
    objc_property_t property = ocm_class_getPropertyForSelector([TestClassWithProperties class], @selector(customSetReadwriteProperty:));
    STAssertTrue(property != NULL,
                 @"Should have returned a valid property.");
    // must check != NULL here too or else property_getName will throw an exception
    STAssertTrue(property != NULL && strcmp(property_getName(property), "readwritePropertyWithCustomSetter") == 0,
                 @"Should have returned the @property readwritePropertyWithCustomSetter for its setter -customSetReadwriteProperty:");
}

#pragma mark - ocm_property_getIsReadonly

- (void)testProperty_getIsReadonlyThrowsIfPropertyIsNull {
    STAssertThrows(ocm_property_getIsReadonly(NULL), @"Should have thrown because the given property was NULL.");
}

- (void)testProperty_getIsReadonlyReturnsExpected {
    objc_property_t readwriteProperty = class_getProperty([TestClassWithProperties class], "readwriteProperty");
    STAssertTrue(readwriteProperty != NULL, @"Should have returned valid property.");
    STAssertFalse(ocm_property_getIsReadonly(readwriteProperty), @"Should have reported that the property was not readonly.");

    objc_property_t readonlyProperty = class_getProperty([TestClassWithProperties class], "readonlyProperty");
    STAssertTrue(readonlyProperty != NULL, @"Should have returned valid property.");
    STAssertTrue(ocm_property_getIsReadonly(readonlyProperty), @"Should have reported that the property was readonly.");
}

#pragma mark - ocm_property_getTypeEncoding

- (void)testProperty_getTypeEncodingReturnsNULLIfPropertyIsNULL {
    STAssertTrue(ocm_property_getTypeEncoding(NULL) == NULL,
                 @"Should have returned NULL because the property was NULL.");
}

- (void)testProperty_getTypeEncodingReturnsExpected {
    objc_property_t property = class_getProperty([TestClassWithProperties class], "readwriteProperty");
    STAssertTrue(property != NULL, @"Should have returned valid property.");

    // this type encoding says that the property is an id-type
    STAssertTrue(strcmp(ocm_property_getTypeEncoding(property), "@") == 0,
                 @"Returned unexpected type encoding.");
}

#pragma mark - ocm_property_getGetterTypeEncoding

- (void)testProperty_getGetterTypeEncodingReturnsNULLIfPropertyIsNULL {
    STAssertTrue(ocm_property_getGetterTypeEncoding(NULL) == NULL,
                 @"Should have returned NULL because the property was NULL.");
}

- (void)testProperty_getGetterTypeEncodingReturnsExpected {
    objc_property_t property = class_getProperty([TestClassWithProperties class], "readwriteProperty");
    STAssertTrue(property != NULL, @"Should have returned valid property.");

    // this type encoding says that the getter returns an id-type
    // and takes the default arguments self and _cmd
    STAssertTrue(strcmp(ocm_property_getGetterTypeEncoding(property), "@@:") == 0,
                 @"Returned unexpected type encoding.");
}

#pragma mark - ocm_property_getSetterTypeEncoding

- (void)testProperty_getSetterTypeEncodingReturnsNULLIfPropertyIsNULL {
    STAssertTrue(ocm_property_getSetterTypeEncoding(NULL) == NULL,
                 @"Should have returned NULL because the property was NULL.");
}

- (void)testProperty_getSetterTypeEncodingReturnsNULLIfPropertyIsReadonly {
    objc_property_t property = class_getProperty([TestClassWithProperties class], "readonlyProperty");
    STAssertTrue(property != NULL, @"Should have returned valid property.");

    STAssertTrue(ocm_property_getSetterTypeEncoding(property) == NULL,
                 @"Should have returned NULL because the property was readonly.");
}

- (void)testProperty_getSetterTypeEncodingReturnsExpected {
    objc_property_t property = class_getProperty([TestClassWithProperties class], "readwriteProperty");
    STAssertTrue(property != NULL, @"Should have returned valid property.");

    // this type encoding says that the setter returns void,
    // takes the default arguments self and _cmd, and takes an id-type argument
    STAssertTrue(strcmp(ocm_property_getSetterTypeEncoding(property), "v@:@") == 0,
                 @"Returned unexpected type encoding.");
}

@end
