/*
    ObjectLoader.h

    A category on Exe32Processor that contains all the loadXXX methods.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "Exe32Processor.h"

@interface Exe32Processor(ObjectLoader)

- (BOOL)loadMachHeader;
- (void)loadLCommands;
- (void)loadSegment: (segment_command*)inSegPtr;
- (void)loadSymbols: (symtab_command*)inSymPtr;
- (void)loadObjcSection: (section*)inSect;
- (void)loadObjcModules;
- (void)loadObjcClassList;
- (void)loadCStringSection: (section*)inSect;
- (void)loadNSStringSection: (section*)inSect;
- (void)loadClassSection: (section*)inSect;
- (void)loadMetaClassSection: (section*)inSect;
- (void)loadIVarSection: (section*)inSect;
- (void)loadObjcModSection: (section*)inSect;
- (void)loadObjcSymSection: (section*)inSect;
- (void)loadObjcMethnameSection: (section*)inSect;
- (void)loadObjcMethtypeSection: (section*)inSect;
- (void)loadObjcClassnameSection: (section*)inSect;
- (void)loadLit4Section: (section*)inSect;
- (void)loadLit8Section: (section*)inSect;
- (void)loadTextSection: (section*)inSect;
- (void)loadCoalTextSection: (section*)inSect;
- (void)loadCoalTextNTSection: (section*)inSect;
- (void)loadConstTextSection: (section*)inSect;
- (void)loadDataSection: (section*)inSect;
- (void)loadCoalDataSection: (section*)inSect;
- (void)loadCoalDataNTSection: (section*)inSect;
- (void)loadConstDataSection: (section*)inSect;
- (void)loadDyldDataSection: (section*)inSect;
- (void)loadCFStringSection: (section*)inSect;
- (void)loadNonLazySymbolSection: (section*)inSect;
- (void)loadObjcClassListSection: (section*)inSect;
- (void)loadObjcCatListSection: (section*)inSect;
- (void)loadObjcConstSection: (section*)inSect;
- (void)loadObjcProtoListSection: (section*)inSect;
- (void)loadObjcSuperRefsSection: (section*)inSect;
- (void)loadObjcClassRefsSection: (section*)inSect;
- (void)loadObjcProtoRefsSection: (section*)inSect;
- (void)loadObjcMsgRefsSection: (section*)inSect;
- (void)loadObjcSelRefsSection: (section*)inSect;
- (void)loadObjcDataSection: (section*)inSect;
- (void)loadImpPtrSection: (section*)inSect;

@end
