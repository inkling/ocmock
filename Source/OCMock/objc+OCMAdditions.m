//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2004-2013 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------


#import "objc+OCMAdditions.h"

objc_property_t ocm_class_getPropertyForSelector(Class aClass, SEL aSelector) {
    if (!aClass || !aSelector) return NULL;

    // To determine if the selector is the getter or setter of a property,
    // we build a mapping between all setters and getters and their properties...
    NSString *selectorName = NSStringFromSelector(aSelector);
    static const void *const kPropertiesForSelectorsMapKey = &kPropertiesForSelectorsMapKey;
    NSDictionary *propertiesForSelectorsMap = objc_getAssociatedObject(aClass, kPropertiesForSelectorsMapKey);
    if (!propertiesForSelectorsMap) {
        NSMutableDictionary *mutablePropertiesForSelectorsMap = [NSMutableDictionary dictionary];

        unsigned int outCount, i;
        objc_property_t *properties = class_copyPropertyList(aClass, &outCount);
        for (i = 0; i < outCount; i++) {
            objc_property_t property = properties[i];
            NSString *propertyName = @(property_getName(property));

            // for every property, derive the names of its getter and possibly setter
            NSString *propertyGetterName = nil, *propertySetterName = nil;

            char *propertyGetterStr = property_copyAttributeValue(property, "G");
            if (propertyGetterStr) {
                propertyGetterName = @(propertyGetterStr);
                free(propertyGetterStr);
            } else {
                // use the default getter name
                propertyGetterName = propertyName;
            }
            char *propertySetterStr = property_copyAttributeValue(property, "S");
            if (propertySetterStr) {
                propertySetterName = @(propertySetterStr);
                free(propertySetterStr);
            } else {
                // if the property is not readonly, use the default setter name
                if (!ocm_property_getIsReadonly(property)) {
                    // can't use -[NSString capitalizedString]
                    // because it lowercases existing capital letters in the property name
                    // (that are not at the beginning of the name)
                    NSMutableString *capitalizedPropertyName = [NSMutableString stringWithString:[[propertyName uppercaseString] substringToIndex:1]];
                    if ([propertyName length] > 1) {
                        [capitalizedPropertyName appendString:[propertyName substringFromIndex:1]];
                    }
                    propertySetterName = [@"set" stringByAppendingFormat:@"%@:", capitalizedPropertyName];
                }
            }

            // record the properties corresponding to each setter and getter
            NSValue *propertyValue = [NSValue valueWithBytes:&property objCType:@encode(objc_property_t)];
            mutablePropertiesForSelectorsMap[propertyGetterName] = propertyValue;
            if (propertySetterName) mutablePropertiesForSelectorsMap[propertySetterName] = propertyValue;
        }
        if (properties) free(properties);

        objc_setAssociatedObject(aClass, kPropertiesForSelectorsMapKey, mutablePropertiesForSelectorsMap, OBJC_ASSOCIATION_RETAIN);
        propertiesForSelectorsMap = mutablePropertiesForSelectorsMap;
    }

    // ...then, the selector is a getter or a setter if we have recorded a property for it.
    objc_property_t property = NULL;
    NSValue *propertyValue = propertiesForSelectorsMap[selectorName];
    if (propertyValue) [propertyValue getValue:&property];

    return property;
}

BOOL ocm_property_getIsReadonly(objc_property_t property) {
    NSCParameterAssert(property);

    char *readonlyStr = property_copyAttributeValue(property, "R");
    BOOL isReadonly = (readonlyStr != NULL);
    if (readonlyStr) free(readonlyStr);

    return isReadonly;
}

const char *ocm_property_getTypeEncoding(objc_property_t property) {
    if (!property) return NULL;

    // extract the type encoding from the property
    char *typeStr = property_copyAttributeValue(property, "T");
    NSString *typeString = @(typeStr);
    free(typeStr);

    // for some reason the type encoding string includes
    // the classes of id types after the '@', like "@"NSString""
    // @encode does not do this, and NSMethodSignature will reject such a type string,
    // so we strip the names
    static NSRegularExpression *classNameExpression = nil;
    static dispatch_once_t onceToken2;
    dispatch_once(&onceToken2, ^{
        classNameExpression = [[NSRegularExpression regularExpressionWithPattern:@"\"\\w+\"" options:0 error:NULL] retain];
    });
    typeString = [classNameExpression stringByReplacingMatchesInString:typeString
                                                               options:0
                                                                 range:NSMakeRange(0, [typeString length])
                                                          withTemplate:@""];

    return [typeString UTF8String];
}

const char *ocm_property_getGetterTypeEncoding(objc_property_t property) {
    if (!property) return NULL;

    const char *propertyTypeEncoding = ocm_property_getTypeEncoding(property);
    // getters have signatures like (<propertyType> (*)(id, SEL))
    return [[@(propertyTypeEncoding) stringByAppendingString:@"@:"] UTF8String];
}

const char *ocm_property_getSetterTypeEncoding(objc_property_t property) {
    if (!property || ocm_property_getIsReadonly(property)) return NULL;

    const char *propertyTypeEncoding = ocm_property_getTypeEncoding(property);
    // setters have signatures like (void (*)(id, SEL, <propertyType))
    return [[@"v@:" stringByAppendingString:@(propertyTypeEncoding)] UTF8String];
}
