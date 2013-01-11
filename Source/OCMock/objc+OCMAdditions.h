//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2004-2013 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------


#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/** This file comprises extensions to the runtime. */

/**
 If aSelector is a setter or getter for a property of aClass,
 returns that property, otherwise NULL.
 
 @param aClass The class to search for a matching property.
 @param aSelector A selector which represents a setter or getter corresponding 
 to some property of aClass.
 @return A pointer of type objc_property_t describing the matching property, 
 or NULL if the class does not declare a property with a setter or getter 
 matching aSelector, or NULL if aClass is Nil or aSelector is NULL.
 */
extern objc_property_t ocm_class_getPropertyForSelector(Class aClass, SEL aSelector);

/**
 Returns YES if a property is readonly, NO otherwise.
 
 @param property A pointer of type objc_property_t describing some property.
 @return YES if property is readonly, NO otherwise.
 @exception NSInternalInconsistencyException if property is NULL.
 */
extern BOOL ocm_property_getIsReadonly(objc_property_t property);

/**
 Returns the type encoding of property.
 
 @param property A pointer of type objc_property_t describing some property.
 @return A string describing the type of property, or NULL if property is NULL.
 */
extern const char *ocm_property_getTypeEncoding(objc_property_t property);

/**
 Returns the type encoding of a property's getter.
 
 @param property A pointer of type objc_property_t describing some property.
 @return A string describing the parameters and return type of property's getter, 
 or NULL if property is NULL.
 */
extern const char *ocm_property_getGetterTypeEncoding(objc_property_t property);

/**
 Returns the type encoding of a property's setter.
 
 @param property A pointer of type objc_property_t describing some property.
 @return A string describing the parameters and return type of property's setter, 
 or NULL if property is readonly, or NULL if property is NULL.
 */
extern const char *ocm_property_getSetterTypeEncoding(objc_property_t property);
