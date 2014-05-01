/*
    Searchers.m

    A category on Exe32Processor that contains the various binary search
    methods.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "Searchers.h"
#import "ObjcAccessors.h"

@implementation Exe32Processor(Searchers)

//  findSymbolByAddress:
// ----------------------------------------------------------------------------

- (char*)findSymbolByAddress: (uint32_t)inAddress
{
    if (!iFuncSyms)
        return NO;

    nlist searchKey = {{0}, 0, 0, 0, inAddress};
    nlist* symbol = (nlist*)bsearch(&searchKey,
        iFuncSyms, iNumFuncSyms, sizeof(nlist),
        (COMPARISON_FUNC_TYPE)Sym_Compare);

    if (symbol) {
        return (char*)((char *)iMachHeaderPtr + iStringTableOffset + symbol->n_un.n_strx);
    }else
        return NULL;
}

//  findClassMethod:byAddress:
// ----------------------------------------------------------------------------

- (BOOL)findClassMethod: (MethodInfo**)outMI
              byAddress: (uint32_t)inAddress;
{
    if (!outMI)
        return NO;

    if (!iClassMethodInfos)
    {
        *outMI  = NULL;
        return NO;
    }

    uint32_t  swappedAddress  = inAddress;

    if (iSwapped)
        swappedAddress  = OSSwapInt32(swappedAddress);

    MethodInfo  searchKey   = {0};
    searchKey.m.method_imp = swappedAddress;

    *outMI  = bsearch(&searchKey,
        iClassMethodInfos, iNumClassMethodInfos, sizeof(MethodInfo),
            (COMPARISON_FUNC_TYPE)
            (iSwapped ? MethodInfo_Compare_Swapped : MethodInfo_Compare));

    return (*outMI != NULL);
}

//  findCatMethod:byAddress:
// ----------------------------------------------------------------------------

- (BOOL)findCatMethod: (MethodInfo**)outMI
            byAddress: (uint32_t)inAddress;
{
    if (!outMI)
        return NO;

    if (!iCatMethodInfos)
    {
        *outMI  = NULL;
        return NO;
    }

    uint32_t  swappedAddress  = inAddress;

    if (iSwapped)
        swappedAddress  = OSSwapInt32(swappedAddress);

    MethodInfo searchKey = {0};
    searchKey.m.method_imp = swappedAddress;

    *outMI  = bsearch(&searchKey,
        iCatMethodInfos, iNumCatMethodInfos, sizeof(MethodInfo),
            (COMPARISON_FUNC_TYPE)
            (iSwapped ? MethodInfo_Compare_Swapped : MethodInfo_Compare));

    return (*outMI != NULL);
}

//  findIvar:inClass:withOffset:
// ----------------------------------------------------------------------------

- (BOOL)findIvar: (objc1_32_ivar*)outIvar
         inClass: (objc1_32_class*)inClass
      withOffset: (uint32_t)inOffset
{
    if (!inClass || !outIvar)
        return NO;

    // Loop thru inClass and all superclasses.
    objc1_32_class*         theClassPtr     = inClass;
    objc1_32_class          theSwappedClass = *theClassPtr;
    objc1_32_class          theDummyClass   = {0};
    char*                   theSuperName    = NULL;
    objc1_32_ivar_list*     theIvars;

    while (theClassPtr)
    {
//      if (mSwapped)
//          swap_objc_class(&theSwappedClass);

        theIvars    = (objc1_32_ivar_list*)[self getPointer:theSwappedClass.ivars type:NULL];

        if (!theIvars)
        {   // Try again with the superclass.
            theSuperName    = [self getPointer:theClassPtr->super_class type:NULL];

            if (!theSuperName)
                break;

            if (![self getObjc1Class:&theDummyClass fromName:theSuperName])
                break;

            theClassPtr = &theDummyClass;

            continue;
        }

        uint32_t  numIvars    = theIvars->ivar_count;

        if (iSwapped)
            numIvars    = OSSwapInt32(numIvars);

        // It would be nice to use bsearch(3) here, but there's too much
        // swapping.
        SInt64  begin   = 0;
        SInt64  end     = numIvars - 1;
        SInt64  split   = numIvars / 2;
        uint32_t  offset;

        while (end >= begin)
        {
            offset  = theIvars->ivar_list[split].ivar_offset;

            if (iSwapped)
                offset  = OSSwapInt32(offset);

            if (offset == inOffset)
            {
                *outIvar    = theIvars->ivar_list[split];

                if (iSwapped)
                    swap_objc1_32_ivar(outIvar);

                return YES;
            }

            if (offset > inOffset)
                end     = split - 1;
            else
                begin   = split + 1;

            split   = (begin + end) / 2;
        }

        // Try again with the superclass.
        theSuperName    = [self getPointer:theClassPtr->super_class type:NULL];

        if (!theSuperName)
            break;

        if (![self getObjc1Class:&theDummyClass fromName:theSuperName])
            break;

        theClassPtr = &theDummyClass;
    }

    return NO;
}

//  findIvar:inClass:withOffset:
// ----------------------------------------------------------------------------

- (BOOL)findIvar: (objc2_32_ivar_t**)outIvar
        inClass2: (objc2_32_class_t*)inClass
      withOffset: (uint32_t)inOffset
{
    if (!inClass || !outIvar)
        return NO;

    objc2_64_ivar_t searchKey = {inOffset, 0, 0, 0, 0};

    *outIvar = bsearch(&searchKey, iClassIvars, iNumClassIvars, sizeof(objc2_32_ivar_t),
        (COMPARISON_FUNC_TYPE)objc2_32_ivar_t_Compare);

    return (*outIvar != NULL);
}

@end
