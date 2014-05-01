/*
    PPCProcessor.h

    A subclass of ExeProcessor that handles PPC-specific issues.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "Exe32Processor.h"

// from cctools-590/otool/ppc-disasm.c
// The various macros defined in that file get their names from the field
// naming conventions given in the PowerPC Programming Environments Manual
// available at http://www.freescale.com
#define RT(x)   (((x) >> 21) & 0x1f)        // bits 21 - 25
#define RA(x)   (((x) >> 16) & 0x1f)        // bits 16 - 20
#define RB(x)   (((x) >> 11) & 0x1f)        // bits 11 - 15
#define MB(x)   (((x) >> 6) & 0x1f)         // bits 6 - 10
#define ME(x)   (((x) >> 1) & 0x1f)         // bits 1 - 5
#define SV(x)   ((x) & 0x1f)                // bits 0 - 4   "Shift Value"
#define SB(x)   ((x) & 0x20)                // bit 5        "Shift Bit"
#define BO(x)   RT((x))
#define RS(x)   RT((x))

// otool masks the entire instruction with 0xfc000000, rather than accessing
// the primary opcode field directly. Maybe this is to help each case in a
// switch statement stand out, maybe it's faster, who knows... I define a
// PO macro here, and use the values given in the PEM. The SO macro accesses
// the unnamed 10-bit field that specifies secondary opcodes in an instruction
// of the XO(extended operand) form. The SPR macro accesses the "special
// register" field of mfspr and mtspr instructions(LR, CTR). SIMM and UIMM
// access the signed and unsigned immediate values.
#define PO(x)   (((x) >> 26) & 0x3f)        // bits 26 - 31
#define SO(x)   (((x) >> 1) & 0x3ff)        // bits 1 - 10
#define SPR(x)  ((((x) >> 6) & 0x3e0) | (((x) >> 16) & 0x1f))
#define UIMM(x) ((x) & 0xffff)              // bits 0 - 15
#define SIMM(x) (SInt16)((x) & 0xffff)      // bits 0 - 15
#define AA(x)   (((x) >> 1) & 0x1)          // bit 1
#define LK(x)   ((x) & 0x1)                 // bit 0
#define BD(x)   (SInt16)((x) & 0xfffc)      // bits 2 - 15

    // bits 2 - 25, sign extended
#define LI(x)   (SInt32)                    \
    (((x) & 0x02000000) ?                   \
    ((x) & 0x03fffffc) | 0xfc000000 :       \
    ((x) & 0x03fffffc))

// SPR values
#define LR          8
#define CTR         9

// indices into MachineState.regInfos array
#define LRIndex     32
#define CTRIndex    33

#define IS_BLOCK_BRANCH(i)                                          \
    ((PO(i) == 0x10 || PO(i) == 0x12 || PO(i) == 0x13) &&           \
    (!AA(i) && !LK(i)))

#define IS_BRANCH_LINK(i)                                           \
    ((PO(i) == 0x10 && LK(i)) ||                                    \
     (PO(i) == 0x12 && LK(i)) ||                                    \
     (PO(i) == 0x13 && (i & 0x7ff) == 0x421))

#define IS_BRANCH_CONDITIONAL(i)                                    \
    (((PO((i)) == 0x13 && SO((i)) == 0x10) || (PO((i)) == 0x10))    \
    && (BO((i)) != 0x14))

#define IS_BLR(i)   ((i) == 0x4e800020)

// Addresses and names of functions in the ObjC runtime page, stolen from
// http://www.opensource.apple.com/darwinsource/10.4.7.ppc/objc4-267.1/runtime/objc-rtp.h

#define kRTAddress_objc_msgSend             0xfffeff00
#define kRTAddress_objc_assign_ivar         0xfffefec0
#define kRTAddress_objc_assign_global       0xfffefeb0
#define kRTAddress_objc_assign_strongCast   0xfffefea0

#define kRTName_objc_msgSend            "_objc_msgSend_rtp"
#define kRTName_objc_assign_ivar        "_objc_assign_ivar_rtp"
#define kRTName_objc_assign_global      "_objc_assign_global_rtp"
#define kRTName_objc_assign_strongCast  "_objc_assign_strongCast_rtp"

// Addresses and names of some dyld routines, stolen from
// http://www.opensource.apple.com/darwinsource/10.4.7.ppc/Csu-58/dyld.s

#define kDyldAddress_LaSymBindingEntry      0x8fe01000
#define kDyldAddress_FuncLookupPointer      0x8fe01008

#define kDyldName_LaSymBindingEntry     "dyld_lazy_symbol_binding_entry_point"
#define kDyldName_FuncLookupPointer     "dyld_func_lookup_pointer"

// ============================================================================

@interface PPCProcessor : Exe32Processor
{
    GPRegisterInfo  iRegInfos[32];
    GPRegisterInfo  iLR;
    GPRegisterInfo  iCTR;

    VarInfo*    iLocalSelves;           // 'self' copied to local variables
    uint32_t      iNumLocalSelves;
    VarInfo*    iLocalVars;
    uint32_t      iNumLocalVars;
}

@end
