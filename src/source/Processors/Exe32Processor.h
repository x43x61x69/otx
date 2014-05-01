/*
    Exe32Processor.h

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "ExeProcessor.h"

/*  MethodInfo

    Additional info pertaining to an Obj-C method.
*/
typedef struct
{
    union {
    struct {
        objc1_32_method     m;
        objc1_32_class      oc_class;
        objc1_32_category   oc_cat;
    };
    struct {
        objc2_32_method_t   m2;
        objc2_32_class_t    oc_class2;
    };
    };
    BOOL                inst;       // to determine '+' or '-'
}
MethodInfo;

/*  GPRegisterInfo

    Processor-specific subclasses maintain arrays of RegisterInfo's to
    simulate the state of registers in the CPU as each line of code is
    executed.
*/
typedef struct
{
    uint32_t            value;
    BOOL                isValid;        // value can be trusted
    objc_32_class_ptr   classPtr;
    objc1_32_category*  catPtr;
}
GPRegisterInfo;

/*  VarInfo

    Represents a local variable in the stack frame. Currently, copies of
    'self' are maintained in the variable-sized array mLocalSelves, and
    variables pushed onto the stack in x86 code are maintained in the array
    mStack[MAX_STACK_SIZE]. May be used for other things in future.

    Note the semantic differences regarding stack frames:

                            PPC                         x86
                            --------------------------------------------------
    local vars              stack ptr(r1) + offset      base ptr(EBP) - offset
    args to current func    ---                         base ptr(EBP) + offset
    args to called func     ---                         stack ptr(ESP) + offset
*/
typedef struct
{
    GPRegisterInfo  regInfo;
    SInt32          offset;
}
VarInfo;

/*  LineInfo

    Used exclusively in the Line struct below, LineInfo encapsulates the
    details pertaining to a line of disassemled code that are not part
    of the basic linked list element.
*/
typedef struct
{
    uint32_t  address;
    UInt8   code[16];       // machine code as int bytes
    UInt8   codeLength;
    BOOL    isCode;         // NO for function and section names etc.
    BOOL    isFunction;     // YES if this is the first instruction in a function.
}
LineInfo;

/*  Line

    Represents a line of text from otool's output. For each __text section,
    otool is called twice- with symbolic operands(-V) and without(-v). The
    resulting 2 text files are each read into a doubly-linked list of Line's.
    Each Line contains a pointer to the corresponding Line in the other list.
    The reason for this approach is due to otool's inaccuracy in guessing
    symbols. From comments in ofile_print.c:

        "Both a verbose (symbolic) and non-verbose modes are supported to aid
        in seeing the values even if they are not correct."

    With both versions on hand, we can choose the better one for each Line.
    The criteria for choosing is defined in chooseLine:. This does result in a
    slight loss of info, in the rare case that otool guesses correctly for
    any instruction that is not a function call.
*/
struct Line
{
    char*           chars;      // C string
    size_t          length;     // C string length
    struct Line*    next;       // next line in this list
    struct Line*    prev;       // previous line in this list
    struct Line*    alt;        // "this" line in the other list
    LineInfo        info;       // details
};

// "typedef struct Line" doesn't work, so we do this instead.
#define Line    struct Line

/*  MachineState

    Saved state of the CPU registers and local copies of self. 'localSelves'
    is an array with 'numLocalSelves' items. 'regInfos' is an array whose
    count is defined by the processor-specific subclasses.
*/
typedef struct
{
    GPRegisterInfo* regInfos;
    VarInfo*        localSelves;
    uint32_t          numLocalSelves;
    VarInfo*        localVars;
    uint32_t          numLocalVars;
}
MachineState;

/*  BlockInfo

    Info pertaining to a logical block of code. 'state' is the saved
    MachineState that should be restored upon entering this block.
*/
typedef struct
{
    uint32_t          beginAddress;
    Line*           endLine;
    BOOL            isEpilog;
    MachineState    state;
}
BlockInfo;

/*  FunctionInfo

    Used for tracking the changing machine states between code blocks in a
    function. 'blocks' is an array with 'numBlocks' items.
*/
typedef struct
{
    uint32_t    address;
    BlockInfo*  blocks;
    uint32_t    numBlocks;
    uint32_t    genericFuncNum; // 'AnonX' if > 0
}
FunctionInfo;

// ============================================================================

@interface Exe32Processor : ExeProcessor
{
@protected
    // guts
    mach_header*        iMachHeaderPtr;         // ptr to the orig header
    mach_header         iMachHeader;            // (swapped?) copy of the header
    Line*               iVerboseLineListHead;   // linked list the first
    Line*               iPlainLineListHead;     // linked list the second
    Line**              iLineArray;
    uint32_t              iNumLines;
    uint32_t              iNumCodeLines;
    cpu_type_t          iArchSelector;
    uint32_t            iCurrentFunctionStart;

    // base pointers for indirect addressing
    uint32_t              iCurrentFuncPtr;    // PPC function address

    // symbols that point to functions
    nlist*              iFuncSyms;
    uint32_t              iNumFuncSyms;

    // FunctionInfo array
    FunctionInfo*       iFuncInfos;
    uint32_t              iNumFuncInfos;

    // Obj-C stuff
    section_info*       iObjcSects;
    uint32_t              iNumObjcSects;
    MethodInfo*         iClassMethodInfos;
    uint32_t              iNumClassMethodInfos;
    BOOL                iIsInstanceMethod;
    uint8_t             iObjcVersion;       // 1 for objc1

    // When iObjcVersion=1, this points to a objc1_32_class
    // When iObjcVersion=2, this points to a objc2_32_class_t
    objc_32_class_ptr   iCurrentClass;      

    // Only valid when iObjcVersion=1 
    objc1_32_category*  iCurrentCat;
    MethodInfo*         iCatMethodInfos;
    uint32_t              iNumCatMethodInfos;

    // Only valid when iObjcVersion=2
    objc2_32_ivar_t*    iClassIvars;
    uint32_t              iNumClassIvars;

    // Mach-O sections
    section_info        iCStringSect;
    section_info        iNSStringSect;
    section_info        iClassSect;
    section_info        iMetaClassSect;
    section_info        iIVarSect;
    section_info        iObjcModSect;
    section_info        iObjcSymSect;
    section_info        iObjcMethnameSect;
    section_info        iObjcMethtypeSect;
    section_info        iObjcClassnameSect;
    section_info        iObjcClassListSect;
    section_info        iObjcCatListSect;
    section_info        iObjcConstSect;
    section_info        iObjcProtoListSect;
    section_info        iObjcSuperRefsSect;
    section_info        iObjcClassRefsSect;
    section_info        iObjcProtoRefsSect;
    section_info        iObjcMsgRefsSect;
    section_info        iObjcSelRefsSect;
    section_info        iObjcDataSect;
    section_info        iLit4Sect;
    section_info        iLit8Sect;
    section_info        iTextSect;
    section_info        iCoalTextSect;
    section_info        iCoalTextNTSect;
    section_info        iConstTextSect;
    section_info        iDataSect;
    section_info        iCoalDataSect;
    section_info        iCoalDataNTSect;
    section_info        iConstDataSect;
    section_info        iDyldSect;
    section_info        iCFStringSect;
    section_info        iNLSymSect;
    section_info        iImpPtrSect;
    uint32_t              iTextOffset;
    uint32_t              iEndOfText;
}

- (id)initWithURL: (NSURL*)inURL
       controller: (id)inController
          options: (ProcOptions*)inOptions;
- (void)deleteFuncInfos;

// processors
- (BOOL)processExe: (NSString*)inOutputFilePath;
- (BOOL)populateLineLists;
- (BOOL)populateLineList: (Line**)inList
               verbosely: (BOOL)inVerbose
             fromSection: (char*)inSectionName
               afterLine: (Line**)inLine
           includingPath: (BOOL)inIncludePath;
- (BOOL)printDataSections;
- (void)printDataSection: (section_info*)inSect
                  toFile: (FILE*)outFile;
- (BOOL)lineIsCode: (const char*)inLine;

// customizers
- (void)gatherLineInfos;
- (void)findFunctions;
- (uint32_t)addressFromLine: (const char*)inLine;
- (void)processLine: (Line*)ioLine;
- (void)processCodeLine: (Line**)ioLine;
- (void)chooseLine: (Line**)ioLine;
- (void)entabLine: (Line*)ioLine;
- (BOOL)getIvarName:(char **)outName type:(char **)outType withOffset:(uint32_t)offset inClass:(objc_32_class_ptr)classPtr;
- (char*)getPointer: (uint32_t)inAddr
               type: (UInt8*)outType;

- (char*)selectorForMsgSend: (char*)outComment
                   fromLine: (Line*)inLine;

- (void)insertMD5;

#ifdef OTX_DEBUG
- (void)printSymbol: (nlist)inSym;
- (void)printBlocks: (uint32_t)inFuncIndex;
#endif

@end

// ----------------------------------------------------------------------------
// Comparison functions for qsort(3) and bsearch(3)

static int
Function_Info_Compare(
    FunctionInfo*   f1,
    FunctionInfo*   f2)
{
    if (f1->address < f2->address)
        return -1;

    return (f1->address > f2->address);
}

static int
Line_Address_Compare(
    Line**   l1,
    Line**   l2)
{
    if ((*l1)->info.address < (*l2)->info.address)
        return -1;

    return ((*l1)->info.address > (*l2)->info.address);
}

static int
MethodInfo_Compare(
    MethodInfo* mi1,
    MethodInfo* mi2)
{
    if (mi1->m.method_imp < mi2->m.method_imp)
        return -1;

    return (mi1->m.method_imp > mi2->m.method_imp);
}

static int
MethodInfo_Compare_Swapped(
    MethodInfo* mi1,
    MethodInfo* mi2)
{
    uint32_t  imp1 = mi1->m.method_imp;
    uint32_t  imp2 = mi2->m.method_imp;

    imp1    = OSSwapInt32(imp1);
    imp2    = OSSwapInt32(imp2);

    if (imp1 < imp2)
        return -1;

    return (imp1 > imp2);
}
