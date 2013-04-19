/*
    ObjcAccessors.h

    What the filename says.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "Exe32Processor.h"

@interface Exe32Processor(ObjcAccessors)

- (BOOL)getObjcClassPtr: (objc_class**)outClass
             fromMethod: (uint32_t)inAddress;
- (BOOL)getObjcCatPtr: (objc_category**)outCat
           fromMethod: (uint32_t)inAddress;
- (BOOL)getObjcMethod: (MethodInfo**)outMI
          fromAddress: (uint32_t)inAddress;
- (BOOL)getObjcMethodList: (objc_method_list*)outList
                  methods: (objc_method**)outMethods
              fromAddress: (uint32_t)inAddress;
- (BOOL)getObjcDescription: (char**)outDescription
                fromObject: (const char*)inObject
                      type: (UInt8)inType;
- (BOOL)getObjcSymtab: (objc_symtab*)outSymTab
                 defs: (void***)outDefs
           fromModule: (objc_module*)inModule;
- (BOOL)getObjcClass: (objc_class*)outClass
             fromDef: (uint32_t)inDef;
- (BOOL)getObjcCategory: (objc_category*)outCat
                fromDef: (uint32_t)inDef;
- (BOOL)getObjcClass: (objc_class*)outClass
            fromName: (const char*)inName;
- (BOOL)getObjcClassPtr: (objc_class**)outClassPtr
               fromName: (const char*)inName;
- (BOOL)getObjcMetaClass: (objc_class*)outClass
               fromClass: (objc_class*)inClass;

@end
