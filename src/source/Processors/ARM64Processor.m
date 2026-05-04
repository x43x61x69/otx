/*
    ARM64Processor.m

    A subclass of Exe64Processor that handles arm64 (Apple Silicon) binaries.
    ARM64 instructions are always 4 bytes (fixed-width), little-endian.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "ARM64Processor.h"
#import "Arch64Specifics.h"
#import "List64Utils.h"
#import "Objc64Accessors.h"
#import "Object64Loader.h"
#import "Searchers64.h"
#import "UserDefaultKeys.h"

// ---------------------------------------------------------------------------
// AArch64 instruction field helpers

// Extract bits [hi:lo] from a 32-bit instruction word.
static inline uint32_t arm64_bits(uint32_t insn, int hi, int lo) {
    return (insn >> lo) & ((1u << (hi - lo + 1)) - 1);
}

// Sign-extend a value of 'bits' width to int64_t.
static inline int64_t arm64_sext(uint64_t val, int bits) {
    int64_t s = (int64_t)(val << (64 - bits));
    return s >> (64 - bits);
}

// Decode Rd (destination register) from bits [4:0].
static inline uint8_t arm64_rd(uint32_t insn) { return insn & 0x1f; }
// Decode Rn from bits [9:5].
static inline uint8_t arm64_rn(uint32_t insn) { return (insn >> 5) & 0x1f; }

// Is this instruction an ADRP?
//   Encoding: 1 | immlo[1:0] | 10000 | immhi[18:0] | Rd[4:0]
static inline BOOL arm64_is_adrp(uint32_t insn) {
    return (insn & 0x9F000000) == 0x90000000;
}

// Decode the ADRP page-relative immediate (sign-extended, page-scaled).
static inline int64_t arm64_adrp_imm(uint32_t insn) {
    uint32_t immlo = arm64_bits(insn, 30, 29);
    uint32_t immhi = arm64_bits(insn, 23, 5);
    uint64_t imm   = ((uint64_t)immhi << 2) | immlo;
    return arm64_sext(imm, 21) << 12;
}

// Is this a 64-bit ADD immediate?
//   Encoding: 1001000100 | sh | imm12 | Rn | Rd
static inline BOOL arm64_is_add_imm64(uint32_t insn) {
    return (insn & 0xFF800000) == 0x91000000;   // sf=1, op=0, S=0, 10001
}

// Decode ADD immediate value (handles LSL#12 shift).
static inline uint64_t arm64_add_imm(uint32_t insn) {
    uint32_t sh   = arm64_bits(insn, 23, 22);
    uint32_t imm  = arm64_bits(insn, 21, 10);
    return sh ? ((uint64_t)imm << 12) : imm;
}

// Is this a 64-bit LDR with unsigned immediate?
//   Encoding: 1111 1000 01xx xxxx xxxx xxxx xxxx xxxx
static inline BOOL arm64_is_ldr_imm64(uint32_t insn) {
    return (insn & 0xFFC00000) == 0xF9400000;
}

// Decode LDR unsigned-offset (scale * imm12, scale = 8 for 64-bit).
static inline uint64_t arm64_ldr_uoff(uint32_t insn) {
    return arm64_bits(insn, 21, 10) * 8;
}

// Is this a BL instruction?
//   Encoding: 100101 | imm26
static inline BOOL arm64_is_bl(uint32_t insn) {
    return (insn & 0xFC000000) == 0x94000000;
}

// Decode BL branch target address given the instruction's PC.
static inline UInt64 arm64_bl_target(uint32_t insn, UInt64 pc) {
    int64_t imm = arm64_sext(insn & 0x03FFFFFF, 26) * 4;
    return (UInt64)((int64_t)pc + imm);
}

// Is this a BLR (indirect call via register)?
//   Encoding: 1101 0110 0011 1111 0000 00xx xxx0 0000
static inline BOOL arm64_is_blr(uint32_t insn) {
    return (insn & 0xFFFFFC1F) == 0xD63F0000;
}

// Is this a 64-bit MOV reg-to-reg? (ORR Xd, XZR, Xm, LSL #0)
//   Encoding: 1010 1010 0000 xxxx 0000 0011 111x xxxx
static inline BOOL arm64_is_mov_reg(uint32_t insn) {
    return (insn & 0xFF2003E0) == 0xAA0003E0;
}

// Decode src register of MOV (= Rm, bits [20:16]).
static inline uint8_t arm64_mov_src(uint32_t insn) {
    return (insn >> 16) & 0x1f;
}

// ---------------------------------------------------------------------------

@implementation ARM64Processor

//  initWithURL:controller:options:
// ----------------------------------------------------------------------------

- (id)initWithURL:(NSURL*)inURL
       controller:(id)inController
          options:(ProcOptions*)inOptions
{
    if ((self = [super initWithURL:inURL controller:inController options:inOptions])) {
        strncpy(iArchString, "arm64", 6);
        iArchSelector            = CPU_TYPE_ARM64;
        iFieldWidths.offset      = 8;
        iFieldWidths.address     = 18;
        iFieldWidths.instruction = 14;  // 4 bytes = 11 hex chars + spaces
        iFieldWidths.mnemonic    = 8;
        iFieldWidths.operands    = 32;
    }
    return self;
}

//  dealloc
// ----------------------------------------------------------------------------

- (void)dealloc
{
    [super dealloc];
}

//  codeFromLine:
// ----------------------------------------------------------------------------
// ARM64 instructions are always 4 bytes.

- (void)codeFromLine:(Line64*)inLine
{
    UInt64 thisAddy = inLine->info.address;
    inLine->info.codeLength = 4;

    unsigned char* theMachPtr = (unsigned char*)iMachHeaderPtr;
    unsigned char* codePtr;

    for (UInt8 i = 0; i < 4; i++) {
        codePtr = (iMachHeader.filetype == MH_OBJECT)
            ? (theMachPtr + (thisAddy + iTextOffset) + i)
            : (theMachPtr + (thisAddy - iTextOffset) + i);
        inLine->info.code[i] = *(UInt8*)codePtr;
    }
}

//  updateRegisters:
// ----------------------------------------------------------------------------
// Track register values for ADRP/ADD/LDR/MOV patterns to resolve addresses
// used by ObjC message sends (x0 = self, x1 = SEL).

- (void)updateRegisters:(Line64*)inLine
{
    if (!inLine->info.isCode)
        return;

    uint32_t insn = OSSwapLittleToHostInt32(*(uint32_t*)inLine->info.code);
    uint8_t  rd   = arm64_rd(insn);
    uint8_t  rn   = arm64_rn(insn);

    if (arm64_is_adrp(insn)) {
        // ADRP Xd, #imm  →  Xd = (PC & ~0xFFF) + (imm << 12)
        UInt64 pageBase = inLine->info.address & ~(UInt64)0xFFF;
        iRegInfos[rd] = (GP64RegisterInfo){0};
        iRegInfos[rd].value   = (UInt64)((int64_t)pageBase + arm64_adrp_imm(insn));
        iRegInfos[rd].isValid = YES;

    } else if (arm64_is_add_imm64(insn)) {
        // ADD Xd, Xn, #imm
        if (iRegInfos[rn].isValid) {
            iRegInfos[rd] = iRegInfos[rn];
            iRegInfos[rd].value += arm64_add_imm(insn);
        } else {
            iRegInfos[rd] = (GP64RegisterInfo){0};
        }

    } else if (arm64_is_ldr_imm64(insn)) {
        // LDR Xt, [Xn, #off]  →  invalidate Xt unless base is known
        uint8_t rt = rd;
        if (iRegInfos[rn].isValid) {
            UInt64 addr = iRegInfos[rn].value + arm64_ldr_uoff(insn);
            char* ptr = [self getPointer:addr type:NULL];
            if (ptr) {
                iRegInfos[rt] = (GP64RegisterInfo){0};
                iRegInfos[rt].value   = *(UInt64*)ptr;
                iRegInfos[rt].isValid = YES;
            } else {
                iRegInfos[rt] = (GP64RegisterInfo){0};
            }
        } else {
            iRegInfos[rt] = (GP64RegisterInfo){0};
        }

    } else if (arm64_is_mov_reg(insn)) {
        // MOV Xd, Xn  (ORR Xd, XZR, Xn)
        uint8_t src = arm64_mov_src(insn);
        iRegInfos[rd] = iRegInfos[src];

    } else if (arm64_is_bl(insn) || arm64_is_blr(insn)) {
        // After a call: x0-x7 (return regs) are clobbered; clear known state.
        for (int i = 0; i <= 7; i++)
            iRegInfos[i] = (GP64RegisterInfo){0};
    }
}

//  commentForLine:
// ----------------------------------------------------------------------------
// Generate human-readable annotations for ARM64 instructions.

- (void)commentForLine:(Line64*)inLine
{
    iLineCommentCString[0] = 0;

    if (!inLine->info.isCode)
        return;

    uint32_t insn = OSSwapLittleToHostInt32(*(uint32_t*)inLine->info.code);

    // ---- BL target: annotate with ObjC msgSend info if applicable ----
    if (arm64_is_bl(insn)) {
        UInt64 target = arm64_bl_target(insn, inLine->info.address);
        char* symPtr  = NULL;

        // Look up the symbol at the branch target.
        char* ptr = [self getPointer:target type:NULL];
        if (ptr) {
            // If the call is to _objc_msgSend (or variant), report the selector.
            if (inLine->alt) {
                // The alternate (verbose) line may already contain the symbol name.
                char* altLine = inLine->alt->chars;
                if (strstr(altLine, "_objc_msgSend")) {
                    symPtr = [self selectorForMsgSend:iLineCommentCString
                                             fromLine:inLine];
                }
            }
        }
        (void)symPtr;
        return;
    }

    // ---- BLR: indirect call; check if x1 (SEL) is known ----
    if (arm64_is_blr(insn)) {
        // Best-effort: if we know x1 try to print the selector.
        if (iRegInfos[ARM64_X1].isValid) {
            char* selPtr = [self getPointer:iRegInfos[ARM64_X1].value type:NULL];
            if (selPtr) {
                snprintf(iLineCommentCString, MAX_COMMENT_LENGTH, "%s", selPtr);
            }
        }
        return;
    }

    // ---- ADRP + (ADD or LDR): try to resolve to a symbol/string ----
    if (arm64_is_adrp(insn)) {
        uint8_t rd = arm64_rd(insn);
        if (iRegInfos[rd].isValid) {
            UInt64 addr = iRegInfos[rd].value;
            char*  ptr  = [self getPointer:addr type:NULL];
            if (ptr) {
                // Only annotate if the target looks like a C string.
                if (*ptr >= 0x20 && *ptr < 0x7f) {
                    snprintf(iLineCommentCString, MAX_COMMENT_LENGTH, "\"%s\"", ptr);
                }
            }
        }
    }
}

//  chooseLine:
// ----------------------------------------------------------------------------
// Prefer the verbose (symbolic) otool output unless the plain one has a
// resolved address that the verbose one replaces with a symbol guess.

- (void)chooseLine:(Line64**)ioLine
{
    if (!(*ioLine)->alt || !(*ioLine)->info.isCode ||
        !(*ioLine)->alt->info.isCode)
        return;

    // For BL instructions with a known symbol, prefer the verbose line.
    uint32_t insn = OSSwapLittleToHostInt32(*(uint32_t*)(*ioLine)->info.code);
    if (arm64_is_bl(insn)) {
        // If verbose line has the symbol name, use it.
        if (strstr((*ioLine)->alt->chars, "_objc_msgSend") ||
            strstr((*ioLine)->alt->chars, "_objc_"))
            *ioLine = (*ioLine)->alt;
    }
}

//  selectorForMsgSend:fromLine:
// ----------------------------------------------------------------------------
// Attempt to fill outComment with the ObjC selector from x1 register state.

- (char*)selectorForMsgSend:(char*)outComment fromLine:(Line64*)inLine
{
    if (!iRegInfos[ARM64_X1].isValid)
        return NULL;

    char* selPtr = [self getPointer:iRegInfos[ARM64_X1].value type:NULL];
    if (!selPtr)
        return NULL;

    snprintf(outComment, MAX_COMMENT_LENGTH, "%s", selPtr);
    return outComment;
}

//  verifyNops:numFound:
// ----------------------------------------------------------------------------
// ARM64 nop checking is not applicable (no NOP-slide obfuscation).

- (BOOL)verifyNops:(unsigned char***)outList numFound:(uint32_t*)outCount
{
    *outList  = NULL;
    *outCount = 0;
    return NO;
}

//  fixNops:toPath:
// ----------------------------------------------------------------------------

- (NSURL*)fixNops:(NopList*)inList toPath:(NSString*)inPath
{
    return nil;
}

@end
