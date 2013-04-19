/*
    Arch64Specifics.h

    A category on Exe64Processor that contains most of the
    architecture-specific methods.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "Exe64Processor.h"

@interface Exe64Processor(Arch64Specifics)

- (void)gatherFuncInfos;
- (void)postProcessCodeLine: (Line64**)ioLine;
- (BOOL)lineIsFunction: (Line64*)inLine;
- (BOOL)codeIsBlockJump: (UInt8*)inCode;
- (void)codeFromLine: (Line64*)inLine;
- (void)checkThunk: (Line64*)inLine;
- (BOOL)getThunkInfo: (ThunkInfo*)outInfo
             forLine: (Line64*)inLine;

- (void)commentForLine: (Line64*)inLine;
- (void)commentForSystemCall;
- (void)commentForMsgSend: (char*)ioComment
                 fromLine: (Line64*)inLine;

- (void)resetRegisters: (Line64*)inLine;
- (void)updateRegisters: (Line64*)inLine;
- (BOOL)restoreRegisters: (Line64*)inLine;

@end
