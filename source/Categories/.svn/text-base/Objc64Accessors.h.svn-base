/*
    Objc64Accessors.h

    What the filename says.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "Exe64Processor.h"

@interface Exe64Processor(ObjcAccessors)

- (BOOL)getObjcClassPtr: (objc2_class_t**)outClass
             fromMethod: (UInt64)inAddress;
- (BOOL)getObjcMethod: (Method64Info**)outMI
          fromAddress: (UInt64)inAddress;
- (BOOL)getObjcMethodList: (objc2_method_list_t*)outList
                  methods: (objc2_method_t**)outMethods
              fromAddress: (UInt64)inAddress;
- (BOOL)getObjcDescription: (char**)outDescription
                fromObject: (const char*)inObject
                      type: (UInt8)inType;
- (BOOL)getObjcClass: (objc2_class_t*)outClass
            fromName: (const char*)inName;
- (BOOL)getObjcClassPtr: (objc2_class_t**)outClassPtr
               fromName: (const char*)inName;
- (BOOL)getObjcMetaClass: (objc2_class_t*)outClass
               fromClass: (objc2_class_t*)inClass;

@end
