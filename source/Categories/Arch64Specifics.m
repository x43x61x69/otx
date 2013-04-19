/*
    Arch64Specifics.m

    A category on Exe64Processor that contains most of the
    architecture-specific methods.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "Arch64Specifics.h"

@implementation Exe64Processor(Arch64Specifics)

//  gatherFuncInfos
// ----------------------------------------------------------------------------

- (void)gatherFuncInfos
{}

//  postProcessCodeLine:
// ----------------------------------------------------------------------------

- (void)postProcessCodeLine: (Line64**)ioLine
{}

//  lineIsFunction:
// ----------------------------------------------------------------------------

- (BOOL)lineIsFunction: (Line64*)inLine
{
    return NO;
}

//  codeIsBlockJump:
// ----------------------------------------------------------------------------

- (BOOL)codeIsBlockJump: (UInt8*)inCode
{
    return NO;
}

//  codeFromLine:
// ----------------------------------------------------------------------------

- (void)codeFromLine: (Line64*)inLine
{}

//  checkThunk:
// ----------------------------------------------------------------------------

- (void)checkThunk:(Line64*)inLine
{}

//  getThunkInfo:forLine:
// ----------------------------------------------------------------------------

- (BOOL)getThunkInfo: (ThunkInfo*)outInfo
             forLine: (Line64*)inLine
{
    return NO;
}

#pragma mark -
//  commentForLine:
// ----------------------------------------------------------------------------

- (void)commentForLine: (Line64*)inLine
{}

//  commentForSystemCall
// ----------------------------------------------------------------------------

- (void)commentForSystemCall
{}

//  commentForMsgSend:fromLine:
// ----------------------------------------------------------------------------

- (void)commentForMsgSend: (char*)ioComment
                 fromLine: (Line64*)inLine
{}

#pragma mark -
//  resetRegisters:
// ----------------------------------------------------------------------------

- (void)resetRegisters: (Line64*)inLine
{}

//  updateRegisters:
// ----------------------------------------------------------------------------

- (void)updateRegisters: (Line64*)inLine
{}

//  restoreRegisters:
// ----------------------------------------------------------------------------

- (BOOL)restoreRegisters: (Line64*)ioLine
{
    return NO;
}

@end
