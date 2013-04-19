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
- (BOOL)findIvar: (objc_ivar*)outIvar
         inClass: (objc_class*)inClass
      withOffset: (uint32_t)inOffset;

@end
