/*
    Searchers.h

    A category on Exe32Processor that contains the various binary search
    methods.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "Exe32Processor.h"

@interface Exe32Processor(Searchers)

- (char*)findSymbolByAddress: (uint32_t)inAddress;
- (BOOL)findClassMethod: (MethodInfo**)outMI
              byAddress: (uint32_t)inAddress;
- (BOOL)findCatMethod: (MethodInfo**)outMI
            byAddress: (uint32_t)inAddress;
- (BOOL)findIvar: (objc1_32_ivar*)outIvar
         inClass: (objc1_32_class*)inClass
      withOffset: (uint32_t)inOffset;
- (BOOL)findIvar: (objc2_32_ivar_t**)outIvar
        inClass2: (objc2_32_class_t*)inClass
      withOffset: (uint32_t)inOffset;

@end
