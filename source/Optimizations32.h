/*
    Optimizations32.h

    Definitions of function types for use with getMethodForSelector: in Exe32Processor.

    This file is in the public domain.
*/

#import "Optimizations.h"

// Function types
#define GetDescriptionFuncType                  (void   (*)GetDescriptionArgTypes)
#define LineIsCodeFuncType                      (BOOL   (*)LineIsCodeArgTypes)
#define CodeIsBlockJumpFuncType                 (BOOL   (*)CodeIsBlockJumpArgTypes)
#define AddressFromLineFuncType                 (uint32_t (*)AddressFromLineArgTypes)
#define CommentForSystemCallFuncType            (void   (*)CommentForSystemCallArgTypes)
#define LineIsFunctionFuncType                  (BOOL   (*)(id, SEL, Line*))
#define CodeFromLineFuncType                    (void   (*)(id, SEL, Line*))
#define CheckThunkFuncType                      (void   (*)(id, SEL, Line*))
#define ProcessLineFuncType                     (void   (*)(id, SEL, Line*))
#define ProcessCodeLineFuncType                 (void   (*)(id, SEL, Line**))
#define PostProcessCodeLineFuncType             (void   (*)(id, SEL, Line**))
#define ChooseLineFuncType                      (void   (*)(id, SEL, Line**))
#define EntabLineFuncType                       (void   (*)(id, SEL, Line*))
#define GetPointerFuncType                      (char*  (*)(id, SEL, uint32_t, UInt8*))
#define CommentForLineFuncType                  (void   (*)(id, SEL, Line*))
#define CommentForMsgSendFromLineFuncType       (void   (*)(id, SEL, char*, Line*))
#define SelectorForMsgSendFuncType              (char*  (*)(id, SEL, char*, Line*))
#define SendTypeFromMsgSendFuncType             (UInt8  (*)(id, SEL, char*))
#define ResetRegistersFuncType                  (void   (*)(id, SEL, Line*))
#define UpdateRegistersFuncType                 (void   (*)(id, SEL, Line*))
#define RestoreRegistersFuncType                (BOOL   (*)(id, SEL, Line*))
#define PrepareNameForDemanglingFuncType        (char*  (*)(id, SEL, char*))
#define GetObjcClassPtrFromMethodFuncType       (BOOL   (*)(id, SEL, objc_class**, uint32_t))
#define GetObjcCatPtrFromMethodFuncType         (BOOL   (*)(id, SEL, objc_category**, uint32_t))
#define GetObjcMethodFromAddressFuncType        (BOOL   (*)(id, SEL, MethodInfo**, uint32_t))
#define GetObjcClassFromNameFuncType            (BOOL   (*)(id, SEL, objc_class*, const char*))
#define GetObjcClassPtrFromNameFuncType         (BOOL   (*)(id, SEL, objc_class**, const char*))
#define GetObjcDescriptionFromObjectFuncType    (BOOL   (*)(id, SEL, char**, const char*, UInt8))
#define GetObjcMetaClassFromClassFuncType       (BOOL   (*)(id, SEL, objc_class*, objc_class*))
#define InsertLineBeforeFuncType                (void   (*)(id, SEL, Line*, Line*, Line**))
#define InsertLineAfterFuncType                 (void   (*)(id, SEL, Line*, Line*, Line**))
#define ReplaceLineFuncType                     (void   (*)(id, SEL, Line*, Line*, Line**))
#define DeleteLinesBeforeFuncType               (void   (*)(id, SEL, Line*, Line**))
#define FindSymbolByAddressFuncType             (char*  (*)(id, SEL, uint32_t))
#define FindClassMethodByAddressFuncType        (BOOL   (*)(id, SEL, MethodInfo**, uint32_t))
#define FindCatMethodByAddressFuncType          (BOOL   (*)(id, SEL, MethodInfo**, uint32_t))
#define FindIvarFuncType                        (BOOL   (*)(id, SEL, objc_ivar*, objc_class*, uint32_t))

// These are not really necessary, but all that "self" crap gets old.
#define GetDescription(a, b)                                                    \
        GetDescription(self, GetDescriptionSel, (a), (b))
#define LineIsCode(a)                                                           \
        LineIsCode(self, LineIsCodeSel, (a))
#define LineIsFunction(a)                                                       \
        LineIsFunction(self, LineIsFunctionSel, (a))
#define CodeIsBlockJump(a)                                                      \
        CodeIsBlockJump(self, CodeIsBlockJumpSel, (a))
#define AddressFromLine(a)                                                      \
        AddressFromLine(self, AddressFromLineSel, (a))
#define CodeFromLine(a)                                                         \
        CodeFromLine(self, CodeFromLineSel, (a))
#define CheckThunk(a)                                                           \
        CheckThunk(self, CheckThunkSel, (a))
#define ProcessLine(a)                                                          \
        ProcessLine(self, ProcessLineSel, (a))
#define ProcessCodeLine(a)                                                      \
        ProcessCodeLine(self, ProcessCodeLineSel, (a))
#define PostProcessCodeLine(a)                                                  \
        PostProcessCodeLine(self, PostProcessCodeLineSel, (a))
#define ChooseLine(a)                                                           \
        ChooseLine(self, ChooseLineSel, (a))
#define EntabLine(a)                                                            \
        EntabLine(self, EntabLineSel, (a))
#define GetPointer(a, b)                                                        \
        GetPointer(self, GetPointerSel, (a), (b))
#define CommentForLine(a)                                                       \
        CommentForLine(self, CommentForLineSel, (a))
#define CommentForSystemCall()                                                  \
        CommentForSystemCall(self, CommentForSystemCallSel)
#define CommentForMsgSendFromLine(a, b)                                         \
        CommentForMsgSendFromLine(self, CommentForMsgSendFromLineSel, (a), (b))
#define SelectorForMsgSend(a, b)                                                \
        SelectorForMsgSend(self, SelectorForMsgSendSel, (a), (b))
#define SendTypeFromMsgSend(a)                                                  \
        SendTypeFromMsgSend(self, SendTypeFromMsgSendSel, (a))
#define ResetRegisters(a)                                                       \
        ResetRegisters(self, ResetRegistersSel, (a))
#define UpdateRegisters(a)                                                      \
        UpdateRegisters(self, UpdateRegistersSel, (a))
#define RestoreRegisters(a)                                                     \
        RestoreRegisters(self, RestoreRegistersSel, (a))
#define PrepareNameForDemangling(a)                                             \
        PrepareNameForDemangling(self, PrepareNameForDemanglingSel, (a))
#define GetObjcClassPtrFromMethod(a, b)                                         \
        GetObjcClassPtrFromMethod(self, GetObjcClassPtrFromMethodSel, (a), (b))
#define GetObjcCatPtrFromMethod(a, b)                                           \
        GetObjcCatPtrFromMethod(self, GetObjcCatPtrFromMethodSel, (a), (b))
#define GetObjcMethodFromAddress(a, b)                                          \
        GetObjcMethodFromAddress(self, GetObjcMethodFromAddressSel, (a), (b))
#define GetObjcClassFromName(a, b)                                              \
        GetObjcClassFromName(self, GetObjcClassFromNameSel, (a), (b))
#define GetObjcClassPtrFromName(a, b)                                           \
        GetObjcClassPtrFromName(self, GetObjcClassPtrFromNameSel, (a), (b))
#define GetObjcDescriptionFromObject(a, b, c)                                   \
        GetObjcDescriptionFromObject(self, GetObjcDescriptionFromObjectSel, (a), (b), (c))
#define GetObjcMetaClassFromClass(a, b)                                         \
        GetObjcMetaClassFromClass(self, GetObjcMetaClassFromClassSel, (a), (b))
#define InsertLineBefore(a, b, c)                                               \
        InsertLineBefore(self, InsertLineBeforeSel, (a), (b), (c))
#define InsertLineAfter(a, b, c)                                                \
        InsertLineAfter(self, InsertLineAfterSel, (a), (b), (c))
#define ReplaceLine(a, b, c)                                                    \
        ReplaceLine(self, ReplaceLineSel, (a), (b), (c))
#define DeleteLinesBefore(a, b)                                                 \
        DeleteLinesBefore(self, DeleteLinesBeforeSel, (a), (b))
#define FindSymbolByAddress(a)                                                  \
        FindSymbolByAddress(self, FindSymbolByAddressSel, (a))
#define FindClassMethodByAddress(a, b)                                          \
        FindClassMethodByAddress(self, FindClassMethodByAddressSel, (a), (b))
#define FindCatMethodByAddress(a, b)                                            \
        FindCatMethodByAddress(self, FindCatMethodByAddressSel, (a), (b))
#define FindIvar(a, b, c)                                                       \
        FindIvar(self, FindIvarSel, (a), (b), (c))
