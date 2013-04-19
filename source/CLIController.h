/*
    CLIController.h

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "SharedDefs.h"
#import "ErrorReporter.h"
#import "ProgressReporter.h"

// Default ProcOptions values
#define SHOW_LOCAL_OFFSETS              YES
#define DONT_ENTAB_OUTPUT               NO
#define DONT_SHOW_DATA_SECTIONS         NO
#define SHOW_CHECKSUM                   YES
#define SHOW_VERBOSE_MSGSENDS           YES
#define DONT_SEPARATE_LOGICAL_BLOCKS    NO
#define DEMANGLE_CPP_NAMES              YES
#define SHOW_METHOD_RETURN_TYPES        YES
#define SHOW_VARIABLE_TYPES             YES
#define SHOW_RETURN_STATEMENTS          YES

// ============================================================================

@interface CLIController : NSObject<ProgressReporter, ErrorReporter>
{
@private
    NSURL*              iOFile;
    cpu_type_t          iArchSelector;
    uint32_t              iFileArchMagic;
    NSString*           iExeName;
    BOOL                iVerify;
    BOOL                iShowProgress;
    ProcOptions         iOpts;
}

- (id)initWithArgs: (char**)argv
             count: (SInt32)argc;
- (void)usage;
- (void)processFile;
- (void)verifyNops;
- (void)newPackageFile: (NSURL*)inPackageFile;
- (void)newOFile: (NSURL*)inOFile
       needsPath: (BOOL)inNeedsPath;

@end
