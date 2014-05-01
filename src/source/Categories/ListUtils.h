/*
    ListUtils.h

    A category on Exe32Processor that contains the linked list
    manipulation methods.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "Exe32Processor.h"

@interface Exe32Processor(ListUtils)

- (void)insertLine: (Line*)inLine
            before: (Line*)nextLine
            inList: (Line**)listHead;
- (void)insertLine: (Line*)inLine
             after: (Line*)prevLine
            inList: (Line**)listHead;
- (void)replaceLine: (Line*)inLine
           withLine: (Line*)newLine
             inList: (Line**)listHead;
- (BOOL)printLinesFromList: (Line*)listHead;
- (void)deleteLinesFromList: (Line*)listHead;
- (void)deleteLinesBefore: (Line*)inLine
                 fromList: (Line**)listHead;

@end
