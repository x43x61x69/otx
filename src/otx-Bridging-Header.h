/*
    otx-Bridging-Header.h

    Exposes Objective-C processor code to Swift.
    Requires HEADER_SEARCH_PATHS to include $(SRCROOT)/src/source.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>
#import <mach/mach_host.h>

#import "Globals.h"

// SystemIncludes.h must come first – it defines struct-alias macros.
#import "SystemIncludes.h"
#import "SharedDefs.h"
#import "ObjcTypes.h"
#import "StolenDefs.h"

// Protocols
#import "ErrorReporter.h"
#import "ProgressReporter.h"
#import "Deobfuscator.h"

// Categories
#import "SysUtils.h"

// Processors
#import "ExeProcessor.h"
#import "Exe64Processor.h"
#import "X8664Processor.h"
#import "ARM64Processor.h"
