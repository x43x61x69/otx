/*
    X8664Processor.h

    A subclass of Exe64Processor that handles x86_64-specific issues.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "Exe64Processor.h"
#import "Deobfuscator.h"

// Addressing modes in mod field of mod r/m byte (Pentium manual table 2.2)
#define MODimm  0   // [reg]
#define MOD8    1   // [reg] + disp8
#define MOD32   2   // [reg] + disp32
#define MODx    3   // ignored

// Addressing modes in r/m field of mod r/m byte
#define DISP32  5   // disp32 when mod == 0

// Register identifiers in r/m field of mod r/m byte
enum {
    NO_REG  = -1,
    EAX,    // 0
    ECX,    // 1
    EDX,    // 2
    EBX,    // 3
    ESP,    // 4
    EBP,    // 5
    ESI,    // 6
    EDI     // 7
};

#define LO(x)               ((x) & 0xf)
#define HI(x)               (((x) >> 4) & 0xf)
#define MOD(x)              (((x) >> 6) & 0x3)
#define REG1(x)             (((x) >> 3) & 0x7)
#define REG2(x)             ((x) & 0x7)
#define OPEXT(x)            REG1((x))
#define RM(x)               REG2((x))
#define HAS_SIB(x)          (MOD((x)) != MODx && REG2((x)) == ESP)
#define HAS_DISP8(x)        (MOD((x)) == MOD8)
#define HAS_REL_DISP32(x)   (MOD((x)) == MOD32)
#define HAS_ABS_DISP32(x)   (MOD((x)) == MODimm && REG2((x)) == EBP)

#define IS_JUMP(o, so)                                              \
    ((o) == 0xe3 || (o) == 0xe9 || (o) == 0xeb  || (o) == 0xc3 ||   \
    ((o) >= 0x71 && (o) <= 0x7f) ||                                 \
    ((o) == 0x0f && (so) >= 0x81 && (so) <= 0x8f))
#define IS_CALL(o)  ((o) == 0xe8)
#define IS_RET(o)   ((o) == 0xc3)

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

@interface X8664Processor : Exe64Processor<Deobfuscator>
{
    GP64RegisterInfo    iStack[MAX_STACK_SIZE];
    GP64RegisterInfo    iRegInfos[16];

    Var64Info*  iLocalSelves;           // 'self' copied to local variables
    uint32_t      iNumLocalSelves;
    Var64Info*  iLocalVars;
    uint32_t      iNumLocalVars;
    UInt64      iHighestJumpTarget;
}

// Deobfuscator
- (BOOL)verifyNops: (unsigned char***)outList
          numFound: (uint32_t*)outFound;
- (unsigned char**)searchForNopsIn: (unsigned char*)inHaystack
                          ofLength: (uint32_t)inHaystackLength
                          numFound: (uint32_t*)outFound;
- (NSURL*)fixNops: (NopList*)inList
           toPath: (NSString*)inOutputFilePath;

@end
