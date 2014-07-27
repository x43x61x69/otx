/*
    SysUtils.m

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>
#import <Foundation/NSCharacterSet.h>

#import "SystemIncludes.h"  // for UTF8STRING()
#import "SysUtils.h"

@implementation NSObject(SysUtils)

//  checkOtool:
// ----------------------------------------------------------------------------

- (BOOL)checkOtool: (NSString*)filePath
{
    NSString* otoolPath = [self pathForTool: @"otool"];
    NSTask* otoolTask = [[[NSTask alloc] init] autorelease];
    NSPipe* silence = [NSPipe pipe];

    [otoolTask setLaunchPath: otoolPath];
    [otoolTask setStandardInput: [NSPipe pipe]];
    [otoolTask setStandardOutput: silence];
    [otoolTask setStandardError: silence];
    [otoolTask launch];
    [otoolTask waitUntilExit];

    return ([otoolTask terminationStatus] == 1);
}

//  pathForTool:
// ----------------------------------------------------------------------------

- (NSString*)pathForTool: (NSString*)toolName
{
    // Xcode 5+: /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/otool
    
    NSString* relToolBase = [NSString pathWithComponents:
        [NSArray arrayWithObjects: @"/", @"usr", @"bin", nil]];
    NSString* relToolPath = [relToolBase stringByAppendingPathComponent: toolName];
    
    NSString* selectToolPath = [relToolBase stringByAppendingPathComponent: @"xcode-select"];
    NSTask* selectTask = [[[NSTask alloc] init] autorelease];
    NSPipe* selectPipe = [NSPipe pipe];
    NSArray* args = [NSArray arrayWithObject: @"--print-path"];

    [selectTask setLaunchPath: selectToolPath];
    [selectTask setArguments: args];
    [selectTask setStandardInput: [NSPipe pipe]];
    [selectTask setStandardOutput: selectPipe];
    [selectTask launch];
    [selectTask waitUntilExit];

    int selectStatus = [selectTask terminationStatus];

    if (selectStatus == -1)
        return relToolPath;

    NSData* selectData = [[selectPipe fileHandleForReading] availableData];
    NSString* absToolPath = [[[NSString alloc] initWithBytes: [selectData bytes]
                                                      length: [selectData length]
                                                    encoding: NSUTF8StringEncoding] autorelease];
    
    absToolPath = [[[[absToolPath stringByTrimmingCharactersInSet:
                     [NSCharacterSet whitespaceAndNewlineCharacterSet]]
                    stringByAppendingPathComponent: @"Toolchains"]
                   stringByAppendingPathComponent: @"XcodeDefault.xctoolchain"]
                   stringByAppendingPathComponent: relToolPath];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:absToolPath]) {
        return relToolPath;
    }
    
    return absToolPath;
}

@end
