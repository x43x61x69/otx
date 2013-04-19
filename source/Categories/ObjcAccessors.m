/*
    ObjcAccessors.m

    What the filename says.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "ObjcAccessors.h"

@implementation Exe32Processor(ObjcAccessors)

//  getObjcClassPtr:fromMethod:
// ----------------------------------------------------------------------------
//  Given a method imp address, return the class to which it belongs. This func
//  is called each time a new function is detected. If that function is known
//  to be an Obj-C method, it's class is returned. Otherwise this returns NULL.

- (BOOL)getObjcClassPtr: (objc_class**)outClass
             fromMethod: (uint32_t)inAddress;
{
    *outClass = NULL;

    MethodInfo* theInfo = NULL;

    FindClassMethodByAddress(&theInfo, inAddress);

    if (theInfo)
        *outClass = &theInfo->oc_class;

    return (*outClass != NULL);
}

//  getObjcCatPtr:fromMethod:
// ----------------------------------------------------------------------------
//  Same as above, for categories.

- (BOOL)getObjcCatPtr: (objc_category**)outCat
           fromMethod: (uint32_t)inAddress;
{
    *outCat = NULL;

    MethodInfo* theInfo = NULL;

    FindCatMethodByAddress(&theInfo, inAddress);

    if (theInfo)
        *outCat = &theInfo->oc_cat;

    return (*outCat != NULL);
}

//  getObjcMethod:fromAddress:
// ----------------------------------------------------------------------------
//  Given a method imp address, return the MethodInfo for it.

- (BOOL)getObjcMethod: (MethodInfo**)outMI
          fromAddress: (uint32_t)inAddress;
{
    *outMI  = NULL;

    FindClassMethodByAddress(outMI, inAddress);

    if (*outMI)
        return YES;

    FindCatMethodByAddress(outMI, inAddress);

    return (*outMI != NULL);
}

//  getObjcMethodList:methods:fromAddress: (was get_method_list)
// ----------------------------------------------------------------------------
//  Removed the truncation flag. 'left' is no longer used by the caller.

- (BOOL)getObjcMethodList: (objc_method_list*)outList
                  methods: (objc_method**)outMethods
              fromAddress: (uint32_t)inAddress;
{
    uint32_t  left, i;

    if (!outList)
        return NO;

    *outList    = (objc_method_list){0};

    for (i = 0; i < iNumObjcSects; i++)
    {
        if (inAddress >= iObjcSects[i].s.addr &&
            inAddress < iObjcSects[i].s.addr + iObjcSects[i].s.size)
        {
            left = iObjcSects[i].s.size -
                (inAddress - iObjcSects[i].s.addr);

            if (left >= sizeof(objc_method_list) - sizeof(objc_method))
            {
                memcpy(outList, iObjcSects[i].contents +
                    (inAddress - iObjcSects[i].s.addr),
                    sizeof(objc_method_list) - sizeof(objc_method));
                *outMethods = (objc_method*)(iObjcSects[i].contents +
                    (inAddress - iObjcSects[i].s.addr) +
                    sizeof(objc_method_list) - sizeof(objc_method));
            }
            else
            {
                memcpy(outList, iObjcSects[i].contents +
                    (inAddress - iObjcSects[i].s.addr), left);
                *outMethods = NULL;
            }

            return YES;
        }
    }

    return NO;
}

//  getObjcDescription:fromObject:type:
// ----------------------------------------------------------------------------
//  Given an Obj-C object, return it's description.

- (BOOL)getObjcDescription: (char**)outDescription
                fromObject: (const char*)inObject
                      type: (UInt8)inType
{
    *outDescription = NULL;

    uint32_t  theValue    = 0;

    switch (inType)
    {
        case OCStrObjectType:
        {
            objc_string_object  ocString    = *(objc_string_object*)inObject;

            if (ocString.length == 0)
                break;

            theValue    = (uint32_t)ocString.chars;

            break;
        }
        case OCClassType:
        {
            objc_class  ocClass = *(objc_class*)inObject;

            theValue    = (ocClass.name != 0) ?
                (uint32_t)ocClass.name : (uint32_t)ocClass.isa;

            break;
        }
        case OCModType:
        {
            objc_module ocMod   = *(objc_module*)inObject;

            theValue    = (uint32_t)ocMod.name;

            break;
        }
        case OCGenericType:
            theValue    = *(uint32_t*)inObject;

            break;

        default:
            return NO;
            break;
    }

    if (iSwapped)
        theValue    = OSSwapInt32(theValue);

    *outDescription = GetPointer(theValue, NULL);

    return (*outDescription != NULL);
}

//  getObjcSymtab:defs:fromModule: (was get_symtab)
// ----------------------------------------------------------------------------
//  Removed the truncation flag. 'left' is no longer used by the caller.

- (BOOL)getObjcSymtab: (objc_symtab*)outSymTab
                 defs: (void***)outDefs
           fromModule: (objc_module*)inModule;
{
    if (!outSymTab)
        return NO;

    unsigned long   addr    = (unsigned long)inModule->symtab;
    unsigned long   i, left;

    *outSymTab  = (objc_symtab){0};

    for (i = 0; i < iNumObjcSects; i++)
    {
        if (addr >= iObjcSects[i].s.addr &&
            addr < iObjcSects[i].s.addr + iObjcSects[i].size)
        {
            left = iObjcSects[i].size -
                (addr - iObjcSects[i].s.addr);

            if (left >= sizeof(objc_symtab) - sizeof(void*))
            {
                memcpy(outSymTab, iObjcSects[i].contents +
                    (addr - iObjcSects[i].s.addr),
                    sizeof(objc_symtab) - sizeof(void*));
                *outDefs    = (void**)(iObjcSects[i].contents +
                    (addr - iObjcSects[i].s.addr) +
                    sizeof(objc_symtab) - sizeof(void*));
            }
            else
            {
                memcpy(outSymTab, iObjcSects[i].contents +
                    (addr - iObjcSects[i].s.addr), left);
                *outDefs    = NULL;
            }

            return YES;
        }
    }

    return NO;
}

//  getObjcClass:fromDef: (was get_objc_class)
// ----------------------------------------------------------------------------

- (BOOL)getObjcClass: (objc_class*)outClass
             fromDef: (uint32_t)inDef;
{
    uint32_t  i;

    for (i = 0; i < iNumObjcSects; i++)
    {
        if (inDef >= iObjcSects[i].s.addr &&
            inDef < iObjcSects[i].s.addr + iObjcSects[i].size)
        {
            *outClass   = *(objc_class*)(iObjcSects[i].contents +
                (inDef - iObjcSects[i].s.addr));

            return YES;
        }
    }

    return NO;
}

//  getObjcCategory:fromDef: (was get_objc_category)
// ----------------------------------------------------------------------------

- (BOOL)getObjcCategory: (objc_category*)outCat
                fromDef: (uint32_t)inDef;
{
    uint32_t  i;

    for (i = 0; i < iNumObjcSects; i++)
    {
        if (inDef >= iObjcSects[i].s.addr &&
            inDef < iObjcSects[i].s.addr + iObjcSects[i].s.size)
        {
            *outCat = *(objc_category*)(iObjcSects[i].contents +
                (inDef - iObjcSects[i].s.addr));

            return YES;
        }
    }

    return NO;
}

//  getObjcClass:fromName:
// ----------------------------------------------------------------------------
//  Given a class name, return the class itself. This func is used to tie
//  categories to classes. We have 2 pointers to the same name, so pointer
//  equality is sufficient.

- (BOOL)getObjcClass: (objc_class*)outClass
            fromName: (const char*)inName;
{
    uint32_t  i, namePtr;

    for (i = 0; i < iNumClassMethodInfos; i++)
    {
        namePtr = (uint32_t)iClassMethodInfos[i].oc_class.name;

        if (iSwapped)
            namePtr = OSSwapInt32(namePtr);

        if (GetPointer(namePtr, NULL) == inName)
        {
            *outClass   = iClassMethodInfos[i].oc_class;
            return YES;
        }
    }

    *outClass   = (objc_class){0};

    return NO;
}

//  getObjcClassPtr:fromName:
// ----------------------------------------------------------------------------
//  Same as above, but returns a pointer.

- (BOOL)getObjcClassPtr: (objc_class**)outClassPtr
               fromName: (const char*)inName;
{
    uint32_t  i, namePtr;

    for (i = 0; i < iNumClassMethodInfos; i++)
    {
        namePtr = (uint32_t)iClassMethodInfos[i].oc_class.name;

        if (iSwapped)
            namePtr = OSSwapInt32(namePtr);

        if (GetPointer(namePtr, NULL) == inName)
        {
            *outClassPtr = &iClassMethodInfos[i].oc_class;
            return YES;
        }
    }

    *outClassPtr = NULL;

    return NO;
}

//  getObjcMetaClass:fromClass:
// ----------------------------------------------------------------------------

- (BOOL)getObjcMetaClass: (objc_class*)outClass
               fromClass: (objc_class*)inClass;
{
    if ((uint32_t)inClass->isa >= iMetaClassSect.s.addr &&
        (uint32_t)inClass->isa < iMetaClassSect.s.addr + iMetaClassSect.s.size)
    {
        *outClass   = *(objc_class*)(iMetaClassSect.contents +
            ((uint32_t)inClass->isa - iMetaClassSect.s.addr));

        return YES;
    }

    return NO;
}

@end
