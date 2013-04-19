/*
    PPCProcessor.m

    A subclass of ExeProcessor that handles PPC-specific issues.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "PPCProcessor.h"
#import "ArchSpecifics.h"
#import "ListUtils.h"
#import "ObjcAccessors.h"
#import "ObjectLoader.h"
#import "SyscallStrings.h"
#import "UserDefaultKeys.h"

extern BOOL gCancel;

@implementation PPCProcessor

//  initWithURL:controller:options:
// ----------------------------------------------------------------------------

- (id)initWithURL: (NSURL*)inURL
       controller: (id)inController
          options: (ProcOptions*)inOptions
{
    if ((self = [super initWithURL: inURL
        controller: inController options: inOptions]))
    {
        strncpy(iArchString, "ppc", 4);

        iArchSelector               = CPU_TYPE_POWERPC;
        iFieldWidths.offset         = 8;
        iFieldWidths.address        = 10;
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

- (void)loadDyldDataSection: (section*)inSect
{
    [super loadDyldDataSection: inSect];

    if (!iAddrDyldStubBindingHelper)
        return;

    iAddrDyldFuncLookupPointer  = iAddrDyldStubBindingHelper + 24;
}

//  codeFromLine:
// ----------------------------------------------------------------------------

- (void)codeFromLine: (Line*)inLine
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

- (void)commentForLine: (Line*)inLine;
{
    uint32_t theCode = *(uint32_t*)inLine->info.code;

    theCode = OSSwapBigToHostInt32(theCode);

    char*   theDummyPtr = NULL;
    char*   theSymPtr   = NULL;
    UInt8   opcode      = PO(theCode);
    uint32_t  localAddy;

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
                            objc_ivar   theIvar         = {0};
                            objc_class  swappedClass    = *iCurrentClass;

                            #if __LITTLE_ENDIAN__
                                swap_objc_class(&swappedClass);
                            #endif

                            if (!iIsInstanceMethod)
                            {
                                if (!GetObjcMetaClassFromClass(
                                    &swappedClass, &swappedClass))
                                    break;

                                #if __LITTLE_ENDIAN__
                                    swap_objc_class(&swappedClass);
                                #endif
                            }

                            if (!FindIvar(&theIvar,
                                &swappedClass, iRegInfos[5].value))
                            {
                                strncpy(iLineCommentCString, tempComment,
                                    strlen(tempComment) + 1);
                                break;
                            }

                            theSymPtr   = GetPointer(
                                (uint32_t)theIvar.ivar_name, NULL);

                            if (!theSymPtr)
                            {
                                strncpy(iLineCommentCString, tempComment,
                                    strlen(tempComment) + 1);
                                break;
                            }

                            if (iOpts.variableTypes)
                            {
                                char    theTypeCString[MAX_TYPE_STRING_LENGTH];

                                theTypeCString[0]   = 0;

                                GetDescription(theTypeCString,
                                    GetPointer((uint32_t)theIvar.ivar_type, NULL));
                                snprintf(iLineCommentCString,
                                    MAX_COMMENT_LENGTH - 1, "%s (%s)%s",
                                    tempComment, theTypeCString, theSymPtr);
                            }
                            else
                                snprintf(iLineCommentCString,
                                    MAX_COMMENT_LENGTH - 1, "%s %s",
                                    tempComment, theSymPtr);
                        }
                        else    // !mReginfos[5].isValid
                            strncpy(iLineCommentCString, tempComment,
                                strlen(tempComment) + 1);

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

                uint32_t  absoluteAddy;

                if (opcode == 0x12)
                    absoluteAddy =
                        inLine->info.address + LI(theCode);
                else
                    absoluteAddy =
                        inLine->info.address + BD(theCode);

                FunctionInfo    searchKey   = {absoluteAddy, NULL, 0, 0};
                FunctionInfo*   funcInfo    = bsearch(&searchKey,
                    iFuncInfos, iNumFuncInfos, sizeof(FunctionInfo),
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

            // Print value of ctr, ignoring the low 2 bits.
            if (iCTR.isValid)
                snprintf(iLineCommentCString, 10, "0x%x",
                    iCTR.value & ~3);

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
                objc_ivar   theIvar         = {0};
                objc_class  swappedClass    =
                    *iRegInfos[RA(theCode)].classPtr;

                #if __LITTLE_ENDIAN__
                    swap_objc_class(&swappedClass);
                #endif

                if (!iIsInstanceMethod)
                {
                    if (!GetObjcMetaClassFromClass(
                        &swappedClass, &swappedClass))
                        break;

                    #if __LITTLE_ENDIAN__
                        swap_objc_class(&swappedClass);
                    #endif
                }

                if (!FindIvar(&theIvar, &swappedClass, UIMM(theCode)))
                    break;

                theSymPtr   = GetPointer(
                    (uint32_t)theIvar.ivar_name, NULL);

                if (theSymPtr)
                {
                    if (iOpts.variableTypes)
                    {
                        char    theTypeCString[MAX_TYPE_STRING_LENGTH];

                        theTypeCString[0]   = 0;

                        GetDescription(theTypeCString,
                            GetPointer((uint32_t)theIvar.ivar_type, NULL));
                        snprintf(iLineCommentCString,
                            MAX_COMMENT_LENGTH - 1, "(%s)%s",
                            theTypeCString, theSymPtr);
                    }
                    else
                        snprintf(iLineCommentCString,
                            MAX_COMMENT_LENGTH - 1, "%s", theSymPtr);
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
                objc_ivar   theIvar     = {0};
                objc_class  swappedClass    =
                    *iRegInfos[RA(theCode)].classPtr;

                #if __LITTLE_ENDIAN__
                    swap_objc_class(&swappedClass);
                #endif

                if (!iIsInstanceMethod)
                {
                    if (!GetObjcMetaClassFromClass(
                        &swappedClass, &swappedClass))
                        break;

                    #if __LITTLE_ENDIAN__
                        swap_objc_class(&swappedClass);
                    #endif
                }

                if (!FindIvar(&theIvar, &swappedClass, UIMM(theCode)))
                    break;

                theSymPtr   = GetPointer(
                    (uint32_t)theIvar.ivar_name, NULL);

                if (theSymPtr)
                {
                    if (iOpts.variableTypes)
                    {
                        char    theTypeCString[MAX_TYPE_STRING_LENGTH];

                        theTypeCString[0]   = 0;

                        GetDescription(theTypeCString,
                            GetPointer((uint32_t)theIvar.ivar_type, NULL));
                        snprintf(iLineCommentCString,
                            MAX_COMMENT_LENGTH - 1, "(%s)%s",
                            theTypeCString, theSymPtr);
                    }
                    else
                        snprintf(iLineCommentCString,
                            MAX_COMMENT_LENGTH - 1, "%s", theSymPtr);
                }
            }
            else    // absolute address
            {
                if (opcode == 0x18) // ori      UIMM
                    localAddy   = iRegInfos[RA(theCode)].value |
                        UIMM(theCode);
                else
                    localAddy   = iRegInfos[RA(theCode)].value +
                        SIMM(theCode);

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
                            cf_string_object    theCFString = 
                                *(cf_string_object*)theSymPtr;

                            if (theCFString.oc_string.length == 0)
                            {
                                theSymPtr   = NULL;
                                break;
                            }

                            theCFString.oc_string.chars =
                                (char*)OSSwapBigToHostInt32(
                                (uint32_t)theCFString.oc_string.chars);
                            theSymPtr   = GetPointer(
                                (uint32_t)theCFString.oc_string.chars, NULL);

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

                            cf_string_object    theCFString = 
                                *(cf_string_object*)theDummyPtr;

                            if (theCFString.oc_string.length == 0)
                            {
                                theSymPtr   = NULL;
                                break;
                            }

                            theCFString.oc_string.chars =
                                (char*)OSSwapBigToHostInt32(
                                (uint32_t)theCFString.oc_string.chars);
                            theSymPtr   = GetPointer(
                                (uint32_t)theCFString.oc_string.chars, NULL);

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
                                            (objc_class*)theSymPtr;
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
                        localAddy   = OSSwapBigToHostInt32(localAddy);

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
                   fromLine: (Line*)inLine
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
            fprintf(stderr, "otx: [PPCProcessor selectorForMsgSend:fromLine:]: "
                "unsupported selector type: %d at address: 0x%x\n",
                selType, inLine->info.address);

            break;
    }

    return selString;
}

//  commentForMsgSend:fromLine:
// ----------------------------------------------------------------------------

- (void)commentForMsgSend: (char*)ioComment
                 fromLine: (Line*)inLine
{
    char*   selString   = SelectorForMsgSend(ioComment, inLine);

    // Bail if we couldn't find the selector.
    if (!selString)
        return;

    UInt8   sendType    = SendTypeFromMsgSend(ioComment);

    // Get the address of the class name string, if this a class method.
    uint32_t  classNameAddy   = 0;

    // If *.classPtr is non-NULL, it's not a name string.
    if (sendType == sendSuper_stret || sendType == send_stret)
    {
        if (iRegInfos[4].isValid && !iRegInfos[4].classPtr)
            classNameAddy   = iRegInfos[4].value;
    }
    else
    {
        if (iRegInfos[3].isValid && !iRegInfos[3].classPtr)
            classNameAddy   = iRegInfos[3].value;
    }

    char*   className           = NULL;
    char*   returnTypeString    =
        (sendType == sendSuper_stret || sendType == send_stret) ?
        "(struct)" : "";
    char    tempComment[MAX_COMMENT_LENGTH];

    tempComment[0]  = 0;

    if (classNameAddy)
    {
        // Get at the class name
        UInt8   classNameType   = PointerType;
        char*   classNamePtr    =
            GetPointer(classNameAddy, &classNameType);

        switch (classNameType)
        {
            // Receiver can be various things in these sections, but we
            // only want to display class names as receivers.
            case DataGenericType:
            case DataConstType:
            case CFStringType:
            case ImpPtrType:
            case OCStrObjectType:
            case OCModType:
            case PStringType:
            case DoubleType:
                break;

            case NLSymType:
                if (classNamePtr)
                {
                    uint32_t	namePtrValue	= *(uint32_t*)classNamePtr;

                    namePtrValue	= OSSwapBigToHostInt32(namePtrValue);
                    classNamePtr    = GetPointer(namePtrValue, &classNameType);

                    switch (classNameType)
                    {
                        case CFStringType:
                            if (classNamePtr != NULL)
                            {
                                cf_string_object    classNameCFString   =
                                    *(cf_string_object*)classNamePtr;

                                namePtrValue	= (uint32_t)classNameCFString.oc_string.chars;
                                namePtrValue	= OSSwapBigToHostInt32(namePtrValue);
                                classNamePtr    = GetPointer(namePtrValue, NULL);
                                className       = classNamePtr;
                            }

                            break;

                        // Not sure what these are for, but they're out there.
                        case NLSymType:
                        case FloatType:
                            break;

                        default:
                            printf("otx: [PPCProcessor commentForMsgSend:fromLine:]: "
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
                fprintf(stderr, "otx: [PPCProcessor commentForMsgSend]: "
                    "unsupported class name type: %d at address: 0x%x\n",
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

    if (tempComment[0])
        strncpy(ioComment, tempComment, strlen(tempComment) + 1);
}

//  chooseLine:
// ----------------------------------------------------------------------------

- (void)chooseLine: (Line**)ioLine
{
    if (!(*ioLine) || !(*ioLine)->info.isCode ||
        !(*ioLine)->alt || !(*ioLine)->alt->chars)
        return;

    uint32_t theCode = *(uint32_t*)(*ioLine)->info.code;

    theCode = OSSwapBigToHostInt32(theCode);

    if (PO(theCode) == 18)  // b, ba, bl, bla
    {
        Line* theNewLine  = malloc(sizeof(Line));

        memcpy(theNewLine, (*ioLine)->alt, sizeof(Line));
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

- (void)resetRegisters: (Line*)inLine
{
    if (!inLine)
    {
        fprintf(stderr, "otx: [PPCProcessor resetRegisters]: "
            "tried to reset with NULL inLine\n");
        return;
    }

    // Setup the registers with default info. r3 is 'self' at the beginning
    // of any Obj-C method, and r12 holds the address of the 1st instruction
    // if the function was called indirectly. In the case of direct calls,
    // r12 will be overwritten before it is used, if it is used at all.
    GetObjcClassPtrFromMethod(&iCurrentClass, inLine->info.address);
    GetObjcCatPtrFromMethod(&iCurrentCat, inLine->info.address);
    memset(iRegInfos, 0, sizeof(GPRegisterInfo) * 32);

    // If we didn't get the class from the method, try to get it from the
    // category.
    if (!iCurrentClass && iCurrentCat)
    {
        objc_category   swappedCat  = *iCurrentCat;

        #if __LITTLE_ENDIAN__
            swap_objc_category(&swappedCat);
        #endif

        GetObjcClassPtrFromName(&iCurrentClass,
            GetPointer((uint32_t)swappedCat.class_name, NULL));
    }

    iRegInfos[3].classPtr   = iCurrentClass;
    iRegInfos[3].catPtr     = iCurrentCat;
    iRegInfos[3].isValid    = YES;
    iRegInfos[12].value     = iCurrentFuncPtr;
    iRegInfos[12].isValid   = YES;
    iLR                     = (GPRegisterInfo){0};
    iCTR                    = (GPRegisterInfo){0};

    // Try to find out whether this is a class or instance method.
    MethodInfo* thisMethod  = NULL;

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

- (void)updateRegisters: (Line*)inLine;
{
    if (!inLine)
    {
        fprintf(stderr, "otx: [PPCProcessor updateRegisters]: "
            "tried to update with NULL inLine\n");
        return;
    }

    uint32_t theNewValue;
    uint32_t theCode = *(uint32_t*)inLine->info.code;

    theCode = OSSwapBigToHostInt32(theCode);

    if (IS_BRANCH_LINK(theCode))
    {
        iLR.value   = inLine->info.address + 4;
        iLR.isValid = YES;
    }

    switch (PO(theCode))
    {
        case 0x07:  // mulli        SIMM
        {
            if (!iRegInfos[RA(theCode)].isValid)
            {
                iRegInfos[RT(theCode)]  = (GPRegisterInfo){0};
                break;
            }

            UInt64  theProduct  =
                (SInt32)iRegInfos[RA(theCode)].value * SIMM(theCode);

            iRegInfos[RT(theCode)]          = (GPRegisterInfo){0};
            iRegInfos[RT(theCode)].value    = (uint32_t)(theProduct & 0xffffffff);
            iRegInfos[RT(theCode)].isValid  = YES;

            break;
        }

        case 0x08:  // subfic       SIMM
            if (!iRegInfos[RA(theCode)].isValid)
            {
                iRegInfos[RT(theCode)]  = (GPRegisterInfo){0};
                break;
            }

            theNewValue = iRegInfos[RA(theCode)].value - SIMM(theCode);

            iRegInfos[RT(theCode)]          = (GPRegisterInfo){0};
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
                iRegInfos[RT(theCode)]          = (GPRegisterInfo){0};
                iRegInfos[RT(theCode)].value    = UIMM(theCode);
                iRegInfos[RT(theCode)].isValid  = YES;
            }
            else                    // addi
            {
                // Update rD if we know what rA is.
                if (!iRegInfos[RA(theCode)].isValid)
                {
                    iRegInfos[RT(theCode)]  = (GPRegisterInfo){0};
                    break;
                }

                iRegInfos[RT(theCode)].classPtr = NULL;
                iRegInfos[RT(theCode)].catPtr   = NULL;

                theNewValue = iRegInfos[RA(theCode)].value + SIMM(theCode);

                iRegInfos[RT(theCode)]          = (GPRegisterInfo){0};
                iRegInfos[RT(theCode)].value    = theNewValue;
                iRegInfos[RT(theCode)].isValid  = YES;
            }

            break;

        case 0x0f:  // addis | lis
            iRegInfos[RT(theCode)].classPtr = NULL;
            iRegInfos[RT(theCode)].catPtr   = NULL;

            if (RA(theCode) == 0)   // lis
            {
                iRegInfos[RT(theCode)]          = (GPRegisterInfo){0};
                iRegInfos[RT(theCode)].value    = UIMM(theCode) << 16;
                iRegInfos[RT(theCode)].isValid  = YES;
                break;
            }

            // addis
            if (!iRegInfos[RA(theCode)].isValid)
            {
                iRegInfos[RT(theCode)]  = (GPRegisterInfo){0};
                break;
            }

            theNewValue = iRegInfos[RA(theCode)].value +
                (SIMM(theCode) << 16);

            iRegInfos[RT(theCode)]          = (GPRegisterInfo){0};
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

            iRegInfos[3]    = (GPRegisterInfo){0};

            break;
        }
        case 0x15:  // rlwinm
        {
            if (!iRegInfos[RT(theCode)].isValid)
            {
                iRegInfos[RA(theCode)]  = (GPRegisterInfo){0};
                break;
            }

            uint32_t  rotatedRT   =
                rotl(iRegInfos[RT(theCode)].value, RB(theCode));
            uint32_t  theMask     = 0x0;
            UInt8   i;

            for (i = MB(theCode); i <= ME(theCode); i++)
                theMask |= 1 << (31 - i);

            theNewValue = rotatedRT & theMask;

            iRegInfos[RA(theCode)]          = (GPRegisterInfo){0};
            iRegInfos[RA(theCode)].value    = theNewValue;
            iRegInfos[RA(theCode)].isValid  = YES;

            break;
        }

        case 0x18:  // ori
            if (!iRegInfos[RT(theCode)].isValid)
            {
                iRegInfos[RA(theCode)]  = (GPRegisterInfo){0};
                break;
            }

            theNewValue =
                iRegInfos[RT(theCode)].value | (uint32_t)UIMM(theCode);

            iRegInfos[RA(theCode)]          = (GPRegisterInfo){0};
            iRegInfos[RA(theCode)].value    = theNewValue;
            iRegInfos[RA(theCode)].isValid  = YES;

            break;

        case 0x1f:  // multiple instructions
            switch (SO(theCode))
            {
                case 23:    // lwzx
                    iRegInfos[RT(theCode)]  = (GPRegisterInfo){0};
                    break;

                case 8:     // subfc
                case 40:    // subf
                    if (!iRegInfos[RA(theCode)].isValid ||
                        !iRegInfos[RB(theCode)].isValid)
                    {
                        iRegInfos[RT(theCode)]  = (GPRegisterInfo){0};
                        break;
                    }

                    // 2's complement subtraction
                    theNewValue =
                        (iRegInfos[RA(theCode)].value ^= 0xffffffff) +
                        iRegInfos[RB(theCode)].value + 1;

                    iRegInfos[RT(theCode)]          = (GPRegisterInfo){0};
                    iRegInfos[RT(theCode)].value    = theNewValue;
                    iRegInfos[RT(theCode)].isValid  = YES;

                    break;

                case 339:   // mfspr
                    iRegInfos[RT(theCode)]  = (GPRegisterInfo){0};

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
                        iRegInfos[RA(theCode)]  = (GPRegisterInfo){0};
                        break;
                    }

                    theNewValue =
                        (iRegInfos[RT(theCode)].value |
                         iRegInfos[RB(theCode)].value);

                    iRegInfos[RA(theCode)]          = (GPRegisterInfo){0};
                    iRegInfos[RA(theCode)].value    = theNewValue;
                    iRegInfos[RA(theCode)].isValid  = YES;

                    // If we just copied a register, copy the
                    // remaining fields.
                    if (RT(theCode) == RB(theCode))
                    {
                        iRegInfos[RA(theCode)].classPtr =
                            iRegInfos[RB(theCode)].classPtr;
                        iRegInfos[RA(theCode)].catPtr   =
                            iRegInfos[RB(theCode)].catPtr;
                    }

                    break;

                case 467:   // mtspr
                    if (SPR(theCode) == CTR)    // to CTR
                    {
                        if (!iRegInfos[RS(theCode)].isValid)
                        {
                            iCTR    = (GPRegisterInfo){0};
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
                        iRegInfos[RA(theCode)]  = (GPRegisterInfo){0};
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

                    iRegInfos[RA(theCode)]          = (GPRegisterInfo){0};
                    iRegInfos[RA(theCode)].value    = theNewValue;
                    iRegInfos[RA(theCode)].isValid  = YES;

                    break;

                case 536:   // srw
                    if (!iRegInfos[RS(theCode)].isValid ||
                        !iRegInfos[RB(theCode)].isValid)
                    {
                        iRegInfos[RA(theCode)]  = (GPRegisterInfo){0};
                        break;
                    }

                    theNewValue =
                        iRegInfos[RS(theCode)].value >>
                            SV(iRegInfos[RB(theCode)].value);

                    iRegInfos[RA(theCode)]          = (GPRegisterInfo){0};
                    iRegInfos[RA(theCode)].value    = theNewValue;
                    iRegInfos[RA(theCode)].isValid  = YES;

                    break;

                default:
                    break;
            }

            break;

        case 0x20:  // lwz
        case 0x22:  // lbz
            if (RA(theCode) == 0)
            {
                iRegInfos[RT(theCode)]          = (GPRegisterInfo){0};
                iRegInfos[RT(theCode)].value    = SIMM(theCode);
                iRegInfos[RT(theCode)].isValid  = YES;
            }
            else if (iRegInfos[RA(theCode)].isValid)
            {
                uint32_t  tempPtr = (uint32_t)GetPointer(
                    iRegInfos[RA(theCode)].value + SIMM(theCode), NULL);

                if (tempPtr)
                {
                    iRegInfos[RT(theCode)]          = (GPRegisterInfo){0};
                    iRegInfos[RT(theCode)].value    = *(uint32_t*)tempPtr;
                    iRegInfos[RT(theCode)].value    =
                        OSSwapBigToHostInt32(iRegInfos[RT(theCode)].value);
                    iRegInfos[RT(theCode)].isValid  = YES;
                }
                else
                    iRegInfos[RT(theCode)]  = (GPRegisterInfo){0};
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
                iRegInfos[RT(theCode)]  = (GPRegisterInfo){0};

            break;

/*      case 0x22:  // lbz
            mRegInfos[RT(theCode)]  = (GPRegisterInfo){0};

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
                    iNumLocalSelves * sizeof(VarInfo));
                iLocalSelves[iNumLocalSelves - 1]   = (VarInfo)
                    {iRegInfos[RT(theCode)], UIMM(theCode)};
            }
            else
            {
                iNumLocalVars++;
                iLocalVars  = realloc(iLocalVars,
                    iNumLocalVars * sizeof(VarInfo));
                iLocalVars[iNumLocalVars - 1]   = (VarInfo)
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

        default:
            break;
    }
}

//  restoreRegisters:
// ----------------------------------------------------------------------------

- (BOOL)restoreRegisters: (Line*)inLine
{
    if (!inLine)
    {
        fprintf(stderr, "otx: [PPCProcessor restoreRegisters]: "
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
        if (funcInfo->blocks[i].beginAddress !=
            inLine->info.address)
            continue;

        // Update machine state.
        MachineState    machState   =
            funcInfo->blocks[i].state;

        memcpy(iRegInfos, machState.regInfos,
            sizeof(GPRegisterInfo) * 32);
        iLR     = machState.regInfos[LRIndex];
        iCTR    = machState.regInfos[CTRIndex];

        if (machState.localSelves)
        {
            if (iLocalSelves)
                free(iLocalSelves);

            iNumLocalSelves = machState.numLocalSelves;
            iLocalSelves    = malloc(
                sizeof(VarInfo) * iNumLocalSelves);
            memcpy(iLocalSelves, machState.localSelves,
                sizeof(VarInfo) * iNumLocalSelves);
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
    if (FindClassMethodByAddress(&theDummyInfo, theAddy))
        return YES;

    if (FindCatMethodByAddress(&theDummyInfo, theAddy))
        return YES;

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
        Line*   thePrevLine = inLine->prev;

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
    Line*           theLine     = iPlainLineListHead;
    uint32_t          theCode;
    uint32_t          progCounter = 0;

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
            uint32_t branchTarget = 0;

            // Retrieve the branch target.
            if (PO(theCode) == 0x12)    // b
                branchTarget    = theLine->info.address + LI(theCode);
            else if (PO(theCode) == 0x10)   // bc
                branchTarget    = theLine->info.address + BD(theCode);

            // Retrieve current FunctionInfo.
            FunctionInfo*   funcInfo    =
                &iFuncInfos[iCurrentFuncInfoIndex];

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
                        Line    searchKey = {NULL, 0, NULL, NULL, NULL, {branchTarget, {0}, YES, NO}};
                        Line*   searchKeyPtr = &searchKey;
                        Line**  beginLine = bsearch(&searchKeyPtr, iLineArray, iNumCodeLines, sizeof(Line*),
                            (COMPARISON_FUNC_TYPE)Line_Address_Compare);

                        if (beginLine != NULL)
                        {
                            // Walk through the block. It's an epilog if it ends
                            // with 'blr' and contains no 'bl's.
                            Line*   nextLine    = *beginLine;
                            BOOL    canBeEpliog = YES;
                            uint32_t  tempCode;

                            while (nextLine)
                            {
                                tempCode = *(uint32_t*)nextLine->info.code;
                                tempCode = OSSwapBigToHostInt32(tempCode);

                                if (IS_BRANCH_LINK(tempCode))
                                    canBeEpliog = NO;

                                if (IS_BLOCK_BRANCH(tempCode))
                                {
                                    endLine = nextLine;

                                    if (canBeEpliog && IS_BLR(tempCode))
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
                fprintf(stderr, "otx: [PPCProcessor gatherFuncInfos] "
                    "currentBlock is NULL. Flame the dev.\n");
                return;
            }

            // Create a new MachineState.
            GPRegisterInfo* savedRegs   = malloc(
                sizeof(GPRegisterInfo) * 34);

            memcpy(savedRegs, iRegInfos, sizeof(GPRegisterInfo) * 32);
            savedRegs[LRIndex]  = iLR;
            savedRegs[CTRIndex] = iCTR;

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
                    savedVars, iNumLocalVars};

            // Store the new BlockInfo.
            BlockInfo   blockInfo   =
                {branchTarget, endLine, isEpilog, machState};

            memcpy(currentBlock, &blockInfo, sizeof(BlockInfo));
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

    FunctionInfo*   funcInfo    = &iFuncInfos[inFuncIndex];

    if (!funcInfo || !funcInfo->blocks)
        return;

    uint32_t  i, j;

    fprintf(stderr, "\nfunction at 0x%x:\n\n", funcInfo->address);
    fprintf(stderr, "%d blocks\n", funcInfo->numBlocks);

    for (i = 0; i < funcInfo->numBlocks; i++)
    {
        fprintf(stderr, "\nblock %d at 0x%x:\n\n", i + 1,
            funcInfo->blocks[i].beginAddress);

        for (j = 0; j < 32; j++)
        {
            if (!funcInfo->blocks[i].state.regInfos[j].isValid)
                continue;

            fprintf(stderr, "\t\tr%d: 0x%x\n", j,
                funcInfo->blocks[i].state.regInfos[j].value);
        }
    }
}
#endif  // OTX_DEBUG

@end
