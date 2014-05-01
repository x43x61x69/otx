/*
    ErrorReporter.h

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

@protocol ErrorReporter

- (void)reportError: (NSString*)inMessageText
         suggestion: (NSString*)inInformativeText;

@end