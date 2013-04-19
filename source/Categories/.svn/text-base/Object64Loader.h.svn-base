/*
    Object64Loader.h

    A category on Exe64Processor that contains all the loadXXX methods.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "Exe64Processor.h"

@interface Exe64Processor(Object64Loader)

- (BOOL)loadMachHeader;
- (void)loadLCommands;
- (void)loadObjcClassList;
- (void)loadSegment: (segment_command_64*)inSegPtr;
- (void)loadSymbols: (symtab_command*)inSymPtr;
- (void)loadCStringSection: (section_64*)inSect;
- (void)loadNSStringSection: (section_64*)inSect;
- (void)loadLit4Section: (section_64*)inSect;
- (void)loadLit8Section: (section_64*)inSect;
- (void)loadTextSection: (section_64*)inSect;
- (void)loadCoalTextSection: (section_64*)inSect;
- (void)loadCoalTextNTSection: (section_64*)inSect;
- (void)loadConstTextSection: (section_64*)inSect;
- (void)loadObjcMethnameSection: (section_64*)inSect;
- (void)loadObjcClassnameSection: (section_64*)inSect;
- (void)loadDataSection: (section_64*)inSect;
- (void)loadCoalDataSection: (section_64*)inSect;
- (void)loadCoalDataNTSection: (section_64*)inSect;
- (void)loadConstDataSection: (section_64*)inSect;
- (void)loadDyldDataSection: (section_64*)inSect;
- (void)loadCFStringSection: (section_64*)inSect;
- (void)loadNonLazySymbolSection: (section_64*)inSect;
- (void)loadImpPtrSection: (section_64*)inSect;
- (void)loadObjcClassListSection: (section_64*)inSect;
- (void)loadObjcCatListSection: (section_64*)inSect;
- (void)loadObjcProtoListSection: (section_64*)inSect;
- (void)loadObjcSuperRefsSection: (section_64*)inSect;
- (void)loadObjcClassRefsSection: (section_64*)inSect;
- (void)loadObjcProtoRefsSection: (section_64*)inSect;
- (void)loadObjcMsgRefsSection: (section_64*)inSect;
- (void)loadObjcSelRefsSection: (section_64*)inSect;

@end
