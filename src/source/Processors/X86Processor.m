/*
    X86Processor.m

    A subclass of Exe32Processor that handles x86-specific issues.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "X86Processor.h"
#import "ArchSpecifics.h"
#import "ListUtils.h"
#import "ObjcAccessors.h"
#import "ObjectLoader.h"
#import "Searchers.h"
#import "SyscallStrings.h"
#import "UserDefaultKeys.h"

#define REUSE_BLOCKS    1

//For debugging -updateRegisters:
// #define UPDATE_REGISTERS_START_DEBUG 0x00000000
// #define UPDATE_REGISTERS_END_DEBUG   0x00000000

// For debugging -commentForLine:
// #define COMMENT_FOR_LINE_DEBUG       0x1999d5

@implementation X86Processor

//  initWithURL:controller:options:
// ----------------------------------------------------------------------------

- (id)initWithURL: (NSURL*)inURL
       controller: (id)inController
          options: (ProcOptions*)inOptions
{
    if ((self = [super initWithURL: inURL
        controller: inController options: inOptions]))
    {
        strncpy(iArchString, "i386", 5);

        iArchSelector               = CPU_TYPE_I386;
        iFieldWidths.offset         = 8;
        iFieldWidths.address        = 10;
        iFieldWidths.instruction    = 24;   // 15 bytes is the real max, but this works
        iFieldWidths.mnemonic       = 14;   // lock/cmpxchgq
        iFieldWidths.operands       = 30;   // 0x00000000(%eax,%eax,4),%xmm0
    }

    return self;
}

//  dealloc
// ----------------------------------------------------------------------------

- (void)dealloc
{
    if (iLocalSelves)
    {
        free(iLocalSelves);
        iLocalSelves    = NULL;
    }

    if (iLocalVars)
    {
        free(iLocalVars);
        iLocalVars  = NULL;
    }

    [super dealloc];
}

//  loadDyldDataSection:
// ----------------------------------------------------------------------------

- (void)loadDyldDataSection: (section*)inSect
{
    [super loadDyldDataSection: inSect];

    if (!iAddrDyldStubBindingHelper)
        return;

    iAddrDyldFuncLookupPointer  = iAddrDyldStubBindingHelper + 12;
}

//  codeFromLine:
// ----------------------------------------------------------------------------

- (void)codeFromLine: (Line*)inLine
{
    UInt8   theInstLength   = 0;
    uint32_t  thisAddy        = inLine->info.address;
    Line*   nextLine        = inLine->next;

    // Try to find next code line.
    while (nextLine)
    {
        if (![self lineIsCode: nextLine->chars])
            nextLine    = nextLine->next;
        else
            break;
    }

    // This instruction size is either the difference of 2 addys or the
    // difference of this addy from the end of the section.
    uint32_t  nextAddy    = iEndOfText;

    if (nextLine)
    {
        uint32_t newNextAddy = [self addressFromLine:nextLine->chars];

        if (newNextAddy > thisAddy && newNextAddy <= thisAddy + 15)
            nextAddy = newNextAddy;
    }

    theInstLength = nextAddy - thisAddy;
    inLine->info.codeLength = theInstLength;

    // Fetch the instruction.
    unsigned char* theMachPtr = (unsigned char*)iMachHeaderPtr;
    unsigned char* codePtr = NULL;
    UInt8 i;

    for (i = 0; i < theInstLength; i++)
    {
        codePtr = (iMachHeader.filetype == MH_OBJECT) ?
            (theMachPtr + (thisAddy + iTextOffset) + i) :
            (theMachPtr + (thisAddy - iTextOffset) + i);
        inLine->info.code[i] = *(UInt8*)codePtr;
    }
}

//  checkThunk:
// ----------------------------------------------------------------------------

- (void)checkThunk: (Line*)inLine
{
    if (!inLine || !inLine->prev || inLine->info.code[1])
        return;

    if (inLine->info.code[0] != 0xc3)
        return;

    uint32_t theInstruction = *(uint32_t*)inLine->prev->info.code;
    ThunkInfo theThunk = {inLine->prev->info.address, NO_REG};

    switch (theInstruction)
    {
        case 0x8b0424:  // movl (%esp,1), %eax
            theThunk.reg    = EAX;
            break;

        case 0x8b0c24:  // movl (%esp,1), %ecx
            theThunk.reg    = ECX;
            break;

        case 0x8b1424:  // movl (%esp,1), %edx
            theThunk.reg    = EDX;
            break;

        case 0x8b1c24:  // movl (%esp,1), %ebx
            theThunk.reg    = EBX;
            break;

        default:
            return;
    }

    // Store a thunk.
    iNumThunks++;
    iThunks = realloc(iThunks, iNumThunks * sizeof(ThunkInfo));
    iThunks[iNumThunks - 1] = theThunk;

    // Recognize it as a function.
    inLine->prev->info.isFunction = YES;

    if (inLine->prev->alt)
        inLine->prev->alt->info.isFunction = YES;
}

//  getThunkInfo:forLine:
// ----------------------------------------------------------------------------
//  Determine whether this line is a call to a get_thunk routine. If so,
//  outRegNum specifies which register is being thunkified.

- (BOOL)getThunkInfo: (ThunkInfo*)outInfo
             forLine: (Line*)inLine
{
    if (!inLine)
    {
        fprintf(stderr, "otx: [X86Processor getThunkInfo:forLine:] "
            "NULL inLine\n");
        return NO;
    }

    if (!inLine->next)
        return NO;

    if (!outInfo)
    {
        fprintf(stderr, "otx: [X86Processor getThunkInfo:forLine:] "
            "NULL outInfo\n");
        return NO;
    }

    if (!iThunks)
        return NO;

    UInt8 opcode = inLine->info.code[0];

    if (opcode != 0xe8) // calll
        return NO;

    BOOL isThunk = NO;
    uint32_t imm = *(uint32_t*)&inLine->info.code[1];
    uint32_t target, i;

    imm = OSSwapInt32(imm);
    target  = imm + inLine->next->info.address;

    for (i = 0; i < iNumThunks; i++)
    {
        if (iThunks[i].address != target)
            continue;

        *outInfo    = iThunks[i];
        isThunk     = YES;
        break;
    }

    return isThunk;
}

#pragma mark -
//  commentForLine:
// ----------------------------------------------------------------------------

- (void)commentForLine: (Line*)inLine;
{
    char*   theDummyPtr = NULL;
    char*   theSymPtr = NULL;
    uint32_t  localAddy = 0;
    uint32_t  targetAddy = 0;
    UInt8   modRM = 0;
    UInt8   opcode = inLine->info.code[0];

    iLineCommentCString[0]  = 0;

#ifdef COMMENT_FOR_LINE_DEBUG
    if (inLine->info.address == COMMENT_FOR_LINE_DEBUG)
    {
        raise(SIGINT);
    }
#endif

    switch (opcode)
    {
        case 0x0f:  // 2-byte and SSE opcodes   **add sysenter support here
        {
            if (inLine->info.code[1] == 0x2e)    // ucomiss
            {
                localAddy = *(uint32_t*)&inLine->info.code[3];
                localAddy = OSSwapLittleToHostInt32(localAddy);

                theDummyPtr = [self getPointer:localAddy type:NULL];
                
                if (theDummyPtr)
                {
                    uint32_t  theInt32    = *(uint32_t*)theDummyPtr;

                    theInt32    = OSSwapLittleToHostInt32(theInt32);
                    snprintf(iLineCommentCString, 30, "%G", *(float*)&theInt32);
                }
            }
            else if (inLine->info.code[1] == 0x84)   // jcc
            {
                if (!inLine->next)
                    break;

                SInt32 targetOffset = *(SInt32*)&inLine->info.code[2];

                targetOffset = OSSwapLittleToHostInt32(targetOffset);
                targetAddy = inLine->next->info.address + targetOffset;

                // Search current FunctionInfo for blocks that start at this address.
                FunctionInfo*   funcInfo    = &iFuncInfos[iCurrentFuncInfoIndex];

                if (!funcInfo->blocks)
                    break;

                uint32_t i;

                for (i = 0; i < funcInfo->numBlocks; i++)
                {
                    if (funcInfo->blocks[i].beginAddress != targetAddy)
                        continue;

                    if (funcInfo->blocks[i].isEpilog)
                        snprintf(iLineCommentCString, 8, "return;");

                    break;
                }
            }
            else if ((inLine->info.code[1] & 0x90) == 0x90) // SETcc + MOVSX + MOVZX + ... ?
            {
                modRM = inLine->info.code[2];
                if (MOD(modRM) == MOD32 && iRegInfos[REG2(modRM)].isValid)
                {
                    uint32_t imm = *(uint32_t*)&inLine->info.code[3];
                    imm = OSSwapLittleToHostInt32(imm);
                    localAddy = iRegInfos[REG2(modRM)].value + imm;
                }
            }

            break;
        }

        case 0x3c:  // cmpb imm8,al
        {
            UInt8 imm = inLine->info.code[1];

            // Check for a single printable 7-bit char.
            if (imm >= 0x20 && imm < 0x7f)
                snprintf(iLineCommentCString, 4, "'%c'", imm);

            break;
        }

        case 0x66:
            if (inLine->info.code[1] != 0x0f ||
                inLine->info.code[2] != 0x2e)    // ucomisd
                break;

            localAddy = *(uint32_t*)&inLine->info.code[4];
            localAddy = OSSwapLittleToHostInt32(localAddy);
            theDummyPtr = [self getPointer:localAddy type:NULL];

            if (theDummyPtr)
            {
                UInt64 theInt64 = *(UInt64*)theDummyPtr;

                theInt64 = OSSwapLittleToHostInt64(theInt64);
                snprintf(iLineCommentCString, 30, "%lG", *(double*)&theInt64);
            }

            break;

        case 0x70: case 0x71: case 0x72: case 0x73: case 0x74: case 0x75: 
        case 0x76: case 0x77: case 0x78: case 0x79: case 0x7a: case 0x7b: 
        case 0x7c: case 0x7d: case 0x7e: case 0xe3: // jcc
        case 0xeb:  // jmp
        {   // FIXME: this doesn't recognize tail calls.
            if (!inLine->next)
                break;

            SInt8 simm = inLine->info.code[1];

            targetAddy = inLine->next->info.address + simm;

            // Search current FunctionInfo for blocks that start at this address.
            FunctionInfo* funcInfo = &iFuncInfos[iCurrentFuncInfoIndex];

            if (!funcInfo->blocks)
                break;

            uint32_t  i;

            for (i = 0; i < funcInfo->numBlocks; i++)
            {
                if (funcInfo->blocks[i].beginAddress != targetAddy)
                    continue;

                if (funcInfo->blocks[i].isEpilog)
                    snprintf(iLineCommentCString, 8, "return;");

                break;
            }

            break;
        }

        // immediate group 1 - add, sub, cmp etc
        case 0x80:  // imm8,r8
        case 0x83:  // imm8,r32
        {
            modRM = inLine->info.code[1];

            // In immediate group 1 we only want cmpb
            if (OPEXT(modRM) != 7)
                break;

            UInt8 imm;
            UInt8 immOffset = 2;

            if (HAS_DISP8(modRM))
                immOffset +=  1;

            imm = inLine->info.code[immOffset];

            if (iRegInfos[REG2(modRM)].classPtr)    // address relative to class
            {
                if (!iRegInfos[REG2(modRM)].isValid)
                    break;

                // Ignore the 4th addressing mode
                if (MOD(modRM) == MODx)
                    break;

                objc_32_class_ptr classPtr = iRegInfos[REG2(modRM)].classPtr;
                immOffset = inLine->info.code[2];

                char *typePtr = NULL;
                if (![self getIvarName:&theSymPtr type:&typePtr withOffset:immOffset inClass:classPtr])
                    break;

                if (theSymPtr)
                {
                    if (iOpts.variableTypes)
                    {
                        char    theTypeCString[MAX_TYPE_STRING_LENGTH];

                        theTypeCString[0]   = 0;

                        [self getDescription:theTypeCString forType:typePtr];
                        snprintf(iLineCommentCString, MAX_COMMENT_LENGTH, "(%s)%s", theTypeCString, theSymPtr);
                    }
                    else
                        snprintf(iLineCommentCString, MAX_COMMENT_LENGTH, "%s", theSymPtr);
                }
            }
            else
                // Check for a single printable 7-bit char.
                if (imm >= 0x20 && imm < 0x7f)
                    snprintf(iLineCommentCString, 4, "'%c'", imm);

            break;
        }

        case 0x2b:  // subl r/m32,r32
        case 0x3b:  // cmpl r/m32,r32
        case 0x81:  // immediate group 1 - imm32,r32
        case 0x88:  // movb r8,r/m8
        case 0x89:  // movl r32,r/m32
        case 0x8a:  // movb r/m8,r8
        case 0x8b:  // movl r/m32,r32
        case 0xc6:  // movb imm8,r/m32
        case 0xf6:  // testb imm8,r/m8
            modRM = inLine->info.code[1];

            // In immediate group 1 we only want cmpl
            if (opcode == 0x81 && OPEXT(modRM) != 7)
                break;

            if (MOD(modRM) == MODimm)   // 1st addressing mode
            {
                if (RM(modRM) == DISP32)
                {
                    localAddy = *(uint32_t*)&inLine->info.code[2];
                    localAddy = OSSwapLittleToHostInt32(localAddy);
                }
            }
            else
            {
                if (iRegInfos[REG2(modRM)].classPtr)    // address relative to class
                {
                    if (!iRegInfos[REG2(modRM)].isValid)
                        break;

                    // Ignore the 4th addressing mode
                    if (MOD(modRM) == MODx)
                        break;

                    objc_32_class_ptr classPtr = iRegInfos[REG2(modRM)].classPtr;
                    uint32 offset = 0;

                    if (MOD(modRM) == MOD8)
                    {
                        offset = (SInt8)inLine->info.code[2];
                    }
                    else if (MOD(modRM) == MOD32)
                    {
                        offset = *(uint32_t*)&inLine->info.code[2];
                        offset = OSSwapLittleToHostInt32(offset);
                    }

                    char *typePtr = NULL;
                    if (![self getIvarName:&theSymPtr type:&typePtr withOffset:offset inClass:classPtr])
                        break;

                    if (theSymPtr)
                    {
                        if (iOpts.variableTypes)
                        {
                            char theTypeCString[MAX_TYPE_STRING_LENGTH];

                            theTypeCString[0] = 0;

                            [self getDescription:theTypeCString forType:typePtr];
                            snprintf(iLineCommentCString, MAX_COMMENT_LENGTH, "(%s)%s", theTypeCString, theSymPtr);
                        }
                        else
                            snprintf(iLineCommentCString, MAX_COMMENT_LENGTH, "%s", theSymPtr);
                    }
                }
                else if (MOD(modRM) == MOD32)   // absolute address
                {
                    if (HAS_SIB(modRM))
                        break;

                    if (iRegInfos[REG2(modRM)].isValid)
                    {
                        uint32_t imm = *(uint32_t*)&inLine->info.code[2];
                        imm = OSSwapLittleToHostInt32(imm);
                        localAddy = iRegInfos[REG2(modRM)].value + imm;
                    }
                }
                else if (MOD(modRM) == MOD8)   // absolute address
                {
                    if (HAS_SIB(modRM))
                        break;

                    if (iRegInfos[REG2(modRM)].isValid)
                    {
                        SInt8 imm = (SInt8)inLine->info.code[2];
                        localAddy = iRegInfos[REG2(modRM)].value + imm;
                    }
                }
            }

            break;

        case 0x8d:  // leal
            modRM = inLine->info.code[1];

            if (iRegInfos[REG2(modRM)].classPtr)    // address relative to class
            {
                if (!iRegInfos[REG2(modRM)].isValid)
                    break;

                // Ignore the 1st and 4th addressing modes
                if (MOD(modRM) == MODimm || MOD(modRM) == MODx)
                    break;

                objc_32_class_ptr classPtr = iRegInfos[REG2(modRM)].classPtr;
                uint32 offset = 0;

                if (MOD(modRM) == MOD8)
                {
                    offset = (sint8)inLine->info.code[2];
                }
                else if (MOD(modRM) == MOD32)
                {
                    offset = *(uint32_t*)&inLine->info.code[2];
                    offset = OSSwapLittleToHostInt32(offset);
                }

                char *typePtr = NULL;
                if (![self getIvarName:&theSymPtr type:&typePtr withOffset:offset inClass:classPtr])
                    break;

                if (theSymPtr)
                {
                    if (iOpts.variableTypes)
                    {
                        char    theTypeCString[MAX_TYPE_STRING_LENGTH];

                        theTypeCString[0]   = 0;

                        [self getDescription:theTypeCString forType:typePtr];
                        snprintf(iLineCommentCString, MAX_COMMENT_LENGTH, "(%s)%s", theTypeCString, theSymPtr);
                    }
                    else
                        snprintf(iLineCommentCString, MAX_COMMENT_LENGTH, "%s", theSymPtr);
                }
            }
            else if (iRegInfos[REG2(modRM)].isValid)
            {
                uint32_t imm = *(uint32_t*)&inLine->info.code[2];

                imm = OSSwapLittleToHostInt32(imm);
                localAddy = iRegInfos[REG2(modRM)].value + imm;
            }
            else
            {
                localAddy = *(uint32_t*)&inLine->info.code[2];
                localAddy = OSSwapLittleToHostInt32(localAddy);
            }

            break;

        case 0xa1:  // movl moffs32,r32
        case 0xa3:  // movl r32,moffs32
            localAddy = *(uint32_t*)&inLine->info.code[1];
            localAddy = OSSwapLittleToHostInt32(localAddy);
            break;

        case 0xb0:  // movb imm8,%al
        case 0xb1:  // movb imm8,%cl
        case 0xb2:  // movb imm8,%dl
        case 0xb3:  // movb imm8,%bl
        case 0xb4:  // movb imm8,%ah
        case 0xb5:  // movb imm8,%ch
        case 0xb6:  // movb imm8,%dh
        case 0xb7:  // movb imm8,%bh
        {
            UInt8 imm = inLine->info.code[1];

            // Check for a single printable 7-bit char.
            if (imm >= 0x20 && imm < 0x7f)
                snprintf(iLineCommentCString, 4, "'%c'", imm);

            break;
        }

        case 0xb8:  // movl imm32,%eax
        case 0xb9:  // movl imm32,%ecx
        case 0xba:  // movl imm32,%edx
        case 0xbb:  // movl imm32,%ebx
        case 0xbc:  // movl imm32,%esp
        case 0xbd:  // movl imm32,%ebp
        case 0xbe:  // movl imm32,%esi
        case 0xbf:  // movl imm32,%edi
            localAddy = *(uint32_t*)&inLine->info.code[1];
            localAddy = OSSwapLittleToHostInt32(localAddy);

            // Check for a four char code.
            if (localAddy >= 0x20202020 && localAddy < 0x7f7f7f7f)
            {
                char*   fcc = (char*)&localAddy;

                if (fcc[0] >= 0x20 && fcc[0] < 0x7f &&
                    fcc[1] >= 0x20 && fcc[1] < 0x7f &&
                    fcc[2] >= 0x20 && fcc[2] < 0x7f &&
                    fcc[3] >= 0x20 && fcc[3] < 0x7f)
                {
                    #if __LITTLE_ENDIAN__   // reversed on purpose
                        localAddy   = OSSwapInt32(localAddy);
                    #endif

                    snprintf(iLineCommentCString,
                        7, "'%.4s'", fcc);
                }
            }
            else    // Check for a single printable 7-bit char.
            if (localAddy >= 0x20 && localAddy < 0x7f)
            {
                snprintf(iLineCommentCString, 4, "'%c'", localAddy);
            }

            break;

        case 0xc7:  // movl imm32,r/m32
        {
            modRM = inLine->info.code[1];

            if (iRegInfos[REG2(modRM)].classPtr)    // address relative to class
            {
                if (!iRegInfos[REG2(modRM)].isValid)
                    break;

                // Ignore the 1st and 4th addressing modes
                if (MOD(modRM) == MODimm || MOD(modRM) == MODx)
                    break;

                UInt8 immOffset = 2;
                char fcc[7] = {0};

                if (HAS_DISP8(modRM))
                    immOffset += 1;
                else if (HAS_REL_DISP32(modRM))
                    immOffset += 4;

                if (HAS_SIB(modRM))
                    immOffset += 1;

                objc_32_class_ptr classPtr = iRegInfos[REG2(modRM)].classPtr;
                uint32_t offset = 0;

                if (MOD(modRM) == MOD8)
                {
                    offset = (SInt8)inLine->info.code[immOffset - 1];
                }
                else if (MOD(modRM) == MOD32)
                {
                    uint32_t imm = *(uint32_t*)&inLine->info.code[immOffset];
                    imm = OSSwapLittleToHostInt32(imm);

                    // offset precedes immediate value
                    offset = *(uint32_t*)&inLine->info.code[immOffset - 4];
                    offset = OSSwapLittleToHostInt32(offset);

                    // Check for a four char code.
                    if (imm >= 0x20202020 && imm < 0x7f7f7f7f)
                    {
                        char*   tempFCC = (char*)&imm;

                        if (tempFCC[0] >= 0x20 && tempFCC[0] < 0x7f &&
                            tempFCC[1] >= 0x20 && tempFCC[1] < 0x7f &&
                            tempFCC[2] >= 0x20 && tempFCC[2] < 0x7f &&
                            tempFCC[3] >= 0x20 && tempFCC[3] < 0x7f)
                        {
                            #if __LITTLE_ENDIAN__   // reversed on purpose
                                imm = OSSwapInt32(imm);
                            #endif

                            snprintf(fcc, 7, "'%.4s'", tempFCC);
                        }
                    }
                    else    // Check for a single printable 7-bit char.
                    if (imm >= 0x20 && imm < 0x7f)
                    {
                        snprintf(fcc, 4, "'%c'", imm);
                    }
                }

                char *typePtr = NULL;
                if (![self getIvarName:&theSymPtr type:&typePtr withOffset:offset inClass:classPtr])
                    break;

                char    tempComment[MAX_COMMENT_LENGTH];

                tempComment[0]  = 0;

                // copy four char code and/or var name to comment.
                if (fcc[0])
                    strncpy(tempComment, fcc, strlen(fcc) + 1);

                if (theSymPtr)
                {
                    if (fcc[0])
                        strncat(tempComment, " ", 2);

                    size_t tempCommentLength = strlen(tempComment);

                    if (iOpts.variableTypes)
                    {
                        char    theTypeCString[MAX_TYPE_STRING_LENGTH];

                        theTypeCString[0]   = 0;

                        [self getDescription:theTypeCString forType:typePtr];
                        snprintf(&tempComment[tempCommentLength],
                            MAX_COMMENT_LENGTH - tempCommentLength - 1,
                            "(%s)%s", theTypeCString, theSymPtr);
                    }
                    else
                        strncat(tempComment, theSymPtr,
                            MAX_COMMENT_LENGTH - tempCommentLength - 1);
                }

                if (tempComment[0])
                    snprintf(iLineCommentCString, MAX_COMMENT_LENGTH, "%s", tempComment);
            }
            else    // absolute address
            {
                UInt8 immOffset = 2;

                if (HAS_DISP8(modRM))
                    immOffset += 1;

                if (HAS_SIB(modRM))
                    immOffset += 1;

                localAddy = *(uint32_t*)&inLine->info.code[immOffset];
                localAddy = OSSwapLittleToHostInt32(localAddy);

                // Check for a four char code.
                if (localAddy >= 0x20202020 && localAddy < 0x7f7f7f7f)
                {
                    char*   fcc = (char*)&localAddy;

                    if (fcc[0] >= 0x20 && fcc[0] < 0x7f &&
                        fcc[1] >= 0x20 && fcc[1] < 0x7f &&
                        fcc[2] >= 0x20 && fcc[2] < 0x7f &&
                        fcc[3] >= 0x20 && fcc[3] < 0x7f)
                    {
                        #if __LITTLE_ENDIAN__   // reversed on purpose
                            localAddy   = OSSwapInt32(localAddy);
                        #endif

                        snprintf(iLineCommentCString,
                            7, "'%.4s'", fcc);
                    }
                }
                else    // Check for a single printable 7-bit char.
                if (localAddy >= 0x20 && localAddy < 0x7f)
                    snprintf(iLineCommentCString, 4, "'%c'", localAddy);
            }

            break;
        }

        case 0xcd:  // int
            modRM = inLine->info.code[1];

            if (modRM == 0x80)
                [self commentForSystemCall];

            break;

        case 0xd9:  // fldsl    r/m32
        case 0xdd:  // fldll
            modRM = inLine->info.code[1];

            if (iRegInfos[REG2(modRM)].classPtr)    // address relative to class
            {
                if (!iRegInfos[REG2(modRM)].isValid)
                    break;

                // Ignore the 1st and 4th addressing modes
                if (MOD(modRM) == MODimm || MOD(modRM) == MODx)
                    break;

                objc_32_class_ptr classPtr = iRegInfos[REG2(modRM)].classPtr;
                uint32 offset = 0;

                if (MOD(modRM) == MOD8)
                {
                    offset = (SInt8)inLine->info.code[2];
                }
                else if (MOD(modRM) == MOD32)
                {
                    offset = *(uint32_t*)&inLine->info.code[2];
                    offset = OSSwapLittleToHostInt32(offset);
                }

                char *typePtr = NULL;
                if (![self getIvarName:&theSymPtr type:&typePtr withOffset:offset inClass:classPtr])
                    break;

                if (theSymPtr)
                {
                    if (iOpts.variableTypes)
                    {
                        char    theTypeCString[MAX_TYPE_STRING_LENGTH];

                        theTypeCString[0]   = 0;

                        [self getDescription:theTypeCString forType:typePtr];
                        snprintf(iLineCommentCString, MAX_COMMENT_LENGTH, "(%s)%s", theTypeCString, theSymPtr);
                    }
                    else
                        snprintf(iLineCommentCString, MAX_COMMENT_LENGTH, "%s", theSymPtr);
                }
            }
            else    // absolute address
            {
                UInt8 immOffset = 2;

                if (HAS_DISP8(modRM))
                    immOffset += 1;

                if (HAS_SIB(modRM))
                    immOffset += 1;

                localAddy = *(uint32_t*)&inLine->info.code[immOffset];
                localAddy = OSSwapLittleToHostInt32(localAddy);
                theDummyPtr = [self getPointer:localAddy type:NULL];

                if (!theDummyPtr)
                    break;

                if (LO(opcode) == 0x9)  // fldsl
                {
                    uint32_t  theInt32    = *(uint32_t*)theDummyPtr;

                    theInt32    = OSSwapLittleToHostInt32(theInt32);

                    // dance around printf's type coersion
                    snprintf(iLineCommentCString,
                        30, "%G", *(float*)&theInt32);
                }
                else if (LO(opcode) == 0xd) // fldll
                {
                    UInt64  theInt64    = *(UInt64*)theDummyPtr;

                    theInt64    = OSSwapLittleToHostInt64(theInt64);

                    // dance around printf's type coersion
                    snprintf(iLineCommentCString,
                        30, "%lG", *(double*)&theInt64);
                }
            }

            break;

        case 0xe8:  // call
        case 0xe9:  // jmp
        {
            // Insert anonymous label if there's not a label yet.
            if (iLineCommentCString[0])
                break;

            localAddy = *(uint32_t*)&inLine->info.code[1];
            localAddy = OSSwapLittleToHostInt32(localAddy);

            uint32_t absoluteAddy = inLine->info.address + 5 + (SInt32)localAddy;

// FIXME: can we use mCurrentFuncInfoIndex here?
            FunctionInfo    searchKey   = {absoluteAddy, NULL, 0, 0};
            FunctionInfo*   funcInfo    = bsearch(&searchKey,
                iFuncInfos, iNumFuncInfos, sizeof(FunctionInfo),
                (COMPARISON_FUNC_TYPE)Function_Info_Compare);

            if (funcInfo && funcInfo->genericFuncNum != 0)
                snprintf(iLineCommentCString,
                    ANON_FUNC_BASE_LENGTH + 11, "%s%d",
                    ANON_FUNC_BASE, funcInfo->genericFuncNum);

            break;
        }

        case 0xf2:  // repne/repnz or movsd, mulsd etc
        case 0xf3:  // rep/repe or movss, mulss etc
        {
            UInt8 byte2 = inLine->info.code[1];

            if (byte2 != 0x0f)  // movsd/s, divsd/s, addsd/s etc
                break;

            modRM = inLine->info.code[3];

            if (iRegInfos[REG2(modRM)].classPtr)    // address relative to self
            {
                if (!iRegInfos[REG2(modRM)].isValid)
                    break;

                // Ignore the 1st and 4th addressing modes
                if (MOD(modRM) == MODimm || MOD(modRM) == MODx)
                    break;

                objc_32_class_ptr classPtr = iRegInfos[REG2(modRM)].classPtr;
                uint32 offset = 0;

                if (MOD(modRM) == MOD8)
                {
                    offset = (SInt8)inLine->info.code[2];
                }
                else if (MOD(modRM) == MOD32)
                {
                    offset = *(uint32_t*)&inLine->info.code[2];
                    offset = OSSwapLittleToHostInt32(offset);
                }

                char *typePtr = NULL;
                if (![self getIvarName:&theSymPtr type:&typePtr withOffset:offset inClass:classPtr])
                    break;

                if (theSymPtr)
                {
                    if (iOpts.variableTypes)
                    {
                        char    theTypeCString[MAX_TYPE_STRING_LENGTH];

                        theTypeCString[0]   = 0;

                        [self getDescription:theTypeCString forType:typePtr];

                        snprintf(iLineCommentCString, MAX_COMMENT_LENGTH, "(%s)%s", theTypeCString, theSymPtr);
                    }
                    else
                        snprintf(iLineCommentCString, MAX_COMMENT_LENGTH, "%s", theSymPtr);
                }
            }
            else    // absolute address
            {
                localAddy = *(uint32_t*)&inLine->info.code[4];
                localAddy = OSSwapLittleToHostInt32(localAddy);
                theDummyPtr = [self getPointer:localAddy type:NULL];

                if (theDummyPtr)
                {
                    if (LO(opcode) == 0x3)
                    {
                        uint32_t  theInt32    = *(uint32_t*)theDummyPtr;

                        theInt32    = OSSwapLittleToHostInt32(theInt32);
                        snprintf(iLineCommentCString,
                            30, "%G", *(float*)&theInt32);
                    }
                    else if (LO(opcode) == 0x2)
                    {
                        UInt64  theInt64    = *(UInt64*)theDummyPtr;

                        theInt64    = OSSwapLittleToHostInt64(theInt64);
                        snprintf(iLineCommentCString,
                            30, "%lG", *(double*)&theInt64);
                    }
                }
            }

            break;
        }

        default:
            break;
    }   // switch (opcode)

    if (!iLineCommentCString[0])
    {
        UInt8   theType     = PointerType;
        uint32_t  theValue;

        theSymPtr = [self findSymbolByAddress:localAddy];

        theDummyPtr = [self getPointer:localAddy type:&theType];

        if (theDummyPtr)
        {
            switch (theType)
            {
                case DataGenericType:
                    theValue    = *(uint32_t*)theDummyPtr;
                    theValue    = OSSwapLittleToHostInt32(theValue);
                    theDummyPtr = [self getPointer:theValue type:&theType];

                    switch (theType)
                    {
                        case PointerType:
                            theSymPtr   = theDummyPtr;
                            break;

                        default:
                            theSymPtr   = NULL;
                            break;
                    }

                    break;

                case PStringType:
                case PointerType:
                case OCClassRefType:
                case OCMsgRefType:
                case OCSelRefType:
                case OCSuperRefType:
                    theSymPtr   = theDummyPtr;

                    break;

                case CFStringType:
                {
                    cfstring_object theCFString =  *(cfstring_object*)theDummyPtr;

                    if (theCFString.oc_string.length == 0)
                    {
                        theSymPtr   = NULL;
                        break;
                    }

                    theValue    = theCFString.oc_string.chars;
                    theValue    = OSSwapLittleToHostInt32(theValue);
                    theSymPtr   = [self getPointer:theValue type:NULL];

                    break;
                }
                case ImpPtrType:
                case NLSymType:
                {
                    theValue    = *(uint32_t*)theDummyPtr;
                    theValue    = OSSwapLittleToHostInt32(theValue);
                    theDummyPtr = [self getPointer:theValue type:NULL];

                    if (!theDummyPtr)
                    {
                        theSymPtr = [self findSymbolByAddress:theValue];
                        break;
                    }

                    theValue    = *(uint32_t*)(theDummyPtr + 4);
                    theValue    = OSSwapLittleToHostInt32(theValue);

                    if (theValue != typeid_NSString)
                    {
                        theValue    = *(uint32_t*)theDummyPtr;
                        theValue    = OSSwapLittleToHostInt32(theValue);
                        theDummyPtr = [self getPointer:theValue type:NULL];

                        if (!theDummyPtr)
                        {
                            theSymPtr   = NULL;
                            break;
                        }
                    }

                    cfstring_object theCFString = *(cfstring_object*)theDummyPtr;

                    if (theCFString.oc_string.length == 0)
                    {
                        theSymPtr   = NULL;
                        break;
                    }

                    theValue    = theCFString.oc_string.chars;
                    theValue    = OSSwapLittleToHostInt32(theValue);
                    theSymPtr   = [self getPointer:theValue type:NULL];

                    break;
                }

                case OCGenericType:
                case OCStrObjectType:
                case OCClassType:
                case OCModType:
                    [self getObjc1Description:&theSymPtr fromObject:theDummyPtr type:theType];

                    break;

                default:
                    break;
            }
        }

        if (theSymPtr)
        {
            if (theType == PStringType)
                snprintf(iLineCommentCString, 255,
                    "%*s", theSymPtr[0], theSymPtr + 1);
            else
                snprintf(iLineCommentCString, MAX_COMMENT_LENGTH, "%s", theSymPtr);
        }
    }
}

//  commentForSystemCall
// ----------------------------------------------------------------------------
//  System call number is stored in EAX, possible values defined in
//  <sys/syscall.h>. Call numbers are indices into a lookup table of handler
//  routines. Args being passed to the looked-up handler are on the stack.

- (void)commentForSystemCall
{
    if (!iRegInfos[EAX].isValid ||
         iRegInfos[EAX].value > SYS_MAXSYSCALL)
    {
        snprintf(iLineCommentCString, 11, "syscall(?)");
        return;
    }

    BOOL        isIndirect  = (iRegInfos[EAX].value == SYS_syscall);
    uint32_t      syscallNum;
    uint32_t      syscallArgIndex = (isIndirect) ? 1 : 0;
    const char* theSysString    = NULL;

    if (isIndirect && iStack[0].isValid &&
        iStack[0].value <= SYS_MAXSYSCALL)
        syscallNum  = iStack[0].value;
    else
        syscallNum  = iRegInfos[EAX].value;

    theSysString    = gSysCalls[syscallNum];

    if (!theSysString)
        return;

    char    theTempComment[50];

    theTempComment[0]   = 0;

    strncpy(theTempComment, theSysString, strlen(theSysString) + 1);

    // Handle various system calls.
    switch(syscallNum)
    {
        case SYS_ptrace:
            if (iStack[syscallArgIndex].isValid &&
                iStack[syscallArgIndex].value == PT_DENY_ATTACH)
                snprintf(iLineCommentCString, 40, "%s(%s)",
                    theTempComment, "PT_DENY_ATTACH");
            else
                snprintf(iLineCommentCString, MAX_COMMENT_LENGTH, "%s", theTempComment);

            break;

        default:
            snprintf(iLineCommentCString, MAX_COMMENT_LENGTH, "%s", theTempComment);

            break;
    }
}

//  selectorForMsgSend:fromLine:
// ----------------------------------------------------------------------------

- (char*)selectorForMsgSend: (char*)outComment
                   fromLine: (Line*)inLine
{
    char* selString = NULL;
    UInt8 opcode = inLine->info.code[0];

    // Bail if this is not an eligible jump.
    if (opcode != 0xe8  &&  // calll
        opcode != 0xe9)     // jmpl
        return NULL;

    // Bail if this is not an objc_msgSend variant.
    // FIXME: this is redundant now.
    if (memcmp(outComment, "_objc_msgSend", 13))
        return NULL;

    // Store the variant type locally to reduce string comparisons.
    uint32_t  sendType    = [self sendTypeFromMsgSend:outComment];
//    uint32_t  receiverAddy;
    uint32_t  selectorAddy;

    // Make sure we know what the selector is.
    if (sendType == sendSuper_stret || sendType == send_stret)
    {
        if (iStack[2].isValid)
        {
            selectorAddy    = iStack[2].value;
//            receiverAddy    = (iStack[1].isValid) ?
//                iStack[1].value : 0;
        }
        else
        {
            if (iOpts.debugMode)
                fprintf(stderr, "%x: selector match: iStack[2].isValid == NO\n", inLine->info.address);

            return NULL;
        }
    }
    else
    {
        if (iStack[1].isValid)
        {
            selectorAddy    = iStack[1].value;
//            receiverAddy    = (iStack[0].isValid) ?
//                iStack[0].value : 0;
        }
        else
        {
            if (iOpts.debugMode)
                fprintf(stderr, "%x: selector match: iStack[1].isValid == NO\n", inLine->info.address);

            return NULL;
        }
    }

    // sanity check
    if (!selectorAddy)
    {
        if (iOpts.debugMode)
            fprintf(stderr, "%x: selector match: selectorAddy == nil\n", inLine->info.address);

        return NULL;
    }

    UInt8   selType = PointerType;
    char*   selPtr  = [self getPointer:selectorAddy type:&selType];

    switch (selType)
    {
        case PointerType:
        case OCSelRefType:
            selString   = selPtr;

            break;

        case OCGenericType:
            if (selPtr)
            {
                uint32_t  selPtrValue = *(uint32_t*)selPtr;

                selPtrValue = OSSwapLittleToHostInt32(selPtrValue);
                selString   = [self getPointer:selPtrValue type:NULL];

                if (!selString && iOpts.debugMode)
                    fprintf(stderr, "%x: selector match returning nil.  selectorAddy=0x%x, selPtrValue=0x%x\n", inLine->info.address, (unsigned int)selectorAddy, selPtrValue);
            }

            break;

        default:
            fprintf(stderr, "otx: [X86Processor selectorForMsgSend:fromLine:]: "
                "unsupported selector type: %d at address: 0x%x\n",
                selType, inLine->info.address);

            break;
    }
    
    if (!selString && (!selPtr || (selType != OCGenericType)))
    {
        if (iOpts.debugMode)
            fprintf(stderr, "%x: selector match returning nil.  selectorAddy=0x%x, selType=%d\n", inLine->info.address, (unsigned int)selectorAddy, selType);
    }


    return selString;
}

//  commentForMsgSend:fromLine:
// ----------------------------------------------------------------------------

- (void)commentForMsgSend: (char*)ioComment
                 fromLine: (Line*)inLine
{
    char    tempComment[MAX_COMMENT_LENGTH];

    tempComment[0]  = 0;

    if (!strncmp(ioComment, "_objc_msgSend", 13))
    {
        char* selString = [self selectorForMsgSend:ioComment fromLine:inLine];

        // Bail if we couldn't find the selector.
        if (!selString)
        {
            iMissedSelectorCount++;
            return;
        }
        
        iMatchedSelectorCount++;

        UInt8   sendType    = [self sendTypeFromMsgSend:ioComment];

        // Get the address of the class name string, if this a class method.
        uint32_t  classNameAddy   = 0;

        // If *.classPtr is non-NULL, it's not a name string.
        if (sendType == sendSuper_stret || sendType == send_stret)
        {
            if (iStack[1].isValid && !iStack[1].classPtr)
                classNameAddy   = iStack[1].value;
        }
        else
        {
            if (iStack[0].isValid && !iStack[0].classPtr)
                classNameAddy   = iStack[0].value;
        }

        char*   className           = NULL;
        char*   returnTypeString    =
            (sendType == sendSuper_stret || sendType == send_stret) ?
            "(struct)" : (sendType == send_fpret) ? "(double)" : "";

        if (classNameAddy)
        {
            // Get at the class name
            UInt8   classNameType   = PointerType;
            char*   classNamePtr    = [self getPointer:classNameAddy type:&classNameType];

            switch (classNameType)
            {
                // Receiver can be a static string or pointer in these sections, but we
                // only want to display class names as receivers.
                case DataGenericType:
                case DataConstType:
                case CFStringType:
                case ImpPtrType:
                case NLSymType:
                case OCStrObjectType:
                    break;

                case PointerType:
                case OCClassRefType:
                    className   = classNamePtr;
                    break;

                case OCGenericType:
                    if (classNamePtr)
                    {
                        uint32_t  namePtrValue    = *(uint32_t*)classNamePtr;

                        namePtrValue    = OSSwapLittleToHostInt32(namePtrValue);
                        className   = [self getPointer:namePtrValue type:NULL];
                    }

                    break;

                case OCClassType:
                    if (classNamePtr)
                        [self getObjc1Description:&className fromObject:classNamePtr type:OCClassType];

                    break;

                default:
                    fprintf(stderr, "otx: [X86Processor commentForMsgSend]: "
                        "unsupported class name type: %d at address: 0x%x\n",
                        classNameType, inLine->info.address);

                    break;
            }
        }

        if (className)
        {
            snprintf(ioComment, MAX_COMMENT_LENGTH,
                ((sendType == sendSuper || sendType == sendSuper_stret) ?
                "+%s[[%s super] %s]" : "+%s[%s %s]"),
                returnTypeString, className, selString);
        }
        else
        {
            switch (sendType)
            {
                case send:
                case send_fpret:
                case send_variadic:
                    snprintf(ioComment, MAX_COMMENT_LENGTH, "-%s[(%%esp,1) %s]", returnTypeString, selString);
                    break;

                case sendSuper:
                    snprintf(ioComment, MAX_COMMENT_LENGTH, "-%s[[(%%esp,1) super] %s]", returnTypeString, selString);
                    break;

                case send_stret:
                    snprintf(ioComment, MAX_COMMENT_LENGTH, "-%s[0x04(%%esp,1) %s]", returnTypeString, selString);
                    break;

                case sendSuper_stret:
                    snprintf(ioComment, MAX_COMMENT_LENGTH, "-%s[[0x04(%%esp,1) super] %s]", returnTypeString, selString);
                    break;

                default:
                    break;
            }
        }
    }
    else if (!strncmp(ioComment, "_objc_assign_ivar", 17))
    {
        if (iCurrentClass && iStack[2].isValid)
        {
            char *name = NULL;
            char *type = NULL;

            if (![self getIvarName:&name type:&type withOffset:iStack[2].value inClass:iCurrentClass])
                return;

            if (iOpts.variableTypes)
            {
                char    theTypeCString[MAX_TYPE_STRING_LENGTH];

                theTypeCString[0]   = 0;

                [self getDescription:theTypeCString forType:type];
                snprintf(tempComment, MAX_COMMENT_LENGTH, " (%s)%s", theTypeCString, name);
            }
            else
                snprintf(tempComment, MAX_COMMENT_LENGTH, " %s", name);

            strncat(ioComment, tempComment, strlen(tempComment));
        }
    }
}

//  chooseLine:
// ----------------------------------------------------------------------------

- (void)chooseLine: (Line**)ioLine
{
    if (!(*ioLine) || !(*ioLine)->info.isCode ||
        !(*ioLine)->alt || !(*ioLine)->alt->chars)
        return;

    UInt8 theCode = (*ioLine)->info.code[0];

    if (theCode == 0xe8 || theCode == 0xe9 || theCode == 0xff || theCode == 0x9a)
    {
        Line*   theNewLine  = malloc(sizeof(Line));

        memcpy(theNewLine, (*ioLine)->alt, sizeof(Line));
        theNewLine->chars   = malloc(theNewLine->length + 1);
        strncpy(theNewLine->chars, (*ioLine)->alt->chars,
            theNewLine->length + 1);

        // Swap in the verbose line and free the previous verbose lines.
        [self deleteLinesBefore:(*ioLine)->alt fromList:&iVerboseLineListHead];
        [self replaceLine:*ioLine withLine:theNewLine inList:&iPlainLineListHead];
        *ioLine = theNewLine;
    }
}

//  postProcessCodeLine:
// ----------------------------------------------------------------------------

- (void)postProcessCodeLine: (Line**)ioLine
{
    if ((*ioLine)->info.code[0] != 0xe8  || !(*ioLine)->next)
        return;

    // Check for thunks.
    char*   theSubstring    =
        strstr(iLineOperandsCString, "i686.get_pc_thunk.");

    if (theSubstring)   // otool knew this was a thunk call
    {
        SInt8 thunkReg = NO_REG;

        if (!strncmp(&theSubstring[18], "ax", 2))
            thunkReg = EAX;
        else if (!strncmp(&theSubstring[18], "bx", 2))
            thunkReg = EBX;
        else if (!strncmp(&theSubstring[18], "cx", 2))
            thunkReg = ECX;
        else if (!strncmp(&theSubstring[18], "dx", 2))
            thunkReg = EDX;

        if (thunkReg != NO_REG)
        {
            iRegInfos[thunkReg].value   = (*ioLine)->next->info.address;
            iRegInfos[thunkReg].isValid = YES;
        }
    }
    else if (iThunks)   // otool didn't spot it, maybe we did earlier...
    {
        uint32_t i;
        size_t target;

        for (i = 0; i < iNumThunks; i++)
        {
            target  = strtoul(iLineOperandsCString, NULL, 16);

            if (target == iThunks[i].address)
            {
                SInt8 thunkReg = iThunks[i].reg;

                if (thunkReg != NO_REG) {
                    iRegInfos[thunkReg].value      =
                        (*ioLine)->next->info.address;
                    iRegInfos[thunkReg].isValid    = YES;
                }

                return;
            }
        }
    }
}

#pragma mark -
//  resetRegisters:
// ----------------------------------------------------------------------------

- (void)resetRegisters: (Line*)inLine
{
    if (!inLine)
    {
        fprintf(stderr, "otx: [X86Processor resetRegisters]: "
            "tried to reset with NULL ioLine\n");
        return;
    }

    [self getObjcClassPtr:&iCurrentClass fromMethod:inLine->info.address];
    [self getObjc1CatPtr:&iCurrentCat fromMethod:inLine->info.address];

    memset(iRegInfos, 0, sizeof(GPRegisterInfo) * 8);

    // If we didn't get the class from the method, try to get it from the
    // category.
    if (iObjcVersion == 1) {
        if (!iCurrentClass && iCurrentCat)
        {
            objc1_32_category swappedCat = *iCurrentCat;

            #if __BIG_ENDIAN__
                swap_objc1_32_category(&swappedCat);
            #endif

            [self getObjcClassPtr:&iCurrentClass fromName:[self getPointer:swappedCat.class_name type:NULL]];
        }
    }

    // Try to find out whether this is a class or instance method.
    MethodInfo* thisMethod  = NULL;

    if ([self getObjcMethod:&thisMethod fromAddress:inLine->info.address])
        iIsInstanceMethod   = thisMethod->inst;

    if (iLocalSelves)
    {
        free(iLocalSelves);
        iLocalSelves    = NULL;
        iNumLocalSelves = 0;
    }

    if (iLocalVars)
    {
        free(iLocalVars);
        iLocalVars      = NULL;
        iNumLocalVars   = 0;
    }

    iCurrentFuncInfoIndex++;

    if (iCurrentFuncInfoIndex >= iNumFuncInfos)
        iCurrentFuncInfoIndex   = -1;
}

//  updateRegisters:
// ----------------------------------------------------------------------------

- (void)updateRegisters: (Line*)inLine;
{
    UInt8 opcode = inLine->info.code[0];
    UInt8 modRM;

#if OTX_DEBUG
#if UPDATE_REGISTERS_START_DEBUG
#if UPDATE_REGISTERS_END_DEBUG
    {
        static BOOL sIsInDebugMode = NO;

        if (inLine->info.address == UPDATE_REGISTERS_START_DEBUG) {
            sIsInDebugMode = YES;
            [self printBlocks:(uint32_t)iCurrentFuncInfoIndex];
        }
        
        if (sIsInDebugMode) {
            [self printCurrentState:inLine->info.address];
            if (inLine->info.address == UPDATE_REGISTERS_END_DEBUG) {
                sIsInDebugMode = NO;
            }
        }
    }
#endif
#endif
#endif 

    switch (opcode)
    {
        // pop stack into thunk registers.
        case 0x5e:  // esi
        case 0x5f:  // edi
        case 0x58:  // eax
        case 0x59:  // ecx
        case 0x5a:  // edx
        case 0x5b:  // ebx
            if (inLine->prev &&
                (inLine->prev->info.code[0] == 0xe8) &&
                (*(uint32_t*)&inLine->prev->info.code[2] == 0))
            {
                iRegInfos[REG2(opcode)] = (GPRegisterInfo){0};
                iRegInfos[REG2(opcode)].value = inLine->info.address;
                iRegInfos[REG2(opcode)].isValid = YES;
            }
            else
            {
                iRegInfos[REG2(opcode)] = (GPRegisterInfo){0};
            }
            break;

        // pop stack into non-thunk registers. Wipe em.
        case 0x5c:  // esp
        case 0x5d:  // ebp
            iRegInfos[REG2(opcode)] = (GPRegisterInfo){0};

            break;

        // immediate group 1
        // add, or, adc, sbb, and, sub, xor, cmp
        case 0x83:  // EXTS(imm8),r32
        {
            modRM = inLine->info.code[1];

            if (!iRegInfos[REG1(modRM)].isValid)
                break;

            UInt8 imm = inLine->info.code[2];

            switch (OPEXT(modRM))
            {
                case 0: // add
                    iRegInfos[REG2(modRM)].value    += (SInt32)imm;
                    iRegInfos[REG2(modRM)].classPtr = NULL;
                    iRegInfos[REG2(modRM)].catPtr   = NULL;

                    break;

                case 1: // or
                    iRegInfos[REG2(modRM)].value    |= (SInt32)imm;
                    iRegInfos[REG2(modRM)].classPtr = NULL;
                    iRegInfos[REG2(modRM)].catPtr   = NULL;

                    break;

                case 4: // and
                    iRegInfos[REG2(modRM)].value    &= (SInt32)imm;
                    iRegInfos[REG2(modRM)].classPtr = NULL;
                    iRegInfos[REG2(modRM)].catPtr   = NULL;

                    break;

                case 5: // sub
                    iRegInfos[REG2(modRM)].value    -= (SInt32)imm;
                    iRegInfos[REG2(modRM)].classPtr = NULL;
                    iRegInfos[REG2(modRM)].catPtr   = NULL;

                    break;

                case 6: // xor
                    iRegInfos[REG2(modRM)].value    ^= (SInt32)imm;
                    iRegInfos[REG2(modRM)].classPtr = NULL;
                    iRegInfos[REG2(modRM)].catPtr   = NULL;

                    break;

                default:
                    break;
            }   // switch (OPEXT(modRM))

            break;
        }

        case 0x89:  // mov reg to r/m
        {
            modRM = inLine->info.code[1];

            if (MOD(modRM) == MODx) // reg to reg
            {
                if (!iRegInfos[REG1(modRM)].isValid)
                {
                    iRegInfos[REG2(modRM)]  = (GPRegisterInfo){0};
                }
                else
                {
                    memcpy(&iRegInfos[REG2(modRM)], &iRegInfos[REG1(modRM)],
                        sizeof(GPRegisterInfo));
                }
                break;
            }

            if ((REG2(modRM) != EBP && !HAS_SIB(modRM)))
                break;

            SInt8 offset  = 0;

            if (HAS_SIB(modRM)) // pushing an arg onto stack
            {
                if (HAS_DISP8(modRM))
                    offset = (SInt8)inLine->info.code[3];

                if (offset >= 0)
                {
                    if (offset / 4 > MAX_STACK_SIZE - 1)
                    {
                        fprintf(stderr, "otx: out of stack bounds: "
                            "stack size needs to be %d\n", (offset / 4) + 1);
                        break;
                    }

                    // Convert offset to array index.
                    offset /= 4;

                    if (iRegInfos[REG1(modRM)].isValid)
                        iStack[offset]  = iRegInfos[REG1(modRM)];
                    else
                        iStack[offset]  = (GPRegisterInfo){0};
                }
            }
            else    // Copying from a register to a local var.
            {
                if (iRegInfos[REG1(modRM)].classPtr && MOD(modRM) == MOD8)
                {
                    offset = (SInt8)inLine->info.code[2];

                    iNumLocalSelves++;
                    iLocalSelves = realloc(iLocalSelves,
                        iNumLocalSelves * sizeof(VarInfo));
                    iLocalSelves[iNumLocalSelves - 1]   = (VarInfo)
                        {iRegInfos[REG1(modRM)], offset};
                }
                else if (iRegInfos[REG1(modRM)].isValid)
                {
                    SInt32 varOffset = 0;

                    if (MOD(modRM) == MOD32)
                    {
                        varOffset = *(SInt32*)&inLine->info.code[2];
                        varOffset = OSSwapLittleToHostInt32(varOffset);
                    }
                    else if (MOD(modRM) == MOD8)
                    {
                        varOffset = (SInt8)inLine->info.code[2];
                    }
                
                    VarInfo *localVarToUse = NULL;
                    for (SInt32 i = 0; i < iNumLocalVars; i++)
                    {
                        if (iLocalVars[i].offset == varOffset)
                        {
                            localVarToUse = &iLocalVars[i];
                        }
                    }
                    
                    if (!localVarToUse)
                    {
                        iNumLocalVars++;
                        iLocalVars  = realloc(iLocalVars, iNumLocalVars * sizeof(VarInfo));
                        localVarToUse = &iLocalVars[iNumLocalVars - 1];
                    }
                    
                    *localVarToUse = (VarInfo) {iRegInfos[REG1(modRM)], varOffset};
                }
            }

            break;
        }

        case 0x8b:  // mov mem to reg
        case 0x8d:  // lea mem to reg
            modRM = inLine->info.code[1];

            if (MOD(modRM) == MODimm)
            {
                if (REG2(modRM) == EBP) // disp32
                {
                    uint32_t offset = *(uint32_t*)&inLine->info.code[2];

                    offset = OSSwapLittleToHostInt32(offset);

                    iRegInfos[REG1(modRM)] = (GPRegisterInfo){0};
                    iRegInfos[REG1(modRM)].value = offset;
                    iRegInfos[REG1(modRM)].isValid = YES;
                    iRegInfos[REG1(modRM)].classPtr = NULL;
                    iRegInfos[REG1(modRM)].catPtr = NULL;
                }
                else
                    iRegInfos[REG1(modRM)] = iRegInfos[REG2(modRM)];
            }
            else if (MOD(modRM) == MOD8)
            {
                SInt8 offset = (SInt8)inLine->info.code[2];

                if (REG2(modRM) == EBP && offset == 0x8)
                {   // Copying self from 1st arg to a register.
                    iRegInfos[REG1(modRM)].isValid = YES;
                    iRegInfos[REG1(modRM)].value = 0;
                    iRegInfos[REG1(modRM)].classPtr = iCurrentClass;
                    iRegInfos[REG1(modRM)].catPtr = iCurrentCat;
                }
                else
                {   // Check for copied self pointer.
                    // Zero the destination regardless.
                    iRegInfos[REG1(modRM)] = (GPRegisterInfo){0};

                    if (REG2(modRM) == EBP && offset < 0)
                    {
                        uint32_t i;

                        if (iLocalSelves)
                        {
                            // If we're accessing a local var copy of self,
                            // copy that info back to the reg in question.
                            for (i = 0; i < iNumLocalSelves; i++)
                            {
                                if (iLocalSelves[i].offset != offset)
                                    continue;

                                iRegInfos[REG1(modRM)] = iLocalSelves[i].regInfo;

                                break;
                            }
                        }
                        
                        if (!iRegInfos[REG1(modRM)].isValid)
                        {
                            for (i = 0; i < iNumLocalVars; i++)
                            {
                                if (iLocalVars[i].offset != offset)
                                    continue;

                                iRegInfos[REG1(modRM)] = iLocalVars[i].regInfo;

                                break;
                            }
                        }
                    }
                }
            }
            else if (REG2(modRM) == EBP && MOD(modRM) == MOD32)
            {
                // Zero the destination regardless.
                iRegInfos[REG1(modRM)] = (GPRegisterInfo){0};

                if (iLocalVars)
                {
                    SInt32 offset = *(SInt32*)&inLine->info.code[2];

                    offset = OSSwapLittleToHostInt32(offset);

                    if (offset < 0)
                    {
                        uint32_t i;

                        for (i = 0; i < iNumLocalVars; i++)
                        {
                            if (iLocalVars[i].offset != offset)
                                continue;

                            iRegInfos[REG1(modRM)]  = iLocalVars[i].regInfo;

                            break;
                        }
                    }
                }
            }
            else if (HAS_ABS_DISP32(modRM))
            {
                uint32_t newValue = *(uint32_t*)&inLine->info.code[2];

                iRegInfos[REG1(modRM)].isValid = YES;
                iRegInfos[REG1(modRM)].value = OSSwapLittleToHostInt32(newValue);
                iRegInfos[REG1(modRM)].classPtr = NULL;
                iRegInfos[REG1(modRM)].catPtr = NULL;
            }
            else if (HAS_REL_DISP32(modRM))
            {
                if (!iRegInfos[REG2(modRM)].isValid)
                    break;

                uint32_t newValue = *(uint32_t*)&inLine->info.code[2];

                newValue = OSSwapLittleToHostInt32(newValue);
                newValue += iRegInfos[REG2(modRM)].value;

                iRegInfos[REG1(modRM)].isValid = YES;
                iRegInfos[REG1(modRM)].value = newValue;
                iRegInfos[REG1(modRM)].classPtr = NULL;
                iRegInfos[REG1(modRM)].catPtr = NULL;
            }

            break;

        case 0xb0:  // movb imm8,%al
        case 0xb1:  // movb imm8,%cl
        case 0xb2:  // movb imm8,%dl
        case 0xb3:  // movb imm8,%bl
        case 0xb4:  // movb imm8,%ah
        case 0xb5:  // movb imm8,%ch
        case 0xb6:  // movb imm8,%dh
        case 0xb7:  // movb imm8,%bh
        {
            iRegInfos[REG2(opcode)] = (GPRegisterInfo){0};

            UInt8 imm = inLine->info.code[1];

            iRegInfos[REG2(opcode)].value = imm;
            iRegInfos[REG2(opcode)].isValid = YES;

            break;
        }

        case 0xa1:  // movl moffs32,%eax
        {
            iRegInfos[EAX]  = (GPRegisterInfo){0};

            uint32_t newValue = *(uint32_t*)&inLine->info.code[1];

            iRegInfos[EAX].value = OSSwapLittleToHostInt32(newValue);
            iRegInfos[EAX].isValid = YES;

            break;
        }

        case 0xb8:  // movl imm32,%eax
        case 0xb9:  // movl imm32,%ecx
        case 0xba:  // movl imm32,%edx
        case 0xbb:  // movl imm32,%ebx
        case 0xbc:  // movl imm32,%esp
        case 0xbd:  // movl imm32,%ebp
        case 0xbe:  // movl imm32,%esi
        case 0xbf:  // movl imm32,%edi
        {
            iRegInfos[REG2(opcode)] = (GPRegisterInfo){0};

            uint32_t newValue = *(uint32_t*)&inLine->info.code[1];

            iRegInfos[REG2(opcode)].value = OSSwapInt32(newValue);
            iRegInfos[REG2(opcode)].isValid = YES;

            break;
        }

        case 0xc7:  // movl imm32,r/m32
        {
            modRM = inLine->info.code[1];

            if (!HAS_SIB(modRM))
                break;

            SInt8 offset = 0;
            SInt32 value = 0;

            if (HAS_DISP8(modRM))
            {
                offset = (SInt8)inLine->info.code[3];
                value = *(SInt32*)&inLine->info.code[4];
                value = OSSwapLittleToHostInt32(value);
            }

            if (offset >= 0)
            {
                if (offset / 4 > MAX_STACK_SIZE - 1)
                {
                    fprintf(stderr, "otx: out of stack bounds: "
                        "stack size needs to be %d\n", (offset / 4) + 1);
                    break;
                }

                // Convert offset to array index.
                offset /= 4;

                iStack[offset]          = (GPRegisterInfo){0};
                iStack[offset].value    = value;
                iStack[offset].isValid  = YES;
            }

            break;
        }

        case 0xe8:  // calll
                memset(iStack, 0, sizeof(GPRegisterInfo) * MAX_STACK_SIZE);
                iRegInfos[EAX]  = (GPRegisterInfo){0};

            break;

        default:
            break;
    }   // switch (opcode)
}

//  restoreRegisters:
// ----------------------------------------------------------------------------

- (BOOL)restoreRegisters: (Line*)inLine
{
    if (!inLine)
    {
        fprintf(stderr, "otx: [X86Processor restoreRegisters]: "
            "tried to restore with NULL inLine\n");
        return NO;
    }

    BOOL needNewLine = NO;

    if (iCurrentFuncInfoIndex < 0)
        return NO;

    // Search current FunctionInfo for blocks that start at this address.
    FunctionInfo*   funcInfo    =
        &iFuncInfos[iCurrentFuncInfoIndex];

    if (!funcInfo->blocks)
        return NO;

    uint32_t  i;

    for (i = 0; i < funcInfo->numBlocks; i++)
    {
        if (funcInfo->blocks[i].beginAddress != inLine->info.address)
            continue;

        // Update machine state.
        MachineState    machState   = funcInfo->blocks[i].state;

        memcpy(iRegInfos, machState.regInfos,
            sizeof(GPRegisterInfo) * 8);

        if (machState.localSelves)
        {
            if (iLocalSelves)
                free(iLocalSelves);

            iNumLocalSelves = machState.numLocalSelves;
            iLocalSelves    = malloc(
                sizeof(VarInfo) * machState.numLocalSelves);
            memcpy(iLocalSelves, machState.localSelves,
                sizeof(VarInfo) * machState.numLocalSelves);
        }

        if (machState.localVars)
        {
            if (iLocalVars)
                free(iLocalVars);

            iNumLocalVars   = machState.numLocalVars;
            iLocalVars      = malloc(
                sizeof(VarInfo) * iNumLocalVars);
            memcpy(iLocalVars, machState.localVars,
                sizeof(VarInfo) * iNumLocalVars);
        }

        // Optionally add a blank line before this block.
        if (iOpts.separateLogicalBlocks && inLine->chars[0] != '\n' &&
            !inLine->info.isFunction)
            needNewLine = YES;

        break;
    }   // for (i = 0...)

    return needNewLine;
}

//  lineIsFunction:
// ----------------------------------------------------------------------------

- (BOOL)lineIsFunction: (Line*)inLine
{
    if (!inLine)
        return NO;

    uint32_t  theAddy = inLine->info.address;

    if (theAddy == iAddrDyldStubBindingHelper   ||
        theAddy == iAddrDyldFuncLookupPointer)
        return YES;

    MethodInfo* theDummyInfo    = NULL;

    // In Obj-C apps, the majority of funcs will have Obj-C symbols, so check
    // those first.
    if ([self findClassMethod:&theDummyInfo byAddress:theAddy])
        return YES;

    if ([self findCatMethod:&theDummyInfo byAddress:theAddy])
        return YES;

    // If it's not an Obj-C method, maybe there's an nlist.
    if ([self findSymbolByAddress:theAddy])
        return YES;

    // If otool gave us a function name, but it came from a dynamic symbol...
    if (inLine->prev && !inLine->prev->info.isCode)
        return YES;

    // Check for saved thunks.
    if (iThunks)
    {
        uint32_t  i;

        for (i = 0; i < iNumThunks; i++)
        {
            if (iThunks[i].address == theAddy)
                return YES;
        }
    }

    // Obvious avenues expended, brute force check now.
    BOOL isFunction  = NO;
    UInt8 opcode = inLine->info.code[0];
    Line* thePrevLine = inLine->prev;

    if (opcode == 0x55) // pushl %ebp
    {
        // Assume it's a func, unless it's preceded by nops and a symbol.
        isFunction  = YES;

        BOOL foundNops = NO;

        while (thePrevLine)
        {
            if (!thePrevLine->info.isCode)
            {
                if (foundNops)
                {
                    isFunction = NO;
                    break;
                }
                else
                    break;
            }

            opcode = thePrevLine->info.code[0];

            if (opcode == 0x90)
                foundNops = YES;
            else if (opcode >= 0x58 && opcode <= 0x5b)
            {
                /*  fast thunk
                    +0  0000286f  e800000000    calll   0x00002874  <- thePrevLine->prev
                    +5  00002874  59            popl    %ecx        <- thePrevLine
                    +6  00002875  55            pushl   %ebp
                    +7  00002876  89e5          movl    %esp,%ebp
                */
                if (thePrevLine->prev->info.code[0] == 0xe8 &&
                    *(uint32_t*)&thePrevLine->prev->info.code[1] == 0)
                {
                    isFunction = NO;
                    break;
                }
            }
            else
                break;

            thePrevLine = thePrevLine->prev;
        }
    }
    else
    {   // Check for the first instruction in this section.
        while (thePrevLine)
        {
            if (thePrevLine->info.isCode)
                break;
            else
                thePrevLine = thePrevLine->prev;
        }

        if (!thePrevLine)
            isFunction = YES;
    }

    return isFunction;
}

//  codeIsBlockJump:
// ----------------------------------------------------------------------------

- (BOOL)codeIsBlockJump: (UInt8*)inCode
{
    UInt8 opcode = inCode[0];
    UInt8 opcode2 = inCode[1];

    return IS_JUMP(opcode, opcode2);
}

//  gatherFuncInfos
// ----------------------------------------------------------------------------

- (void)gatherFuncInfos
{
    Line*           theLine     = iPlainLineListHead;
    UInt8           opcode, opcode2;
    uint32_t          progCounter = 0;

    // Loop thru lines.
    while (theLine)
    {
        if (!(progCounter % (PROGRESS_FREQ * 5)))
        {
            if (gCancel == YES)
                return;
        }

        if (!theLine->info.isCode)
        {
            theLine = theLine->next;
            continue;
        }

        opcode = theLine->info.code[0];
        opcode2 = theLine->info.code[1];

        if (theLine->info.isFunction)
        {
            iCurrentFuncPtr = theLine->info.address;
            [self resetRegisters:theLine];
        }
        else
        {
            [self restoreRegisters:theLine];
            [self updateRegisters:theLine];

            ThunkInfo   theInfo;

            if ([self getThunkInfo: &theInfo forLine: theLine])
            {
                iRegInfos[theInfo.reg].value    = theLine->next->info.address;
                iRegInfos[theInfo.reg].isValid  = YES;
            }
        }

        // Check if we need to save the machine state.
        if (IS_JUMP(opcode, opcode2) && iCurrentFuncInfoIndex >= 0)
        {
            uint32_t  jumpTarget;
            BOOL    validTarget = NO;

            // Retrieve the jump target.
            if ((opcode >= 0x71 && opcode <= 0x7f) ||
                opcode == 0xe3 || opcode == 0xeb)
            {
                // No need for sscanf here- opcode2 is already the unsigned
                // second byte, which in this case is the signed offset that
                // we want.
                jumpTarget  = theLine->info.address + 2 + (SInt8)opcode2;
                validTarget = YES;
            }
            else if (opcode == 0xe9)
            {
                SInt32 rel32 = *(SInt32*)&theLine->info.code[1];

                rel32 = OSSwapLittleToHostInt32(rel32);
                jumpTarget = theLine->info.address + 5 + rel32;
                validTarget = YES;
            }
            else if (opcode == 0x0f && opcode2 >= 0x81 && opcode2 <= 0x8f)
            {
                SInt32 rel32 = *(SInt32*)&theLine->info.code[2];

                rel32 = OSSwapLittleToHostInt32(rel32);
                jumpTarget = theLine->info.address + 6 + rel32;
                validTarget = YES;
            }

            if (!validTarget)
            {
                theLine = theLine->next;
                continue;
            }

            // Retrieve current FunctionInfo.
            FunctionInfo*   funcInfo    =
                &iFuncInfos[iCurrentFuncInfoIndex];
#ifdef REUSE_BLOCKS
            // 'currentBlock' will point to either an existing block which
            // we will update, or a newly allocated block.
            BlockInfo*  currentBlock    = NULL;
            Line*       endLine         = NULL;
            BOOL        isEpilog        = NO;
            uint32_t      i;

            if (funcInfo->blocks)
            {   // Blocks exist, find 1st one matching this address.
                // This is an exhaustive search, but the speed hit should
                // only be an issue with extremely long functions.
                for (i = 0; i < funcInfo->numBlocks; i++)
                {
                    if (funcInfo->blocks[i].beginAddress == jumpTarget)
                    {
                        currentBlock = &funcInfo->blocks[i];
                        break;
                    }
                }

                if (currentBlock)
                {   // Determine if the target block is an epilog.
                    if (currentBlock->endLine == NULL &&
                        iOpts.returnStatements)
                    {
                        // Find the first line of the target block.
                        Line    searchKey = {NULL, 0, NULL, NULL, NULL, {jumpTarget, {0}, YES, NO}};
                        Line*   searchKeyPtr = &searchKey;
                        Line**  beginLine = bsearch(&searchKeyPtr, iLineArray, iNumCodeLines, sizeof(Line*),
                            (COMPARISON_FUNC_TYPE)Line_Address_Compare);

                        if (beginLine != NULL)
                        {
                            // Walk through the block. It's an epilog if it ends
                            // with 'ret' and contains no 'call's.
                            Line* nextLine    = *beginLine;
                            BOOL canBeEpliog = YES;
                            UInt8 tempOpcode = 0;
                            UInt8 tempOpcode2 = 0;

                            while (nextLine)
                            {
                                tempOpcode = nextLine->info.code[0];
                                tempOpcode2 = nextLine->info.code[1];

                                if (IS_CALL(tempOpcode))
                                    canBeEpliog = NO;

                                if (IS_JUMP(tempOpcode, tempOpcode2))
                                {
                                    endLine = nextLine;

                                    if (canBeEpliog && IS_RET(tempOpcode))
                                        isEpilog = YES;

                                    break;
                                }

                                nextLine = nextLine->next;
                            }
                        }

//                      currentBlock->endLine   = endLine;
                    }
                }
                else
                {   // No matching blocks found, so allocate a new one.
                    funcInfo->numBlocks++;
                    funcInfo->blocks = realloc(funcInfo->blocks,
                        sizeof(BlockInfo) * funcInfo->numBlocks);
                    currentBlock =
                        &funcInfo->blocks[funcInfo->numBlocks - 1];
                    *currentBlock = (BlockInfo){0};
                }
            }
            else
            {   // No existing blocks, allocate one.
                funcInfo->numBlocks++;
                funcInfo->blocks    = calloc(1, sizeof(BlockInfo));
                currentBlock        = funcInfo->blocks;
            }

            // sanity check
            if (!currentBlock)
            {
                fprintf(stderr, "otx: [X86Processor gatherFuncInfos] "
                    "currentBlock is NULL. Flame the dev.\n");
                return;
            }

            // Create a new MachineState.
            GPRegisterInfo* savedRegs   = malloc(
                sizeof(GPRegisterInfo) * 8);

            memcpy(savedRegs, iRegInfos, sizeof(GPRegisterInfo) * 8);

            VarInfo*    savedSelves = NULL;

            if (iLocalSelves)
            {
                savedSelves = malloc(
                    sizeof(VarInfo) * iNumLocalSelves);
                memcpy(savedSelves, iLocalSelves,
                    sizeof(VarInfo) * iNumLocalSelves);
            }

            VarInfo*    savedVars   = NULL;

            if (iLocalVars)
            {
                savedVars   = malloc(
                    sizeof(VarInfo) * iNumLocalVars);
                memcpy(savedVars, iLocalVars,
                    sizeof(VarInfo) * iNumLocalVars);
            }

            MachineState    machState   =
                {savedRegs, savedSelves, iNumLocalSelves,
                    savedVars, iNumLocalVars };

            // Store the new BlockInfo.
            BlockInfo   blockInfo   =
                {jumpTarget, endLine, isEpilog, machState};

            memcpy(currentBlock, &blockInfo, sizeof(BlockInfo));
#else
    // At this point, the x86 logic departs from the PPC logic. We seem
    // to get better results by not reusing blocks.

            // Allocate another BlockInfo.
            funcInfo->numBlocks++;
            funcInfo->blocks    = realloc(funcInfo->blocks,
                sizeof(BlockInfo) * funcInfo->numBlocks);
            // Create a new MachineState.
            GPRegisterInfo* savedRegs   = malloc(
                sizeof(GPRegisterInfo) * 8);

            memcpy(savedRegs, mRegInfos, sizeof(GPRegisterInfo) * 8);

            VarInfo*    savedSelves = NULL;

            if (mLocalSelves)
            {
                savedSelves = malloc(
                    sizeof(VarInfo) * mNumLocalSelves);
                memcpy(savedSelves, mLocalSelves,
                    sizeof(VarInfo) * mNumLocalSelves);
            }

            VarInfo*    savedVars   = NULL;

            if (mLocalVars)
            {
                savedVars   = malloc(
                    sizeof(VarInfo) * mNumLocalVars);
                memcpy(savedVars, mLocalVars,
                    sizeof(VarInfo) * mNumLocalVars);
            }

            MachineState    machState   =
                {savedRegs, savedSelves, mNumLocalSelves
                    savedVars, mNumLocalVars};

            // Create and store a new BlockInfo.
            funcInfo->blocks[funcInfo->numBlocks - 1]   =
                (BlockInfo){jumpTarget, machState};
#endif

        }

        theLine = theLine->next;
    }

    iCurrentFuncInfoIndex   = -1;
}

#pragma mark -
#pragma mark Deobfuscator protocol
//  verifyNops:numFound:
// ----------------------------------------------------------------------------

- (BOOL)verifyNops: (unsigned char***)outList
          numFound: (uint32_t*)outFound
{
    if (![self loadMachHeader])
    {
        fprintf(stderr, "otx: failed to load mach header\n");
        return NO;
    }

    [self loadLCommands];

    *outList    = [self searchForNopsIn: (unsigned char*)iTextSect.contents
        ofLength: iTextSect.size numFound: outFound];

    return (*outFound != 0);
}

//  searchForNopsIn:ofLength:numFound:
// ----------------------------------------------------------------------------
//  Return value is a newly allocated list of addresses of 'outFound' length.
//  Caller owns the list.

- (unsigned char**)searchForNopsIn: (unsigned char*)inHaystack
                          ofLength: (uint32_t)inHaystackLength
                          numFound: (uint32_t*)outFound;
{
    unsigned char** foundList       = NULL;
    unsigned char*  current;
    unsigned char   searchString[4] = {0x00, 0x55, 0x89, 0xe5};

    *outFound   = 0;

    // Loop thru haystack
    for (current = inHaystack;
         current <= inHaystack + inHaystackLength - 4;
         current++)
    {
        if (!current) continue;
        
        if (memcmp(current, searchString, 4) != 0)
            continue;

        // Match and bail for common benign occurences.
        if (*(current - 4) == 0xe8  ||  // calll
            *(current - 4) == 0xe9  ||  // jmpl
            *(current - 2) == 0xc2)     // ret
            continue;

        // Match and bail for (not) common malignant occurences.
        if (*(current - 7) != 0xe8  &&  // calll
            *(current - 5) != 0xe8  &&  // calll
            *(current - 7) != 0xe9  &&  // jmpl
            *(current - 5) != 0xe9  &&  // jmpl
            *(current - 4) != 0xeb  &&  // jmp
            *(current - 2) != 0xeb  &&  // jmp
            *(current - 5) != 0xc2  &&  // ret
            *(current - 5) != 0xca  &&  // ret
            *(current - 3) != 0xc2  &&  // ret
            *(current - 3) != 0xca  &&  // ret
            *(current - 3) != 0xc3  &&  // ret
            *(current - 3) != 0xcb  &&  // ret
            *(current - 1) != 0xc3  &&  // ret
            *(current - 1) != 0xcb)     // ret
            continue;

        (*outFound)++;
        foundList   = realloc(
            foundList, *outFound * sizeof(unsigned char*));
        foundList[*outFound - 1]    = current;
    }

    return foundList;
}

//  fixNops:toPath:
// ----------------------------------------------------------------------------

- (NSURL*)fixNops: (NopList*)inList
           toPath: (NSString*)inOutputFilePath
{
    if (!inList)
    {
        fprintf(stderr, "otx: -[X86Processor fixNops]: "
            "tried to fix NULL NopList.\n");
        return nil;
    }

    if (!inOutputFilePath)
    {
        fprintf(stderr, "otx: -[X86Processor fixNops]: "
            "inOutputFilePath was nil.\n");
        return nil;
    }

    uint32_t          i   = 0;
    unsigned char*  item;

    for (i = 0; i < inList->count; i++)
    {
        item    = inList->list[i];

        // For some unknown reason, the following direct memory accesses make
        // the app crash when running inside MallocDebug. Until the cause is
        // found, comment them out when looking for memory leaks.

        // This appears redundant, but to avoid false positives, we must
        // check jumps first(in decreasing size) and return statements last.
        if (*(item - 7) == 0xe8)        // e8xxxxxxxx0000005589e5
        {
            *(item)     = 0x90;
            *(item - 1) = 0x90;
            *(item - 2) = 0x90;
        }
        else if (*(item - 5) == 0xe8)   // e8xxxxxxxx005589e5
        {
            *(item)     = 0x90;
        }
        else if (*(item - 7) == 0xe9)   // e9xxxxxxxx0000005589e5
        {
            *(item)     = 0x90;
            *(item - 1) = 0x90;
            *(item - 2) = 0x90;
        }
        else if (*(item - 5) == 0xe9)   // e9xxxxxxxx005589e5
        {
            *(item)     = 0x90;
        }
        else if (*(item - 4) == 0xeb)   // ebxx0000005589e5
        {
            *(item)     = 0x90;
            *(item - 1) = 0x90;
            *(item - 2) = 0x90;
        }
        else if (*(item - 2) == 0xeb)   // ebxx005589e5
        {
            *(item)     = 0x90;
        }
        else if (*(item - 5) == 0xc2)   // c2xxxx0000005589e5
        {
            *(item)     = 0x90;
            *(item - 1) = 0x90;
            *(item - 2) = 0x90;
        }
        else if (*(item - 5) == 0xca)   // caxxxx0000005589e5
        {
            *(item)     = 0x90;
            *(item - 1) = 0x90;
            *(item - 2) = 0x90;
        }
        else if (*(item - 3) == 0xc2)   // c2xxxx005589e5
        {
            *(item)     = 0x90;
        }
        else if (*(item - 3) == 0xca)   // caxxxx005589e5
        {
            *(item)     = 0x90;
        }
        else if (*(item - 3) == 0xc3)   // c30000005589e5
        {
            *(item)     = 0x90;
            *(item - 1) = 0x90;
            *(item - 2) = 0x90;
        }
        else if (*(item - 3) == 0xcb)   // cb0000005589e5
        {
            *(item)     = 0x90;
            *(item - 1) = 0x90;
            *(item - 2) = 0x90;
        }
        else if (*(item - 1) == 0xc3)   // c3005589e5
        {
            *(item)     = 0x90;
        }
        else if (*(item - 1) == 0xcb)   // cb005589e5
        {
            *(item)     = 0x90;
        }
    }

    // Write data to a new file.
    NSData*     newFile = [NSData dataWithBytesNoCopy: iRAMFile
        length: iRAMFileSize];

    if (!newFile)
    {
        fprintf(stderr, "otx: -[X86Processor fixNops]: "
            "unable to create NSData for new file.\n");
        return nil;
    }

    NSError*    error   = nil;
    NSURL*      newURL  = [[NSURL alloc] initFileURLWithPath:
        [[[inOutputFilePath stringByDeletingLastPathComponent]
        stringByAppendingPathComponent: [[iOFile path] lastPathComponent]]
        stringByAppendingString: @"_fixed"]];

    [newURL autorelease];

    if (![newFile writeToURL: newURL options: NSAtomicWrite error: &error])
    {
        if (error)
            fprintf(stderr, "otx: -[X86Processor fixNops]: "
                "unable to write to new file. %s\n",
                UTF8STRING([error localizedDescription]));
        else
            fprintf(stderr, "otx: -[X86Processor fixNops]: "
                "unable to write to new file.\n");

        return nil;
    }

    // Copy original app's permissions to new file.
    NSFileManager*  fileMan     = [NSFileManager defaultManager];
    NSDictionary*   fileAttrs   = [fileMan attributesOfItemAtPath:[iOFile path] error:nil];

    if (!fileAttrs)
    {
        fprintf(stderr, "otx: -[X86Processor fixNops]: "
            "unable to read attributes from executable.\n");
        return nil;
    }

    NSDictionary*   permsDict   = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedInteger: [fileAttrs filePosixPermissions]],
        NSFilePosixPermissions, nil];

    if (![fileMan setAttributes: permsDict ofItemAtPath: [newURL path] error:nil])
    {
        fprintf(stderr, "otx: -[X86Processor fixNops]: "
            "unable to change file permissions for fixed executable.\n");
    }

    // Return fixed file.
    return newURL;
}


- (void) printCurrentState: (uint32_t)currentAddress
{
    char r[8 ][20];
    char s[MAX_STACK_SIZE][20];
    char v[MAX_STACK_SIZE][20];
    
    bzero(r, sizeof(r));
    bzero(s, sizeof(s));
    bzero(v, sizeof(v));
    
    BOOL srow[8] = { NO, NO, NO, NO, NO, NO, NO, NO };

    for (int i = 0; i < 8; i++) {
        if (iRegInfos[i].isValid) {
            snprintf(r[i], 20, "%08x", iRegInfos[i].value);
        } else {
            snprintf(r[i], 20, "--------");
        }
    }

    for (int i = 0; i < MAX_STACK_SIZE; i++) {
        if (iStack[i].isValid) {
            srow[i / 8] = YES;
            snprintf(s[i], 20, "%08x", iStack[i].value);
        } else {
            snprintf(s[i], 20, "--------");
        }
    }

    
    printf("---[ 0x%08x ]---\n", currentAddress);
    printf("EAX:%s  EBX:%s  ECX:%s  EDX:%s  ESI:%s  EDI:%s  EBP:%s  ESP:%s\n", r[EAX],  r[EBX],  r[ECX],  r[EDX],  r[ESI],  r[EDI],  r[EBP],  r[ESP]  );
    if (srow[0]) printf(" s0:%s   s1:%s   s2:%s   s3:%s   s4:%s   s5:%s   s6:%s   s7:%s\n", s[0],  s[1],  s[2],  s[3],  s[4],  s[5],  s[6],  s[7]  );
    if (srow[1]) printf(" s8:%s   s9:%s  s10:%s  s11:%s  s12:%s  s13:%s  s14:%s  s15:%s\n", s[8],  s[9],  s[10], s[11], s[12], s[13], s[14], s[15] );
    if (srow[2]) printf("s16:%s  s17:%s  s18:%s  s19:%s  s20:%s  s21:%s  s22:%s  s23:%s\n", s[16], s[17], s[18], s[19], s[20], s[21], s[22], s[23] );
    if (srow[3]) printf("s24:%s  s25:%s  s26:%s  s27:%s  s28:%s  s29:%s  s30:%s  s31:%s\n", s[24], s[25], s[26], s[27], s[28], s[29], s[30], s[31] );
    if (srow[4]) printf("s32:%s  s33:%s  s34:%s  s35:%s  s36:%s  s37:%s  s38:%s  s39:%s\n", s[32], s[33], s[34], s[35], s[36], s[37], s[38], s[39] );

    for (int i = 0; i < iNumLocalVars; i++) {
        printf(" var %x: %08x\n", (unsigned int)iLocalVars[i].offset, iLocalVars[i].regInfo.value);
    }

    for (int i = 0; i < iNumLocalSelves; i++) {
        printf("self %x: %08x\n", (unsigned int)iLocalSelves[i].offset, iLocalSelves[i].regInfo.value);
    }
}

@end
