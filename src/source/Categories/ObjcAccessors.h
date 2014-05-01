/*
    ObjcAccessors.h

    What the filename says.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "Exe32Processor.h"

@interface Exe32Processor(ObjcAccessors)

- (BOOL)getObjcClassPtr: (objc_32_class_ptr*)outClass
             fromMethod: (uint32_t)inAddress;
- (BOOL)getObjcClassPtr: (objc_32_class_ptr *)outClassPtr
               fromName: (const char*)inName;
- (BOOL)getObjcMethod: (MethodInfo**)outMI
          fromAddress: (uint32_t)inAddress;

// Obj-C 1 Only
- (BOOL)getObjc1CatPtr: (objc1_32_category**)outCat
            fromMethod: (uint32_t)inAddress;
- (BOOL)getObjc1MethodList: (objc1_32_method_list*)outList
                   methods: (objc1_32_method**)outMethods
               fromAddress: (uint32_t)inAddress;
- (BOOL)getObjc1Description: (char**)outDescription
                 fromObject: (const char*)inObject
                       type: (UInt8)inType;
- (BOOL)getObjc1Symtab: (objc1_32_symtab*)outSymTab
                  defs: (uint32_t **)outDefs
            fromModule: (objc1_32_module*)inModule;
- (BOOL)getObjc1Class: (objc1_32_class*)outClass
              fromDef: (uint32_t)inDef;
- (BOOL)getObjc1Category: (objc1_32_category*)outCat
                 fromDef: (uint32_t)inDef;
- (BOOL)getObjc1Class: (objc1_32_class*)outClass
             fromName: (const char*)inName;
- (BOOL)getObjc1MetaClass: (objc1_32_class*)outClass
                fromClass: (objc1_32_class*)inClass;

@end
