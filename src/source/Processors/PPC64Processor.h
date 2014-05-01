/*
    PPC64Processor.h

    A subclass of Exe64Processor that handles PPC64-specific issues.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "Exe64Processor.h"

#define MB64(x) ((((x) >> 6) & 0x1f) | (x) & 0x20) // bits 5 - 10, split
#define SH(x) ((((x) >> 12) & 0x0f) | ((x) >> 7) & 0x10) // bits 11 - 15, split
#define DS(x) (SInt64)(BD((x)))     // bits 2 - 15

// ============================================================================

@interface PPC64Processor : Exe64Processor
{
    GP64RegisterInfo    iRegInfos[32];
    GP64RegisterInfo    iLR;
    GP64RegisterInfo    iCTR;

    Var64Info*  iLocalSelves;           // 'self' copied to local variables
    uint32_t      iNumLocalSelves;
    Var64Info*  iLocalVars;
    uint32_t      iNumLocalVars;
}

@end
