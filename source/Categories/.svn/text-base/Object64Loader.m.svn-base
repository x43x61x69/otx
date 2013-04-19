/*
    Object64Loader.m

    A category on Exe64Processor that contains all the loadXXX methods.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "Object64Loader.h"
#import "Objc64Accessors.h"

@implementation Exe64Processor(Object64Loader)

//  loadMachHeader
// ----------------------------------------------------------------------------
//  Assuming mRAMFile points to RAM that contains the contents of the exe, we
//  can set our mach_header_64* to point to the appropriate mach header, whether
//  the exe is unibin or not.

- (BOOL)loadMachHeader
{
    // Convert possible unibin to a single arch.
    if (iFileArchMagic  == FAT_MAGIC ||
        iFileArchMagic  == FAT_CIGAM)
    {
        fat_header  fh      = *(fat_header*)iRAMFile;
        fat_arch*   faPtr   = (fat_arch*)((char*)iRAMFile + sizeof(fat_header));
        fat_arch    fa;
        uint32_t      i;

        // fat_header and fat_arch are always big-endian. Swap if necessary.
#if TARGET_RT_LITTLE_ENDIAN
        swap_fat_header(&fh, OSLittleEndian);
#endif

        // Find the mach header we want.
        for (i = 0; i < fh.nfat_arch && !iMachHeaderPtr; i++)
        {
            fa  = *faPtr;

#if TARGET_RT_LITTLE_ENDIAN
            swap_fat_arch(&fa, 1, OSLittleEndian);
#endif

            if (fa.cputype == iArchSelector)
            {
                iMachHeaderPtr  = (mach_header_64*)(iRAMFile + fa.offset);
//                iFileArchMagic      = *(uint32_t*)iMachHeaderPtr;
//                iSwapped        = iFileArchMagic == MH_CIGAM || iFileArchMagic == MH_CIGAM_64;
                uint32_t  targetArchMagic = *(uint32_t*)iMachHeaderPtr;

                iSwapped = targetArchMagic == MH_CIGAM || targetArchMagic == MH_CIGAM_64;
                break;
            }

            faPtr++;    // next arch
        }

        if (!iMachHeaderPtr)
            fprintf(stderr, "otx: architecture not found in unibin\n");
    }
    else    // not a unibin, so mach header = start of file.
    {
        switch (iFileArchMagic)
        {
            case MH_CIGAM:
            case MH_CIGAM_64:
                iSwapped = YES;    // fall thru
            case MH_MAGIC:
            case MH_MAGIC_64:
                iMachHeaderPtr  =  (mach_header_64*)iRAMFile;
                break;

            default:
                fprintf(stderr, "otx: unknown magic value: 0x%x\n", iFileArchMagic);
                break;
        }
    }

    if (!iMachHeaderPtr)
    {
        fprintf(stderr, "otx: mach header not found\n");
        return NO;
    }

    iMachHeader = *iMachHeaderPtr;

    if (iSwapped)
        swap_mach_header_64(&iMachHeader, OSHostByteOrder());

    return YES;
}

//  loadLCommands
// ----------------------------------------------------------------------------
//  From the mach_header_64 ptr, loop thru the load commands for each segment.

- (void)loadLCommands
{
    // We need byte pointers for pointer arithmetic. Set a pointer to the 1st
    // load command.
    char*   ptr = (char*)(iMachHeaderPtr + 1);
    UInt16  i;

    // Loop thru load commands.
    for (i = 0; i < iMachHeader.ncmds; i++)
    {
        // Copy the load_command so we can:
        // -Swap it if needed without double-swapping parts of segments
        //      and symtabs.
        // -Easily advance to next load_command at end of loop regardless
        //      of command type.
        load_command    theCommandCopy  = *(load_command*)ptr;

        if (iSwapped)
            swap_load_command(&theCommandCopy, OSHostByteOrder());

        switch (theCommandCopy.cmd)
        {
            case LC_SEGMENT_64:
                [self loadSegment: (segment_command_64*)ptr];
                break;

            case LC_SYMTAB:
                [self loadSymbols: (symtab_command*)ptr];
                break;

            default:
                break;
        }

        // Point to the next command.
        ptr += theCommandCopy.cmdsize;
    }   // for(i = 0; i < mMachHeaderPtr->ncmds; i++)

    [self loadObjcClassList];
}

//  loadObjcClassList
// ----------------------------------------------------------------------------

- (void)loadObjcClassList
{
    if (iObjcClassListSect.size == 0)
        return;

    uint32_t numClasses = (uint32_t)(iObjcClassListSect.size / 8);  // sizeof(uint64_t)
    uint64_t* classList = (uint64_t*)iObjcClassListSect.contents;
    uint64_t fileClassPtr;
    uint32_t i;

    for (i = 0; i < numClasses; i++)
    {
        fileClassPtr = classList[i];

        if (iSwapped)
            fileClassPtr = OSSwapInt64(fileClassPtr);

        // Save methods, ivars, and protocols
        // Don't call getPointer here, its __DATA logic doesn't fit
        objc2_class_t workingClass = *(objc2_class_t*)(iDataSect.contents +
            (fileClassPtr - iDataSect.s.addr));

        if (iSwapped)
            swap_objc2_class(&workingClass);

        objc2_class_ro_t* roData;
        UInt64 methodBase;
        UInt64 ivarBase;

        if (workingClass.data != 0)
        {
            uint32_t count;
            uint32_t i;

            roData = (objc2_class_ro_t*)(iDataSect.contents +
                (uintptr_t)(workingClass.data - iDataSect.s.addr));
            methodBase = roData->baseMethods;
            ivarBase = roData->ivars;

            if (iSwapped)
            {
                methodBase = OSSwapInt64(methodBase);
                ivarBase = OSSwapInt64(ivarBase);
            }

            if (methodBase != 0)
            {
                objc2_method_list_t* methods = (objc2_method_list_t*)(iDataSect.contents +
                    (uintptr_t)(methodBase - iDataSect.s.addr));
                objc2_method_t* methodArray = &methods->first;
                count = methods->count;

                if (iSwapped)
                    count = OSSwapInt32(count);

                for (i = 0; i < count; i++)
                {
                    objc2_method_t swappedMethod = methodArray[i];

                    if (iSwapped)
                        swap_objc2_method(&swappedMethod);

                    Method64Info methodInfo = {swappedMethod, workingClass, YES};

                    iNumClassMethodInfos++;
                    iClassMethodInfos   = realloc(iClassMethodInfos,
                        iNumClassMethodInfos * sizeof(Method64Info));
                    iClassMethodInfos[iNumClassMethodInfos - 1] = methodInfo;
                }
            }

            if (ivarBase != 0)
            {
                objc2_ivar_list_t* ivars = (objc2_ivar_list_t*)(iDataSect.contents +
                    (uintptr_t)(ivarBase - iDataSect.s.addr));
                objc2_ivar_t* ivarArray = &ivars->first;
                count = ivars->count;

                if (iSwapped)
                    count = OSSwapInt32(count);

                for (i = 0; i < count; i++)
                {
                    objc2_ivar_t swappedIvar = ivarArray[i];

                    if (iSwapped)
                        swap_objc2_ivar(&swappedIvar);

                    iNumClassIvars++;
                    iClassIvars = realloc(iClassIvars,
                        iNumClassIvars * sizeof(objc2_ivar_t));
                    iClassIvars[iNumClassIvars - 1] = swappedIvar;
                }
            }
        }

        // Get metaclass methods
        if (workingClass.isa != 0)
        {
            workingClass = *(objc2_class_t*)(iDataSect.contents +
                (workingClass.isa - iDataSect.s.addr));

            if (iSwapped)
                swap_objc2_class(&workingClass);

            if (workingClass.data != 0)
            {
                roData = (objc2_class_ro_t*)(iDataSect.contents +
                    (uintptr_t)(workingClass.data - iDataSect.s.addr));
                methodBase = roData->baseMethods;

                if (iSwapped)
                    methodBase = OSSwapInt64(methodBase);

                if (methodBase != 0)
                {
                    objc2_method_list_t* methods = (objc2_method_list_t*)(iDataSect.contents +
                        (uintptr_t)(methodBase - iDataSect.s.addr));
                    objc2_method_t* methodArray = &methods->first;
                    uint32_t count = methods->count;
                    uint32_t i;

                    if (iSwapped)
                        count = OSSwapInt32(count);

                    for (i = 0; i < count; i++)
                    {
                        objc2_method_t swappedMethod = methodArray[i];

                        if (iSwapped)
                            swap_objc2_method(&swappedMethod);

                        Method64Info methodInfo = {swappedMethod, workingClass, NO};

                        iNumClassMethodInfos++;
                        iClassMethodInfos   = realloc(iClassMethodInfos,
                            iNumClassMethodInfos * sizeof(Method64Info));
                        iClassMethodInfos[iNumClassMethodInfos - 1] = methodInfo;
                    }
                }
            }
        }
    }

    qsort(iClassMethodInfos, iNumClassMethodInfos, sizeof(Method64Info),
        (COMPARISON_FUNC_TYPE)
        (iSwapped ? Method64Info_Compare_Swapped : Method64Info_Compare));
    qsort(iClassIvars, iNumClassIvars, sizeof(objc2_ivar_t),
        (COMPARISON_FUNC_TYPE)objc2_ivar_t_Compare);
}

//  loadSegment:
// ----------------------------------------------------------------------------
//  Given a pointer to a segment, loop thru its sections and save whatever
//  we'll need later.

- (void)loadSegment: (segment_command_64*)inSegPtr
{
    segment_command_64 swappedSeg  = *inSegPtr;

    if (iSwapped)
        swap_segment_command_64(&swappedSeg, OSHostByteOrder());

    // Set a pointer to the first section_64.
    section_64*    sectionPtr  =
        (section_64*)((char*)inSegPtr + sizeof(segment_command_64));
    UInt16      i;

    // Loop thru sections.
    for (i = 0; i < swappedSeg.nsects; i++)
    {
        if (strcmp_sectname(sectionPtr->segname, SEG_TEXT) == 0 || sectionPtr->segname[0] == 0)
        {
            if (iMachHeader.filetype == MH_OBJECT)
                iTextOffset = swappedSeg.fileoff;
            else
                iTextOffset = swappedSeg.vmaddr - swappedSeg.fileoff;

            if (strcmp_sectname(sectionPtr->sectname, SECT_TEXT) == 0)
                [self loadTextSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__coalesced_text") == 0)
                [self loadCoalTextSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__textcoal_nt") == 0)
                [self loadCoalTextNTSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__const") == 0)
                [self loadConstTextSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__objc_methname") == 0)
                [self loadObjcMethnameSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__objc_classname") == 0)
                [self loadObjcClassnameSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__cstring") == 0)
                [self loadCStringSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__literal4") == 0)
                [self loadLit4Section: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__literal8") == 0)
                [self loadLit8Section: sectionPtr];
        }
        else if (strcmp_sectname(sectionPtr->segname, SEG_DATA) == 0)
        {
            if (strcmp_sectname(sectionPtr->sectname, SECT_DATA) == 0)
                [self loadDataSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__coalesced_data") == 0)
                [self loadCoalDataSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__datacoal_nt") == 0)
                [self loadCoalDataNTSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__const") == 0)
                [self loadConstDataSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__dyld") == 0)
                [self loadDyldDataSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__cfstring") == 0)
                [self loadCFStringSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__nl_symbol_ptr") == 0)
                [self loadNonLazySymbolSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__objc_classlist") == 0)
                [self loadObjcClassListSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__objc_classrefs") == 0)
                [self loadObjcClassRefsSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__objc_msgrefs") == 0)
                [self loadObjcMsgRefsSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__objc_catlist") == 0)
                [self loadObjcCatListSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__objc_catlist") == 0)
                [self loadObjcCatListSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__objc_protolist") == 0)
                [self loadObjcProtoListSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__objc_protorefs") == 0)
                [self loadObjcProtoRefsSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__objc_superrefs") == 0)
                [self loadObjcSuperRefsSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__objc_selrefs") == 0)
                [self loadObjcSelRefsSection: sectionPtr];
        }
        else if (strcmp_sectname(sectionPtr->segname, "__IMPORT") == 0)
        {
            if (strcmp_sectname(sectionPtr->sectname, "__pointers") == 0)
                [self loadImpPtrSection: sectionPtr];
        }

        sectionPtr++;
    }
}

//  loadSymbols:
// ----------------------------------------------------------------------------
//  This refers to the symbol table located in the SEG_LINKEDIT segment.
//  See loadObjcSymTabFromModule for ObjC symbols.

- (void)loadSymbols: (symtab_command*)inSymPtr
{
//  nlist(3) doesn't quite cut it...

    symtab_command  swappedSymTab   = *inSymPtr;

    if (iSwapped)
        swap_symtab_command(&swappedSymTab, OSHostByteOrder());

    iStringTableOffset     = swappedSymTab.stroff;
    nlist_64*  theSymPtr   = (nlist_64*)((char*)iMachHeaderPtr + swappedSymTab.symoff);
    nlist_64   theSym      = {0};
    uint32_t  i;

    // loop thru symbols
    for (i = 0; i < swappedSymTab.nsyms; i++)
    {
        theSym  = theSymPtr[i];

        if (iSwapped)
            swap_nlist_64(&theSym, 1, OSHostByteOrder());

        if (theSym.n_value == 0)
            continue;

        if ((theSym.n_type & N_STAB) == 0)  // not a STAB
        {
            if ((theSym.n_type & N_SECT) != N_SECT)
                continue;

            iNumFuncSyms++;
            iFuncSyms   = realloc(iFuncSyms,
                iNumFuncSyms * sizeof(nlist_64));
            iFuncSyms[iNumFuncSyms - 1] = theSym;

#ifdef OTX_DEBUG
#if _OTX_DEBUG_SYMBOLS_
            [self printSymbol: theSym];
#endif
#endif
        }
    }   // for (i = 0; i < swappedSymTab.nsyms; i++)

    // Sort the symbols so we can use binary searches later.
    qsort(iFuncSyms, iNumFuncSyms, sizeof(nlist_64),
        (COMPARISON_FUNC_TYPE)Sym_Compare_64);
}

//  loadCStringSection:
// ----------------------------------------------------------------------------

- (void)loadCStringSection: (section_64*)inSect
{
    iCStringSect.s  = *inSect;

    if (iSwapped)
        swap_section_64(&iCStringSect.s, 1, OSHostByteOrder());

    iCStringSect.contents   = (char*)iMachHeaderPtr + iCStringSect.s.offset;
    iCStringSect.size       = iCStringSect.s.size;
}

//  loadNSStringSection:
// ----------------------------------------------------------------------------

- (void)loadNSStringSection: (section_64*)inSect
{
    iNSStringSect.s = *inSect;

    if (iSwapped)
        swap_section_64(&iNSStringSect.s, 1, OSHostByteOrder());

    iNSStringSect.contents  = (char*)iMachHeaderPtr + iNSStringSect.s.offset;
    iNSStringSect.size      = iNSStringSect.s.size;
}

//  loadLit4Section:
// ----------------------------------------------------------------------------

- (void)loadLit4Section: (section_64*)inSect
{
    iLit4Sect.s = *inSect;

    if (iSwapped)
        swap_section_64(&iLit4Sect.s, 1, OSHostByteOrder());

    iLit4Sect.contents  = (char*)iMachHeaderPtr + iLit4Sect.s.offset;
    iLit4Sect.size      = iLit4Sect.s.size;
}

//  loadLit8Section:
// ----------------------------------------------------------------------------

- (void)loadLit8Section: (section_64*)inSect
{
    iLit8Sect.s = *inSect;

    if (iSwapped)
        swap_section_64(&iLit8Sect.s, 1, OSHostByteOrder());

    iLit8Sect.contents  = (char*)iMachHeaderPtr + iLit8Sect.s.offset;
    iLit8Sect.size      = iLit8Sect.s.size;
}

//  loadTextSection:
// ----------------------------------------------------------------------------

- (void)loadTextSection: (section_64*)inSect
{
    iTextSect.s = *inSect;

    if (iSwapped)
        swap_section_64(&iTextSect.s, 1, OSHostByteOrder());

    iTextSect.contents  = (char*)iMachHeaderPtr + iTextSect.s.offset;
    iTextSect.size      = iTextSect.s.size;

    iEndOfText  = iTextSect.s.addr + iTextSect.s.size;
}

//  loadConstTextSection:
// ----------------------------------------------------------------------------

- (void)loadConstTextSection: (section_64*)inSect
{
    iConstTextSect.s    = *inSect;

    if (iSwapped)
        swap_section_64(&iConstTextSect.s, 1, OSHostByteOrder());

    iConstTextSect.contents = (char*)iMachHeaderPtr + iConstTextSect.s.offset;
    iConstTextSect.size     = iConstTextSect.s.size;
}

//  loadObjcMethnameSection:
// ----------------------------------------------------------------------------

- (void)loadObjcMethnameSection: (section_64*)inSect
{
    iObjcMethnameSect.s    = *inSect;
    
    if (iSwapped)
        swap_section_64(&iObjcMethnameSect.s, 1, OSHostByteOrder());
    
    iObjcMethnameSect.contents = (char*)iMachHeaderPtr + iObjcMethnameSect.s.offset;
    iObjcMethnameSect.size     = iObjcMethnameSect.s.size;
}

//  loadObjcClassnameSection:
// ----------------------------------------------------------------------------

- (void)loadObjcClassnameSection: (section_64*)inSect
{
    iObjcClassnameSect.s    = *inSect;
    
    if (iSwapped)
        swap_section_64(&iObjcClassnameSect.s, 1, OSHostByteOrder());
    
    iObjcClassnameSect.contents = (char*)iMachHeaderPtr + iObjcClassnameSect.s.offset;
    iObjcClassnameSect.size     = iObjcClassnameSect.s.size;
}

//  loadCoalTextSection:
// ----------------------------------------------------------------------------

- (void)loadCoalTextSection: (section_64*)inSect
{
    iCoalTextSect.s = *inSect;

    if (iSwapped)
        swap_section_64(&iCoalTextSect.s, 1, OSHostByteOrder());

    iCoalTextSect.contents  = (char*)iMachHeaderPtr + iCoalTextSect.s.offset;
    iCoalTextSect.size      = iCoalTextSect.s.size;
}

//  loadCoalTextNTSection:
// ----------------------------------------------------------------------------

- (void)loadCoalTextNTSection: (section_64*)inSect
{
    iCoalTextNTSect.s   = *inSect;

    if (iSwapped)
        swap_section_64(&iCoalTextNTSect.s, 1, OSHostByteOrder());

    iCoalTextNTSect.contents    = (char*)iMachHeaderPtr + iCoalTextNTSect.s.offset;
    iCoalTextNTSect.size        = iCoalTextNTSect.s.size;
}

//  loadDataSection:
// ----------------------------------------------------------------------------

- (void)loadDataSection: (section_64*)inSect
{
    iDataSect.s = *inSect;

    if (iSwapped)
        swap_section_64(&iDataSect.s, 1, OSHostByteOrder());

    iDataSect.contents  = (char*)iMachHeaderPtr + iDataSect.s.offset;
    iDataSect.size      = iDataSect.s.size;
}

//  loadCoalDataSection:
// ----------------------------------------------------------------------------

- (void)loadCoalDataSection: (section_64*)inSect
{
    iCoalDataSect.s = *inSect;

    if (iSwapped)
        swap_section_64(&iCoalDataSect.s, 1, OSHostByteOrder());

    iCoalDataSect.contents  = (char*)iMachHeaderPtr + iCoalDataSect.s.offset;
    iCoalDataSect.size      = iCoalDataSect.s.size;
}

//  loadCoalDataNTSection:
// ----------------------------------------------------------------------------

- (void)loadCoalDataNTSection: (section_64*)inSect
{
    iCoalDataNTSect.s   = *inSect;

    if (iSwapped)
        swap_section_64(&iCoalDataNTSect.s, 1, OSHostByteOrder());

    iCoalDataNTSect.contents    = (char*)iMachHeaderPtr + iCoalDataNTSect.s.offset;
    iCoalDataNTSect.size        = iCoalDataNTSect.s.size;
}

//  loadConstDataSection:
// ----------------------------------------------------------------------------

- (void)loadConstDataSection: (section_64*)inSect
{
    iConstDataSect.s    = *inSect;

    if (iSwapped)
        swap_section_64(&iConstDataSect.s, 1, OSHostByteOrder());

    iConstDataSect.contents = (char*)iMachHeaderPtr + iConstDataSect.s.offset;
    iConstDataSect.size     = iConstDataSect.s.size;
}

//  loadDyldDataSection:
// ----------------------------------------------------------------------------

- (void)loadDyldDataSection: (section_64*)inSect
{
    iDyldSect.s = *inSect;

    if (iSwapped)
        swap_section_64(&iDyldSect.s, 1, OSHostByteOrder());

    iDyldSect.contents  = (char*)iMachHeaderPtr + iDyldSect.s.offset;
    iDyldSect.size      = iDyldSect.s.size;

    if (iDyldSect.size < sizeof(dyld_data_section))
        return;

    dyld_data_section*  data    = (dyld_data_section*)iDyldSect.contents;

    iAddrDyldStubBindingHelper  = (uint32_t)(data->dyld_stub_binding_helper);

    if (iSwapped)
        iAddrDyldStubBindingHelper  = OSSwapInt32(iAddrDyldStubBindingHelper);
}

//  loadCFStringSection:
// ----------------------------------------------------------------------------

- (void)loadCFStringSection: (section_64*)inSect
{
    iCFStringSect.s = *inSect;

    if (iSwapped)
        swap_section_64(&iCFStringSect.s, 1, OSHostByteOrder());

    iCFStringSect.contents  = (char*)iMachHeaderPtr + iCFStringSect.s.offset;
    iCFStringSect.size      = iCFStringSect.s.size;
}

//  loadNonLazySymbolSection:
// ----------------------------------------------------------------------------

- (void)loadNonLazySymbolSection: (section_64*)inSect
{
    iNLSymSect.s    = *inSect;

    if (iSwapped)
        swap_section_64(&iNLSymSect.s, 1, OSHostByteOrder());

    iNLSymSect.contents = (char*)iMachHeaderPtr + iNLSymSect.s.offset;
    iNLSymSect.size     = iNLSymSect.s.size;
}

//  loadObjcClassListSection:
// ----------------------------------------------------------------------------

- (void)loadObjcClassListSection: (section_64*)inSect
{
    iObjcClassListSect.s = *inSect;

    if (iSwapped)
        swap_section_64(&iObjcClassListSect.s, 1, OSHostByteOrder());

    iObjcClassListSect.contents = (char*)iMachHeaderPtr + iObjcClassListSect.s.offset;
    iObjcClassListSect.size = iObjcClassListSect.s.size;
}

//  loadObjcCatListSection:
// ----------------------------------------------------------------------------

- (void)loadObjcCatListSection: (section_64*)inSect
{
    iObjcCatListSect.s = *inSect;

    if (iSwapped)
        swap_section_64(&iObjcCatListSect.s, 1, OSHostByteOrder());

    iObjcCatListSect.contents = (char*)iMachHeaderPtr + iObjcCatListSect.s.offset;
    iObjcCatListSect.size = iObjcCatListSect.s.size;
}

//  loadObjcProtoListSection:
// ----------------------------------------------------------------------------

- (void)loadObjcProtoListSection: (section_64*)inSect
{
    iObjcProtoListSect.s = *inSect;

    if (iSwapped)
        swap_section_64(&iObjcProtoListSect.s, 1, OSHostByteOrder());

    iObjcProtoListSect.contents = (char*)iMachHeaderPtr + iObjcProtoListSect.s.offset;
    iObjcProtoListSect.size = iObjcProtoListSect.s.size;
}

//  loadObjcSuperRefsSection:
// ----------------------------------------------------------------------------

- (void)loadObjcSuperRefsSection: (section_64*)inSect
{
    iObjcSuperRefsSect.s = *inSect;

    if (iSwapped)
        swap_section_64(&iObjcSuperRefsSect.s, 1, OSHostByteOrder());

    iObjcSuperRefsSect.contents = (char*)iMachHeaderPtr + iObjcSuperRefsSect.s.offset;
    iObjcSuperRefsSect.size = iObjcSuperRefsSect.s.size;
}

//  loadObjcClassRefsSection:
// ----------------------------------------------------------------------------

- (void)loadObjcClassRefsSection: (section_64*)inSect
{
    iObjcClassRefsSect.s = *inSect;

    if (iSwapped)
        swap_section_64(&iObjcClassRefsSect.s, 1, OSHostByteOrder());

    iObjcClassRefsSect.contents = (char*)iMachHeaderPtr + iObjcClassRefsSect.s.offset;
    iObjcClassRefsSect.size = iObjcClassRefsSect.s.size;
}

//  loadObjcProtoRefsSection:
// ----------------------------------------------------------------------------

- (void)loadObjcProtoRefsSection: (section_64*)inSect
{
    iObjcProtoRefsSect.s = *inSect;

    if (iSwapped)
        swap_section_64(&iObjcProtoRefsSect.s, 1, OSHostByteOrder());

    iObjcProtoRefsSect.contents = (char*)iMachHeaderPtr + iObjcProtoRefsSect.s.offset;
    iObjcProtoRefsSect.size = iObjcProtoRefsSect.s.size;
}

//  loadObjcMsgRefsSection:
// ----------------------------------------------------------------------------

- (void)loadObjcMsgRefsSection: (section_64*)inSect
{
    iObjcMsgRefsSect.s = *inSect;

    if (iSwapped)
        swap_section_64(&iObjcMsgRefsSect.s, 1, OSHostByteOrder());

    iObjcMsgRefsSect.contents = (char*)iMachHeaderPtr + iObjcMsgRefsSect.s.offset;
    iObjcMsgRefsSect.size = iObjcMsgRefsSect.s.size;
}

//  loadObjcSelRefsSection:
// ----------------------------------------------------------------------------

- (void)loadObjcSelRefsSection: (section_64*)inSect
{
    iObjcSelRefsSect.s = *inSect;

    if (iSwapped)
        swap_section_64(&iObjcSelRefsSect.s, 1, OSHostByteOrder());

    iObjcSelRefsSect.contents = (char*)iMachHeaderPtr + iObjcSelRefsSect.s.offset;
    iObjcSelRefsSect.size = iObjcSelRefsSect.s.size;
}

//  loadImpPtrSection:
// ----------------------------------------------------------------------------

- (void)loadImpPtrSection: (section_64*)inSect
{
    iImpPtrSect.s = *inSect;

    if (iSwapped)
        swap_section_64(&iImpPtrSect.s, 1, OSHostByteOrder());

    iImpPtrSect.contents = (char*)iMachHeaderPtr + iImpPtrSect.s.offset;
    iImpPtrSect.size = iImpPtrSect.s.size;
}

@end
