/*
    ObjcAccessors.m

    What the filename says.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "ObjcAccessors.h"
#import "Searchers.h"

@implementation Exe32Processor(ObjcAccessors)

//  getObjcClassPtr:fromMethod:
// ----------------------------------------------------------------------------
//  Given a method imp address, return the class to which it belongs. This func
//  is called each time a new function is detected. If that function is known
//  to be an Obj-C method, it's class is returned. Otherwise this returns NULL.

- (BOOL)getObjcClassPtr: (objc_32_class_ptr*)outClass
             fromMethod: (uint32_t)inAddress;
{
    *outClass = NULL;

    MethodInfo* theInfo = NULL;
    [self findClassMethod:&theInfo byAddress:inAddress];

    if (theInfo)
    {
        if (iObjcVersion < 2)
        {
            *outClass = (objc_32_class_ptr)&theInfo->oc_class;
        }
        else if (iObjcVersion == 2)
        {
            *outClass = (objc_32_class_ptr)&theInfo->oc_class2;
        }
    }

    return (*outClass != NULL);
}

//  getObjcClassPtr:fromName:
// ----------------------------------------------------------------------------
//  Given a class name, return the class itself. This func is used to tie
//  categories to classes. We have 2 pointers to the same name, so pointer
//  equality is sufficient.

- (BOOL)getObjcClassPtr: (objc_32_class_ptr *)outClassPtr
               fromName: (const char*)inName;
{
    if (iObjcVersion < 2)
    {
        for (uint32_t i = 0; i < iNumClassMethodInfos; i++)
        {
            uint32_t namePtr = (uint32_t)iClassMethodInfos[i].oc_class.name;

            if (iSwapped)
                namePtr = OSSwapInt32(namePtr);

            if ([self getPointer:namePtr type:NULL] == inName)
            {
                *outClassPtr = (objc_32_class_ptr) &iClassMethodInfos[i].oc_class;
                return YES;
            }
        }

    }
    else if (iObjcVersion == 2)
    {
        for (uint32_t i = 0; i < iNumClassMethodInfos; i++)
        {
            objc2_32_class_ro_t* roData = (objc2_32_class_ro_t*)(iObjcConstSect.contents +
                (uintptr_t)(iClassMethodInfos[i].oc_class2.data - iObjcConstSect.s.addr)); 

            uint32_t namePtr = roData->name;

            if (iSwapped)
                namePtr = OSSwapInt32(namePtr);

            if ([self getPointer:namePtr type:NULL] == inName)
            {
                *outClassPtr = (objc_32_class_ptr) &iClassMethodInfos[i].oc_class2;
                return YES;
            }
        }
    }

    *outClassPtr = NULL;

    return NO;
}

//  getObjcMethod:fromAddress:
// ----------------------------------------------------------------------------
//  Given a method imp address, return the MethodInfo for it.

- (BOOL)getObjcMethod: (MethodInfo**)outMI
          fromAddress: (uint32_t)inAddress;
{
    *outMI  = NULL;

    [self findClassMethod:outMI byAddress:inAddress];

    if (*outMI)
        return YES;

    [self findCatMethod:outMI byAddress:inAddress];

    return (*outMI != NULL);
}

//  getObjc1CatPtr:fromMethod:
// ----------------------------------------------------------------------------
//  Given a method imp address, return the category to which it belongs.

- (BOOL)getObjc1CatPtr: (objc1_32_category**)outCat
            fromMethod: (uint32_t)inAddress;
{
    *outCat = NULL;

    MethodInfo* theInfo = NULL;
    [self findCatMethod:&theInfo byAddress:inAddress];

    if (theInfo)
        *outCat = &theInfo->oc_cat;

    return (*outCat != NULL);
}

//  getObjc1MethodList:methods:fromAddress: (was get_method_list)
// ----------------------------------------------------------------------------
//  Removed the truncation flag. 'left' is no longer used by the caller.

- (BOOL)getObjc1MethodList: (objc1_32_method_list*)outList
                   methods: (objc1_32_method**)outMethods
               fromAddress: (uint32_t)inAddress;
{
    uint32_t  left, i;

    if (!outList)
        return NO;

    *outList    = (objc1_32_method_list){0};

    for (i = 0; i < iNumObjcSects; i++)
    {
        if (inAddress >= iObjcSects[i].s.addr &&
            inAddress < iObjcSects[i].s.addr + iObjcSects[i].s.size)
        {
            left = iObjcSects[i].s.size -
                (inAddress - iObjcSects[i].s.addr);

            if (left >= sizeof(objc1_32_method_list) - sizeof(objc1_32_method))
            {
                memcpy(outList, iObjcSects[i].contents +
                    (inAddress - iObjcSects[i].s.addr),
                    sizeof(objc1_32_method_list) - sizeof(objc1_32_method));
                *outMethods = (objc1_32_method*)(iObjcSects[i].contents +
                    (inAddress - iObjcSects[i].s.addr) +
                    sizeof(objc1_32_method_list) - sizeof(objc1_32_method));
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

//  getObjc1Description:fromObject:type:
// ----------------------------------------------------------------------------
//  Given an Obj-C object, return it's description.

- (BOOL)getObjc1Description: (char**)outDescription
                 fromObject: (const char*)inObject
                       type: (UInt8)inType
{
    *outDescription = NULL;

    uint32_t  theValue    = 0;

    switch (inType)
    {
        case OCStrObjectType:
        {
            nxstring_object  ocString    = *(nxstring_object*)inObject;

            if (ocString.length == 0)
                break;

            theValue = ocString.chars;

            break;
        }
        case OCClassType:
        {
            objc1_32_class  ocClass = *(objc1_32_class*)inObject;

            theValue = ocClass.name ? ocClass.name : ocClass.isa;

            break;
        }
        case OCModType:
        {
            objc1_32_module ocMod   = *(objc1_32_module*)inObject;

            theValue = ocMod.name;

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

    *outDescription = [self getPointer:theValue type:NULL];

    return (*outDescription != NULL);
}

//  getObjc1Symtab:defs:fromModule: (was get_symtab)
// ----------------------------------------------------------------------------
//  Removed the truncation flag. 'left' is no longer used by the caller.

- (BOOL)getObjc1Symtab: (objc1_32_symtab*)outSymTab
                  defs: (uint32_t **)outDefs
            fromModule: (objc1_32_module*)inModule;
{
    if (!outSymTab)
        return NO;

    uint32_t   addr    = inModule->symtab;
    uint32_t   i, left;

    *outSymTab  = (objc1_32_symtab){0};

    for (i = 0; i < iNumObjcSects; i++)
    {
        if (addr >= iObjcSects[i].s.addr &&
            addr < iObjcSects[i].s.addr + iObjcSects[i].size)
        {
            left = iObjcSects[i].size -
                (addr - iObjcSects[i].s.addr);

            if (left >= sizeof(objc1_32_symtab) - sizeof(uint32_t))
            {
                memcpy(outSymTab, iObjcSects[i].contents +
                    (addr - iObjcSects[i].s.addr),
                    sizeof(objc1_32_symtab) - sizeof(uint32_t));
                *outDefs    = (uint32_t *)(iObjcSects[i].contents +
                    (addr - iObjcSects[i].s.addr) +
                    sizeof(objc1_32_symtab) - sizeof(uint32_t));
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

//  getObjc1Class:fromDef: (was get_objc_class)
// ----------------------------------------------------------------------------

- (BOOL)getObjc1Class: (objc1_32_class*)outClass
              fromDef: (uint32_t)inDef;
{
    if (iObjcVersion < 2)
    {
        uint32_t  i;

        for (i = 0; i < iNumObjcSects; i++)
        {
            if (inDef >= iObjcSects[i].s.addr &&
                inDef < iObjcSects[i].s.addr + iObjcSects[i].size)
            {
                *outClass   = *(objc1_32_class*)(iObjcSects[i].contents +
                    (inDef - iObjcSects[i].s.addr));

                return YES;
            }
        }
    }

    return NO;
}

//  getObjc1Category:fromDef: (was get_objc_category)
// ----------------------------------------------------------------------------

- (BOOL)getObjc1Category: (objc1_32_category*)outCat
                 fromDef: (uint32_t)inDef;
{
    if (iObjcVersion < 2)
    {
        uint32_t  i;

        for (i = 0; i < iNumObjcSects; i++)
        {
            if (inDef >= iObjcSects[i].s.addr &&
                inDef < iObjcSects[i].s.addr + iObjcSects[i].s.size)
            {
                *outCat = *(objc1_32_category*)(iObjcSects[i].contents +
                    (inDef - iObjcSects[i].s.addr));

                return YES;
            }
        }
    }

    return NO;
}

//  getObjc1Class:fromName:
// ----------------------------------------------------------------------------
//  Given a class name, return the class itself. This func is used to tie
//  categories to classes. We have 2 pointers to the same name, so pointer
//  equality is sufficient.

- (BOOL)getObjc1Class: (objc1_32_class *)outClass
             fromName: (const char*)inName;
{
    uint32_t  i, namePtr;

    for (i = 0; i < iNumClassMethodInfos; i++)
    {
        namePtr = (uint32_t)iClassMethodInfos[i].oc_class.name;

        if (iSwapped)
            namePtr = OSSwapInt32(namePtr);

        if ([self getPointer:namePtr type:NULL] == inName)
        {
            *outClass   = iClassMethodInfos[i].oc_class;
            return YES;
        }
    }

    *outClass   = (objc1_32_class){0};

    return NO;
}

//  getObjc1MetaClass:fromClass:
// ----------------------------------------------------------------------------

- (BOOL)getObjc1MetaClass: (objc1_32_class*)outClass
                fromClass: (objc1_32_class*)inClass;
{
    if (iObjcVersion < 2)
    {
        if (inClass->isa >= iMetaClassSect.s.addr &&
            inClass->isa < iMetaClassSect.s.addr + iMetaClassSect.s.size)
        {
            *outClass   = *(objc1_32_class*)(iMetaClassSect.contents +
                (inClass->isa - iMetaClassSect.s.addr));

            return YES;
        }
    }

    return NO;
}

@end
