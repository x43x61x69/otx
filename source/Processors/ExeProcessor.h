/*
    ExeProcessor.h

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "SystemIncludes.h"

#import "SharedDefs.h"
#import "StolenDefs.h"
#import "ProgressReporter.h"

/*  ThunkInfo

    http://developer.apple.com/documentation/DeveloperTools/Conceptual/MachOTopics/Articles/dynamic_code.html#//apple_ref/doc/uid/TP40002528-SW1

    This URL describes Apple's approach to PIC and indirect addressing in
    PPC assembly. The idea is to use the address of an instruction as a
    base address, from which some data can be referenced by some offset.
    The address of the next instruction to be executed is stored in the
    program counter register, which is not directly accessible by user-level
    code. Since it's not directly accessible, Apple uses CPU-specific
    techniques to access it indirectly.

    In PPC asm, they save the link register then use the bcl instruction
    to load the link register with the address of the following instruction.
    This saved address is then copied from the link register into some GP
    register, and the original link register is restored. Subsequent code
    can add an offset to the saved address to reference whatever data.

    In the x86 chip, the program counter is called the instruction pointer.
    The call and ret instructions modify the IP as a side effect. The call
    instruction pushes IP onto the stack and the ret instruction pops it.
    To exploit this behavior, gcc uses small functions whose purpose is
    to simply copy the IP from the stack into some GP register, like so:

___i686.get_pc_thunk.bx:
    8b1c24      movl    (%esp,1),%ebx
    c3          ret

    This routine copies IP into EBX and returns. Subsequent code in the
    calling function can use EBX as a base address, same as above. Note the
    use of 'pc'(program counter) in the routine name, as opposed to IP or
    EIP. This use of the word 'thunk' is inconsistent with other definitions
    I've heard, but there it is. From what I've seen, the thunk can be stored
    in EAX, EBX, ECX, or EDX, and there can be multiple get_pc_thunk routines,
    each referencing one of these registers.

    The PPC version of this behavior requires no function calls, and is
    fairly easy to spot. And in x86 code, when symbols have not been stripped,
    otool reports the ___i686.get_pc_thunk.bx calls like a champ. Our only
    problem occurs when symbols are stripped in x86 code. In that case, otool
    cannot display the name of the routine, only the address being called.
    This is why we need ThunkInfos. otx makes several passes over otool's
    output. During the first pass, it recognizes the code pattern of these
    get_pc_thunk routines, and saves their addresses in an array of
    ThunkInfo's. Having this data available during the 2nd pass makes it
    possible to reference whatever data we need in the calling function.
*/
typedef struct
{
    uint32_t  address;    // address of the get_pc_thunk routine
    SInt8   reg;        // register to which the thunk is being saved
}
ThunkInfo;

/*  TextFieldWidths

    Number of characters in each field, pre-entabified. Comment field is
    limited only by MAX_COMMENT_LENGTH. A single space per field is
    hardcoded in the snprintf format strings to prevent collisions.
*/
typedef struct
{
    UInt16  offset;
    UInt16  address;
    UInt16  instruction;
    UInt16  mnemonic;
    UInt16  operands;
}
TextFieldWidths;

// Constants for dealing with objc_msgSend variants.
enum {
    send,
    send_rtp,           // ppc only
    sendSuper,
    send_stret,
    sendSuper_stret,
    send_fpret,         // x86 only
    send_variadic
};

// Constants that represent which section is being referenced, indicating
// likely data types.
enum {
    PointerType,        // C string in (__TEXT,__cstring)
    PStringType,        // Str255 in (__TEXT,__const)
    TextConstType,      // ? in (__TEXT,__const)
    CFStringType,       // cf_string_object in (__TEXT,__cfstring)
    FloatType,          // float in (__TEXT,__literal4)
    DoubleType,         // double in (__TEXT,__literal8)
    DataGenericType,    // ? in (__DATA,__data)
    DataConstType,      // ? in (__DATA,__const)
    DYLDType,           // function ptr in (__DATA,__dyld)
    NLSymType,          // non-lazy symbol* in (__DATA,__nl_symbol_ptr)
    ImpPtrType,         // cf_string_object* in (__IMPORT,__pointers)
    OCGenericType,          // Obj-C types
    OCStrObjectType,    // objc_string_object in (__OBJC,__string_object)
    OCClassType,        // objc_class in (__OBJC,__class)
    OCModType,          // objc_module in (__OBJC,__module_info)
    OCClassRefType,     // objc2_class_t* in (__DATA,__objc_classrefs)
    OCMsgRefType,       // objc2_message_ref_t in (__DATA,__objc_msgrefs)
    OCSelRefType,       // char* in (__DATA,__objc_selrefs)
    OCSuperRefType,     // objc2_class_t* in (__DATA,__objc_superrefs)
    OCCatListType,      // ? in (__DATA,__objc_catlist)
    OCProtoListType,    // objc2_protocol_t* in (__DATA,__objc_protolist)
    OCProtoRefType,     // objc2_protocol_t* in (__DATA,__objc_protorefs)
};

#define MAX_FIELD_SPACING           50      // spaces between fields
#define MAX_FIELD_SPACES            "                                                  "  // 50 spaces
#define MAX_FORMAT_LENGTH           50      // snprintf() format string
#define MAX_OPERANDS_LENGTH         1000
#define MAX_COMMENT_LENGTH          2000
#define MAX_LINE_LENGTH             10000
#define MAX_TYPE_STRING_LENGTH      200     // for encoded ObjC data types
#define MAX_MD5_LINE                40      // for the md5 pipe
#define MAX_ARCH_STRING_LENGTH      20      // "ppc", "i386" etc.
#define MAX_UNIBIN_OTOOL_CMD_SIZE   MAXPATHLEN + MAX_ARCH_STRING_LENGTH + 7 // strlen(" -arch ")
#define MAX_STACK_SIZE              40      // maximum number of stack variables

#define ANON_FUNC_BASE          "Anon"
#define ANON_FUNC_BASE_LENGTH   4

// Toggle these to print symbol descriptions and blocks to standard out.
#define _OTX_DEBUG_SYMBOLS_     0
#define _OTX_DEBUG_DYSYMBOLS_   0
#define _OTX_DEBUG_BLOCKS_      0   // too numerous, add it yourself.

#define COMPARISON_FUNC_TYPE    int (*)(const void*, const void*)

#ifdef OTX_CLI
#define PROGRESS_FREQ   10000   // Refresh progress bar after processing this many lines.
#else
#define PROGRESS_FREQ   3500
#endif

// ============================================================================

@interface ExeProcessor : NSObject
{
@protected
    BOOL                iSwapped;
    id                  iController;
    NSTimer*            iIndeterminateProgBarTimer;

    // guts
    NSURL*              iOFile;                 // exe on disk
    char*               iRAMFile;               // exe in RAM
    uint32_t              iRAMFileSize;
    NSString*           iOutputFilePath;
    uint32_t              iFileArchMagic;         // 0xCAFEBABE etc.
    BOOL                iExeIsFat;
    uint32_t              iLocalOffset;           // +420 etc.
    ThunkInfo*          iThunks;                // x86 only
    uint32_t              iNumThunks;             // x86 only
    TextFieldWidths     iFieldWidths;
    ProcOptions         iOpts;
    NSTask*             iCPFiltTask;
    NSPipe*             iCPFiltInputPipe;
    NSPipe*             iCPFiltOutputPipe;

    // FunctionInfo stuff
    uint32_t              iCurrentGenericFuncNum;

    // Symbols stuff
    uint32_t       iStringTableOffset;

    // dyld stuff
    uint32_t      iAddrDyldStubBindingHelper;
    uint32_t      iAddrDyldFuncLookupPointer;

    BOOL        iEnteringNewBlock;
    SInt64      iCurrentFuncInfoIndex;

    // saved strings
    char        iArchString[MAX_ARCH_STRING_LENGTH];    // "ppc", "i386" etc.
    char        iLineCommentCString[MAX_COMMENT_LENGTH];
    char        iLineOperandsCString[MAX_OPERANDS_LENGTH];

    void        (*GetDescription)(id, SEL, char*, const char*);
}

- (id)initWithURL: (NSURL*)inURL
       controller: (id)inController
          options: (ProcOptions*)inOptions;
- (BOOL)printDataSections;
- (void)printDataSection: (section_info*)inSect
                  toFile: (FILE*)outFile;
- (UInt8)sendTypeFromMsgSend: (char*)inString;

- (NSString*)generateMD5String;
- (void)decodeMethodReturnType: (const char*)inTypeCode
                        output: (char*)outCString;

- (void)getDescription: (char*)ioCString
               forType: (const char*)inTypeCode;

- (void)speedyDelivery;

#ifdef OTX_DEBUG
- (void)printSymbol: (nlist)inSym;
- (void)printBlocks: (uint32_t)inFuncIndex;
#endif

@end

// ----------------------------------------------------------------------------
// Comparison functions for qsort(3) and bsearch(3)

static int
Sym_Compare(
    nlist*  sym1,
    nlist*  sym2)
{
    if (sym1->n_value < sym2->n_value)
        return -1;

    return (sym1->n_value > sym2->n_value);
}

static int
Sym_Compare_64(
    nlist_64*  sym1,
    nlist_64*  sym2)
{
    if (sym1->n_value < sym2->n_value)
        return -1;

    return (sym1->n_value > sym2->n_value);
}

// ----------------------------------------------------------------------------
// Utils

// This could be a macro if I could figure out the syntax…
static int
strcmp_sectname(const char *data, const char *str)
{
    if (strlen(str) == 16)
        return strncmp(data, str, 16);
    else
        return strcmp(data, str);
}
