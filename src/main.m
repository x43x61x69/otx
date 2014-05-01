/*
    main.m

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#ifdef OTX_CLI
    #import "CLIController.h"
#else
    #import <AppKit/NSApplication.h>
#endif

BOOL gCancel = NO;

int main(
    int     argc,
    char*   argv[])
{
    if (OS_IS_PRE_TIGER)
    {
        fprintf(stderr, "otx requires Mac OS X 10.4 or higher.\n");
        return -1;
    }

    int result  = 1;

#ifdef OTX_CLI
    @autoreleasepool {
        CLIController*      controller  =
        [[CLIController alloc] initWithArgs: argv count: argc];

        if (controller)
        {
            [controller processFile];
            result  = noErr;
        }
        else
            result  = -1;
    }
#else
    result  = NSApplicationMain(argc, (const char**)argv);
#endif

    return result;
}
