/*
    Optimizations.h

    Definitions of argument lists and selectors for use with getMethodForSelector:
    in ExeXXProcessor.

    This file is in the public domain.
*/

// Shared argument types
#define GetDescriptionArgTypes          (id, SEL, char*, const char*)
#define LineIsCodeArgTypes              (id, SEL, const char*)
#define CodeIsBlockJumpArgTypes         (id, SEL, UInt8*)
#define AddressFromLineArgTypes         (id, SEL, const char*)
#define CommentForSystemCallArgTypes    (id, SEL)

// Selectors
#define GetDescriptionSel               @selector(getDescription:forType:)
#define LineIsCodeSel                   @selector(lineIsCode:)
#define LineIsFunctionSel               @selector(lineIsFunction:)
#define CodeIsBlockJumpSel              @selector(codeIsBlockJump:)
#define AddressFromLineSel              @selector(addressFromLine:)
#define CodeFromLineSel                 @selector(codeFromLine:)
#define CheckThunkSel                   @selector(checkThunk:)
#define ProcessLineSel                  @selector(processLine:)
#define ProcessCodeLineSel              @selector(processCodeLine:)
#define PostProcessCodeLineSel          @selector(postProcessCodeLine:)
#define ChooseLineSel                   @selector(chooseLine:)
#define EntabLineSel                    @selector(entabLine:)
#define GetPointerSel                   @selector(getPointer:type:)
#define CommentForLineSel               @selector(commentForLine:)
#define CommentForSystemCallSel         @selector(commentForSystemCall)
#define CommentForMsgSendFromLineSel    @selector(commentForMsgSend:fromLine:)
#define SelectorForMsgSendSel           @selector(selectorForMsgSend:fromLine:)
#define SendTypeFromMsgSendSel          @selector(sendTypeFromMsgSend:)
#define ResetRegistersSel               @selector(resetRegisters:)
#define UpdateRegistersSel              @selector(updateRegisters:)
#define RestoreRegistersSel             @selector(restoreRegisters:)
#define PrepareNameForDemanglingSel     @selector(prepareNameForDemangling:)
#define GetObjcClassPtrFromMethodSel    @selector(getObjcClassPtr:fromMethod:)
#define GetObjcCatPtrFromMethodSel      @selector(getObjcCatPtr:fromMethod:)
#define GetObjcMethodFromAddressSel     @selector(getObjcMethod:fromAddress:)
#define GetObjcClassFromNameSel         @selector(getObjcClass:fromName:)
#define GetObjcClassPtrFromNameSel      @selector(getObjcClassPtr:fromName:)
#define GetObjcDescriptionFromObjectSel @selector(getObjcDescription:fromObject:type:)
#define GetObjcMetaClassFromClassSel    @selector(getObjcMetaClass:fromClass:)
#define InsertLineBeforeSel             @selector(insertLine:before:inList:)
#define InsertLineAfterSel              @selector(insertLine:after:inList:)
#define ReplaceLineSel                  @selector(replaceLine:withLine:inList:)
#define DeleteLinesBeforeSel            @selector(deleteLinesBefore:fromList:)
#define FindSymbolByAddressSel          @selector(findSymbolByAddress:)
#define FindClassMethodByAddressSel     @selector(findClassMethod:byAddress:)
#define FindCatMethodByAddressSel       @selector(findCatMethod:byAddress:)
#define FindIvarSel                     @selector(findIvar:inClass:withOffset:)
