/*
    PPC64Processor.m

    A subclass of Exe64Processor that handles PPC64-specific issues.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "PPC64Processor.h"
#import "PPCProcessor.h"
#import "ArchSpecifics.h"
#import "ListUtils.h"
#import "ObjcAccessors.h"
#import "Object64Loader.h"
#import "SyscallStrings.h"
#import "UserDefaultKeys.h"

@implementation PPC64Processor

//  initWithURL:controller:options:
// ----------------------------------------------------------------------------

- (id)initWithURL: (NSURL*)inURL
       controller: (id)inController
          options: (ProcOptions*)inOptions
{
    if ((self = [super initWithURL: inURL
        controller: inController options: inOptions]))
    {
        strncpy(iArchString, "ppc64", 6);

        iArchSelector               = CPU_TYPE_POWERPC64;
        iFieldWidths.offset         = 8;
        iFieldWidths.address        = 18;
        iFieldWidths.instruction    = 10;
        iFieldWidths.mnemonic       = 9;
        iFieldWidths.operands       = 17;
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

- (void)loadDyldDataSection: (section_64*)inSect
{
    [super loadDyldDataSection: inSect];

    if (!iAddrDyldStubBindingHelper)
        return;

    iAddrDyldFuncLookupPointer  = iAddrDyldStubBindingHelper + 24;
}

//  codeFromLine:
// ----------------------------------------------------------------------------

- (void)codeFromLine: (Line64*)inLine
{
    uint32_t  theInstruction  = (iMachHeader.filetype == MH_OBJECT) ?
        *(uint32_t*)((char*)iMachHeaderPtr + (inLine->info.address + iTextOffset)) :
        *(uint32_t*)((char*)iMachHeaderPtr + (inLine->info.address - iTextOffset));

    inLine->info.codeLength = 4;

    uint32_t* intPtr = (uint32_t*)&inLine->info.code[0];

    *intPtr = theInstruction;
}

#pragma mark -
//  commentForLine:
// ----------------------------------------------------------------------------

- (void)commentForLine: (Line64*)inLine;
{
    uint32_t theCode = *(uint32_t*)inLine->info.code;

    theCode = OSSwapBigToHostInt32(theCode);

    char*   theDummyPtr = NULL;
    char*   theSymPtr   = NULL;
    UInt8   opcode      = PO(theCode);
    UInt64  localAddy;

    iLineCommentCString[0]  = 0;

    // Examine the primary opcode to see if we need to look for comments.
    switch (opcode)
    {
        case 0x0a:  // cmpli | cmplwi   UIMM
        case 0x0b:  // cmpi | cmpwi     SIMM
        {
            SInt16  imm = SIMM(theCode);

            // Check for a single printable 7-bit char.
            if (imm >= 0x20 && imm < 0x7f)
                snprintf(iLineCommentCString, 4, "'%c'", imm);

            break;
        }

        case 0x11:  // sc
            CommentForSystemCall();

            break;

        case 0x10:  // bc, bca, bcl, bcla
        case 0x12:  // b, ba, bl, bla
        {
            // Check for absolute branches to the ObjC runtime page. Similar to
            // the comm page behavior described at
            // http://www.opensource.apple.com/darwinsource/10.4.7.ppc/xnu-792.6.76/osfmk/ppc/cpu_capabilities.h
            // However, the ObjC runtime page is not really a comm page, and it
            // cannot be accessed by bca and bcla instructions, due to their
            // 16-bit limitation.

            // Deal with absolute branches.
            if (AA(theCode))
            {
                uint32_t  target  = LI(theCode);

                switch (target)
                {
                    case kRTAddress_objc_msgSend:
                    {
                        char    tempComment[MAX_COMMENT_LENGTH];

                        strncpy(tempComment, kRTName_objc_msgSend,
                            strlen(kRTName_objc_msgSend) + 1);

                        if (iOpts.verboseMsgSends)
                            CommentForMsgSendFromLine(tempComment, inLine);

                        strncpy(iLineCommentCString, tempComment,
                            strlen(tempComment) + 1);

                        break;
                    }

                    case kRTAddress_objc_assign_ivar:
                    {
                        char    tempComment[MAX_COMMENT_LENGTH];

                        strncpy(tempComment, kRTName_objc_assign_ivar,
                            strlen(kRTName_objc_assign_ivar) + 1);

                        // Bail if we don't know about the class.
                        if (!iCurrentClass)
                        {
                            strncpy(iLineCommentCString, tempComment,
                                strlen(tempComment) + 1);
                            break;
                        }

                        if (iRegInfos[5].isValid)
                        {
                            objc2_ivar_t* theIvar = NULL;
                            objc2_class_t swappedClass = *iCurrentClass;

                            #if __LITTLE_ENDIAN__
                                swap_objc2_class(&swappedClass);
                            #endif

                            if (!iIsInstanceMethod)
                            {
                                if (!GetObjcMetaClassFromClass(&swappedClass, &swappedClass))
                                    break;

                                #if __LITTLE_ENDIAN__
                                    swap_objc2_class(&swappedClass);
                                #endif
                            }

                            if (!FindIvar(&theIvar, &swappedClass, iRegInfos[5].value))
                            {
                                strncpy(iLineCommentCString, tempComment, strlen(tempComment) + 1);
                                break;
                            }

                            theSymPtr = GetPointer(theIvar->name, NULL);

                            if (!theSymPtr)
                            {
                                strncpy(iLineCommentCString, tempComment, strlen(tempComment) + 1);
                                break;
                            }

                            if (iOpts.variableTypes)
                            {
                                char    theTypeCString[MAX_TYPE_STRING_LENGTH];

                                theTypeCString[0]   = 0;

                                GetDescription(theTypeCString, GetPointer(theIvar->type, NULL));
                                snprintf(iLineCommentCString, MAX_COMMENT_LENGTH - 1, "%s (%s)%s",
                                    tempComment, theTypeCString, theSymPtr);
                            }
                            else
                                snprintf(iLineCommentCString, MAX_COMMENT_LENGTH - 1, "%s %s",
                                    tempComment, theSymPtr);
                        }
                        else    // !mReginfos[5].isValid
                            strncpy(iLineCommentCString, tempComment, strlen(tempComment) + 1);

                        break;
                    }

                    case kRTAddress_objc_assign_global:
                        strncpy(iLineCommentCString, kRTName_objc_assign_global,
                            strlen(kRTName_objc_assign_global) + 1);
                        break;

                    case kRTAddress_objc_assign_strongCast:
                        strncpy(iLineCommentCString, kRTName_objc_assign_strongCast,
                            strlen(kRTName_objc_assign_strongCast) + 1);
                        break;

                    default:
                        break;
                }
            }
            else    // not an absolute branch
            {
                // Insert anonymous label or 'return' if there's not a comment yet.
                if (iLineCommentCString[0])
                    break;

                UInt64  absoluteAddy;

                if (opcode == 0x12)
                    absoluteAddy =
                        inLine->info.address + LI(theCode);
                else
                    absoluteAddy =
                        inLine->info.address + BD(theCode);

                Function64Info  searchKey   = {absoluteAddy, NULL, 0, 0};
                Function64Info* funcInfo    = bsearch(&searchKey,
                    iFuncInfos, iNumFuncInfos, sizeof(Function64Info),
                    (COMPARISON_FUNC_TYPE)Function_Info_Compare);

                if (funcInfo && funcInfo->genericFuncNum != 0)
                {
                    snprintf(iLineCommentCString,
                        ANON_FUNC_BASE_LENGTH + 11, "%s%d",
                        ANON_FUNC_BASE, funcInfo->genericFuncNum);
                    break;
                }

// FIXME: mCurrentFuncInfoIndex is -1 here when it should not be
                funcInfo = &iFuncInfos[iCurrentFuncInfoIndex];

                if (!funcInfo->blocks)
                    break;

                uint32_t  i;

                for (i = 0; i < funcInfo->numBlocks; i++)
                {
                    if (funcInfo->blocks[i].beginAddress != absoluteAddy)
                        continue;

                    if (funcInfo->blocks[i].isEpilog)
                        snprintf(iLineCommentCString, 8, "return;");

                    break;
                }
            }

            break;
        }

        case 0x13:  // bcctr, bclr, isync
            if (SO(theCode) != 528) // bcctr
                break;

            if (iRegInfos[4].messageRefSel != NULL)
            {
                char* sel = iRegInfos[4].messageRefSel;

                strncpy(iLineOperandsCString, " ", 2);

                if (iRegInfos[3].className != NULL)
                    snprintf(iLineCommentCString, MAX_COMMENT_LENGTH - 1,
                        "+[%s %s]", iRegInfos[3].className, sel);
                else // Instance method?
                    if (iRegInfos[3].isValid)
                        snprintf(iLineCommentCString, MAX_COMMENT_LENGTH - 1,
                            "objc_msgSend(%%r3, %s)", sel);
                    else
                        snprintf(iLineCommentCString, MAX_COMMENT_LENGTH - 1,
                            "-[%%r3 %s]", sel);
            }

            // Print value of ctr, ignoring the low 2 bits.
//            if (iCTR.isValid)
//                snprintf(iLineCommentCString, 10, "0x%x",
//                    iCTR.value & ~3);

            break;

        case 0x30:  // lfs      SIMM
        case 0x34:  // stfs     SIMM
        case 0x32:  // lfd      SIMM
        case 0x36:  // stfd     SIMM
        {
            if (!iRegInfos[RA(theCode)].isValid || RA(theCode) == 0)
                break;

            if (iRegInfos[RA(theCode)].classPtr)
            {   // search instance vars
                objc2_ivar_t* theIvar = NULL;
                objc2_class_t swappedClass = *iRegInfos[RA(theCode)].classPtr;

                #if __LITTLE_ENDIAN__
                    swap_objc2_class(&swappedClass);
                #endif

                if (!iIsInstanceMethod)
                {
                    if (!GetObjcMetaClassFromClass(&swappedClass, &swappedClass))
                        break;

                    #if __LITTLE_ENDIAN__
                        swap_objc2_class(&swappedClass);
                    #endif
                }

                if (!FindIvar(&theIvar, &swappedClass, UIMM(theCode)))
                    break;

                theSymPtr = GetPointer(theIvar->name, NULL);

                if (theSymPtr)
                {
                    if (iOpts.variableTypes)
                    {
                        char theTypeCString[MAX_TYPE_STRING_LENGTH];

                        theTypeCString[0] = 0;

                        GetDescription(theTypeCString, GetPointer(theIvar->type, NULL));
                        snprintf(iLineCommentCString, MAX_COMMENT_LENGTH - 1, "(%s)%s",
                            theTypeCString, theSymPtr);
                    }
                    else
                        snprintf(iLineCommentCString, MAX_COMMENT_LENGTH - 1, "%s", theSymPtr);
                }
            }
            else
            {
                localAddy   = iRegInfos[RA(theCode)].value + SIMM(theCode);
                theDummyPtr = GetPointer(localAddy, NULL);

                if (!theDummyPtr)
                    break;

                if (opcode == 0x32 || opcode == 0x36)   // lfd | stfd
                {
                    UInt64  theInt64    = *(UInt64*)theDummyPtr;

                    theInt64    = OSSwapBigToHostInt64(theInt64);

                    // dance around printf's type coersion
                    snprintf(iLineCommentCString,
                        30, "%lG", *(double*)&theInt64);
                }
                else    // lfs | stfs
                {
                    uint32_t  theInt32    = *(uint32_t*)theDummyPtr;

                    theInt32    = OSSwapBigToHostInt32(theInt32);

                    // dance around printf's type coersion
                    snprintf(iLineCommentCString,
                        30, "%G", *(float*)&theInt32);
                }
            }

            break;
        }

        case 0x0e:  // li | addi    SIMM
        case 0x18:  // ori          UIMM
        case 0x20:  // lwz          SIMM
        case 0x22:  // lbz          SIMM
        case 0x24:  // stw          SIMM
        case 0x26:  // stb          SIMM
        case 0x28:  // lhz          SIMM
        case 0x2c:  // sth          SIMM
        {
            if (!iRegInfos[RA(theCode)].isValid || RA(theCode) == 0)
                break;

            if (iRegInfos[RA(theCode)].classPtr)    // relative to a class
            {   // search instance vars
                objc2_ivar_t* theIvar = NULL;
                objc2_class_t swappedClass = *iRegInfos[RA(theCode)].classPtr;

                if (!FindIvar(&theIvar, &swappedClass, UIMM(theCode)))
                    break;

                theSymPtr = GetPointer(theIvar->name, NULL);

                if (theSymPtr)
                {
                    if (iOpts.variableTypes)
                    {
                        char theTypeCString[MAX_TYPE_STRING_LENGTH];

                        theTypeCString[0] = 0;

                        GetDescription(theTypeCString, GetPointer(theIvar->type, NULL));
                        snprintf(iLineCommentCString, MAX_COMMENT_LENGTH - 1, "(%s)%s",
                            theTypeCString, theSymPtr);
                    }
                    else
                        snprintf(iLineCommentCString, MAX_COMMENT_LENGTH - 1, "%s", theSymPtr);
                }
            }
            else    // absolute address
            {
                if (opcode == 0x18) // ori      UIMM
                    localAddy   = iRegInfos[RA(theCode)].value | UIMM(theCode);
                else
                    localAddy   = iRegInfos[RA(theCode)].value + SIMM(theCode);

                UInt8   theType = PointerType;
                uint32_t  theValue;

                theSymPtr   = GetPointer(localAddy, &theType);

                if (theSymPtr)
                {
                    switch (theType)
                    {
                        case DataGenericType:
                            theValue    = *(uint32_t*)theSymPtr;
                            theValue    = OSSwapBigToHostInt32(theValue);
                            theDummyPtr = GetPointer(theValue, &theType);

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

                        case DataConstType:
                            theSymPtr   = NULL;
                            break;

// See http://www.opensource.apple.com/darwinsource/10.4.7.ppc/Csu-58/dyld.s
// They hardcoded the values, we may as well...
                        case DYLDType:
                        {
                            char*   dyldComment = NULL;

                            theValue    = *(uint32_t*)theSymPtr;
                            theValue    = OSSwapBigToHostInt32(theValue);

                            switch(theValue)
                            {
                                case kDyldAddress_LaSymBindingEntry:
                                    dyldComment = kDyldName_LaSymBindingEntry;
                                    break;
                                case kDyldAddress_FuncLookupPointer:
                                    dyldComment = kDyldName_FuncLookupPointer;
                                    break;

                                default:
                                    break;
                            }

                            if (dyldComment)
                                strcpy(iLineCommentCString, dyldComment);

                            break;
                        }

                        case PointerType:
                            break;

                        case CFStringType:
                        {
                            cf_string_object_64 theCFString = 
                                *(cf_string_object_64*)theSymPtr;

                            if (theCFString.oc_string.length == 0)
                            {
                                theSymPtr   = NULL;
                                break;
                            }

                            theCFString.oc_string.chars =
                                OSSwapBigToHostInt64(theCFString.oc_string.chars);
                            theSymPtr   = GetPointer(theCFString.oc_string.chars, NULL);

                            break;
                        }

                        case ImpPtrType:
                        case NLSymType:
                        {
                            theValue    = *(uint32_t*)theSymPtr;
                            theValue    = OSSwapBigToHostInt32(theValue);
                            theDummyPtr = GetPointer(theValue, NULL);

                            if (!theDummyPtr)
                            {
                                theSymPtr   = NULL;
                                break;
                            }

                            theValue    = *(uint32_t*)(theDummyPtr + 4);
                            theValue    = OSSwapBigToHostInt32(theValue);

                            if (theValue != typeid_NSString)
                            {
                                theValue    = *(uint32_t*)theDummyPtr;
                                theValue    = OSSwapBigToHostInt32(theValue);
                                theDummyPtr = GetPointer(theValue, NULL);

                                if (!theDummyPtr)
                                {
                                    theSymPtr   = NULL;
                                    break;
                                }
                            }

                            cf_string_object_64 theCFString = 
                                *(cf_string_object_64*)theDummyPtr;

                            if (theCFString.oc_string.length == 0)
                            {
                                theSymPtr   = NULL;
                                break;
                            }

                            theCFString.oc_string.chars =
                                OSSwapBigToHostInt64(theCFString.oc_string.chars);
                            theSymPtr = GetPointer(theCFString.oc_string.chars, NULL);

                            break;
                        }

                        case OCGenericType:
                        case OCStrObjectType:
                        case OCClassType:
                        case OCModType:
                            if (!GetObjcDescriptionFromObject(
                                &theDummyPtr, theSymPtr, theType))
                                break;

                            if (theDummyPtr)
                            {
                                switch (theType)
                                {
                                    case OCClassType:
                                        iRegInfos[RT(theCode)].classPtr =
                                            (objc2_class_t*)theSymPtr;
                                        break;

                                    default:
                                        break;
                                }
                            }

                            theSymPtr   = theDummyPtr;
                            break;

                        default:
                            break;
                    }

                    if (theSymPtr && !iLineCommentCString[0])
                    {
                        if (theType == PStringType)
                            snprintf(iLineCommentCString, 255,
                                "%*s", theSymPtr[0], theSymPtr + 1);
                        else
                            snprintf(iLineCommentCString,
                                MAX_COMMENT_LENGTH - 1, "%s", theSymPtr);
                    }
                }   // if (theSymPtr)
                else
                {   // Maybe it's a four-char code...
                    if ((opcode == 0x0e || opcode == 0x18) &&   // li | addi | ori
                        localAddy >= 0x20202020 && localAddy < 0x7f7f7f7f)
                    {
                        localAddy   = OSSwapBigToHostInt64(localAddy);

                        char*   fcc = (char*)&localAddy;

                        if (fcc[0] >= 0x20 && fcc[0] < 0x7f &&
                            fcc[1] >= 0x20 && fcc[1] < 0x7f &&
                            fcc[2] >= 0x20 && fcc[2] < 0x7f &&
                            fcc[3] >= 0x20 && fcc[3] < 0x7f)
                            snprintf(iLineCommentCString,
                                7, "'%.4s'", fcc);
                    }
                }
            }   // if !(.classPtr)

            break;
        }   // case 0x0e...

        case 0x3a:  // ld
        {
            if (iRegInfos[RA(theCode)].isValid == NO)
                break;

            UInt64 address = iRegInfos[RA(theCode)].value + DS(theCode);
            UInt8 type;
            char* symName = NULL;

            theSymPtr = GetPointer(address, &type);

            if (theSymPtr)
            {
                switch (type)
                {
                    case CFStringType:
                        GetObjcDescriptionFromObject(&symName, theSymPtr, type);

                        if (symName)
                            snprintf(iLineCommentCString, MAX_COMMENT_LENGTH - 1, "%s", symName);

                        break;

                    case OCClassRefType:
                    case OCSuperRefType:
                    case OCProtoRefType:
                    case OCProtoListType:
                    case OCMsgRefType:
                    case OCSelRefType:
                        snprintf(iLineCommentCString, MAX_COMMENT_LENGTH - 1, "%s", theSymPtr);
                        break;

                    default:
                        break;
                }
            }
            else
            {
                if (address >= iDataSect.s.addr && address < (iDataSect.s.addr + iDataSect.size))
                {
                    objc2_ivar_t* foundIvar = NULL;
                    objc2_ivar_t* maybeIvar = (objc2_ivar_t*)((iDataSect.contents) + (address - iDataSect.s.addr));

                    if (maybeIvar->offset != 0)
                    {
                        UInt64 offset = OSSwapBigToHostInt64(maybeIvar->offset);

                        if (FindIvar(&foundIvar, iCurrentClass, offset))
                        {
                            theSymPtr = GetPointer(foundIvar->name, NULL);

                            if (theSymPtr)
                            {
                                if (iOpts.variableTypes)
                                {
                                    char theTypeCString[MAX_TYPE_STRING_LENGTH];

                                    theTypeCString[0] = 0;

                                    GetDescription(theTypeCString, GetPointer(foundIvar->type, NULL));
                                    snprintf(iLineCommentCString, MAX_COMMENT_LENGTH - 1, "(%s)%s",
                                        theTypeCString, theSymPtr);
                                }
                                else
                                    snprintf(iLineCommentCString, MAX_COMMENT_LENGTH - 1, "%s", theSymPtr);
                            }
                        }
                    }
                }
            }

            break;
        }

        default:
            break;
    }
}

//  commentForSystemCall
// ----------------------------------------------------------------------------
//  System call number is stored in r0, possible values defined in
//  <sys/syscall.h>. Call numbers are indices into a lookup table of handler
//  routines. Args being passed to the looked-up handler start at r3 or r4,
//  depending on whether it's an indirect SYS_syscall.

- (void)commentForSystemCall
{
    if (!iRegInfos[0].isValid ||
         iRegInfos[0].value > SYS_MAXSYSCALL)
    {
        snprintf(iLineCommentCString, 11, "syscall(?)");
        return;
    }

    BOOL    isIndirect      = (iRegInfos[0].value == SYS_syscall);
    uint32_t  syscallNumReg   = isIndirect ? 3 : 0;
    uint32_t  syscallArg1Reg  = isIndirect ? 4 : 3;

    if (!iRegInfos[syscallNumReg].isValid   ||
        iRegInfos[syscallNumReg].value > SYS_MAXSYSCALL)
    {
        snprintf(iLineCommentCString, 11, "syscall(?)");
        return;
    }

    const char* theSysString    = gSysCalls[iRegInfos[syscallNumReg].value];

    if (!theSysString)
        return;

    char    theTempComment[50];

    theTempComment[0]   = 0;
    strncpy(theTempComment, theSysString, strlen(theSysString) + 1);

    // Handle various system calls.
    switch (iRegInfos[syscallNumReg].value)
    {
        case SYS_ptrace:
            if (iRegInfos[syscallArg1Reg].isValid &&
                iRegInfos[syscallArg1Reg].value == PT_DENY_ATTACH)
                snprintf(iLineCommentCString, 40, "%s(%s)",
                    theTempComment, "PT_DENY_ATTACH");
            else
                strncpy(iLineCommentCString, theTempComment,
                    strlen(theTempComment) + 1);

            break;

        default:
            strncpy(iLineCommentCString, theTempComment,
                strlen(theTempComment) + 1);

            break;
    }
}

//  selectorForMsgSend:fromLine:
// ----------------------------------------------------------------------------

- (char*)selectorForMsgSend: (char*)outComment
                   fromLine: (Line64*)inLine
{
    char* selString = NULL;
    uint32_t theCode = *(uint32_t*)inLine->info.code;

    theCode = OSSwapBigToHostInt32(theCode);

    // Bail if this is not an eligible branch.
    if (PO(theCode) != 0x12)    // b, bl, ba, bla
        return NULL;

    // Bail if this is not an objc_msgSend variant.
    if (memcmp(outComment, "_objc_msgSend", 13))
        return NULL;

    UInt8   sendType        = SendTypeFromMsgSend(outComment);
    uint32_t  selectorRegNum  =
        (sendType == sendSuper_stret || sendType == send_stret) ? 5 : 4;

    if (!iRegInfos[selectorRegNum].isValid ||
        !iRegInfos[selectorRegNum].value)
        return NULL;

    // Get at the selector.
    UInt8   selType     = PointerType;
    char*   selPtr      = GetPointer(
        iRegInfos[selectorRegNum].value, &selType);

    switch (selType)
    {
        case PointerType:
            selString   = selPtr;

            break;

        case OCGenericType:
            if (selPtr)
            {
                uint32_t  selPtrValue = *(uint32_t*)selPtr;

                selPtrValue = OSSwapBigToHostInt32(selPtrValue);
                selString   = GetPointer(selPtrValue, NULL);
            }

            break;

        default:
            fprintf(stderr, "otx: [PPC64Processor selectorForMsgSend:fromLine:]: "
                "unsupported selector type: %d at address: 0x%llx\n",
                selType, inLine->info.address);

            break;
    }

    return selString;
}

//  commentForMsgSend:fromLine:
// ----------------------------------------------------------------------------

- (void)commentForMsgSend: (char*)ioComment
                 fromLine: (Line64*)inLine
{
    char tempComment[MAX_COMMENT_LENGTH];

    tempComment[0] = 0;

    if (!strncmp(ioComment, "_objc_msgSend", 13))
    {
    char* selString = SelectorForMsgSend(ioComment, inLine);

    // Bail if we couldn't find the selector.
    if (!selString)
        return;

    UInt8 sendType = SendTypeFromMsgSend(ioComment);

    // Get the address of the class name string, if this a class method.
    UInt64 classNameAddy = 0;

    // If *.classPtr is non-NULL, it's not a name string.
    if (sendType == sendSuper_stret || sendType == send_stret)
    {
        if (iRegInfos[4].isValid && !iRegInfos[4].classPtr)
            classNameAddy = iRegInfos[4].value;
    }
    else
    {
        if (iRegInfos[3].isValid && !iRegInfos[3].classPtr)
            classNameAddy = iRegInfos[3].value;
    }

    char*   className           = NULL;
    char*   returnTypeString    =
        (sendType == sendSuper_stret || sendType == send_stret) ?
        "(struct)" : "";
//    char    tempComment[MAX_COMMENT_LENGTH];

//    tempComment[0]  = 0;

    if (classNameAddy)
    {
        // Get at the class name
        UInt8   classNameType   = PointerType;
        char*   classNamePtr    =
            GetPointer(classNameAddy, &classNameType);

        switch (classNameType)
        {
            // Receiver can be a static string or pointer in these sections, but we
            // only want to display class names as receivers.
            case DataGenericType:
            case DataConstType:
            case CFStringType:
            case ImpPtrType:
            case OCStrObjectType:
                break;

            case NLSymType:
				if (classNamePtr)
				{
					UInt64	namePtrValue	= *(UInt64*)classNamePtr;

					namePtrValue	= OSSwapBigToHostInt64(namePtrValue);
					classNamePtr    = GetPointer(namePtrValue, &classNameType);

                    switch (classNameType)
                    {
                        case CFStringType:
                            if (classNamePtr != NULL)
                            {
                                cf_string_object_64 classNameCFString   =
                                    *(cf_string_object_64*)classNamePtr;

                                namePtrValue	= classNameCFString.oc_string.chars;
                                namePtrValue	= OSSwapBigToHostInt64(namePtrValue);
                                classNamePtr    = GetPointer(namePtrValue, NULL);
                                className       = classNamePtr;
                            }

                            break;

                        // Not sure what these are for, but they're NULL.
                        case NLSymType:
                            break;

                        default:
                            printf("otx: [PPC64Processor commentForMsgSend:fromLine:]: "
                                "non-lazy symbol pointer points to unrecognized section: %d\n", classNameType);
                            break;
                    }
				}

                break;

            case PointerType:
                className   = classNamePtr;
                break;

            case OCGenericType:
                if (classNamePtr)
                {
                    uint32_t  namePtrValue    = *(uint32_t*)classNamePtr;

                    namePtrValue    = OSSwapBigToHostInt32(namePtrValue);
                    className       = GetPointer(namePtrValue, NULL);
                }

                break;

            case OCClassType:
                if (classNamePtr)
                    GetObjcDescriptionFromObject(
                        &className, classNamePtr, OCClassType);
                break;

            default:
                fprintf(stderr, "otx: [PPC64Processor commentForMsgSend]: "
                    "unsupported class name type: %d at address: 0x%llx\n",
                    classNameType, inLine->info.address);

                break;
        }
    }

    if (className)
    {
        snprintf(tempComment, MAX_COMMENT_LENGTH - 1,
            ((sendType == sendSuper || sendType == sendSuper_stret) ?
            "+%s[[%s super] %s]" : "+%s[%s %s]"),
            returnTypeString, className, selString);
    }
    else
    {
        switch (sendType)
        {
            case send:
            case send_rtp:
            case send_variadic:
                snprintf(tempComment, MAX_COMMENT_LENGTH - 1, "-%s[r3 %s]", returnTypeString, selString);
                break;

            case sendSuper:
                snprintf(tempComment, MAX_COMMENT_LENGTH - 1, "-%s[[r3 super] %s]", returnTypeString, selString);
                break;

            case send_stret:
                snprintf(tempComment, MAX_COMMENT_LENGTH - 1, "-%s[r4 %s]", returnTypeString, selString);
                break;

            case sendSuper_stret:
                snprintf(tempComment, MAX_COMMENT_LENGTH - 1, "-%s[[r4 super] %s]", returnTypeString, selString);
                break;

            default:
                break;
        }
    }
    }   // if (!strncmp(ioComment, "_objc_msgSend", 13))
    else if (!strncmp(ioComment, "_objc_assign_ivar", 17))
    {
        if (iCurrentClass && iRegInfos[5].isValid)
        {
            char* theSymPtr = NULL;
            objc2_ivar_t* theIvar = NULL;
            objc2_class_t swappedClass = *iCurrentClass;

            if (!iIsInstanceMethod)
            {
                if (!GetObjcMetaClassFromClass(&swappedClass, &swappedClass))
                    return;

                #if __LITTLE_ENDIAN__
                    swap_objc2_class(&swappedClass);
                #endif
            }

            if (!FindIvar(&theIvar, &swappedClass, iRegInfos[5].value))
                return;

            theSymPtr = GetPointer(theIvar->name, NULL);

            if (!theSymPtr)
                return;

            if (iOpts.variableTypes)
            {
                char    theTypeCString[MAX_TYPE_STRING_LENGTH];

                theTypeCString[0]   = 0;

                GetDescription(theTypeCString, GetPointer(theIvar->type, NULL));
                snprintf(tempComment, MAX_COMMENT_LENGTH - 1, " (%s)%s",
                    theTypeCString, theSymPtr);
            }
            else
                snprintf(tempComment,
                    MAX_COMMENT_LENGTH - 1, " %s", theSymPtr);

            strncat(ioComment, tempComment, strlen(tempComment));
        }
    }
}

//  chooseLine:
// ----------------------------------------------------------------------------

- (void)chooseLine: (Line64**)ioLine
{
    if (!(*ioLine) || !(*ioLine)->info.isCode ||
        !(*ioLine)->alt || !(*ioLine)->alt->chars)
        return;

    uint32_t theCode = *(uint32_t*)(*ioLine)->info.code;

    theCode = OSSwapBigToHostInt32(theCode);

    if (PO(theCode) == 18)  // b, ba, bl, bla
    {
        Line64* theNewLine  = malloc(sizeof(Line64));

        memcpy(theNewLine, (*ioLine)->alt, sizeof(Line64));
        theNewLine->chars   = malloc(theNewLine->length + 1);
        strncpy(theNewLine->chars, (*ioLine)->alt->chars,
            theNewLine->length + 1);

        // Swap in the verbose line and free the previous verbose lines.
        DeleteLinesBefore((*ioLine)->alt, &iVerboseLineListHead);
        ReplaceLine(*ioLine, theNewLine, &iPlainLineListHead);
        *ioLine = theNewLine;
    }
}

#pragma mark -
//  resetRegisters:
// ----------------------------------------------------------------------------

- (void)resetRegisters: (Line64*)inLine
{
    if (!inLine)
    {
        fprintf(stderr, "otx: [PPC64Processor resetRegisters]: "
            "tried to reset with NULL inLine\n");
        return;
    }

    // Setup the registers with default info. r3 is 'self' at the beginning
    // of any Obj-C method, and r12 holds the address of the 1st instruction
    // if the function was called indirectly. In the case of direct calls,
    // r12 will be overwritten before it is used, if it is used at all.
    GetObjcClassPtrFromMethod(&iCurrentClass, inLine->info.address);
//    GetObjcCatPtrFromMethod(&iCurrentCat, inLine->info.address);
    memset(iRegInfos, 0, sizeof(GP64RegisterInfo) * 32);

    // If we didn't get the class from the method, try to get it from the
    // category.
/*    if (!iCurrentClass && iCurrentCat)
    {
        objc_category   swappedCat  = *iCurrentCat;

        #if __LITTLE_ENDIAN__
            swap_objc_category(&swappedCat);
        #endif

        GetObjcClassPtrFromName(&iCurrentClass,
            GetPointer(swappedCat.class_name, NULL));
    }*/

    iRegInfos[3].classPtr   = iCurrentClass;
//    iRegInfos[3].catPtr     = iCurrentCat;
    iRegInfos[3].isValid    = YES;
    iRegInfos[12].value     = iCurrentFuncPtr;
    iRegInfos[12].isValid   = YES;
    iLR                     = (GP64RegisterInfo){0};
    iCTR                    = (GP64RegisterInfo){0};

    // Try to find out whether this is a class or instance method.
    Method64Info* thisMethod  = NULL;

    if (GetObjcMethodFromAddress(&thisMethod, inLine->info.address))
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
//  Keep our local copy of the GPRs in sync as much as possible with the
//  values that the exe will use at runtime. Assign classPtr and catPtr fields
//  in a register's info if its new value points to a class or category.
// http://developer.apple.com/documentation/DeveloperTools/Conceptual/LowLevelABI/Articles/32bitPowerPC.html
// http://developer.apple.com/documentation/DeveloperTools/Conceptual/MachOTopics/Articles/dynamic_code.html

- (void)updateRegisters: (Line64*)inLine;
{
    if (!inLine)
    {
        fprintf(stderr, "otx: [PPC64Processor updateRegisters]: "
            "tried to update with NULL inLine\n");
        return;
    }

    UInt64 theNewValue;
    uint32_t theCode = *(uint32_t*)inLine->info.code;

    theCode = OSSwapBigToHostInt32(theCode);

    if (IS_BRANCH_LINK(theCode))
    {
        iLR.value = inLine->info.address + 4;
        iLR.isValid = YES;
    }

    switch (PO(theCode))
    {
        case 0x07:  // mulli        SIMM
        {
            if (!iRegInfos[RA(theCode)].isValid)
            {
                iRegInfos[RT(theCode)] = (GP64RegisterInfo){0};
                break;
            }

            UInt64 theProduct = (SInt32)iRegInfos[RA(theCode)].value * SIMM(theCode);

            iRegInfos[RT(theCode)]          = (GP64RegisterInfo){0};
            iRegInfos[RT(theCode)].value    = theProduct & 0xffffffff;
            iRegInfos[RT(theCode)].isValid  = YES;

            break;
        }

        case 0x08:  // subfic       SIMM
            if (!iRegInfos[RA(theCode)].isValid)
            {
                iRegInfos[RT(theCode)]  = (GP64RegisterInfo){0};
                break;
            }

            theNewValue = iRegInfos[RA(theCode)].value - SIMM(theCode);

            iRegInfos[RT(theCode)]          = (GP64RegisterInfo){0};
            iRegInfos[RT(theCode)].value    = theNewValue;
            iRegInfos[RT(theCode)].isValid  = YES;

            break;

        case 0x0c:  // addic        SIMM
        case 0x0d:  // addic.       SIMM
        case 0x0e:  // addi | li    SIMM
            if (RA(theCode) == 1    &&  // current reg is stack pointer (r1)
                SIMM(theCode) >= 0)     // we're accessing local vars, not args
            {
                BOOL    found = NO;
                uint32_t  i;

                // Check for copied self pointer. This happens mostly in "init"
                // methods, as in: "self = [super init]"
                if (iLocalSelves)   // self was copied to a local variable
                {
                    // If we're accessing a local var copy of self,
                    // copy that info back to the reg in question.
                    for (i = 0; i < iNumLocalSelves; i++)
                    {
                        if (iLocalSelves[i].offset != UIMM(theCode))
                            continue;

                        iRegInfos[RT(theCode)] = iLocalSelves[i].regInfo;
                        found = YES;

                        break;
                    }
                }

                if (found)
                    break;

                // Check for other local variables.
                if (iLocalVars)
                {
                    for (i = 0; i < iNumLocalVars; i++)
                    {
                        if (iLocalVars[i].offset != UIMM(theCode))
                            continue;

                        iRegInfos[RT(theCode)] = iLocalVars[i].regInfo;
                        found = YES;

                        break;
                    }
                }

                if (found)
                    break;
            }

            // We didn't find any local variables, try immediates.
            if (RA(theCode) == 0)   // li
            {
                iRegInfos[RT(theCode)]          = (GP64RegisterInfo){0};
                iRegInfos[RT(theCode)].value    = UIMM(theCode);
                iRegInfos[RT(theCode)].isValid  = YES;
            }
            else                    // addi
            {
                // Update rD if we know what rA is.
                if (!iRegInfos[RA(theCode)].isValid)
                {
                    iRegInfos[RT(theCode)]  = (GP64RegisterInfo){0};
                    break;
                }

                iRegInfos[RT(theCode)].classPtr = NULL;
                iRegInfos[RT(theCode)].className = NULL;
                iRegInfos[RT(theCode)].messageRefSel = NULL;
//                iRegInfos[RT(theCode)].catPtr   = NULL;

                theNewValue = iRegInfos[RA(theCode)].value + SIMM(theCode);

                UInt8 type;
                char* ref = GetPointer(theNewValue, &type);

                if (type == OCMsgRefType)
                    iRegInfos[RT(theCode)].messageRefSel = ref;
                else if (type == OCClassRefType)
                    iRegInfos[RT(theCode)].className = ref;

                iRegInfos[RT(theCode)].value    = theNewValue;
                iRegInfos[RT(theCode)].isValid  = YES;
            }

            break;

        case 0x0f:  // addis | lis
            iRegInfos[RT(theCode)].classPtr = NULL;
//            iRegInfos[RT(theCode)].catPtr   = NULL;

            if (RA(theCode) == 0)   // lis
            {
                iRegInfos[RT(theCode)]          = (GP64RegisterInfo){0};
                iRegInfos[RT(theCode)].value    = UIMM(theCode) << 16;
                iRegInfos[RT(theCode)].isValid  = YES;
                break;
            }

            // addis
            if (!iRegInfos[RA(theCode)].isValid)
            {
                iRegInfos[RT(theCode)]  = (GP64RegisterInfo){0};
                break;
            }

            theNewValue = iRegInfos[RA(theCode)].value +
                (SIMM(theCode) << 16);

            iRegInfos[RT(theCode)]          = (GP64RegisterInfo){0};
            iRegInfos[RT(theCode)].value    = theNewValue;
            iRegInfos[RT(theCode)].isValid  = YES;

            break;

        case 0x10:  // bcl, bcla
        case 0x13:  // bclrl, bcctrl
            if (!IS_BRANCH_LINK(theCode))   // fall thru if link
                break;

        case 0x12:  // b, ba, bl, bla
        {
            if (!LK(theCode))   // bl, bla
                break;

            iRegInfos[3]    = (GP64RegisterInfo){0};

            break;
        }
        case 0x15:  // rlwinm
        {
            if (!iRegInfos[RT(theCode)].isValid)
            {
                iRegInfos[RA(theCode)]  = (GP64RegisterInfo){0};
                break;
            }

            UInt64  rotatedRT   =
                rotl(iRegInfos[RT(theCode)].value, RB(theCode));
            uint32_t  theMask     = 0x0;
            UInt8   i;

            for (i = MB(theCode); i <= ME(theCode); i++)
                theMask |= 1 << (31 - i);

            theNewValue = rotatedRT & theMask;

            iRegInfos[RA(theCode)]          = (GP64RegisterInfo){0};
            iRegInfos[RA(theCode)].value    = theNewValue;
            iRegInfos[RA(theCode)].isValid  = YES;

            break;
        }

        case 0x18:  // ori
            if (!iRegInfos[RT(theCode)].isValid)
            {
                iRegInfos[RA(theCode)]  = (GP64RegisterInfo){0};
                break;
            }

            theNewValue =
                iRegInfos[RT(theCode)].value | (uint32_t)UIMM(theCode);

            iRegInfos[RA(theCode)]          = (GP64RegisterInfo){0};
            iRegInfos[RA(theCode)].value    = theNewValue;
            iRegInfos[RA(theCode)].isValid  = YES;

            break;

        case 0x1e:  // rldicl
        {
            if (!iRegInfos[RT(theCode)].isValid)
            {
                iRegInfos[RA(theCode)]  = (GP64RegisterInfo){0};
                break;
            }

            UInt8 shift = SH(theCode);
            UInt8 maskBegin = MB64(theCode);

            UInt64  rotatedRT = rotl64(iRegInfos[RT(theCode)].value, shift);
            UInt64  theMask = (UInt64)-1 >> maskBegin;

            theNewValue = rotatedRT & theMask;

            iRegInfos[RA(theCode)]          = (GP64RegisterInfo){0};
            iRegInfos[RA(theCode)].value    = theNewValue;
            iRegInfos[RA(theCode)].isValid  = YES;

            break;
        }

        case 0x1f:  // multiple instructions
            switch (SO(theCode))
            {
                case 21:    // ldx
/*                    if ((RA(theCode) != 0 && !iRegInfos[RA(theCode)].isValid) ||
                        !iRegInfos[RB(theCode)].isValid)
                    {
                        iRegInfos[RT(theCode)] = (GP64RegisterInfo){0};
                        break;
                    }

                    theNewValue = (RA(theCode) == 0) ? 0 :
                        iRegInfos[RA(theCode)].value + iRegInfos[RB(theCode)].value;*/

                    iRegInfos[RT(theCode)] = (GP64RegisterInfo){0};

                    break;
                case 23:    // lwzx
                    iRegInfos[RT(theCode)]  = (GP64RegisterInfo){0};
                    break;

                case 8:     // subfc
                case 40:    // subf
                    if (!iRegInfos[RA(theCode)].isValid ||
                        !iRegInfos[RB(theCode)].isValid)
                    {
                        iRegInfos[RT(theCode)]  = (GP64RegisterInfo){0};
                        break;
                    }

                    // 2's complement subtraction
                    theNewValue =
                        (iRegInfos[RA(theCode)].value ^= 0xffffffff) +
                        iRegInfos[RB(theCode)].value + 1;

                    iRegInfos[RT(theCode)]          = (GP64RegisterInfo){0};
                    iRegInfos[RT(theCode)].value    = theNewValue;
                    iRegInfos[RT(theCode)].isValid  = YES;

                    break;

                case 266:   // add
                    if (iRegInfos[RA(theCode)].isValid && iRegInfos[RB(theCode)].isValid)
                    {
                        iRegInfos[RT(theCode)].value =
                            iRegInfos[RA(theCode)].value + iRegInfos[RB(theCode)].value;
                        iRegInfos[RT(theCode)].isValid = YES;
                        iRegInfos[RT(theCode)].classPtr = NULL;
                        iRegInfos[RT(theCode)].className = NULL;
                        iRegInfos[RT(theCode)].messageRefSel = NULL;
                    }
                    else
                        iRegInfos[RT(theCode)] = (GP64RegisterInfo){0};

                    break;

                case 339:   // mfspr
                    iRegInfos[RT(theCode)]  = (GP64RegisterInfo){0};

                    if (SPR(theCode) == LR  &&  // from LR
                        iLR.isValid)
                    {   // Copy LR into rD.
                        iRegInfos[RT(theCode)].value    = iLR.value;
                        iRegInfos[RT(theCode)].isValid  = YES;
                    }

                    break;

                case 444:   // or | or.
                    if (!iRegInfos[RT(theCode)].isValid ||
                        !iRegInfos[RB(theCode)].isValid)
                    {
                        iRegInfos[RA(theCode)]  = (GP64RegisterInfo){0};
                        break;
                    }

                    theNewValue =
                        (iRegInfos[RT(theCode)].value |
                         iRegInfos[RB(theCode)].value);

                    iRegInfos[RA(theCode)]          = (GP64RegisterInfo){0};
                    iRegInfos[RA(theCode)].value    = theNewValue;
                    iRegInfos[RA(theCode)].isValid  = YES;

                    // If we just copied a register, copy the
                    // remaining fields.
                    if (RT(theCode) == RB(theCode))
                    {
                        iRegInfos[RA(theCode)].classPtr =
                            iRegInfos[RB(theCode)].classPtr;
                        iRegInfos[RA(theCode)].className =
                            iRegInfos[RB(theCode)].className;
                        iRegInfos[RA(theCode)].messageRefSel =
                            iRegInfos[RB(theCode)].messageRefSel;
//                        iRegInfos[RA(theCode)].catPtr   =
//                            iRegInfos[RB(theCode)].catPtr;
                    }

                    break;

                case 467:   // mtspr
                    if (SPR(theCode) == CTR)    // to CTR
                    {
                        if (!iRegInfos[RS(theCode)].isValid)
                        {
                            iCTR = (GP64RegisterInfo){0};
                            break;
                        }

                        iCTR.value = iRegInfos[RS(theCode)].value;
                        iCTR.isValid = YES;
                    }

                    break;

                case 24:    // slw
                    if (!iRegInfos[RS(theCode)].isValid ||
                        !iRegInfos[RB(theCode)].isValid)
                    {
                        iRegInfos[RA(theCode)] = (GP64RegisterInfo){0};
                        break;
                    }

                    if (SB(iRegInfos[RB(theCode)].value))
                    {
                        theNewValue =
                            iRegInfos[RS(theCode)].value <<
                                SV(iRegInfos[RB(theCode)].value);
                    }
                    else    // If RB.5 == 0, RA = 0.
                        theNewValue = 0;

                    iRegInfos[RA(theCode)]          = (GP64RegisterInfo){0};
                    iRegInfos[RA(theCode)].value    = theNewValue;
                    iRegInfos[RA(theCode)].isValid  = YES;

                    break;

                case 536:   // srw
                    if (!iRegInfos[RS(theCode)].isValid ||
                        !iRegInfos[RB(theCode)].isValid)
                    {
                        iRegInfos[RA(theCode)]  = (GP64RegisterInfo){0};
                        break;
                    }

                    theNewValue =
                        iRegInfos[RS(theCode)].value >>
                            SV(iRegInfos[RB(theCode)].value);

                    iRegInfos[RA(theCode)]          = (GP64RegisterInfo){0};
                    iRegInfos[RA(theCode)].value    = theNewValue;
                    iRegInfos[RA(theCode)].isValid  = YES;

                    break;

                default:
                    // Ideally, we would zero the destination register here. Sadly, because SO values can vary in their formats, we don't know which register is the destination.
                    break;
            }

            break;

        case 0x20:  // lwz
        case 0x22:  // lbz
            if (RA(theCode) == 0)
            {
                iRegInfos[RT(theCode)]          = (GP64RegisterInfo){0};
                iRegInfos[RT(theCode)].value    = SIMM(theCode);
                iRegInfos[RT(theCode)].isValid  = YES;
            }
            else if (iRegInfos[RA(theCode)].isValid)
            {
                uint32_t  tempPtr = (uint32_t)GetPointer(
                    iRegInfos[RA(theCode)].value + SIMM(theCode), NULL);

                if (tempPtr)
                {
                    iRegInfos[RT(theCode)]          = (GP64RegisterInfo){0};
                    iRegInfos[RT(theCode)].value    = *(uint32_t*)tempPtr;
                    iRegInfos[RT(theCode)].value    =
                        OSSwapBigToHostInt64(iRegInfos[RT(theCode)].value);
                    iRegInfos[RT(theCode)].isValid  = YES;
                }
                else
                    iRegInfos[RT(theCode)]  = (GP64RegisterInfo){0};
            }
            else if (iLocalVars)
            {
                uint32_t  i;

                for (i = 0; i < iNumLocalVars; i++)
                {
                    if (iLocalVars[i].offset == SIMM(theCode))
                    {
                        iRegInfos[RT(theCode)]  = iLocalVars[i].regInfo;
                        break;
                    }
                }
            }
            else
                iRegInfos[RT(theCode)]  = (GP64RegisterInfo){0};

            break;

/*      case 0x22:  // lbz
            mRegInfos[RT(theCode)]  = (GP64RegisterInfo){0};

            if (RA(theCode) == 0)
            {
                mRegInfos[RT(theCode)].value    = SIMM(theCode);
                mRegInfos[RT(theCode)].isValid  = YES;
            }

            break;*/

        case 0x24:  // stw
            if (!iRegInfos[RT(theCode)].isValid ||
                RA(theCode) != 1                ||
                SIMM(theCode) < 0)
                break;

            if (iRegInfos[RT(theCode)].classPtr)    // if it's a class
            {
                iNumLocalSelves++;
                iLocalSelves    = realloc(iLocalSelves,
                    iNumLocalSelves * sizeof(Var64Info));
                iLocalSelves[iNumLocalSelves - 1]   = (Var64Info)
                    {iRegInfos[RT(theCode)], UIMM(theCode)};
            }
            else
            {
                iNumLocalVars++;
                iLocalVars  = realloc(iLocalVars,
                    iNumLocalVars * sizeof(Var64Info));
                iLocalVars[iNumLocalVars - 1]   = (Var64Info)
                    {iRegInfos[RT(theCode)], UIMM(theCode)};
            }

            break;

/*      case 0x21:
        case 0x23:
        case 0x25:
        case 0x26:
        case 0x27:
        case 0x28:
        case 0x29:
        case 0x2a:
        case 0x2b:
        case 0x2c:
        case 0x2d:
        case 0x2e:
        case 0x2f:
            break;*/

        case 0x3a:  // ld
        {
            if (RA(theCode) == 0)
            {
                iRegInfos[RT(theCode)]          = (GP64RegisterInfo){0};
                iRegInfos[RT(theCode)].value    = DS(theCode);
                iRegInfos[RT(theCode)].isValid  = YES;
            }
            else if (iRegInfos[RA(theCode)].className != NULL && DS(theCode) == 0)
            {
                iRegInfos[RT(theCode)] = iRegInfos[RA(theCode)];
            }
            else if (iRegInfos[RA(theCode)].isValid)
            {
                iRegInfos[RT(theCode)].classPtr = NULL;
                iRegInfos[RT(theCode)].className = NULL;
                iRegInfos[RT(theCode)].messageRefSel = NULL;

                UInt64 newValue = iRegInfos[RA(theCode)].value + DS(theCode);

                iRegInfos[RT(theCode)].value = newValue;
                iRegInfos[RT(theCode)].isValid = YES;

                UInt8 type;

                char* ref = GetPointer(newValue, &type);

                if (type == OCClassRefType || type == OCSuperRefType)
                    iRegInfos[RT(theCode)].className = ref;
            }
            else if (RA(theCode) == 1 && DS(theCode) >= 0)
            {
                BOOL    found = NO;
                uint32_t  i;

                // Check for copied self pointer. This happens mostly in "init"
                // methods, as in: "self = [super init]"
                if (iLocalSelves)   // self was copied to a local variable
                {
                    // If we're accessing a local var copy of self,
                    // copy that info back to the reg in question.
                    for (i = 0; i < iNumLocalSelves; i++)
                    {
                        if (iLocalSelves[i].offset != UIMM(theCode))
                            continue;

                        iRegInfos[RT(theCode)] = iLocalSelves[i].regInfo;
                        found = YES;
                        break;
                    }
                }

                if (found)
                    break;

                // Check for other local variables.
                if (iLocalVars)
                {
                    for (i = 0; i < iNumLocalVars; i++)
                    {
                        if (iLocalVars[i].offset != UIMM(theCode))
                            continue;

                        iRegInfos[RT(theCode)] = iLocalVars[i].regInfo;
                        found = YES;
                        break;
                    }
                }

                // We don't know what's being loaded, just zero the receiver.
                if (found == NO)
                    iRegInfos[RT(theCode)] = (GP64RegisterInfo){0};
            }
            else
                iRegInfos[RT(theCode)] = (GP64RegisterInfo){0};

/*            else if (iRegInfos[RA(theCode)].isValid)
            {
                UInt64 address = iRegInfos[RA(theCode)].value + DS(theCode);
                UInt8 ptrType = PointerType;

                char* sel = GetPointer(address, &ptrType);

                if (sel != NULL && ptrType == OCMsgRefType)
                    iRegInfos[RT(theCode)].messageRefSel = sel;
                else
                    iRegInfos[RT(theCode)].messageRefSel = NULL;

                iRegInfos[RT(theCode)].classPtr = NULL;
                iRegInfos[RT(theCode)].className = NULL;
                iRegInfos[RT(theCode)].value    = address;
                iRegInfos[RT(theCode)].isValid  = YES;
            }*/

            break;
        }

        case 0x3e:  // std
            if (!iRegInfos[RT(theCode)].isValid || RA(theCode) != 1 || DS(theCode) < 0)
                break;

            if (iRegInfos[RT(theCode)].classPtr)    // if it's a class
            {
                iNumLocalSelves++;
                iLocalSelves = realloc(iLocalSelves, iNumLocalSelves * sizeof(Var64Info));
                iLocalSelves[iNumLocalSelves - 1] = (Var64Info){iRegInfos[RT(theCode)], (uint32_t)DS(theCode)};
            }
            else
            {
                iNumLocalVars++;
                iLocalVars = realloc(iLocalVars, iNumLocalVars * sizeof(Var64Info));
                iLocalVars[iNumLocalVars - 1] = (Var64Info) {iRegInfos[RT(theCode)], (uint32_t)DS(theCode)};
            }

            break;

        default:
            break;
    }
}

//  restoreRegisters:
// ----------------------------------------------------------------------------

- (BOOL)restoreRegisters: (Line64*)inLine
{
    if (!inLine)
    {
        fprintf(stderr, "otx: [PPC64Processor restoreRegisters]: "
            "tried to restore with NULL inLine\n");
        return NO;
    }

    BOOL needNewLine = NO;

    if (iCurrentFuncInfoIndex < 0)
        return NO;

    // Search current Function64Info for blocks that start at this address.
    Function64Info* funcInfo    =
        &iFuncInfos[iCurrentFuncInfoIndex];

    if (!funcInfo->blocks)
        return NO;

    uint32_t  i;

    for (i = 0; i < funcInfo->numBlocks; i++)
    {
        if (funcInfo->blocks[i].beginAddress !=
            inLine->info.address)
            continue;

        // Update machine state.
        Machine64State  machState   =
            funcInfo->blocks[i].state;

        memcpy(iRegInfos, machState.regInfos,
            sizeof(GP64RegisterInfo) * 32);
        iLR     = machState.regInfos[LRIndex];
        iCTR    = machState.regInfos[CTRIndex];

        if (machState.localSelves)
        {
            if (iLocalSelves)
                free(iLocalSelves);

            iNumLocalSelves = machState.numLocalSelves;
            iLocalSelves    = malloc(
                sizeof(Var64Info) * iNumLocalSelves);
            memcpy(iLocalSelves, machState.localSelves,
                sizeof(Var64Info) * iNumLocalSelves);
        }

        if (machState.localVars)
        {
            if (iLocalVars)
                free(iLocalVars);

            iNumLocalVars   = machState.numLocalVars;
            iLocalVars      = malloc(
                sizeof(Var64Info) * iNumLocalVars);
            memcpy(iLocalVars, machState.localVars,
                sizeof(Var64Info) * iNumLocalVars);
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

- (BOOL)lineIsFunction: (Line64*)inLine
{
    if (!inLine)
        return NO;

    UInt64 theAddy = inLine->info.address;

    if (theAddy == iAddrDyldStubBindingHelper   ||
        theAddy == iAddrDyldFuncLookupPointer)
        return YES;

    Method64Info* theDummyInfo    = NULL;

    // In Obj-C apps, the majority of funcs will have Obj-C symbols, so check
    // those first.
    if (FindClassMethodByAddress(&theDummyInfo, theAddy))
        return YES;

//    if (FindCatMethodByAddress(&theDummyInfo, theAddy))
//        return YES;

    // If it's not an Obj-C method, maybe there's an nlist.
    if (FindSymbolByAddress(theAddy))
        return YES;

    // If otool gave us a function name...
    if (inLine->prev && !inLine->prev->info.isCode)
        return YES;

    BOOL isFunction = NO;
    uint32_t theCode = *(uint32_t*)inLine->info.code;

    theCode = OSSwapBigToHostInt32(theCode);

    if ((theCode & 0xfc1fffff) == 0x7c0802a6)   // mflr to any reg
    {   // Allow for late mflr
        BOOL    foundUB = NO;
        Line64* thePrevLine = inLine->prev;

        // Walk back to the most recent unconditional branch, looking
        // for existing symbols.
        while (!foundUB && thePrevLine)
        {
            // Allow for multiple mflr's
            if (thePrevLine->info.isFunction)
                return NO;

            theCode = *(uint32_t*)thePrevLine->info.code;
            theCode = OSSwapBigToHostInt32(theCode);

            if ((theCode & 0xfc0007ff) == 0x7c000008)   // trap
            {
                foundUB = YES;
                continue;
            }

            UInt8   opcode  = PO(theCode);

            if (opcode == 16 || opcode == 18 || opcode == 19)
            // bc, bca, bcl, bcla, b, ba, bl, bla, bclr, bclrl and more
            {
                if (!IS_BRANCH_CONDITIONAL(theCode) &&
                    theCode != 0x429f0005 &&    // bcl w/ "always branch"
                    (theCode & 0x48000001) != 0x48000001)    // bl
                    foundUB = YES;
            }

            if (!foundUB)
                thePrevLine = thePrevLine->prev;
        }

        if (!thePrevLine)
            return YES;

        thePrevLine = thePrevLine->next;

        // If the code line following the most recent unconditional
        // branch is not already recognized, flag it now.
        if (thePrevLine == inLine)
            isFunction  = YES;
        else
        {
            BOOL foundStart = NO;

            for (; thePrevLine != inLine;
                thePrevLine = thePrevLine->next)
            {
                if (!thePrevLine->info.isCode)
                    continue;   // not code, keep looking
                else if (!thePrevLine->info.isFunction)
                {               // not yet recognized, try it
                    theCode = *(uint32_t*)thePrevLine->info.code;
                    theCode = OSSwapBigToHostInt32(theCode);

                    if (theCode == 0x7fe00008   ||  // ignore traps
                        theCode == 0x60000000   ||  // ignore nops
                        theCode == 0x00000000)      // ignore .longs
                        continue;
                    else
                    {
                        thePrevLine->info.isFunction = YES;
                        foundStart = YES;
                        break;
                    }
                }
                else    // already recognized, bail
                {
                    foundStart = YES;
                    break;
                }
            }

            if (!foundStart)
                isFunction = YES;
        }
    }   // if (theCode == 0x7c0802a6)

    return isFunction;
}

//  codeIsBlockJump:
// ----------------------------------------------------------------------------

- (BOOL)codeIsBlockJump: (UInt8*)inCode
{
    uint32_t theCode = *(uint32_t*)inCode;

    theCode = OSSwapBigToHostInt32(theCode);
    return IS_BLOCK_BRANCH(theCode);
}

//  gatherFuncInfos
// ----------------------------------------------------------------------------

- (void)gatherFuncInfos
{
    Line64* theLine     = iPlainLineListHead;
    uint32_t  theCode;
    uint32_t  progCounter = 0;

    // Loop thru lines.
    while (theLine)
    {
        if (!(progCounter % (PROGRESS_FREQ * 5)))
        {
            if (gCancel == YES)
                return;

//            [NSThread sleepForTimeInterval: 0.0];
        }

        if (!theLine->info.isCode)
        {
            theLine = theLine->next;
            continue;
        }

        theCode = *(uint32_t*)theLine->info.code;
        theCode = OSSwapBigToHostInt32(theCode);

        if (theLine->info.isFunction)
        {
            iCurrentFuncPtr = theLine->info.address;
            ResetRegisters(theLine);
        }
        else
            RestoreRegisters(theLine);

        UpdateRegisters(theLine);

        // Check if we need to save the machine state.
        if (IS_BLOCK_BRANCH(theCode) && iCurrentFuncInfoIndex >= 0 &&
            PO(theCode) != 0x13)    // no new blocks for blr, bctr
        {
            UInt64 branchTarget = 0;

            // Retrieve the branch target.
            if (PO(theCode) == 0x12)    // b
                branchTarget = theLine->info.address + LI(theCode);
            else if (PO(theCode) == 0x10)   // bc
                branchTarget = theLine->info.address + BD(theCode);

            // Retrieve current Function64Info.
            Function64Info* funcInfo    =
                &iFuncInfos[iCurrentFuncInfoIndex];

            // 'currentBlock' will point to either an existing block which
            // we will update, or a newly allocated block.
            Block64Info*    currentBlock    = NULL;
            Line64*         endLine         = NULL;
            BOOL            isEpilog        = NO;
            uint32_t          i;

            if (funcInfo->blocks)
            {   // Blocks exist, find 1st one matching this address.
                // This is an exhaustive search, but the speed hit should
                // only be an issue with extremely long functions.
                for (i = 0; i < funcInfo->numBlocks; i++)
                {
                    if (funcInfo->blocks[i].beginAddress == branchTarget)
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
                        Line64      searchKey = {NULL, 0, NULL, NULL, NULL, {branchTarget, {0}, YES, NO}};
                        Line64*     searchKeyPtr = &searchKey;
                        Line64**    beginLine = bsearch(&searchKeyPtr, iLineArray, iNumCodeLines, sizeof(Line64*),
                            (COMPARISON_FUNC_TYPE)Line_Address_Compare);

                        if (beginLine != NULL)
                        {
                            // Walk through the block. It's an epilog if it ends
                            // with 'blr'.
                            Line64* nextLine    = *beginLine;
                            uint32_t  tempCode;

                            while (nextLine)
                            {
                                tempCode = *(uint32_t*)nextLine->info.code;
                                tempCode = OSSwapBigToHostInt32(tempCode);

                                if (IS_BLOCK_BRANCH(tempCode))
                                {
                                    endLine = nextLine;

                                    if (IS_BLR(tempCode))
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
                        sizeof(Block64Info) * funcInfo->numBlocks);
                    currentBlock =
                        &funcInfo->blocks[funcInfo->numBlocks - 1];
                    *currentBlock = (Block64Info){0};
                }
            }
            else
            {   // No existing blocks, allocate one.
                funcInfo->numBlocks++;
                funcInfo->blocks    = calloc(1, sizeof(Block64Info));
                currentBlock        = funcInfo->blocks;
            }

            // sanity check
            if (!currentBlock)
            {
                fprintf(stderr, "otx: [PPC64Processor gatherFuncInfos] "
                    "currentBlock is NULL. Flame the dev.\n");
                return;
            }

            // Create a new Machine64State.
            GP64RegisterInfo*   savedRegs   = malloc(
                sizeof(GP64RegisterInfo) * 34);

            memcpy(savedRegs, iRegInfos, sizeof(GP64RegisterInfo) * 32);
            savedRegs[LRIndex]  = iLR;
            savedRegs[CTRIndex] = iCTR;

            Var64Info*  savedSelves = NULL;

            if (iLocalSelves)
            {
                savedSelves = malloc(
                    sizeof(Var64Info) * iNumLocalSelves);
                memcpy(savedSelves, iLocalSelves,
                    sizeof(Var64Info) * iNumLocalSelves);
            }

            Var64Info*  savedVars   = NULL;

            if (iLocalVars)
            {
                savedVars   = malloc(
                    sizeof(Var64Info) * iNumLocalVars);
                memcpy(savedVars, iLocalVars,
                    sizeof(Var64Info) * iNumLocalVars);
            }

            Machine64State  machState   =
                {savedRegs, savedSelves, iNumLocalSelves,
                    savedVars, iNumLocalVars};

            // Store the new Block64Info.
            Block64Info blockInfo   =
                {branchTarget, endLine, isEpilog, machState};

            memcpy(currentBlock, &blockInfo, sizeof(Block64Info));
        }

        theLine = theLine->next;
        progCounter++;
    }

    iCurrentFuncInfoIndex   = -1;
}

#ifdef OTX_DEBUG
//  printBlocks:
// ----------------------------------------------------------------------------

- (void)printBlocks: (uint32_t)inFuncIndex;
{
    if (!iFuncInfos)
        return;

    Function64Info* funcInfo    = &iFuncInfos[inFuncIndex];

    if (!funcInfo || !funcInfo->blocks)
        return;

    uint32_t  i, j;

    fprintf(stderr, "\nfunction at 0x%llx:\n\n", funcInfo->address);
    fprintf(stderr, "%d blocks\n", funcInfo->numBlocks);

    for (i = 0; i < funcInfo->numBlocks; i++)
    {
        fprintf(stderr, "\nblock %d at 0x%llx:\n\n", i + 1,
            funcInfo->blocks[i].beginAddress);

        for (j = 0; j < 32; j++)
        {
            if (!funcInfo->blocks[i].state.regInfos[j].isValid)
                continue;

            fprintf(stderr, "\t\tr%d: 0x%llx\n", j,
                funcInfo->blocks[i].state.regInfos[j].value);
        }
    }
}
#endif  // OTX_DEBUG

@end
