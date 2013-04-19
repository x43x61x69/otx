/*
    Objc64Accessors.m

    What the filename says.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "Objc64Accessors.h"

@implementation Exe64Processor(Objc64Accessors)

//  getObjcClassPtr:fromMethod:
// ----------------------------------------------------------------------------
//  Given a method imp address, return the class to which it belongs. This func
//  is called each time a new function is detected. If that function is known
//  to be an Obj-C method, it's class is returned. Otherwise this returns NULL.

- (BOOL)getObjcClassPtr: (objc2_class_t**)outClass
             fromMethod: (UInt64)inAddress;
{
    *outClass   = NULL;

    Method64Info* theInfo = NULL;

    FindClassMethodByAddress(&theInfo, inAddress);

    if (theInfo)
        *outClass   = &theInfo->oc_class;

    return (*outClass != NULL);
}

//  getObjcMethod:fromAddress:
// ----------------------------------------------------------------------------
//  Given a method imp address, return the MethodInfo for it.

- (BOOL)getObjcMethod: (Method64Info**)outMI
          fromAddress: (UInt64)inAddress;
{
    *outMI  = NULL;

    FindClassMethodByAddress(outMI, inAddress);

/*    if (*outMI)
        return YES;

    FindCatMethodByAddress(outMI, inAddress);*/

    return (*outMI != NULL);
}

//  getObjcMethodList:methods:fromAddress: (was get_method_list)
// ----------------------------------------------------------------------------
//  Removed the truncation flag. 'left' is no longer used by the caller.

- (BOOL)getObjcMethodList: (objc2_method_list_t*)outList
                  methods: (objc2_method_t**)outMethods
              fromAddress: (UInt64)inAddress;
{
/*    uint32_t  left, i;

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
                left -= sizeof(objc_method_list) -
                    sizeof(objc_method);
                *outMethods = (objc_method*)(iObjcSects[i].contents +
                    (inAddress - iObjcSects[i].s.addr) +
                    sizeof(objc_method_list) - sizeof(objc_method));
            }
            else
            {
                memcpy(outList, iObjcSects[i].contents +
                    (inAddress - iObjcSects[i].s.addr), left);
                left = 0;
                *outMethods = NULL;
            }

            return YES;
        }
    }

    return NO;
*/
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

    UInt64  theValue    = 0;

    switch (inType)
    {
        case CFStringType:
        {
            cf_string_object_64 cfString = *(cf_string_object_64*)inObject;

            if (cfString.oc_string.length == 0)
                break;

            theValue = cfString.oc_string.chars;

            break;
        }

        case OCStrObjectType:
        {
            objc2_string_object ocString = *(objc2_string_object*)inObject;

            if (ocString.length == 0)
                break;

            theValue = ocString.chars;

            break;
        }

        case OCGenericType:
            theValue = *(UInt64*)inObject;

            break;

        default:
            return NO;
            break;
    }

    if (iSwapped)
        theValue = OSSwapInt64(theValue);

    *outDescription = GetPointer(theValue, NULL);

    return (*outDescription != NULL);
}

//  getObjcClass:fromName:
// ----------------------------------------------------------------------------
//  Given a class name, return the class itself. This func is used to tie
//  categories to classes. We have 2 pointers to the same name, so pointer
//  equality is sufficient.

- (BOOL)getObjcClass: (objc2_class_t*)outClass
            fromName: (const char*)inName;
{
    uint32_t  i;
    UInt64  namePtr;

    for (i = 0; i < iNumClassMethodInfos; i++)
    {
        objc2_class_ro_t* roData = (objc2_class_ro_t*)(iDataSect.contents +
            (uintptr_t)(iClassMethodInfos[i].oc_class.data - iDataSect.s.addr)); 

        namePtr = roData->name;

        if (iSwapped)
            namePtr = OSSwapInt64(namePtr);

        if (GetPointer(namePtr, NULL) == inName)
        {
            *outClass   = iClassMethodInfos[i].oc_class;
            return YES;
        }
    }

    *outClass   = (objc2_class_t){0};
    return NO;
}

//  getObjcClassPtr:fromName:
// ----------------------------------------------------------------------------
//  Same as above, but returns a pointer.

- (BOOL)getObjcClassPtr: (objc2_class_t**)outClassPtr
               fromName: (const char*)inName;
{
    uint32_t  i;
    UInt64  namePtr;

    for (i = 0; i < iNumClassMethodInfos; i++)
    {
        objc2_class_ro_t* roData = (objc2_class_ro_t*)(iDataSect.contents +
            (uintptr_t)(iClassMethodInfos[i].oc_class.data - iDataSect.s.addr)); 

        namePtr = roData->name;

        if (iSwapped)
            namePtr = OSSwapInt64(namePtr);

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

- (BOOL)getObjcMetaClass: (objc2_class_t*)outClass
               fromClass: (objc2_class_t*)inClass;
{
/*    if ((uint32_t)inClass->isa >= iMetaClassSect.s.addr &&
        (uint32_t)inClass->isa < iMetaClassSect.s.addr + iMetaClassSect.s.size)
    {
        *outClass   = *(objc_class*)(iMetaClassSect.contents +
            ((uint32_t)inClass->isa - iMetaClassSect.s.addr));

        return YES;
    }*/

    return NO;
}

@end
