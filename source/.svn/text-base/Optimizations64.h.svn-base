/*
    Optimizations64.h

    Definitions of function types for use with getMethodForSelector: in Exe64Processor.

    This file is in the public domain.
*/

#import "Optimizations.h"

// Function types
#define GetDescription64FuncType                (void   (*)GetDescriptionArgTypes)
#define LineIsCode64FuncType                    (BOOL   (*)LineIsCodeArgTypes)
#define CodeIsBlockJump64FuncType               (BOOL   (*)CodeIsBlockJumpArgTypes)
#define AddressFromLine64FuncType               (UInt64 (*)AddressFromLineArgTypes)
#define CommentForSystemCall64FuncType          (void   (*)CommentForSystemCallArgTypes)
#define LineIsFunction64FuncType                (BOOL   (*)(id, SEL, Line64*))
#define CodeFromLine64FuncType                  (void   (*)(id, SEL, Line64*))
#define CheckThunk64FuncType                    (void   (*)(id, SEL, Line64*))
#define ProcessLine64FuncType                   (void   (*)(id, SEL, Line64*))
#define ProcessCodeLine64FuncType               (void   (*)(id, SEL, Line64**))
#define PostProcessCodeLine64FuncType           (void   (*)(id, SEL, Line64**))
#define ChooseLine64FuncType                    (void   (*)(id, SEL, Line64**))
#define EntabLine64FuncType                     (void   (*)(id, SEL, Line64*))
#define GetPointer64FuncType                    (char*  (*)(id, SEL, UInt64, UInt8*))
#define CommentForLine64FuncType                (void   (*)(id, SEL, Line64*))
#define CommentForMsgSendFromLine64FuncType     (void   (*)(id, SEL, char*, Line64*))
#define SelectorForMsgSend64FuncType            (char*  (*)(id, SEL, char*, Line64*))
#define SendTypeFromMsgSend64FuncType           (UInt8  (*)(id, SEL, char*))
#define ResetRegisters64FuncType                (void   (*)(id, SEL, Line64*))
#define UpdateRegisters64FuncType               (void   (*)(id, SEL, Line64*))
#define RestoreRegisters64FuncType              (BOOL   (*)(id, SEL, Line64*))
#define PrepareNameForDemangling64FuncType      (char*  (*)(id, SEL, char*))
#define GetObjcClassPtrFromMethod64FuncType     (BOOL   (*)(id, SEL, objc2_class_t**, UInt64))
#define GetObjcCatPtrFromMethod64FuncType       (BOOL   (*)(id, SEL, objc_category**, UInt64))
#define GetObjcMethodFromAddress64FuncType      (BOOL   (*)(id, SEL, Method64Info**, UInt64))
#define GetObjcClassFromName64FuncType          (BOOL   (*)(id, SEL, objc2_class_t*, const char*))
#define GetObjcClassPtrFromName64FuncType       (BOOL   (*)(id, SEL, objc2_class_t**, const char*))
#define GetObjcDescriptionFromObject64FuncType  (BOOL   (*)(id, SEL, char**, const char*, UInt8))
#define GetObjcMetaClassFromClass64FuncType     (BOOL   (*)(id, SEL, objc2_class_t*, objc2_class_t*))
#define InsertLineBefore64FuncType              (void   (*)(id, SEL, Line64*, Line64*, Line64**))
#define InsertLineAfter64FuncType               (void   (*)(id, SEL, Line64*, Line64*, Line64**))
#define ReplaceLine64FuncType                   (void   (*)(id, SEL, Line64*, Line64*, Line64**))
#define DeleteLinesBefore64FuncType             (void   (*)(id, SEL, Line64*, Line64**))
#define FindSymbolByAddress64FuncType           (char*  (*)(id, SEL, UInt64))
#define FindClassMethodByAddress64FuncType      (BOOL   (*)(id, SEL, Method64Info**, UInt64))
#define FindCatMethodByAddress64FuncType        (BOOL   (*)(id, SEL, Method64Info**, UInt64))
#define FindIvar64FuncType                      (BOOL   (*)(id, SEL, objc2_ivar_t**, objc2_class_t*, UInt64))

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
