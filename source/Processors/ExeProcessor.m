/*
    ExeProcessor.m

    This file relies upon, and steals code from, the cctools source code
    available from: http://www.opensource.apple.com/darwinsource/

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "ExeProcessor.h"
#import "ArchSpecifics.h"
#import "ListUtils.h"
#import "ObjcAccessors.h"
#import "ObjectLoader.h"
#import "Optimizations.h"
#import "SysUtils.h"
#import "UserDefaultKeys.h"

@implementation ExeProcessor

// ExeProcessor is a base class that handles processor-independent issues.
// PPCProcessor and X86Processor are subclasses that add functionality
// specific to those CPUs. The AppController class creates a new instance of
// one of those subclasses for each processing, and deletes the instance as
// soon as possible. Member variables may or may not be re-initialized before
// destruction. Do not reuse a single instance of those subclasses for
// multiple processings.

//  initWithURL:controller:options:
// ----------------------------------------------------------------------------

- (id)initWithURL: (NSURL*)inURL
       controller: (id)inController
          options: (ProcOptions*)inOptions
{
    if (!inURL || !inController || !inOptions)
        return nil;

    if ((self = [super init]) == nil)
        return nil;

    iOFile                  = inURL;
    iController             = inController;
    iOpts                   = *inOptions;
    iCurrentFuncInfoIndex   = -1;

    // Load exe into RAM.
    NSError*    theError    = nil;
    NSData*     theData     = [NSData dataWithContentsOfURL: iOFile
        options: 0 error: &theError];

    if (!theData)
    {
        fprintf(stderr, "otx: error loading executable from disk: %s\n",
            UTF8STRING([theError localizedFailureReason]));
        [self release];
        return nil;
    }

    iRAMFileSize    = [theData length];

    if (iRAMFileSize < sizeof(iFileArchMagic))
    {
        fprintf(stderr, "otx: truncated executable file\n");
        [self release];
        return nil;
    }

    iRAMFile    = malloc(iRAMFileSize);

    if (!iRAMFile)
    {
        fprintf(stderr, "otx: not enough memory to allocate mRAMFile\n");
        [self release];
        return nil;
    }

    [theData getBytes: iRAMFile];

    iFileArchMagic  = *(uint32_t*)iRAMFile;
    iExeIsFat   = (iFileArchMagic == FAT_MAGIC || iFileArchMagic == FAT_CIGAM);

    // Setup the C++ name demangler.
    if (iOpts.demangleCppNames)
    {
        NSArray* args = [NSArray arrayWithObjects: @"-_", nil];

        iCPFiltTask = [[NSTask alloc] init];
        iCPFiltInputPipe = [[NSPipe alloc] init];
        iCPFiltOutputPipe = [[NSPipe alloc] init];

        [iCPFiltTask setLaunchPath: @"/usr/bin/c++filt"];
        [iCPFiltTask setArguments: args];
        [iCPFiltTask setStandardInput: iCPFiltInputPipe];
        [iCPFiltTask setStandardOutput: iCPFiltOutputPipe];
        [iCPFiltTask launch];
    }

    [self speedyDelivery];

    return self;
}

//  dealloc
// ----------------------------------------------------------------------------

- (void)dealloc
{
    if (iRAMFile)
    {
        free(iRAMFile);
        iRAMFile = NULL;
    }

    if (iThunks)
    {
        free(iThunks);
        iThunks = NULL;
    }

    if (iCPFiltInputPipe)
    {
        [iCPFiltInputPipe release];
        iCPFiltInputPipe = nil;
    }

    if (iCPFiltOutputPipe)
    {
        [iCPFiltOutputPipe release];
        iCPFiltOutputPipe = nil;
    }

    if (iCPFiltTask)
    {
        [iCPFiltTask terminate];
        [iCPFiltTask release];
    }

    [super dealloc];
}

#pragma mark -
//  sendTypeFromMsgSend:
// ----------------------------------------------------------------------------

- (UInt8)sendTypeFromMsgSend: (char*)inString
{
    UInt8 sendType = send;

    if (strlen(inString) != 13) // not _objc_msgSend
    {
        if (strstr(inString, "Super_stret"))
            sendType = sendSuper_stret;
        else if (strstr(inString, "Super"))
            sendType = sendSuper;
        else if (strstr(inString, "_stret"))
            sendType = send_stret;
        else if (strstr(inString, "_rtp"))
            sendType = send_rtp;
        else if (strstr(inString, "_fpret"))
            sendType = send_fpret;
        else
            sendType = send_variadic;
    }

    return sendType;
}

//  getDescription:forType:
// ----------------------------------------------------------------------------
//  "filer types" defined in objc/objc-class.h, NSCoder.h, and
// http://developer.apple.com/documentation/DeveloperTools/gcc-3.3/gcc/Type-encoding.html

- (void)getDescription: (char*)ioCString
               forType: (const char*)inTypeCode
{
    if (!inTypeCode || !ioCString)
        return;

    char    theSuffixCString[50];
    uint32_t  theNextChar = 0;
    UInt16  i           = 0;

/*
    char vs. BOOL

    data type       encoding
    ÑÑÑÑÑÑÑÑÑ       ÑÑÑÑÑÑÑÑ
    char            c
    BOOL            c
    char[100]       [100c]
    BOOL[100]       [100c]

    from <objc/objc.h>:
        typedef signed char     BOOL; 
        // BOOL is explicitly signed so @encode(BOOL) == "c" rather than "C" 
        // even if -funsigned-char is used.

    Ok, so BOOL is just a synonym for signed char, and the @encode directive
    can't be expected to desynonize that. Fair enough, but for our purposes,
    it would be nicer if BOOL was synonized to unsigned char instead.

    So, any occurence of 'c' may be a char or a BOOL. The best option I can
    see is to treat arrays as char arrays and atomic values as BOOL, and maybe
    let the user disagree via preferences. Since the data type of an array is
    decoded with a recursive call, we can use the following static variable
    for this purpose.

    As of otx 0.14b, letting the user override this behavior with a pref is
    left as an exercise for the reader.
*/
    static BOOL isArray = NO;

    // Convert '^^' prefix to '**' suffix.
    while (inTypeCode[theNextChar] == '^')
    {
        theSuffixCString[i++]   = '*';
        theNextChar++;
    }

    // Add the null terminator.
    theSuffixCString[i] = 0;
    i   = 0;

    char    theTypeCString[MAX_TYPE_STRING_LENGTH];

    theTypeCString[0]   = 0;

    // Now we can get at the basic type.
    switch (inTypeCode[theNextChar])
    {
        case '@':
        {
            if (inTypeCode[theNextChar + 1] == '"')
            {
                uint32_t  classNameLength =
                    strlen(&inTypeCode[theNextChar + 2]);

                memcpy(theTypeCString, &inTypeCode[theNextChar + 2],
                    classNameLength - 1);

                // Add the null terminator.
                theTypeCString[classNameLength - 1] = 0;
            }
            else
                strncpy(theTypeCString, "id", 3);

            break;
        }

        case '#':
            strncpy(theTypeCString, "Class", 6);
            break;
        case ':':
            strncpy(theTypeCString, "SEL", 4);
            break;
        case '*':
            strncpy(theTypeCString, "char*", 6);
            break;
        case '?':
            strncpy(theTypeCString, "undefined", 10);
            break;
        case 'i':
            strncpy(theTypeCString, "int", 4);
            break;
        case 'I':
            strncpy(theTypeCString, "unsigned int", 13);
            break;
        // bitfield according to objc-class.h, C++ bool according to NSCoder.h.
        // The above URL expands on obj-class.h's definition of 'b' when used
        // in structs/unions, but NSCoder.h's definition seems to take
        // priority in return values.
        case 'B':
        case 'b':
            strncpy(theTypeCString, "bool", 5);
            break;
        case 'c':
            strncpy(theTypeCString, (isArray) ? "char" : "BOOL", 5);
            break;
        case 'C':
            strncpy(theTypeCString, "unsigned char", 14);
            break;
        case 'd':
            strncpy(theTypeCString, "double", 7);
            break;
        case 'f':
            strncpy(theTypeCString, "float", 6);
            break;
        case 'l':
            strncpy(theTypeCString, "long", 5);
            break;
        case 'L':
            strncpy(theTypeCString, "unsigned long", 14);
            break;
        case 'q':   // not in objc-class.h
            strncpy(theTypeCString, "long long", 10);
            break;
        case 'Q':   // not in objc-class.h
            strncpy(theTypeCString, "unsigned long long", 19);
            break;
        case 's':
            strncpy(theTypeCString, "short", 6);
            break;
        case 'S':
            strncpy(theTypeCString, "unsigned short", 15);
            break;
        case 'v':
            strncpy(theTypeCString, "void", 5);
            break;
        case '(':   // union- just copy the name
            while (inTypeCode[++theNextChar] != '=' &&
                   inTypeCode[theNextChar]   != ')' &&
                   inTypeCode[theNextChar]   != '<' &&
                   theNextChar < MAX_TYPE_STRING_LENGTH)
                theTypeCString[i++] = inTypeCode[theNextChar];

                // Add the null terminator.
                theTypeCString[i]   = 0;

            break;

        case '{':   // struct- just copy the name
            while (inTypeCode[++theNextChar] != '=' &&
                   inTypeCode[theNextChar]   != '}' &&
                   inTypeCode[theNextChar]   != '<' &&
                   theNextChar < MAX_TYPE_STRING_LENGTH)
                theTypeCString[i++] = inTypeCode[theNextChar];

                // Add the null terminator.
                theTypeCString[i]   = 0;

            break;

        case '[':   // arrayÉ   [12^f] <-> float*[12]
        {
            char    theArrayCCount[10]  = {0};

            while (inTypeCode[++theNextChar] >= '0' &&
                   inTypeCode[theNextChar]   <= '9')
                theArrayCCount[i++] = inTypeCode[theNextChar];

            // Recursive madness. See 'char vs. BOOL' note above.
            char    theCType[MAX_TYPE_STRING_LENGTH];

            theCType[0] = 0;

            isArray = YES;
            GetDescription(theCType, &inTypeCode[theNextChar]);
            isArray = NO;

            snprintf(theTypeCString, MAX_TYPE_STRING_LENGTH + 1, "%s[%s]",
                theCType, theArrayCCount);

            break;
        }

        default:
            strncpy(theTypeCString, "?", 2);

            break;
    }

    strncat(ioCString, theTypeCString, strlen(theTypeCString));

    if (theSuffixCString[0])
        strncat(ioCString, theSuffixCString, strlen(theSuffixCString));
}

#pragma mark -
- (BOOL)printDataSections
{
    return NO;
}

- (void)printDataSection: (section_info*)inSect
                  toFile: (FILE*)outFile
{}

- (NSString*)generateMD5String
{
    NSString* md5Path = [NSString pathWithComponents: [NSArray arrayWithObjects:
        @"/", @"sbin", @"md5", nil]];
    NSTask* md5Task = [[[NSTask alloc] init] autorelease];
    NSPipe* md5Pipe = [NSPipe pipe];
    NSPipe* errorPipe = [NSPipe pipe];
    NSArray* args = [NSArray arrayWithObjects: @"-q", [iOFile path], nil];

    [md5Task setLaunchPath: md5Path];
    [md5Task setArguments: args];
    [md5Task setStandardInput: [NSPipe pipe]];
    [md5Task setStandardOutput: md5Pipe];
    [md5Task setStandardError: errorPipe];

    @try
    {
        [md5Task launch];
    }
    @catch (NSException* e)
    {
        NSLog(@"otx: unable to launch md5: %@", [e reason]);
        return nil;
    }

    [md5Task waitUntilExit];

    int md5Status = [md5Task terminationStatus];

    if (md5Status != 0) // md5Task failed, log and bail
    {
        NSData* errorData = nil;

        @try
        {
            errorData = [[errorPipe fileHandleForReading] availableData];
        }
        @catch (NSException* e)
        {
            NSLog(@"otx: unable to read data from md5 error for \"%@\": %@", [iOFile path], [e reason]);
            return nil;
        }

        if (errorData == nil)
        {
            NSLog(@"otx: md5 error data is nil for \"%@\"", [iOFile path]);
            return nil;
        }

        NSString* errorString = [[[NSString alloc] initWithBytes: [errorData bytes]
                                                          length: [errorData length]
                                                        encoding: NSUTF8StringEncoding] autorelease];

        if (errorString == nil || [errorString length] == 0)
            errorString = @"unknown error";

        NSLog(@"otx: unable to generate md5 checksum for \"%@\": %@", [iOFile path], errorString);
        return nil;
    }

    NSData* md5Data = nil;

    @try
    {
        md5Data = [[md5Pipe fileHandleForReading] availableData];
    }
    @catch (NSException* e)
    {
        NSLog(@"otx: unable to read from md5 data for \"%@\": %@", [iOFile path], [e reason]);
        return nil;
    }

    if (md5Data == nil || [md5Data length] == 0) // md5Task produced no data, log and bail
    {
        NSLog(@"otx: unexpected failure while generating md5 checksum of \"%@\"", [iOFile path]);
        return nil;
    }

    NSString* stringFromData = [[[NSString alloc] initWithBytes: [md5Data bytes]
                                                         length: [md5Data length]
                                                       encoding: NSUTF8StringEncoding] autorelease];

    return [NSString stringWithFormat: @"\nmd5: %@\n", [stringFromData stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]]];
}

#pragma mark -
//  decodeMethodReturnType:output:
// ----------------------------------------------------------------------------

- (void)decodeMethodReturnType: (const char*)inTypeCode
                        output: (char*)outCString
{
    uint32_t  theNextChar = 0;

    // Check for type specifiers.
    // r* <-> const char* ... VI <-> oneway unsigned int
    switch (inTypeCode[theNextChar++])
    {
        case 'r':
            strncpy(outCString, "const ", 7);
            break;
        case 'n':
            strncpy(outCString, "in ", 4);
            break;
        case 'N':
            strncpy(outCString, "inout ", 7);
            break;
        case 'o':
            strncpy(outCString, "out ", 5);
            break;
        case 'O':
            strncpy(outCString, "bycopy ", 8);
            break;
        case 'V':
            strncpy(outCString, "oneway ", 8);
            break;

        // No specifier found, roll back the marker.
        default:
            theNextChar--;
            break;
    }

    GetDescription(outCString, &inTypeCode[theNextChar]);
}

#pragma mark -

//  speedyDelivery
// ----------------------------------------------------------------------------

- (void)speedyDelivery
{
    GetDescription = GetDescriptionFuncType
        [self methodForSelector: GetDescriptionSel];
}

#ifdef OTX_DEBUG
//  printSymbol:
// ----------------------------------------------------------------------------
//  Used for symbol debugging.

- (void)printSymbol: (nlist)inSym
{
    fprintf(stderr, "----------------\n\n");
    fprintf(stderr, " n_strx = 0x%08x\n", inSym.n_un.n_strx);
    fprintf(stderr, " n_type = 0x%02x\n", inSym.n_type);
    fprintf(stderr, " n_sect = 0x%02x\n", inSym.n_sect);
    fprintf(stderr, " n_desc = 0x%04x\n", inSym.n_desc);
    fprintf(stderr, "n_value = 0x%08x (%u)\n\n", inSym.n_value, inSym.n_value);

    if ((inSym.n_type & N_STAB) != 0)
    {   // too complicated, see <mach-o/stab.h>
        fprintf(stderr, "STAB symbol\n");
    }
    else    // not a STAB
    {
        if ((inSym.n_type & N_PEXT) != 0)
            fprintf(stderr, "Private external symbol\n\n");
        else if ((inSym.n_type & N_EXT) != 0)
            fprintf(stderr, "External symbol\n\n");

        UInt8   theNType    = inSym.n_type & N_TYPE;
        UInt16  theRefType  = inSym.n_desc & REFERENCE_TYPE;

        fprintf(stderr, "Symbol type: ");

        if (theNType == N_ABS)
            fprintf(stderr, "Absolute\n");
        else if (theNType == N_SECT)
            fprintf(stderr, "Defined in section %u\n", inSym.n_sect);
        else if (theNType == N_INDR)
            fprintf(stderr, "Indirect\n");
        else
        {
            if (theNType == N_UNDF)
                fprintf(stderr, "Undefined\n");
            else if (theNType == N_PBUD)
                fprintf(stderr, "Prebound undefined\n");

            switch (theRefType)
            {
                case REFERENCE_FLAG_UNDEFINED_NON_LAZY:
                    fprintf(stderr, "REFERENCE_FLAG_UNDEFINED_NON_LAZY\n");
                    break;
                case REFERENCE_FLAG_UNDEFINED_LAZY:
                    fprintf(stderr, "REFERENCE_FLAG_UNDEFINED_LAZY\n");
                    break;
                case REFERENCE_FLAG_DEFINED:
                    fprintf(stderr, "REFERENCE_FLAG_DEFINED\n");
                    break;
                case REFERENCE_FLAG_PRIVATE_DEFINED:
                    fprintf(stderr, "REFERENCE_FLAG_PRIVATE_DEFINED\n");
                    break;
                case REFERENCE_FLAG_PRIVATE_UNDEFINED_NON_LAZY:
                    fprintf(stderr, "REFERENCE_FLAG_PRIVATE_UNDEFINED_NON_LAZY\n");
                    break;
                case REFERENCE_FLAG_PRIVATE_UNDEFINED_LAZY:
                    fprintf(stderr, "REFERENCE_FLAG_PRIVATE_UNDEFINED_LAZY\n");
                    break;

                default:
                    break;
            }
        }
    }

    fprintf(stderr, "\n");
}

//  printBlocks:
// ----------------------------------------------------------------------------
//  Used for block debugging. Sublclasses may override.

- (void)printBlocks: (uint32_t)inFuncIndex;
{}
#endif  // OTX_DEBUG

@end
