/*
    SharedDefs.h

    Definitions shared by GUI and CLI targets.

    This file is in the public domain.
*/

/*  ProcOptions

    Options for processing executables. GUI target sets these using
    NSUserDefaults, CLI target sets them with command line arguments. This
    is necessary for the CLI target to behave consistently across
    invocations, and to keep it from altering the GUI target's prefs.
*/
#define OTX_VERSION "2.0.0"

// Checksum algorithm values for ProcOptions.checksumAlgorithm
#define CHECKSUM_NONE   0
#define CHECKSUM_MD5    1
#define CHECKSUM_SHA1   2
#define CHECKSUM_SHA256 3

typedef struct
{                                           // CLI flags
    BOOL        localOffsets;               // l
    BOOL        showCode;                   // C
    BOOL        entabOutput;                // e
    BOOL        dataSections;               // d
    uint8_t     checksumAlgorithm;          // c
    BOOL        verboseMsgSends;            // m
    BOOL        separateLogicalBlocks;      // b
    BOOL        demangleCppNames;           // n
    BOOL        returnTypes;                // r
    BOOL        variableTypes;              // v
    BOOL        returnStatements;           // R
    BOOL        debugMode;                  // -debug
}
ProcOptions;
