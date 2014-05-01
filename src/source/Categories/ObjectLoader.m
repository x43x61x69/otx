/*
    ObjectLoader.m

    A category on Exe32Processor that contains all the loadXXX methods.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "ObjectLoader.h"
#import "ObjcAccessors.h"

@implementation Exe32Processor(ObjectLoader)

//  loadMachHeader
// ----------------------------------------------------------------------------
//  Assuming mRAMFile points to RAM that contains the contents of the exe, we
//  can set our mach_header* to point to the appropriate mach header, whether
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
                iMachHeaderPtr  = (mach_header*)(iRAMFile + fa.offset);
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
                iMachHeaderPtr  =  (mach_header*)iRAMFile;
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
        swap_mach_header(&iMachHeader, OSHostByteOrder());

    return YES;
}

//  loadLCommands
// ----------------------------------------------------------------------------
//  From the mach_header ptr, loop thru the load commands for each segment.

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
            case LC_SEGMENT:
                [self loadSegment: (segment_command*)ptr];
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

    if (iObjcClassListSect.size != 0) {
        iObjcVersion = 2;
    } else if (iNumObjcSects != 0) {
        iObjcVersion = 1;
    }

    // Now that we have all the objc sections, we can load the objc modules.
    [self loadObjcModules];
    [self loadObjcClassList];
}

//  loadSegment:
// ----------------------------------------------------------------------------
//  Given a pointer to a segment, loop thru its sections and save whatever
//  we'll need later.

- (void)loadSegment: (segment_command*)inSegPtr
{
    segment_command swappedSeg  = *inSegPtr;

    if (iSwapped)
        swap_segment_command(&swappedSeg, OSHostByteOrder());

    // Set a pointer to the first section.
    section*    sectionPtr  =
        (section*)((char*)inSegPtr + sizeof(segment_command));
    UInt16      i;

    // Loop thru sections.
    for (i = 0; i < swappedSeg.nsects; i++)
    {
        if (!strcmp(sectionPtr->segname, SEG_OBJC))
        {
            [self loadObjcSection: sectionPtr];
        }
        else if (!strcmp(sectionPtr->segname, SEG_TEXT) ||
                 !sectionPtr->segname[0])
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
            else if (strcmp_sectname(sectionPtr->sectname, "__cstring") == 0)
                [self loadCStringSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__objc_methname") == 0)
                [self loadObjcMethnameSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__objc_methtype") == 0)
                [self loadObjcMethtypeSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__objc_classname") == 0)
                [self loadObjcClassnameSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__literal4") == 0)
                [self loadLit4Section: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__literal8") == 0)
                [self loadLit8Section: sectionPtr];
        }
        else if (!strcmp(sectionPtr->segname, SEG_DATA))
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
            else if (strcmp_sectname(sectionPtr->sectname, "__objc_const") == 0)
                [self loadObjcConstSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__objc_protolist") == 0)
                [self loadObjcProtoListSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__objc_protorefs") == 0)
                [self loadObjcProtoRefsSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__objc_superrefs") == 0)
                [self loadObjcSuperRefsSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__objc_selrefs") == 0)
                [self loadObjcSelRefsSection: sectionPtr];
            else if (strcmp_sectname(sectionPtr->sectname, "__objc_data") == 0)
                [self loadObjcDataSection: sectionPtr];
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

    iStringTableOffset  = swappedSymTab.stroff;
    nlist*  theSymPtr   = (nlist*)((char*)iMachHeaderPtr + swappedSymTab.symoff);
    nlist   theSym      = {0};
    uint32_t  i;

    // loop thru symbols
    for (i = 0; i < swappedSymTab.nsyms; i++)
    {
        theSym  = theSymPtr[i];

        if (iSwapped)
            swap_nlist(&theSym, 1, OSHostByteOrder());

        if (theSym.n_value == 0)
            continue;

        if ((theSym.n_type & N_STAB) == 0)  // not a STAB
        {
            if ((theSym.n_type & N_SECT) != N_SECT)
                continue;

            iNumFuncSyms++;
            iFuncSyms   = realloc(iFuncSyms,
                iNumFuncSyms * sizeof(nlist));
            iFuncSyms[iNumFuncSyms - 1] = theSym;

#ifdef OTX_DEBUG
#if _OTX_DEBUG_SYMBOLS_
            [self printSymbol: theSym];
#endif
#endif
        }
    }   // for (i = 0; i < swappedSymTab.nsyms; i++)

    // Sort the symbols so we can use binary searches later.
    qsort(iFuncSyms, iNumFuncSyms, sizeof(nlist),
        (COMPARISON_FUNC_TYPE)Sym_Compare);
}

//  loadObjcSection:
// ----------------------------------------------------------------------------

- (void)loadObjcSection: (section*)inSect
{
    section swappedSect = *inSect;

    if (iSwapped)
        swap_section(&swappedSect, 1, OSHostByteOrder());

    iNumObjcSects++;
    iObjcSects  = realloc(iObjcSects,
        iNumObjcSects * sizeof(section_info));
    iObjcSects[iNumObjcSects - 1]   = (section_info)
        {swappedSect, (char*)iMachHeaderPtr + swappedSect.offset,
        swappedSect.size};

    if (!strncmp(inSect->sectname, "__cstring_object", 16))
        [self loadNSStringSection: inSect];
    else if (!strcmp(inSect->sectname, "__class"))
        [self loadClassSection: inSect];
    else if (!strcmp(inSect->sectname, "__meta_class"))
        [self loadMetaClassSection: inSect];
    else if (!strcmp(inSect->sectname, "__instance_vars"))
        [self loadIVarSection: inSect];
    else if (!strcmp(inSect->sectname, "__module_info"))
        [self loadObjcModSection: inSect];
    else if (!strcmp(inSect->sectname, "__symbols"))
        [self loadObjcSymSection: inSect];
}

//  loadObjcModules
// ----------------------------------------------------------------------------

- (void)loadObjcModules
{
    char*               theMachPtr  = (char*)iMachHeaderPtr;
    char*               theModPtr;
    section_info*       theSectInfo;
    objc1_32_module     theModule;
    uint32_t            theModSize;
    objc1_32_symtab     theSymTab;
    objc1_32_class      theClass, theSwappedClass;
    objc1_32_class      theMetaClass, theSwappedMetaClass;
    objc1_32_category   theCat, theSwappedCat;
    uint32_t*           theDefs;
    uint32_t            theOffset;
    uint32_t            i, j, k;

    // Loop thru objc sections.
    for (i = 0; i < iNumObjcSects; i++)
    {
        theSectInfo = &iObjcSects[i];

        // Bail if not a module section.
        if (strcmp(theSectInfo->s.sectname, SECT_OBJC_MODULES))
            continue;

        theOffset   = theSectInfo->s.addr - theSectInfo->s.offset;
        theModPtr   = theMachPtr + theSectInfo->s.addr - theOffset;
        theModule   = *(objc1_32_module*)theModPtr;

        if (iSwapped)
            swap_objc1_32_module(&theModule);

        theModSize  = theModule.size;

        // Loop thru modules.
        while (theModPtr <
            theMachPtr + theSectInfo->s.offset + theSectInfo->s.size)
        {
            // Try to locate the objc_symtab for this module.
            if (![self getObjc1Symtab: &theSymTab defs: &theDefs
                fromModule: &theModule] || !theDefs)
            {
                // point to next module
                theModPtr   += theModSize;
                theModule   = *(objc1_32_module*)theModPtr;

                if (iSwapped)
                    swap_objc1_32_module(&theModule);

                theModSize  = theModule.size;

                continue;
            }

            if (iSwapped)
                swap_objc1_32_symtab(&theSymTab);

// In the objc_symtab struct defined in <objc/objc-runtime.h>, the format of
// the void* array 'defs' is 'cls_def_cnt' class pointers followed by
// 'cat_def_cnt' category pointers.
            uint32_t  theDef;

            // Loop thru class definitions in the objc_symtab.
            for (j = 0; j < theSymTab.cls_def_cnt; j++)
            {
                // Try to locate the objc_class for this def.
                uint32_t  theDef  = (uint32_t)theDefs[j];

                if (iSwapped)
                    theDef  = OSSwapInt32(theDef);

                if (![self getObjc1Class: &theClass fromDef: theDef])
                    continue;

                theSwappedClass = theClass;

                if (iSwapped)
                    swap_objc1_32_class(&theSwappedClass);

                // Save class's instance method info.
                objc1_32_method_list    theMethodList;
                objc1_32_method_list    theSwappedMethodList;
                objc1_32_method*        theMethods;
                objc1_32_method         theMethod;
                objc1_32_method         theSwappedMethod;

                if ([self getObjc1MethodList: &theMethodList
                    methods: &theMethods
                    fromAddress: theSwappedClass.methodLists])
                {
                    theSwappedMethodList    = theMethodList;

                    if (iSwapped)
                        swap_objc1_32_method_list(&theSwappedMethodList);

                    for (k = 0; k < theSwappedMethodList.method_count; k++)
                    {
                        theMethod           = theMethods[k];
                        theSwappedMethod    = theMethod;

                        if (iSwapped)
                            swap_objc1_32_method(&theSwappedMethod);

                        MethodInfo  theMethInfo =
                            {theMethod, theClass, {0}, YES};

                        iNumClassMethodInfos++;
                        iClassMethodInfos   = realloc(iClassMethodInfos,
                            iNumClassMethodInfos * sizeof(MethodInfo));
                        iClassMethodInfos[iNumClassMethodInfos - 1] = theMethInfo;
                    }
                }

                // Save class's class method info.
                if ([self getObjc1MetaClass: &theMetaClass
                    fromClass: &theSwappedClass])
                {
                    theSwappedMetaClass = theMetaClass;

                    if (iSwapped)
                        swap_objc1_32_class(&theSwappedMetaClass);

                    if ([self getObjc1MethodList: &theMethodList
                        methods: &theMethods
                        fromAddress: theSwappedMetaClass.methodLists])
                    {
                        theSwappedMethodList    = theMethodList;

                        if (iSwapped)
                            swap_objc1_32_method_list(&theSwappedMethodList);

                        for (k = 0; k < theSwappedMethodList.method_count; k++)
                        {
                            theMethod           = theMethods[k];
                            theSwappedMethod    = theMethod;

                            if (iSwapped)
                                swap_objc1_32_method(&theSwappedMethod);

                            MethodInfo  theMethInfo =
                                {theMethod, theClass, {0}, NO};

                            iNumClassMethodInfos++;
                            iClassMethodInfos   = realloc(
                                iClassMethodInfos, iNumClassMethodInfos *
                                sizeof(MethodInfo));
                            iClassMethodInfos[iNumClassMethodInfos - 1] =
                                theMethInfo;
                        }
                    }
                }   // theMetaClass != nil
            }

            // Loop thru category definitions in the objc_symtab.
            for (; j < theSymTab.cat_def_cnt + theSymTab.cls_def_cnt; j++)
            {
                // Try to locate the objc_category for this def.
                theDef  = (uint32_t)theDefs[j];

                if (iSwapped)
                    theDef  = OSSwapInt32(theDef);

                if (![self getObjc1Category: &theCat fromDef: theDef])
                    continue;

                theSwappedCat   = theCat;

                if (iSwapped)
                    swap_objc1_32_category(&theSwappedCat);

                // Categories are linked to classes by name only. Try to 
                // find the class for this category. May be nil.
                [self getObjc1Class:&theClass fromName:[self getPointer:theSwappedCat.class_name type:NULL]];

                theSwappedClass = theClass;

                if (iSwapped)
                    swap_objc1_32_class(&theSwappedClass);

                // Save category instance method info.
                objc1_32_method_list    theMethodList;
                objc1_32_method_list    theSwappedMethodList;
                objc1_32_method*        theMethods;
                objc1_32_method         theMethod;
                objc1_32_method         theSwappedMethod;

                if ([self getObjc1MethodList: &theMethodList
                    methods: &theMethods
                    fromAddress: theSwappedCat.instance_methods])
                {
                    theSwappedMethodList    = theMethodList;

                    if (iSwapped)
                        swap_objc1_32_method_list(&theSwappedMethodList);

                    for (k = 0; k < theSwappedMethodList.method_count; k++)
                    {
                        theMethod           = theMethods[k];
                        theSwappedMethod    = theMethod;

                        if (iSwapped)
                            swap_objc1_32_method(&theSwappedMethod);

                        MethodInfo  theMethInfo =
                            {theMethod, theClass, theCat, YES};

                        iNumCatMethodInfos++;
                        iCatMethodInfos = realloc(iCatMethodInfos,
                            iNumCatMethodInfos * sizeof(MethodInfo));
                        iCatMethodInfos[iNumCatMethodInfos - 1] = theMethInfo;
                    }
                }

                // Save category class method info.
                if ([self getObjc1MethodList: &theMethodList
                    methods: &theMethods
                    fromAddress: theSwappedCat.class_methods])
                {
                    theSwappedMethodList    = theMethodList;

                    if (iSwapped)
                        swap_objc1_32_method_list(&theSwappedMethodList);

                    for (k = 0; k < theSwappedMethodList.method_count; k++)
                    {
                        theMethod           = theMethods[k];
                        theSwappedMethod    = theMethod;

                        if (iSwapped)
                            swap_objc1_32_method(&theSwappedMethod);

                        MethodInfo  theMethInfo =
                            {theMethod, theClass, theCat, NO};

                        iNumCatMethodInfos++;
                        iCatMethodInfos = realloc(iCatMethodInfos,
                            iNumCatMethodInfos * sizeof(MethodInfo));
                        iCatMethodInfos[iNumCatMethodInfos - 1] = theMethInfo;
                    }
                }
            }   // for (; j < theSymTab.cat_def_cnt; j++)

            // point to next module
            theModPtr   += theModSize;
            theModule   = *(objc1_32_module*)theModPtr;

            if (iSwapped)
                swap_objc1_32_module(&theModule);

            theModSize  = theModule.size;
        }   // while (theModPtr...)
    }   // for (i = 0; i < mNumObjcSects; i++)

    // Sort MethodInfos.
    qsort(iClassMethodInfos, iNumClassMethodInfos, sizeof(MethodInfo),
        (COMPARISON_FUNC_TYPE)
        (iSwapped ? MethodInfo_Compare_Swapped : MethodInfo_Compare));
    qsort(iCatMethodInfos, iNumCatMethodInfos, sizeof(MethodInfo),
        (COMPARISON_FUNC_TYPE)
        (iSwapped ? MethodInfo_Compare_Swapped : MethodInfo_Compare));
}

//  loadObjcClassList
// ----------------------------------------------------------------------------

- (void)loadObjcClassList
{
    if (iObjcClassListSect.size == 0)
        return;

    uint32_t numClasses = (uint32_t)(iObjcClassListSect.size / 4);  // sizeof(uint32_t)
    uint32_t* classList = (uint32_t*)iObjcClassListSect.contents;
    uint32_t fileClassPtr;
    uint32_t i;

    for (i = 0; i < numClasses; i++)
    {
        fileClassPtr = classList[i];

        if (iSwapped)
            fileClassPtr = OSSwapInt32(fileClassPtr);

        // Save methods, ivars, and protocols
        // Don't call getPointer here, its __DATA logic doesn't fit
        objc2_32_class_t workingClass = *(objc2_32_class_t*)(iObjcDataSect.contents +
            (fileClassPtr - iObjcDataSect.s.addr));

        if (iSwapped)
            swap_objc2_32_class(&workingClass);

        objc2_32_class_ro_t* roData;
        UInt64 methodBase;
        UInt64 ivarBase;

        if (workingClass.data != 0)
        {
            uint32_t count;
            uint32_t i;

            roData = (objc2_32_class_ro_t*)(iObjcConstSect.contents +
                (uintptr_t)(workingClass.data - iObjcConstSect.s.addr));
            methodBase = roData->baseMethods;
            ivarBase = roData->ivars;

            if (iSwapped)
            {
                methodBase = OSSwapInt64(methodBase);
                ivarBase = OSSwapInt64(ivarBase);
            }

            if (methodBase != 0)
            {
                objc2_32_method_list_t* methods = (objc2_32_method_list_t*)(iObjcDataSect.contents +
                    (uintptr_t)(methodBase - iObjcDataSect.s.addr));
                objc2_32_method_t* methodArray = &methods->first;
                count = methods->count;

                if (iSwapped)
                    count = OSSwapInt32(count);

                for (i = 0; i < count; i++)
                {
                    objc2_32_method_t swappedMethod = methodArray[i];

                    if (iSwapped)
                        swap_objc2_32_method(&swappedMethod);

                    MethodInfo methodInfo = {0};
                    methodInfo.inst = YES;
                    methodInfo.m2 = swappedMethod;
                    methodInfo.oc_class2 = workingClass;

                    iNumClassMethodInfos++;
                    iClassMethodInfos   = realloc(iClassMethodInfos,
                        iNumClassMethodInfos * sizeof(MethodInfo));
                    iClassMethodInfos[iNumClassMethodInfos - 1] = methodInfo;
                }
            }

            if (ivarBase != 0)
            {
                objc2_32_ivar_list_t* ivars = (objc2_32_ivar_list_t*)(iObjcDataSect.contents +
                    (uintptr_t)(ivarBase - iObjcDataSect.s.addr));
                objc2_32_ivar_t* ivarArray = &ivars->first;
                count = ivars->count;

                if (iSwapped)
                    count = OSSwapInt32(count);

                for (i = 0; i < count; i++)
                {
                    objc2_32_ivar_t swappedIvar = ivarArray[i];

                    if (iSwapped)
                        swap_objc2_32_ivar(&swappedIvar);

                    iNumClassIvars++;
                    iClassIvars = realloc(iClassIvars,
                        iNumClassIvars * sizeof(objc2_32_ivar_t));
                    iClassIvars[iNumClassIvars - 1] = swappedIvar;
                }
            }
        }

        // Get metaclass methods
        if (workingClass.isa != 0)
        {
            workingClass = *(objc2_32_class_t*)(iObjcDataSect.contents +
                (workingClass.isa - iObjcDataSect.s.addr));

            if (iSwapped)
                swap_objc2_32_class(&workingClass);

            if (workingClass.data != 0)
            {
                roData = (objc2_32_class_ro_t*)(iObjcConstSect.contents +
                    (uintptr_t)(workingClass.data - iObjcConstSect.s.addr));
                methodBase = roData->baseMethods;

                if (iSwapped)
                    methodBase = OSSwapInt32(methodBase);

                if (methodBase != 0)
                {
                    objc2_32_method_list_t* methods = (objc2_32_method_list_t*)(iObjcDataSect.contents +
                        (uintptr_t)(methodBase - iObjcDataSect.s.addr));
                    objc2_32_method_t* methodArray = &methods->first;
                    uint32_t count = methods->count;
                    uint32_t i;

                    if (iSwapped)
                        count = OSSwapInt32(count);

                    for (i = 0; i < count; i++)
                    {
                        objc2_32_method_t swappedMethod = methodArray[i];

                        if (iSwapped)
                            swap_objc2_32_method(&swappedMethod);

                        MethodInfo methodInfo = {0};
                        methodInfo.m2 = swappedMethod;
                        methodInfo.oc_class2 = workingClass;

                        iNumClassMethodInfos++;
                        iClassMethodInfos   = realloc(iClassMethodInfos,
                            iNumClassMethodInfos * sizeof(MethodInfo));
                        iClassMethodInfos[iNumClassMethodInfos - 1] = methodInfo;
                    }
                }
            }
        }
    }

    qsort(iClassMethodInfos, iNumClassMethodInfos, sizeof(MethodInfo),
        (COMPARISON_FUNC_TYPE)
        (iSwapped ? MethodInfo_Compare_Swapped : MethodInfo_Compare));
    qsort(iClassIvars, iNumClassIvars, sizeof(objc2_32_ivar_t),
        (COMPARISON_FUNC_TYPE)objc2_32_ivar_t_Compare);
}


//  loadCStringSection:
// ----------------------------------------------------------------------------

- (void)loadCStringSection: (section*)inSect
{
    iCStringSect.s  = *inSect;

    if (iSwapped)
        swap_section(&iCStringSect.s, 1, OSHostByteOrder());

    iCStringSect.contents   = (char*)iMachHeaderPtr + iCStringSect.s.offset;
    iCStringSect.size       = iCStringSect.s.size;
}

//  loadNSStringSection:
// ----------------------------------------------------------------------------

- (void)loadNSStringSection: (section*)inSect
{
    iNSStringSect.s = *inSect;

    if (iSwapped)
        swap_section(&iNSStringSect.s, 1, OSHostByteOrder());

    iNSStringSect.contents  = (char*)iMachHeaderPtr + iNSStringSect.s.offset;
    iNSStringSect.size      = iNSStringSect.s.size;
}

//  loadClassSection:
// ----------------------------------------------------------------------------

- (void)loadClassSection: (section*)inSect
{
    iClassSect.s    = *inSect;

    if (iSwapped)
        swap_section(&iClassSect.s, 1, OSHostByteOrder());

    iClassSect.contents = (char*)iMachHeaderPtr + iClassSect.s.offset;
    iClassSect.size     = iClassSect.s.size;
}

//  loadMetaClassSection:
// ----------------------------------------------------------------------------

- (void)loadMetaClassSection: (section*)inSect
{
    iMetaClassSect.s    = *inSect;

    if (iSwapped)
        swap_section(&iMetaClassSect.s, 1, OSHostByteOrder());

    iMetaClassSect.contents = (char*)iMachHeaderPtr + iMetaClassSect.s.offset;
    iMetaClassSect.size     = iMetaClassSect.s.size;
}

//  loadIVarSection:
// ----------------------------------------------------------------------------

- (void)loadIVarSection: (section*)inSect
{
    iIVarSect.s = *inSect;

    if (iSwapped)
        swap_section(&iIVarSect.s, 1, OSHostByteOrder());

    iIVarSect.contents  = (char*)iMachHeaderPtr + iIVarSect.s.offset;
    iIVarSect.size      = iIVarSect.s.size;
}

//  loadObjcModSection:
// ----------------------------------------------------------------------------

- (void)loadObjcModSection: (section*)inSect
{
    iObjcModSect.s  = *inSect;

    if (iSwapped)
        swap_section(&iObjcModSect.s, 1, OSHostByteOrder());

    iObjcModSect.contents   = (char*)iMachHeaderPtr + iObjcModSect.s.offset;
    iObjcModSect.size       = iObjcModSect.s.size;
}

//  loadObjcSymSection:
// ----------------------------------------------------------------------------

- (void)loadObjcSymSection: (section*)inSect
{
    iObjcSymSect.s  = *inSect;

    if (iSwapped)
        swap_section(&iObjcSymSect.s, 1, OSHostByteOrder());

    iObjcSymSect.contents   = (char*)iMachHeaderPtr + iObjcSymSect.s.offset;
    iObjcSymSect.size       = iObjcSymSect.s.size;
}

//  loadObjcMethTypeSection:
// ----------------------------------------------------------------------------

- (void)loadObjcMethtypeSection: (section*)inSect
{
    iObjcMethtypeSect.s  = *inSect;

    if (iSwapped)
        swap_section(&iObjcMethtypeSect.s, 1, OSHostByteOrder());

    iObjcMethtypeSect.contents   = (char*)iMachHeaderPtr + iObjcMethtypeSect.s.offset;
    iObjcMethtypeSect.size       = iObjcMethtypeSect.s.size;
}

//  loadObjcMethNameSection:
// ----------------------------------------------------------------------------

- (void)loadObjcMethnameSection: (section*)inSect
{
    iObjcMethnameSect.s  = *inSect;

    if (iSwapped)
        swap_section(&iObjcMethnameSect.s, 1, OSHostByteOrder());

    iObjcMethnameSect.contents   = (char*)iMachHeaderPtr + iObjcMethnameSect.s.offset;
    iObjcMethnameSect.size       = iObjcMethnameSect.s.size;
}

//  loadObjcClassNameSection:
// ----------------------------------------------------------------------------

- (void)loadObjcClassnameSection: (section*)inSect
{
    iObjcClassnameSect.s  = *inSect;

    if (iSwapped)
        swap_section(&iObjcClassnameSect.s, 1, OSHostByteOrder());

    iObjcClassnameSect.contents   = (char*)iMachHeaderPtr + iObjcClassnameSect.s.offset;
    iObjcClassnameSect.size       = iObjcClassnameSect.s.size;
}

//  loadLit4Section:
// ----------------------------------------------------------------------------

- (void)loadLit4Section: (section*)inSect
{
    iLit4Sect.s = *inSect;

    if (iSwapped)
        swap_section(&iLit4Sect.s, 1, OSHostByteOrder());

    iLit4Sect.contents  = (char*)iMachHeaderPtr + iLit4Sect.s.offset;
    iLit4Sect.size      = iLit4Sect.s.size;
}

//  loadLit8Section:
// ----------------------------------------------------------------------------

- (void)loadLit8Section: (section*)inSect
{
    iLit8Sect.s = *inSect;

    if (iSwapped)
        swap_section(&iLit8Sect.s, 1, OSHostByteOrder());

    iLit8Sect.contents  = (char*)iMachHeaderPtr + iLit8Sect.s.offset;
    iLit8Sect.size      = iLit8Sect.s.size;
}

//  loadTextSection:
// ----------------------------------------------------------------------------

- (void)loadTextSection: (section*)inSect
{
    iTextSect.s = *inSect;

    if (iSwapped)
        swap_section(&iTextSect.s, 1, OSHostByteOrder());

    iTextSect.contents  = (char*)iMachHeaderPtr + iTextSect.s.offset;
    iTextSect.size      = iTextSect.s.size;

    iEndOfText  = iTextSect.s.addr + iTextSect.s.size;
}

//  loadConstTextSection:
// ----------------------------------------------------------------------------

- (void)loadConstTextSection: (section*)inSect
{
    iConstTextSect.s    = *inSect;

    if (iSwapped)
        swap_section(&iConstTextSect.s, 1, OSHostByteOrder());

    iConstTextSect.contents = (char*)iMachHeaderPtr + iConstTextSect.s.offset;
    iConstTextSect.size     = iConstTextSect.s.size;
}

//  loadCoalTextSection:
// ----------------------------------------------------------------------------

- (void)loadCoalTextSection: (section*)inSect
{
    iCoalTextSect.s = *inSect;

    if (iSwapped)
        swap_section(&iCoalTextSect.s, 1, OSHostByteOrder());

    iCoalTextSect.contents  = (char*)iMachHeaderPtr + iCoalTextSect.s.offset;
    iCoalTextSect.size      = iCoalTextSect.s.size;
}

//  loadCoalTextNTSection:
// ----------------------------------------------------------------------------

- (void)loadCoalTextNTSection: (section*)inSect
{
    iCoalTextNTSect.s   = *inSect;

    if (iSwapped)
        swap_section(&iCoalTextNTSect.s, 1, OSHostByteOrder());

    iCoalTextNTSect.contents    = (char*)iMachHeaderPtr + iCoalTextNTSect.s.offset;
    iCoalTextNTSect.size        = iCoalTextNTSect.s.size;
}

//  loadDataSection:
// ----------------------------------------------------------------------------

- (void)loadDataSection: (section*)inSect
{
    iDataSect.s = *inSect;

    if (iSwapped)
        swap_section(&iDataSect.s, 1, OSHostByteOrder());

    iDataSect.contents  = (char*)iMachHeaderPtr + iDataSect.s.offset;
    iDataSect.size      = iDataSect.s.size;
}

//  loadCoalDataSection:
// ----------------------------------------------------------------------------

- (void)loadCoalDataSection: (section*)inSect
{
    iCoalDataSect.s = *inSect;

    if (iSwapped)
        swap_section(&iCoalDataSect.s, 1, OSHostByteOrder());

    iCoalDataSect.contents  = (char*)iMachHeaderPtr + iCoalDataSect.s.offset;
    iCoalDataSect.size      = iCoalDataSect.s.size;
}

//  loadCoalDataNTSection:
// ----------------------------------------------------------------------------

- (void)loadCoalDataNTSection: (section*)inSect
{
    iCoalDataNTSect.s   = *inSect;

    if (iSwapped)
        swap_section(&iCoalDataNTSect.s, 1, OSHostByteOrder());

    iCoalDataNTSect.contents    = (char*)iMachHeaderPtr + iCoalDataNTSect.s.offset;
    iCoalDataNTSect.size        = iCoalDataNTSect.s.size;
}

//  loadConstDataSection:
// ----------------------------------------------------------------------------

- (void)loadConstDataSection: (section*)inSect
{
    iConstDataSect.s    = *inSect;

    if (iSwapped)
        swap_section(&iConstDataSect.s, 1, OSHostByteOrder());

    iConstDataSect.contents = (char*)iMachHeaderPtr + iConstDataSect.s.offset;
    iConstDataSect.size     = iConstDataSect.s.size;
}

//  loadDyldDataSection:
// ----------------------------------------------------------------------------

- (void)loadDyldDataSection: (section*)inSect
{
    iDyldSect.s = *inSect;

    if (iSwapped)
        swap_section(&iDyldSect.s, 1, OSHostByteOrder());

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

- (void)loadCFStringSection: (section*)inSect
{
    iCFStringSect.s = *inSect;

    if (iSwapped)
        swap_section(&iCFStringSect.s, 1, OSHostByteOrder());

    iCFStringSect.contents  = (char*)iMachHeaderPtr + iCFStringSect.s.offset;
    iCFStringSect.size      = iCFStringSect.s.size;
}

//  loadNonLazySymbolSection:
// ----------------------------------------------------------------------------

- (void)loadNonLazySymbolSection: (section*)inSect
{
    iNLSymSect.s    = *inSect;

    if (iSwapped)
        swap_section(&iNLSymSect.s, 1, OSHostByteOrder());

    iNLSymSect.contents = (char*)iMachHeaderPtr + iNLSymSect.s.offset;
    iNLSymSect.size     = iNLSymSect.s.size;
}

//  loadObjcClassListSection:
// ----------------------------------------------------------------------------

- (void)loadObjcClassListSection: (section*)inSect
{
    iObjcClassListSect.s = *inSect;

    if (iSwapped)
        swap_section(&iObjcClassListSect.s, 1, OSHostByteOrder());

    iObjcClassListSect.contents = (char*)iMachHeaderPtr + iObjcClassListSect.s.offset;
    iObjcClassListSect.size = iObjcClassListSect.s.size;
}

//  loadObjcCatListSection:
// ----------------------------------------------------------------------------

- (void)loadObjcCatListSection: (section*)inSect
{
    iObjcCatListSect.s = *inSect;

    if (iSwapped)
        swap_section(&iObjcCatListSect.s, 1, OSHostByteOrder());

    iObjcCatListSect.contents = (char*)iMachHeaderPtr + iObjcCatListSect.s.offset;
    iObjcCatListSect.size = iObjcCatListSect.s.size;
}

//  loadObjcConstSection:
// ----------------------------------------------------------------------------

- (void)loadObjcConstSection: (section*)inSect
{
    iObjcConstSect.s = *inSect;

    if (iSwapped)
        swap_section(&iObjcConstSect.s, 1, OSHostByteOrder());

    iObjcConstSect.contents = (char*)iMachHeaderPtr + iObjcConstSect.s.offset;
    iObjcConstSect.size = iObjcCatListSect.s.size;
}

//  loadObjcProtoListSection:
// ----------------------------------------------------------------------------

- (void)loadObjcProtoListSection: (section*)inSect
{
    iObjcProtoListSect.s = *inSect;

    if (iSwapped)
        swap_section(&iObjcProtoListSect.s, 1, OSHostByteOrder());

    iObjcProtoListSect.contents = (char*)iMachHeaderPtr + iObjcProtoListSect.s.offset;
    iObjcProtoListSect.size = iObjcProtoListSect.s.size;
}

//  loadObjcSuperRefsSection:
// ----------------------------------------------------------------------------

- (void)loadObjcSuperRefsSection: (section*)inSect
{
    iObjcSuperRefsSect.s = *inSect;

    if (iSwapped)
        swap_section(&iObjcSuperRefsSect.s, 1, OSHostByteOrder());

    iObjcSuperRefsSect.contents = (char*)iMachHeaderPtr + iObjcSuperRefsSect.s.offset;
    iObjcSuperRefsSect.size = iObjcSuperRefsSect.s.size;
}

//  loadObjcClassRefsSection:
// ----------------------------------------------------------------------------

- (void)loadObjcClassRefsSection: (section*)inSect
{
    iObjcClassRefsSect.s = *inSect;

    if (iSwapped)
        swap_section(&iObjcClassRefsSect.s, 1, OSHostByteOrder());

    iObjcClassRefsSect.contents = (char*)iMachHeaderPtr + iObjcClassRefsSect.s.offset;
    iObjcClassRefsSect.size = iObjcClassRefsSect.s.size;
}

//  loadObjcProtoRefsSection:
// ----------------------------------------------------------------------------

- (void)loadObjcProtoRefsSection: (section*)inSect
{
    iObjcProtoRefsSect.s = *inSect;

    if (iSwapped)
        swap_section(&iObjcProtoRefsSect.s, 1, OSHostByteOrder());

    iObjcProtoRefsSect.contents = (char*)iMachHeaderPtr + iObjcProtoRefsSect.s.offset;
    iObjcProtoRefsSect.size = iObjcProtoRefsSect.s.size;
}

//  loadObjcMsgRefsSection:
// ----------------------------------------------------------------------------

- (void)loadObjcMsgRefsSection: (section*)inSect
{
    iObjcMsgRefsSect.s = *inSect;

    if (iSwapped)
        swap_section(&iObjcMsgRefsSect.s, 1, OSHostByteOrder());

    iObjcMsgRefsSect.contents = (char*)iMachHeaderPtr + iObjcMsgRefsSect.s.offset;
    iObjcMsgRefsSect.size = iObjcMsgRefsSect.s.size;
}

//  loadObjcSelRefsSection:
// ----------------------------------------------------------------------------

- (void)loadObjcSelRefsSection: (section*)inSect
{
    iObjcSelRefsSect.s = *inSect;

    if (iSwapped)
        swap_section(&iObjcSelRefsSect.s, 1, OSHostByteOrder());

    iObjcSelRefsSect.contents = (char*)iMachHeaderPtr + iObjcSelRefsSect.s.offset;
    iObjcSelRefsSect.size = iObjcSelRefsSect.s.size;
}

//  loadObjcDataSection:
// ----------------------------------------------------------------------------

- (void)loadObjcDataSection: (section*)inSect
{
    iObjcDataSect.s = *inSect;

    if (iSwapped)
        swap_section(&iObjcDataSect.s, 1, OSHostByteOrder());

    iObjcDataSect.contents = (char*)iMachHeaderPtr + iObjcDataSect.s.offset;
    iObjcDataSect.size = iObjcDataSect.s.size;
}

//  loadImpPtrSection:
// ----------------------------------------------------------------------------

- (void)loadImpPtrSection: (section*)inSect
{
    iImpPtrSect.s   = *inSect;

    if (iSwapped)
        swap_section(&iImpPtrSect.s, 1, OSHostByteOrder());

    iImpPtrSect.contents    = (char*)iMachHeaderPtr + iImpPtrSect.s.offset;
    iImpPtrSect.size        = iImpPtrSect.s.size;
}

@end
