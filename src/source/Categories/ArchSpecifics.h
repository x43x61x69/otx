/*
    ArchSpecifics.h

    A category on Exe32Processor that contains most of the
    architecture-specific methods.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "Exe32Processor.h"

@interface Exe32Processor(ArchSpecifics)

- (void)gatherFuncInfos;
- (void)postProcessCodeLine: (Line**)ioLine;
- (BOOL)lineIsFunction: (Line*)inLine;
- (BOOL)codeIsBlockJump: (UInt8*)inCode;
- (void)codeFromLine: (Line*)inLine;
- (void)checkThunk: (Line*)inLine;
- (BOOL)getThunkInfo: (ThunkInfo*)outInfo
             forLine: (Line*)inLine;

- (void)commentForLine: (Line*)inLine;
- (void)commentForSystemCall;
- (void)commentForMsgSend: (char*)ioComment
                 fromLine: (Line*)inLine;

- (void)resetRegisters: (Line*)inLine;
- (void)updateRegisters: (Line*)inLine;
- (BOOL)restoreRegisters: (Line*)inLine;

@end
