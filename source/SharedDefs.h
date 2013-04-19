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
typedef struct
{                                   // CLI flags
    BOOL    localOffsets;           // l
    BOOL    entabOutput;            // e
    BOOL    dataSections;           // d
    BOOL    checksum;               // c
    BOOL    verboseMsgSends;        // m
    BOOL    separateLogicalBlocks;  // b
    BOOL    demangleCppNames;       // n
    BOOL    returnTypes;            // r
    BOOL    variableTypes;          // v
    BOOL    returnStatements;       // R
}
ProcOptions;
