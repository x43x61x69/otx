/*
    ArchSpecifics.m

    A category on Exe32Processor that contains most of the
    architecture-specific methods.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "ArchSpecifics.h"

@implementation Exe32Processor(ArchSpecifics)

//  gatherFuncInfos
// ----------------------------------------------------------------------------

- (void)gatherFuncInfos
{}

//  postProcessCodeLine:
// ----------------------------------------------------------------------------

- (void)postProcessCodeLine: (Line**)ioLine
{}

//  lineIsFunction:
// ----------------------------------------------------------------------------

- (BOOL)lineIsFunction: (Line*)inLine
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

- (void)codeFromLine: (Line*)inLine
{}

//  checkThunk:
// ----------------------------------------------------------------------------

- (void)checkThunk:(Line*)inLine
{}

//  getThunkInfo:forLine:
// ----------------------------------------------------------------------------

- (BOOL)getThunkInfo: (ThunkInfo*)outInfo
             forLine: (Line*)inLine
{
    return NO;
}

#pragma mark -
//  commentForLine:
// ----------------------------------------------------------------------------

- (void)commentForLine: (Line*)inLine
{}

//  commentForSystemCall
// ----------------------------------------------------------------------------

- (void)commentForSystemCall
{}

//  commentForMsgSend:fromLine:
// ----------------------------------------------------------------------------

- (void)commentForMsgSend: (char*)ioComment
                 fromLine: (Line*)inLine
{}

#pragma mark -
//  resetRegisters:
// ----------------------------------------------------------------------------

- (void)resetRegisters: (Line*)inLine
{}

//  updateRegisters:
// ----------------------------------------------------------------------------

- (void)updateRegisters: (Line*)inLine
{}

//  restoreRegisters:
// ----------------------------------------------------------------------------

- (BOOL)restoreRegisters: (Line*)ioLine
{
    return NO;
}

@end
