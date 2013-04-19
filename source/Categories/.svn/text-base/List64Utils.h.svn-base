/*
    List64Utils.h

    A category on Exe64Processor that contains the linked list
    manipulation methods.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "Exe64Processor.h"

@interface Exe64Processor(List64Utils)

- (void)insertLine: (Line64*)inLine
            before: (Line64*)nextLine
            inList: (Line64**)listHead;
- (void)insertLine: (Line64*)inLine
             after: (Line64*)prevLine
            inList: (Line64**)listHead;
- (void)replaceLine: (Line64*)inLine
           withLine: (Line64*)newLine
             inList: (Line64**)listHead;
- (BOOL)printLinesFromList: (Line64*)listHead;
- (void)deleteLinesFromList: (Line64*)listHead;
- (void)deleteLinesBefore: (Line64*)inLine
                 fromList: (Line64**)listHead;

@end
