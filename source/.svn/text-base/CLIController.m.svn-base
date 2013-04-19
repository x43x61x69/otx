/*
    CLIController.m

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>
#import <mach/mach_host.h>

#import "SystemIncludes.h"

#import "CLIController.h"
#import "PPCProcessor.h"
#import "PPC64Processor.h"
#import "SysUtils.h"
#import "X86Processor.h"
#import "X8664Processor.h"

@implementation CLIController

//  init
// ----------------------------------------------------------------------------

- (id)init
{
    self = [super init];
    return self;
}

//  initWithArgs:count:
// ----------------------------------------------------------------------------

- (id)initWithArgs: (char**)argv
             count: (SInt32)argc
{
    if (argc < 2)
    {
        [self usage];
        return nil;
    }

    if (!(self = [super init]))
        return nil;

    // Set iArchSelector to the host architecture by default. This code was
    // lifted from http://developer.apple.com/technotes/tn/tn2086.html
    host_basic_info_data_t  hostInfo    = {0};
    mach_msg_type_number_t  infoCount   = HOST_BASIC_INFO_COUNT;

    host_info(mach_host_self(), HOST_BASIC_INFO,
        (host_info_t)&hostInfo, &infoCount);

    iArchSelector   = hostInfo.cpu_type;

    if (iArchSelector != CPU_TYPE_POWERPC   &&
        iArchSelector != CPU_TYPE_I386)
    {   // We're running on a machine that doesn't exist.
        fprintf(stderr, "otx: I shouldn't be here...\n");
        [self release];
        return nil;
    }

    // Assign default options.
    iOpts   = (ProcOptions){
        SHOW_LOCAL_OFFSETS,
        DONT_ENTAB_OUTPUT,
        DONT_SHOW_DATA_SECTIONS,
        SHOW_CHECKSUM,
        SHOW_VERBOSE_MSGSENDS,
        DONT_SEPARATE_LOGICAL_BLOCKS,
        DEMANGLE_CPP_NAMES,
        SHOW_METHOD_RETURN_TYPES,
        SHOW_VARIABLE_TYPES,
        SHOW_RETURN_STATEMENTS
    };

    // Parse options.
    NSString*   origFilePath    = nil;
    uint32_t      i, j;

    for (i = 1; i < argc; i++)
    {
        if (argv[i][0] == '-')
        {
            if (argv[i][1] == '\0') // just '-'
            {
                [self usage];
                [self release];
                return nil;
            }

            if (!strncmp(&argv[i][1], "arch", 5))
            {
                char*   archString  = argv[++i];

                if (!strncmp(archString, "ppc", 4))
                    iArchSelector   = CPU_TYPE_POWERPC;
                else if (!strncmp(archString, "ppc64", 6))
                    iArchSelector   = CPU_TYPE_POWERPC64;
                else if (!strncmp(archString, "i386", 5) ||
                         !strncmp(archString, "x86", 4))
                    iArchSelector   = CPU_TYPE_I386;
                else if (!strncmp(archString, "x86_64", 7))
                    iArchSelector   = CPU_TYPE_X86_64;
                else
                {
                    fprintf(stderr, "otx: unknown architecture: \"%s\"\n",
                        argv[i]);
                    [self usage];
                    [self release];
                    return nil;
                }
            }
            else
            {
                for (j = 1; argv[i][j] != '\0'; j++)
                {
                    switch (argv[i][j])
                    {
                        case 'l':
                            iOpts.localOffsets = !SHOW_LOCAL_OFFSETS;
                            break;
                        case 'e':
                            iOpts.entabOutput = !DONT_ENTAB_OUTPUT;
                            break;
                        case 'd':
                            iOpts.dataSections = !DONT_SHOW_DATA_SECTIONS;
                            break;
                        case 'c':
                            iOpts.checksum = !SHOW_CHECKSUM;
                            break;
                        case 'm':
                            iOpts.verboseMsgSends = !SHOW_VERBOSE_MSGSENDS;
                            break;
                        case 'b':
                            iOpts.separateLogicalBlocks = !DONT_SEPARATE_LOGICAL_BLOCKS;
                            break;
                        case 'n':
                            iOpts.demangleCppNames = !DEMANGLE_CPP_NAMES;
                            break;
                        case 'r':
                            iOpts.returnTypes = !SHOW_METHOD_RETURN_TYPES;
                            break;
                        case 'R':
                            iOpts.returnStatements = !SHOW_RETURN_STATEMENTS;
                            break;
                        case 'v':
                            iOpts.variableTypes = !SHOW_VARIABLE_TYPES;
                            break;
                        case 'p':
                            iShowProgress = YES;
                            break;
                        case 'o':
                            iVerify = YES;
                            break;

                        default:
                            fprintf(stderr, "otx: unknown argument: '%c'\n",
                                argv[i][j]);
                            [self usage];
                            [self release];
                            return nil;
                    }   // switch (argv[i][j])
                }   // for (j = 1; argv[i][j] != '\0'; j++)
            }
        }
        else    // not a flag, must be the file path
        {
            origFilePath    = [NSString stringWithCString: &argv[i][0]
                encoding: NSMacOSRomanStringEncoding];
        }
    }

    if (!origFilePath)
    {
        fprintf(stderr, "You must specify an executable file to process.\n");
        [self release];
        return nil;
    }

    NSFileManager*  fileMan = [NSFileManager defaultManager];

    // Check that the file exists.
    if (![fileMan fileExistsAtPath: origFilePath])
    {
        fprintf(stderr, "otx: No file found at %s.\n", UTF8STRING(origFilePath));
        [self release];
        return nil;
    }

    // Check that the file is an executable.
    if ([[NSWorkspace sharedWorkspace] isFilePackageAtPath: origFilePath])
        [self newPackageFile: [NSURL fileURLWithPath: origFilePath]];
    else
        [self newOFile: [NSURL fileURLWithPath: origFilePath] needsPath: YES];

    // Sanity check
    if (!iOFile)
    {
        fprintf(stderr, "otx: Invalid file.\n");
        [self release];
        return nil;
    }

    // Check that the executable is a Mach-O file.
    NSFileHandle*   theFileH    =
        [NSFileHandle fileHandleForReadingAtPath: [iOFile path]];

    if (!theFileH)
    {
        fprintf(stderr, "otx: Unable to open %s.\n",
            UTF8STRING([origFilePath lastPathComponent]));
        [self release];
        return nil;
    }

    NSData* fileData;

    @try
    {
        fileData    = [theFileH readDataOfLength: sizeof(iFileArchMagic)];
    }
    @catch (NSException* e)
    {
        fprintf(stderr, "otx: Unable to read from %s. %s\n",
            UTF8STRING([origFilePath lastPathComponent]),
            UTF8STRING([e reason]));
        [self release];
        return nil;
    }

    if ([fileData length] < sizeof(iFileArchMagic))
    {
        fprintf(stderr, "otx: Truncated executable file.\n");
        [self release];
        return nil;
    }

    // Override the -arch flag if necessary.
    switch (*(uint32_t*)[fileData bytes])
    {
        case MH_MAGIC:
#if TARGET_RT_LITTLE_ENDIAN
            iArchSelector   = CPU_TYPE_I386;
#else
            iArchSelector   = CPU_TYPE_POWERPC;
#endif
            break;

        case MH_MAGIC_64:
#if TARGET_RT_LITTLE_ENDIAN
            iArchSelector   = CPU_TYPE_X86_64;
#else
            iArchSelector   = CPU_TYPE_POWERPC64;
#endif
            break;

        case MH_CIGAM:
#if TARGET_RT_LITTLE_ENDIAN
            iArchSelector   = CPU_TYPE_POWERPC;
#else
            iArchSelector   = CPU_TYPE_I386;
#endif
            break;

        case MH_CIGAM_64:
#if TARGET_RT_LITTLE_ENDIAN
            iArchSelector   = CPU_TYPE_POWERPC64;
#else
            iArchSelector   = CPU_TYPE_X86_64;
#endif
            break;

        case FAT_MAGIC:
        case FAT_CIGAM:
            break;

        default:
            fprintf(stderr, "otx: %s is not a Mach-O file.\n",
                UTF8STRING([origFilePath lastPathComponent]));
            [self release];
            return nil;
    }

    return self;
}

//  usage
// ----------------------------------------------------------------------------

- (void)usage
{
    fprintf(stderr,
        "Usage: otx [-bcdelmnoprv] [-arch <arch type>] <object file>\n"
        "\t-b             separate logical blocks\n"
        "\t-c             don't show md5 checksum\n"
        "\t-d             show data sections\n"
        "\t-e             don't entab output\n"
        "\t-l             don't show local offsets\n"
        "\t-m             don't show verbose objc_msgSend\n"
        "\t-n             don't demangle C++ symbol names\n"
        "\t-o             only check the executable for obfuscation\n"
        "\t-p             display progress\n"
        "\t-r             don't show Obj-C method return types\n"
        "\t-v             don't show Obj-C member variable types\n"
        "\t-arch archVal  specify a single architecture in a universal binary\n"
        "\t               if not specified, the host architecture is used\n"
        "\t               allowed values: ppc, ppc64, i386, x86_64\n"
    );
}

//  dealloc
// ----------------------------------------------------------------------------

- (void)dealloc
{
    if (iOFile)
        [iOFile release];

    if (iExeName)
        [iExeName release];

    [super dealloc];
}

#pragma mark -
//  newPackageFile:
// ----------------------------------------------------------------------------
//  Attempt to drill into the package to the executable. Fails when the exe is
//  unreadable.

- (void)newPackageFile: (NSURL*)inPackageFile
{
    NSString*   origPath    = [inPackageFile path];
    NSBundle*   exeBundle   = [NSBundle bundleWithPath: origPath];

    if (!exeBundle)
    {
        fprintf(stderr, "otx: [CLIController newPackageFile:] "
            "unable to get bundle from path: %s\n", UTF8STRING(origPath));
        return;
    }

    NSString*   exePath = [exeBundle executablePath];

    if (!exePath)
    {
        fprintf(stderr, "otx: [CLIController newPackageFile:] "
            "unable to get executable path from bundle: %s\n",
            UTF8STRING(origPath));
        return;
    }

    [self newOFile: [NSURL fileURLWithPath: exePath] needsPath: NO];
}

//  newOFile:
// ----------------------------------------------------------------------------

- (void)newOFile: (NSURL*)inOFile
       needsPath: (BOOL)inNeedsPath
{
    if (iOFile)
        [iOFile release];

    if (iExeName)
        [iExeName release];

    iOFile  = inOFile;
    [iOFile retain];

    iExeName    = [[inOFile path] lastPathComponent];
    [iExeName retain];
}

#pragma mark -
//  processFile
// ----------------------------------------------------------------------------

- (void)processFile
{
    if (!iOFile)
    {
        fprintf(stderr, "otx: [CLIController processFile]: "
            "tried to process nil object file.\n");
        return;
    }

    if (iVerify)
    {
        [self verifyNops];
        return;
    }

    if ([self checkOtool: [iOFile path]] == NO)
    {
        fprintf(stderr,
            "otx: otool was not found. Please install otool and try again.\n");
        return;
    }

    Class   procClass   = nil;

    switch (iArchSelector)
    {
        case CPU_TYPE_POWERPC:
            procClass   = [PPCProcessor class];
            break;

        case CPU_TYPE_I386:
            procClass   = [X86Processor class];
            break;

        case CPU_TYPE_POWERPC64:
            procClass   = [PPC64Processor class];
            break;

        case CPU_TYPE_X86_64:
            procClass   = [X8664Processor class];
            break;

        default:
            fprintf(stderr, "otx: [CLIController processFile]: "
                "unknown arch type: %d\n", iArchSelector);
            break;
    }

    if (!procClass)
        return;

    id  theProcessor    =
        [[procClass alloc] initWithURL: iOFile controller: self
        options: &iOpts];

    if (!theProcessor)
    {
        fprintf(stderr, "otx: -[CLIController processFile]: "
            "unable to create processor.\n");
        return;
    }

    NSDictionary*   progDict    = [[NSDictionary alloc] initWithObjectsAndKeys:
        [NSNumber numberWithBool: YES], PRIndeterminateKey,
        @"Loading executable", PRDescriptionKey,
        nil];

    [self reportProgress: progDict];
    [progDict release];

    if (![theProcessor processExe: nil])
    {
        fprintf(stderr, "otx: -[CLIController processFile]: "
            "possible permission error\n");
        [theProcessor release];
        return;
    }

    [theProcessor release];
}

//  verifyNops
// ----------------------------------------------------------------------------
//  Create an instance of xxxProcessor to search for obfuscated nops. If any
//  are found, let user decide to fix them or not.

- (void)verifyNops
{
    Class procClass = nil;

    if (iArchSelector == CPU_TYPE_I386)
        procClass = [X86Processor class];
    else if (iArchSelector == CPU_TYPE_X86_64)
        procClass = [X8664Processor class];

    switch (iArchSelector)
    {
        case CPU_TYPE_I386:
        case CPU_TYPE_X86_64:
        {
            ProcOptions opts = {0};
            id theProcessor = [[procClass alloc] initWithURL: iOFile
                                                  controller: self
                                                     options: &opts];

            if (!theProcessor)
            {
                fprintf(stderr, "otx: -[CLIController verifyNops]: "
                    "unable to create processor.\n");
                return;
            }

            unsigned char** foundList   = NULL;
            uint32_t foundCount  = 0;

            if ([theProcessor verifyNops: &foundList
                numFound: &foundCount])
            {
                printf("otx found %d broken nop's. Would you like to save "
                    "a copy of the executable with fixed nop's? (y/n)\n",
                    foundCount);

                char    response;

                scanf("%c", &response);

                if (response == 'y' || response == 'Y')
                {
                    NopList*    theNops = malloc(sizeof(NopList));

                    theNops->list   = foundList;
                    theNops->count  = foundCount;

                    NSURL*  fixedFile   = [theProcessor fixNops: theNops
                        toPath: [[iOFile path]
                        stringByAppendingString: @"_fixed"]];

                    free(theNops->list);
                    free(theNops);

                    if (!fixedFile)
                        fprintf(stderr, "otx: unable to fix nops\n");
                }
            }
            else
                printf("The executable is healthy.\n");

            [theProcessor release];

            break;
        }

        default:
            printf("Deobfuscation is only available for x86 binaries.\n");
            break;
    }
}

#pragma mark -
#pragma mark ErrorReporter protocol
//  reportError:suggestion:
// ----------------------------------------------------------------------------

- (void)reportError: (NSString*)inMessageText
         suggestion: (NSString*)inInformativeText
{
    fprintf(stderr, "otx: %s\n     %s\n",
        UTF8STRING(inMessageText), UTF8STRING(inInformativeText));
}

#pragma mark -
#pragma mark ProgressReporter protocol
//  reportProgress:
// ----------------------------------------------------------------------------

- (void)reportProgress: (NSDictionary*)inDict
{
    if (!iShowProgress)
        return;

    if (!inDict)
    {
        fprintf(stderr, "otx: [CLIController reportProgress:] nil inDict\n");
        return;
    }

    NSString*   description = [inDict objectForKey: PRDescriptionKey];
    NSNumber*   newLine     = [inDict objectForKey: PRNewLineKey];
    NSNumber*   value       = [inDict objectForKey: PRValueKey];
    NSNumber*   complete    = [inDict objectForKey: PRCompleteKey];

    if (newLine && [newLine boolValue])
        fprintf(stderr, "\n");

    if (description)
        fprintf(stderr, "%s", UTF8STRING(description));

    if (value)
        fprintf(stderr, ".");

    if (complete && [complete boolValue])
        fprintf(stderr, "\n");
}

@end
