/*
    Exe64Processor.h

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "ExeProcessor.h"
#import "Optimizations64.h"

/*  MethodInfo

    Additional info pertaining to an Obj-C method.
*/
typedef struct
{
    objc2_method_t  m;
    objc2_class_t   oc_class;
    BOOL            inst;       // to determine '+' or '-'
}
Method64Info;

/*  GP64RegisterInfo

    Processor-specific subclasses maintain arrays of RegisterInfo's to
    simulate the state of registers in the CPU as each line of code is
    executed.
*/
typedef struct
{
    UInt64          value;
    BOOL            isValid;        // value can be trusted
    objc2_class_t*  classPtr;
    char*           className;
    char*           messageRefSel;  // selector for calls through pointers
}
GP64RegisterInfo;

/*  Var64Info

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
    GP64RegisterInfo    regInfo;
    SInt32              offset;
}
Var64Info;

/*  Line64Info

    Used exclusively in the Line64 struct below, LineInfo encapsulates the
    details pertaining to a line of disassemled code that are not part
    of the basic linked list element.
*/
typedef struct
{
    UInt64  address;
    UInt8   code[16];       // machine code as int bytes
    UInt8   codeLength;
    BOOL    isCode;         // NO for function names, section names etc.
    BOOL    isFunction;     // YES if this is the first instruction in a function.
    BOOL    isFunctionEnd;  // YES if this is the last instruction in a function.
}
Line64Info;

/*  Line64

    Represents a line of text from otool's output. For each __text section,
    otool is called twice- with symbolic operands(-V) and without(-v). The
    resulting 2 text files are each read into a doubly-linked list of Line64's.
    Each Line64 contains a pointer to the corresponding Line64 in the other list.
    The reason for this approach is due to otool's inaccuracy in guessing
    symbols. From comments in ofile_print.c:

        "Both a verbose (symbolic) and non-verbose modes are supported to aid
        in seeing the values even if they are not correct."

    With both versions on hand, we can choose the better one for each Line64.
    The criteria for choosing is defined in chooseLine:. This does result in a
    slight loss of info, in the rare case that otool guesses correctly for
    any instruction that is not a function call.
*/
struct Line64
{
    char*           chars;      // C string
    uint32_t          length;     // C string length
    struct Line64*  next;       // next line in this list
    struct Line64*  prev;       // previous line in this list
    struct Line64*  alt;        // "this" line in the other list
    Line64Info      info;       // details
};

// "typedef struct Line64" doesn't work, so we do this instead.
#define Line64  struct Line64

/*  Machine64State

    Saved state of the CPU registers and local copies of self. 'localSelves'
    is an array with 'numLocalSelves' items. 'regInfos' is an array whose
    count is defined by the processor-specific subclasses.
*/
typedef struct
{
    GP64RegisterInfo*   regInfos;
    Var64Info*          localSelves;
    uint32_t              numLocalSelves;
    Var64Info*          localVars;
    uint32_t              numLocalVars;
}
Machine64State;

/*  Block64Info

    Info pertaining to a logical block of code. 'state' is the saved
    MachineState that should be restored upon entering this block.
*/
typedef struct
{
    UInt64          beginAddress;
    Line64*         endLine;
    BOOL            isEpilog;
    Machine64State  state;
}
Block64Info;

/*  Function64Info

    Used for tracking the changing machine states between code blocks in a
    function. 'blocks' is an array with 'numBlocks' items.
*/
typedef struct
{
    UInt64          address;
    Block64Info*    blocks;
    uint32_t          numBlocks;
    uint32_t          genericFuncNum; // 'AnonX' if > 0
}
Function64Info;

// ============================================================================

@interface Exe64Processor : ExeProcessor
{
@protected
    // guts
    mach_header_64*     iMachHeaderPtr;         // ptr to the orig header
    mach_header_64      iMachHeader;            // (swapped?) copy of the header
    Line64*             iVerboseLineListHead;   // linked list the first
    Line64*             iPlainLineListHead;     // linked list the second
    Line64**            iLineArray;
    uint32_t              iNumLines;
    uint32_t              iNumCodeLines;
    cpu_type_t          iArchSelector;

    // base pointers for indirect addressing
    SInt8               iCurrentThunk;      // x86 register identifier
    UInt64              iCurrentFuncPtr;    // PPC function address

    // symbols that point to functions
    nlist_64*           iFuncSyms;
    uint32_t            iNumFuncSyms;

    // FunctionInfo array
    Function64Info*     iFuncInfos;
    uint32_t              iNumFuncInfos;

    // Obj-C stuff
    Method64Info*       iClassMethodInfos;
    uint32_t              iNumClassMethodInfos;
    objc2_ivar_t*       iClassIvars;
    uint32_t              iNumClassIvars;
    objc2_class_t*      iCurrentClass;
    BOOL                iIsInstanceMethod;

    // Mach-O sections
    section_info_64     iObjcClassListSect;
    section_info_64     iObjcCatListSect;   //
    section_info_64     iObjcProtoListSect; //
    section_info_64     iObjcSuperRefsSect;  //
    section_info_64     iObjcClassRefsSect;
    section_info_64     iObjcProtoRefsSect;  //
    section_info_64     iObjcMsgRefsSect;
    section_info_64     iObjcSelRefsSect;    //
    section_info_64     iCStringSect;
    section_info_64     iNSStringSect;
    section_info_64     iLit4Sect;
    section_info_64     iLit8Sect;
    section_info_64     iTextSect;
    section_info_64     iCoalTextSect;
    section_info_64     iCoalTextNTSect;
    section_info_64     iConstTextSect;
    section_info_64     iObjcMethnameSect;
    section_info_64     iObjcClassnameSect;
    section_info_64     iDataSect;
    section_info_64     iCoalDataSect;
    section_info_64     iCoalDataNTSect;
    section_info_64     iConstDataSect;
    section_info_64     iDyldSect;
    section_info_64     iCFStringSect;
    section_info_64     iNLSymSect;
    section_info_64     iImpPtrSect;
    UInt64              iTextOffset;
    UInt64              iEndOfText;

    // C function pointers- see Optimizations.h and speedyDelivery
    BOOL    (*LineIsCode)                   (id, SEL, const char*);
    BOOL    (*LineIsFunction)               (id, SEL, Line64*);
    BOOL    (*CodeIsBlockJump)              (id, SEL, UInt8*);
    UInt64  (*AddressFromLine)              (id, SEL, const char*);
    void    (*CodeFromLine)                 (id, SEL, Line64*);
    void    (*CheckThunk)                   (id, SEL, Line64*);
    void    (*ProcessLine)                  (id, SEL, Line64*);
    void    (*ProcessCodeLine)              (id, SEL, Line64**);
    void    (*PostProcessCodeLine)          (id, SEL, Line64**);
    void    (*ChooseLine)                   (id, SEL, Line64**);
    void    (*EntabLine)                    (id, SEL, Line64*);
    char*   (*GetPointer)                   (id, SEL, UInt64, UInt8*);
    void    (*CommentForLine)               (id, SEL, Line64*);
    void    (*CommentForSystemCall)         (id, SEL);
    void    (*CommentForMsgSendFromLine)    (id, SEL, char*, Line64*);
    void    (*ResetRegisters)               (id, SEL, Line64*);
    void    (*UpdateRegisters)              (id, SEL, Line64*);
    BOOL    (*RestoreRegisters)             (id, SEL, Line64*);
    char*   (*SelectorForMsgSend)           (id, SEL, char*, Line64*);
    UInt8   (*SendTypeFromMsgSend)          (id, SEL, char*);
    char*   (*PrepareNameForDemangling)     (id, SEL, char*);

    BOOL    (*GetObjcClassPtrFromMethod)    (id, SEL, objc2_class_t**, UInt64);
    BOOL    (*GetObjcMethodFromAddress)     (id, SEL, Method64Info**, UInt64);
    BOOL    (*GetObjcClassFromName)         (id, SEL, objc2_class_t*, const char*);
    BOOL    (*GetObjcClassPtrFromName)      (id, SEL, objc2_class_t**, const char*);
    BOOL    (*GetObjcDescriptionFromObject) (id, SEL, char**, const char*, UInt8);
    BOOL    (*GetObjcMetaClassFromClass)    (id, SEL, objc2_class_t*, objc2_class_t*);

    void    (*InsertLineBefore)     (id, SEL, Line64*, Line64*, Line64**);
    void    (*InsertLineAfter)      (id, SEL, Line64*, Line64*, Line64**);
    void    (*ReplaceLine)          (id, SEL, Line64*, Line64*, Line64**);
    void    (*DeleteLinesBefore)    (id, SEL, Line64*, Line64**);

    char*   (*FindSymbolByAddress)      (id, SEL, UInt64);
    BOOL    (*FindClassMethodByAddress) (id, SEL, Method64Info**, UInt64);
    BOOL    (*FindCatMethodByAddress)   (id, SEL, Method64Info**, UInt64);
    BOOL    (*FindIvar)                 (id, SEL, objc2_ivar_t**, objc2_class_t*, UInt64);
}

- (id)initWithURL: (NSURL*)inURL
       controller: (id)inController
          options: (ProcOptions*)inOptions;
- (void)deleteFuncInfos;

// processors
- (BOOL)processExe: (NSString*)inOutputFilePath;
- (BOOL)populateLineLists;
- (BOOL)populateLineList: (Line64**)inList
               verbosely: (BOOL)inVerbose
             fromSection: (char*)inSectionName
               afterLine: (Line64**)inLine
           includingPath: (BOOL)inIncludePath;
- (BOOL)printDataSections;
- (void)printDataSection: (section_info_64*)inSect
                  toFile: (FILE*)outFile;
- (BOOL)lineIsCode: (const char*)inLine;

// customizers
- (void)gatherLineInfos;
- (void)findFunctions;
- (UInt64)addressFromLine: (const char*)inLine;
- (void)processLine: (Line64*)ioLine;
- (void)processCodeLine: (Line64**)ioLine;
- (void)chooseLine: (Line64**)ioLine;
- (void)entabLine: (Line64*)ioLine;
- (char*)getPointer: (UInt64)inAddr
               type: (UInt8*)outType;

- (char*)selectorForMsgSend: (char*)outComment
                   fromLine: (Line64*)inLine;

- (void)insertMD5;

- (void)speedyDelivery;

#ifdef OTX_DEBUG
- (void)printSymbol: (nlist_64)inSym;
- (void)printBlocks: (uint32_t)inFuncIndex;
#endif

@end

// ----------------------------------------------------------------------------
// Comparison functions for qsort(3) and bsearch(3)

static int
Function64_Info_Compare(
    Function64Info* f1,
    Function64Info* f2)
{
    if (f1->address < f2->address)
        return -1;

    return (f1->address > f2->address);
}

static int
Method64Info_Compare(
    Method64Info* mi1,
    Method64Info* mi2)
{
    if (mi1->m.imp < mi2->m.imp)
        return -1;

    return (mi1->m.imp > mi2->m.imp);
}

static int
Method64Info_Compare_Swapped(
    Method64Info* mi1,
    Method64Info* mi2)
{
    UInt64 imp1 = OSSwapInt64(mi1->m.imp);
    UInt64 imp2 = OSSwapInt64(mi2->m.imp);

    if (imp1 < imp2)
        return -1;

    return (imp1 > imp2);
}

static int
objc2_ivar_t_Compare(
    objc2_ivar_t* i1,
    objc2_ivar_t* i2)
{
    if (i1->offset < i2->offset)
        return -1;

    return (i1->offset > i2->offset);
}

// ----------------------------------------------------------------------------
// Utils

static void
swap_method64_info(
    Method64Info* mi)
{
    swap_objc2_method(&mi->m);
    swap_objc2_class(&mi->oc_class);
}
