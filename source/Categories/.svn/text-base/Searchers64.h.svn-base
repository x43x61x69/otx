/*
    Searchers64.h

    A category on Exe64Processor that contains the various binary search
    methods.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "Exe64Processor.h"

@interface Exe64Processor(Searchers64)

- (char*)findSymbolByAddress: (uint64_t)inAddress;
- (BOOL)findClassMethod: (Method64Info**)outMI
              byAddress: (UInt64)inAddress;
- (BOOL)findIvar: (objc2_ivar_t**)outIvar
         inClass: (objc2_class_t*)inClass
      withOffset: (UInt64)inOffset;

@end
