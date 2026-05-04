/*
    ARM64Processor.h

    A subclass of Exe64Processor that handles arm64 (Apple Silicon) binaries.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "Exe64Processor.h"
#import "Deobfuscator.h"

// AArch64 general-purpose register count (x0-x30 + sp = 32 slots).
#define ARM64_NREGS 32

// Well-known register indices
#define ARM64_X0    0
#define ARM64_X1    1
#define ARM64_X8    8   // indirect result location (stret)
#define ARM64_LR    30  // link register
#define ARM64_SP    31  // stack pointer

// ============================================================================

@interface ARM64Processor : Exe64Processor
{
    GP64RegisterInfo    iRegInfos[ARM64_NREGS];
    UInt64              iHighestJumpTarget;
}

@end
