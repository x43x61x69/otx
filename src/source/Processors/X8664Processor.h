/*
    X8664Processor.h

    A subclass of Exe64Processor that handles x86_64-specific issues.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "Exe64Processor.h"
#import "Deobfuscator.h"

#define REX_BIT_ON      (1 << 3)
#define REX_BIT_OFF     0

/*#define REX_W(r)    ((r) >> 3 & 0x1)
#define REX_R(r)    ((r) >> 2 & 0x1)    // extends "REG1"
#define REX_X(r)    ((r) >> 1 & 0x1)
#define REX_B(r)    ((r) & 0x1)         // extends "REG2"*/

#define REX_W(x)    ((x) & 0x8)
#define REX_R(x)    ((x) & 0x4)     // extends "REG1"
#define REX_X(x)    ((x) & 0x2)
#define REX_B(x)    ((x) & 0x1)     // extends "REG2"

#define XREG1(n, x) (REG1((n)) | (REX_R((x)) << 1)) 
#define XREG2(n, x) (REG2((n)) | (REX_B(x) << 3))

// Extended register identifiers in r/m field of mod r/m byte
enum {
    R8 = 8,
    R9,
    R10,
    R11,
    R12,
    R13,
    R14,
    R15
};

// ============================================================================

@interface X8664Processor : Exe64Processor
{
    GP64RegisterInfo    iStack[MAX_STACK_SIZE];
    GP64RegisterInfo    iRegInfos[16];

    Var64Info*  iLocalSelves;           // 'self' copied to local variables
    uint32_t      iNumLocalSelves;
    Var64Info*  iLocalVars;
    uint32_t      iNumLocalVars;
    UInt64      iHighestJumpTarget;
}

@end
