/*
    AppController.m

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>
#import <mach/mach_host.h>

#import "SystemIncludes.h"

#import "AppController.h"
#import "ListUtils.h"
#import "PPCProcessor.h"
#import "PPC64Processor.h"
#import "SmoothViewAnimation.h"
#import "SysUtils.h"
#import "UserDefaultKeys.h"
#import "X86Processor.h"
#import "X8664Processor.h"

#define UNIFIED_TOOLBAR_DELTA           12
#define CONTENT_BORDER_SIZE_TOP         2
#define CONTENT_BORDER_SIZE_BOTTOM      10
#define CONTENT_BORDER_MARGIN_BOTTOM    4

#define PROCESS_SUCCESS @"PROCESS_SUCCESS"

@implementation AppController

//  initialize
// ----------------------------------------------------------------------------

+ (void)initialize
{
    NSUserDefaultsController*   theController   =
        [NSUserDefaultsController sharedUserDefaultsController];
    NSDictionary*               theValues       =
        [NSDictionary dictionaryWithObjectsAndKeys:
        @"1",       AskOutputDirKey,
        @"YES",     DemangleCppNamesKey,
        @"NO",      EntabOutputKey,
        @"YES",     OpenOutputFileKey,
        @"BBEdit",  OutputAppKey,
        @"txt",     OutputFileExtensionKey,
        @"output",  OutputFileNameKey,
        @"NO",      SeparateLogicalBlocksKey,
        @"NO",      ShowDataSectionKey,
        @"YES",     ShowIvarTypesKey,
        @"YES",     ShowLocalOffsetsKey,
        @"YES",     ShowMD5Key,
        @"YES",     ShowMethodReturnTypesKey,
        @"YES",     ShowReturnStatementsKey,
        @"0",       UseCustomNameKey,
        @"YES",     VerboseMsgSendsKey,
        nil];

    [theController setInitialValues: theValues];
    [[theController defaults] registerDefaults: theValues];
}

//  init
// ----------------------------------------------------------------------------

- (id)init
{
    if ((self = [super init]) == nil)
        return nil;

    return self;
}

//  dealloc
// ----------------------------------------------------------------------------

- (void)dealloc
{
    if (iObjectFile)
        [iObjectFile release];

    if (iExeName)
        [iExeName release];

    if (iOutputFileLabel)
        [iOutputFileLabel release];

    if (iOutputFileName)
        [iOutputFileName release];

    if (iOutputFilePath)
        [iOutputFilePath release];

    if (iTextShadow)
        [iTextShadow release];

    if (iPrefsViews)
        free(iPrefsViews);

    if (iIndeterminateProgBarMainThreadTimer)
        [iIndeterminateProgBarMainThreadTimer release];

    [super dealloc];
}

#pragma mark -
//  openExe:
// ----------------------------------------------------------------------------
//  Open from File menu. Packages are treated as directories, so we can get
//  at frameworks, bundles etc.

- (IBAction)openExe: (id)sender
{
    NSOpenPanel*    thePanel    = [NSOpenPanel openPanel];

    [thePanel setTreatsFilePackagesAsDirectories: YES];

    if ([thePanel runModalForTypes: nil] != NSFileHandlingPanelOKButton)
        return;

    NSString*   theName = [[thePanel filenames] objectAtIndex: 0];

    [self newOFile: [NSURL fileURLWithPath: theName] needsPath: YES];
}

//  newPackageFile:
// ----------------------------------------------------------------------------
//  Attempt to drill into the package to the executable. Fails when the exe is
//  unreadable.

- (void)newPackageFile: (NSURL*)inPackageFile
{
    if (iOutputFilePath)
        [iOutputFilePath release];

    iOutputFilePath = [inPackageFile path];
    [iOutputFilePath retain];

    NSBundle*   exeBundle   = [NSBundle bundleWithPath: iOutputFilePath];

    if (!exeBundle)
    {
        fprintf(stderr, "otx: [AppController newPackageFile:] "
            "unable to get bundle from path: %s\n", UTF8STRING(iOutputFilePath));
        return;
    }

    NSString*   theExePath  = [exeBundle executablePath];

    if (!theExePath)
    {
        fprintf(stderr, "otx: [AppController newPackageFile:] "
            "unable to get executable path from bundle: %s\n",
            UTF8STRING(iOutputFilePath));
        return;
    }

    [self newOFile: [NSURL fileURLWithPath: theExePath] needsPath: NO];
}

//  newOFile:needsPath:
// ----------------------------------------------------------------------------

- (void)newOFile: (NSURL*)inOFile
       needsPath: (BOOL)inNeedsPath
{
    if (iObjectFile)
        [iObjectFile release];

    if (iExeName)
        [iExeName release];

    iObjectFile  = inOFile;
    [iObjectFile retain];

    if (inNeedsPath)
    {
        if (iOutputFilePath)
            [iOutputFilePath release];

        iOutputFilePath = [iObjectFile path];
        [iOutputFilePath retain];
    }

    if ([[NSWorkspace sharedWorkspace] isFilePackageAtPath: iOutputFilePath])
        iExeName    = [[iOutputFilePath lastPathComponent]
            stringByDeletingPathExtension];
    else
        iExeName    = [iOutputFilePath lastPathComponent];

    [iExeName retain];

    [self refreshMainWindow];
    [self syncOutputText: nil];
    [self syncSaveButton];
}

#pragma mark -
//  setupMainWindow
// ----------------------------------------------------------------------------

- (void)setupMainWindow
{
    if (OS_IS_POST_TIGER)
    {   // Adjust main window for Leopard.
        // Save the resize masks and apply new ones.
        uint32_t  origMainViewMask    = [iMainView autoresizingMask];
        uint32_t  origProgViewMask    = [iProgView autoresizingMask];

        [iMainView setAutoresizingMask: NSViewMaxYMargin];
        [iProgView setAutoresizingMask: NSViewMaxYMargin];

        NSRect  curFrame    = [iMainWindow frame];
        NSSize  maxSize     = [iMainWindow contentMaxSize];
        NSSize  minSize     = [iMainWindow contentMinSize];

        curFrame.size.height    -= UNIFIED_TOOLBAR_DELTA;
        minSize.height          -= UNIFIED_TOOLBAR_DELTA - CONTENT_BORDER_MARGIN_BOTTOM;
        maxSize.height          -= UNIFIED_TOOLBAR_DELTA - CONTENT_BORDER_MARGIN_BOTTOM;

        [iMainWindow setContentMinSize: minSize];
        [iMainWindow setFrame: curFrame
                      display: YES];
        [iMainWindow setContentMaxSize: maxSize];

        // Grow the prog view for the gradient.
        [iMainView setAutoresizingMask: NSViewMinYMargin | NSViewNotSizable];
        [iProgView setAutoresizingMask: NSViewHeightSizable | NSViewMaxYMargin];

        curFrame.size.height += CONTENT_BORDER_MARGIN_BOTTOM;
        [iMainWindow setFrame: curFrame
                      display: YES];

        [iMainView setAutoresizingMask: origMainViewMask];
        [iProgView setAutoresizingMask: origProgViewMask];

        // Set up smaller gradients.
        [iMainWindow setAutorecalculatesContentBorderThickness: NO
                                                       forEdge: NSMaxYEdge];
        [iMainWindow setAutorecalculatesContentBorderThickness: NO
                                                       forEdge: NSMinYEdge];
        [iMainWindow setContentBorderThickness: CONTENT_BORDER_SIZE_TOP
                                       forEdge: NSMaxYEdge];
        [iMainWindow setContentBorderThickness: CONTENT_BORDER_SIZE_BOTTOM
                                       forEdge: NSMinYEdge];

        // Set up text shadows.
        [[iPathText cell] setBackgroundStyle: NSBackgroundStyleRaised];
        [[iPathLabelText cell] setBackgroundStyle: NSBackgroundStyleRaised];
        [[iTypeText cell] setBackgroundStyle: NSBackgroundStyleRaised];
        [[iTypeLabelText cell] setBackgroundStyle: NSBackgroundStyleRaised];
        [[iOutputLabelText cell] setBackgroundStyle: NSBackgroundStyleRaised];
        [[iProgText cell] setBackgroundStyle: NSBackgroundStyleRaised];
    }
    else
    {
        NSImage*    bgImage = [NSImage imageNamed: @"Main Window Background"];

        [iMainWindow setBackgroundColor:
            [NSColor colorWithPatternImage: bgImage]];

        // Set up text shadows.
        [self applyShadowToText: iPathLabelText];
        [self applyShadowToText: iTypeLabelText];
        [self applyShadowToText: iOutputLabelText];
    }

    // At this point, the window is still brushed metal. We can get away with
    // not setting the background image here because hiding the prog view
    // resizes the window, which results in our delegate saving the day.
    [self hideProgView: NO openFile: NO];

    [iMainWindow setFrameAutosaveName: [iMainWindow title]];
//    [iArchPopup selectItemWithTag: iSelectedArchCPUType];
}

//  showMainWindow
// ----------------------------------------------------------------------------

- (IBAction)showMainWindow: (id)sender
{
    if (!iMainWindow)
    {
        fprintf(stderr, "otx: failed to load MainMenu.nib\n");
        return;
    }

    [iMainWindow makeKeyAndOrderFront: nil];
}

//  applyShadowToText:
// ----------------------------------------------------------------------------

- (void)applyShadowToText: (NSTextField*)inText
{
    if (OS_IS_TIGER)    // not needed on Leopard
    {
        NSMutableAttributedString*  newString   =
            [[NSMutableAttributedString alloc] initWithAttributedString:
            [inText attributedStringValue]];

        [newString addAttribute: NSShadowAttributeName value: iTextShadow
            range: NSMakeRange(0, [newString length])];
        [inText setAttributedStringValue: newString];
        [newString release];
    }
}

#pragma mark -
//  selectArch:
// ----------------------------------------------------------------------------

- (IBAction)selectArch: (id)sender
{
    CPUID*  selectedCPU = (CPUID*)[[iArchPopup selectedItem] tag];

    iSelectedArchCPUType        = selectedCPU->type;
    iSelectedArchCPUSubType     = selectedCPU->subtype;
    const NXArchInfo* archInfo  = NXGetArchInfoFromCpuType(
        iSelectedArchCPUType, iSelectedArchCPUSubType);

    if (iOutputFileLabel)
    {
        [iOutputFileLabel release];
        iOutputFileLabel    = nil;
    }

    iOutputFileLabel = [NSString stringWithFormat: @"_%s", archInfo->name];

    switch (iSelectedArchCPUType)
    {
        case CPU_TYPE_POWERPC:
            [iVerifyButton setEnabled: NO];
            break;
        case CPU_TYPE_I386:
            [iVerifyButton setEnabled: YES];
            break;
        case CPU_TYPE_POWERPC64:
            [iVerifyButton setEnabled: NO];
            break;
        case CPU_TYPE_X86_64:
            [iVerifyButton setEnabled: YES];
            break;

        default:
            break;
    }

    if (iOutputFileLabel)
        [iOutputFileLabel retain];

    [self syncOutputText: nil];
    [self syncSaveButton];
}

//  attemptToProcessFile:
// ----------------------------------------------------------------------------

- (IBAction)attemptToProcessFile: (id)sender
{
    gCancel = NO;    // Fresh start.

    NSTimeInterval interval = 0.0333;

    if (OS_IS_PRE_SNOW)
        interval = 0.0;

    if (iIndeterminateProgBarMainThreadTimer)
    {
        [iIndeterminateProgBarMainThreadTimer invalidate];
        [iIndeterminateProgBarMainThreadTimer release];
    }

    iIndeterminateProgBarMainThreadTimer = [NSTimer scheduledTimerWithTimeInterval: interval
        target: self selector: @selector(nudgeIndeterminateProgBar:)
        userInfo: nil repeats: YES];

    if (!iObjectFile)
    {
        fprintf(stderr, "otx: [AppController attemptToProcessFile]: "
            "tried to process nil object file.\n");
        return;
    }

    if (iOutputFileName)
        [iOutputFileName release];

    iOutputFileName = [iOutputText stringValue];
    [iOutputFileName retain];

    NSString*   theTempOutputFilePath   = iOutputFilePath;

    [theTempOutputFilePath retain];

    if ([[NSUserDefaults standardUserDefaults] boolForKey: AskOutputDirKey])
    {
        NSSavePanel*    thePanel    = [NSSavePanel savePanel];

        [thePanel setTreatsFilePackagesAsDirectories: YES];

        if ([thePanel runModalForDirectory: nil
            file: iOutputFileName]  != NSFileHandlingPanelOKButton)
            return;

        if (iOutputFilePath)
            [iOutputFilePath release];

        iOutputFilePath = [thePanel filename];
    }
    else
    {
        iOutputFilePath =
            [[theTempOutputFilePath stringByDeletingLastPathComponent]
            stringByAppendingPathComponent: [iOutputText stringValue]];
    }

    [iOutputFilePath retain];
    [theTempOutputFilePath release];

    // Check if the output file exists.
    if ([[NSFileManager defaultManager] fileExistsAtPath: iOutputFilePath])
    {
        NSString*   fileName    = [iOutputFilePath lastPathComponent];
        NSString*   folderName  =
            [[iOutputFilePath stringByDeletingLastPathComponent]
            lastPathComponent];
        NSAlert*    alert       = [[[NSAlert alloc] init] autorelease];

        [alert addButtonWithTitle: @"Replace"];
        [alert addButtonWithTitle: @"Cancel"];
        [alert setMessageText: [NSString stringWithFormat:
            @"\"%@\" already exists. Do you want to replace it?", fileName]];
        [alert setInformativeText:
            [NSString stringWithFormat: @"A file or folder"
            @" with the same name already exists in %@."
            @" Replacing it will overwrite its current contents.", folderName]];
        [alert beginSheetModalForWindow: iMainWindow
            modalDelegate: self
            didEndSelector: @selector(dupeFileAlertDidEnd:returnCode:contextInfo:)
            contextInfo: nil];
    }
    else
    {
        [self processFile];
    }
}

//  processFile
// ----------------------------------------------------------------------------

- (void)processFile
{
    NSDictionary*   progDict    = [[NSDictionary alloc] initWithObjectsAndKeys:
        [NSNumber numberWithBool: YES], PRIndeterminateKey,
        @"Loading executable", PRDescriptionKey,
        nil];

    [self reportProgress: progDict];
    [progDict release];

    if ([self checkOtool: [iObjectFile path]] == NO)
    {
        [self reportError: @"otool was not found."
               suggestion: @"Please install otool and try again."];
        return;
    }

    iProcessing = YES;
    [self adjustInterfaceForMultiThread];
    [self showProgView];
}

//  continueProcessingFile
// ----------------------------------------------------------------------------

- (void)continueProcessingFile
{
    NSAutoreleasePool*  pool        = [[NSAutoreleasePool alloc] init];
    Class               procClass   = nil;

    switch (iSelectedArchCPUType)
    {
        case CPU_TYPE_POWERPC:
            procClass = [PPCProcessor class];
            break;

        case CPU_TYPE_POWERPC64:
            procClass = [PPC64Processor class];
            break;

        case CPU_TYPE_I386:
            procClass = [X86Processor class];
            break;

        case CPU_TYPE_X86_64:
            procClass = [X8664Processor class];
            break;

        default:
            fprintf(stderr, "otx: [AppController continueProcessingFile]: "
                "unknown arch type: %d", iSelectedArchCPUType);
            break;
    }

    if (!procClass)
    {
        [self performSelectorOnMainThread: @selector(processingThreadDidFinish:)
                               withObject: @"Unsupported architecture."
                            waitUntilDone: NO];
        [pool release];
        return;
    }

    // Save defaults into the ProcOptions struct.
    NSUserDefaults* theDefaults = [NSUserDefaults standardUserDefaults];
    ProcOptions     opts        = {0};

    opts.localOffsets           =
        [theDefaults boolForKey: ShowLocalOffsetsKey];
    opts.entabOutput            =
        [theDefaults boolForKey: EntabOutputKey];
    opts.dataSections           =
        [theDefaults boolForKey: ShowDataSectionKey];
    opts.checksum               =
        [theDefaults boolForKey: ShowMD5Key];
    opts.verboseMsgSends        =
        [theDefaults boolForKey: VerboseMsgSendsKey];
    opts.separateLogicalBlocks  =
        [theDefaults boolForKey: SeparateLogicalBlocksKey];
    opts.demangleCppNames       =
        [theDefaults boolForKey: DemangleCppNamesKey];
    opts.returnTypes            =
        [theDefaults boolForKey: ShowMethodReturnTypesKey];
    opts.variableTypes          =
        [theDefaults boolForKey: ShowIvarTypesKey];
    opts.returnStatements       =
        [theDefaults boolForKey: ShowReturnStatementsKey];

    id  theProcessor    = [[procClass alloc] initWithURL: iObjectFile
        controller: self options: &opts];

    if (!theProcessor)
    {
        [self performSelectorOnMainThread: @selector(processingThreadDidFinish:)
                               withObject: @"Unable to create processor."
                            waitUntilDone: NO];
        [pool release];
        return;
    }

    if (![theProcessor processExe: iOutputFilePath])
    {
        NSString* resultString = (gCancel == YES) ? PROCESS_SUCCESS :
            [NSString stringWithFormat: @"Unable to process %@.", [iObjectFile path]];

        [self performSelectorOnMainThread: @selector(processingThreadDidFinish:)
                               withObject: resultString
                            waitUntilDone: NO];
        [theProcessor release];
        [pool release];
        return;
    }

    [self performSelectorOnMainThread: @selector(processingThreadDidFinish:)
                           withObject: PROCESS_SUCCESS
                        waitUntilDone: NO];
    [theProcessor release];
    [pool release];
}

//  processingThreadDidFinish:
// ----------------------------------------------------------------------------

- (void)processingThreadDidFinish: (NSString*)result
{
    iProcessing = NO;
    [iIndeterminateProgBarMainThreadTimer invalidate];
    iIndeterminateProgBarMainThreadTimer = nil;

    if ([result isEqualTo: PROCESS_SUCCESS])
    {
        [self hideProgView: YES openFile: (gCancel == YES) ? NO :
            [[NSUserDefaults standardUserDefaults]
            boolForKey: OpenOutputFileKey]];
    }
    else
    {
        [self hideProgView: YES openFile: NO];
        [self reportError: @"Error processing file."
               suggestion: result];
    }
}


#pragma mark -
//  adjustInterfaceForMultiThread
// ----------------------------------------------------------------------------
//  In future, we may allow the user to do more than twiddle prefs and resize
//  the window. For now, just disable the fun stuff.

- (void)adjustInterfaceForMultiThread
{
    [self syncSaveButton];

    [iArchPopup setEnabled: NO];
    [iThinButton setEnabled: NO];
    [iVerifyButton setEnabled: NO];
    [iOutputText setEnabled: NO];
    [[iMainWindow standardWindowButton: NSWindowCloseButton]
        setEnabled: NO];

    [iMainWindow display];
}

//  adjustInterfaceForSingleThread
// ----------------------------------------------------------------------------

- (void)adjustInterfaceForSingleThread
{
    [self syncSaveButton];

    [iArchPopup setEnabled: iExeIsFat];
    [iThinButton setEnabled: iExeIsFat];
    [iVerifyButton setEnabled: (iSelectedArchCPUType == CPU_TYPE_I386) ||
                               (iSelectedArchCPUType == CPU_TYPE_X86_64)];
    [iOutputText setEnabled: YES];
    [[iMainWindow standardWindowButton: NSWindowCloseButton]
        setEnabled: YES];

    [iMainWindow display];
}

#pragma mark -
//  showProgView
// ----------------------------------------------------------------------------

- (void)showProgView
{
    // Set up the target window frame.
    NSRect  targetWindowFrame   = [iMainWindow frame];
    NSRect  progViewFrame       = [iProgView frame];

    targetWindowFrame.origin.y      -= progViewFrame.size.height;
    targetWindowFrame.size.height   += progViewFrame.size.height;

    // Save the resize masks and apply new ones.
    uint32_t  origMainViewMask    = [iMainView autoresizingMask];
    uint32_t  origProgViewMask    = [iProgView autoresizingMask];

    [iMainView setAutoresizingMask: NSViewMinYMargin];
    [iProgView setAutoresizingMask: NSViewMinYMargin];

    // Set up an animation.
    NSMutableDictionary*    newWindowItem =
        [NSMutableDictionary dictionaryWithCapacity: 8];

    // Standard keys
    [newWindowItem setObject: iMainWindow
        forKey: NSViewAnimationTargetKey];
    [newWindowItem setObject: [NSValue valueWithRect: targetWindowFrame]
        forKey: NSViewAnimationEndFrameKey];

    NSNumber*   effect          = [NSNumber numberWithUnsignedInt:
        (NSXViewAnimationUpdateResizeMasksAtEndEffect       |
        NSXViewAnimationUpdateWindowMinMaxSizesAtEndEffect  |
        NSXViewAnimationPerformSelectorAtEndEffect)];
    NSNumber*   origMainMask    = [NSNumber numberWithUnsignedInt:
        origMainViewMask];
    NSNumber*   origProgMask    = [NSNumber numberWithUnsignedInt:
        origProgViewMask];

    // Custom keys
    [newWindowItem setObject: effect
        forKey: NSXViewAnimationCustomEffectsKey];
    [newWindowItem setObject: [NSArray arrayWithObjects:
        origMainMask, origProgMask, nil]
        forKey: NSXViewAnimationResizeMasksArrayKey];
    [newWindowItem setObject: [NSArray arrayWithObjects:
        iMainView, iProgView, nil]
        forKey: NSXViewAnimationResizeViewsArrayKey];

    // Since we're about to grow the window, first adjust the max height.
    NSSize  maxSize = [iMainWindow contentMaxSize];
    NSSize  minSize = [iMainWindow contentMinSize];

    maxSize.height  += progViewFrame.size.height;
    minSize.height  += progViewFrame.size.height;

    [iMainWindow setContentMaxSize: maxSize];

    // Set the min size after the animation completes.
    NSValue*    minSizeValue    = [NSValue valueWithSize: minSize];

    [newWindowItem setObject: minSizeValue
        forKey: NSXViewAnimationWindowMinSizeKey];

    // Continue processing after the animation completes.
    SEL continueSel = @selector(continueProcessingFile);

    [newWindowItem setObject:
        [NSValue value: &continueSel withObjCType: @encode(SEL)]
        forKey: NSXViewAnimationSelectorKey];
    [newWindowItem setObject: [NSNumber numberWithBool: YES]
        forKey: NSXViewAnimationPerformInNewThreadKey];

    SmoothViewAnimation*    theAnim = [[SmoothViewAnimation alloc]
        initWithViewAnimations: [NSArray arrayWithObject: newWindowItem]];

    [theAnim setDelegate: self];
    [theAnim setDuration: kMainAnimationTime];
    [theAnim setAnimationCurve: NSAnimationLinear];

    // Do the deed.
    [theAnim startAnimation];
    [theAnim autorelease];
}

//  hideProgView:
// ----------------------------------------------------------------------------

- (void)hideProgView: (BOOL)inAnimate
            openFile: (BOOL)inOpenFile
{
    NSRect  targetWindowFrame   = [iMainWindow frame];
    NSRect  progViewFrame       = [iProgView frame];

    targetWindowFrame.origin.y      += progViewFrame.size.height;
    targetWindowFrame.size.height   -= progViewFrame.size.height;

    uint32_t  origMainViewMask    = [iMainView autoresizingMask];
    uint32_t  origProgViewMask    = [iProgView autoresizingMask];

    NSNumber*   origMainMask    = [NSNumber numberWithUnsignedInt:
        origMainViewMask];
    NSNumber*   origProgMask    = [NSNumber numberWithUnsignedInt:
        origProgViewMask];

    [iMainView setAutoresizingMask: NSViewMinYMargin];
    [iProgView setAutoresizingMask: NSViewMinYMargin];

    NSSize  maxSize = [iMainWindow contentMaxSize];
    NSSize  minSize = [iMainWindow contentMinSize];

    maxSize.height  -= progViewFrame.size.height;
    minSize.height  -= progViewFrame.size.height;

    [iMainWindow setContentMinSize: minSize];

    if (inAnimate)
    {
        NSMutableDictionary*    newWindowItem =
            [NSMutableDictionary dictionaryWithCapacity: 10];

        [newWindowItem setObject: iMainWindow
            forKey: NSViewAnimationTargetKey];
        [newWindowItem setObject: [NSValue valueWithRect: targetWindowFrame]
            forKey: NSViewAnimationEndFrameKey];

        uint32_t  effects =
            NSXViewAnimationUpdateResizeMasksAtEndEffect        |
            NSXViewAnimationUpdateWindowMinMaxSizesAtEndEffect  |
            NSXViewAnimationPerformSelectorAtEndEffect;

        if (inOpenFile)
        {
            effects |= NSXViewAnimationOpenFileWithAppAtEndEffect;
            [newWindowItem setObject: iOutputFilePath
                forKey: NSXViewAnimationFilePathKey];
            [newWindowItem setObject: [[NSUserDefaults standardUserDefaults]
                objectForKey: OutputAppKey]
                forKey: NSXViewAnimationAppNameKey];
        }

        // Custom keys
        [newWindowItem setObject:[NSNumber numberWithUnsignedInt: effects]
            forKey: NSXViewAnimationCustomEffectsKey];
        [newWindowItem setObject: [NSArray arrayWithObjects:
            origMainMask, origProgMask, nil]
            forKey: NSXViewAnimationResizeMasksArrayKey];
        [newWindowItem setObject: [NSArray arrayWithObjects:
            iMainView, iProgView, nil]
            forKey: NSXViewAnimationResizeViewsArrayKey];

        SEL adjustSel   = @selector(adjustInterfaceForSingleThread);

        [newWindowItem setObject:
            [NSValue value: &adjustSel withObjCType: @encode(SEL)]
            forKey: NSXViewAnimationSelectorKey];

        NSValue*    maxSizeValue    =
            [NSValue valueWithSize: maxSize];

        [newWindowItem setObject: maxSizeValue
            forKey: NSXViewAnimationWindowMaxSizeKey];

        SmoothViewAnimation*    theAnim = [[SmoothViewAnimation alloc]
            initWithViewAnimations: [NSArray arrayWithObject: newWindowItem]];

        [theAnim setDelegate: self];
        [theAnim setDuration: kMainAnimationTime];
        [theAnim setAnimationCurve: NSAnimationLinear];

        // Do the deed.
        [theAnim startAnimation];
        [theAnim autorelease];
    }
    else
    {
        [iMainWindow setFrame: targetWindowFrame display: NO];
        [iMainWindow setContentMaxSize: maxSize];
        [iMainView setAutoresizingMask: origMainViewMask];
        [iProgView setAutoresizingMask: origProgViewMask];
    }   
}

#pragma mark -
//  thinFile:
// ----------------------------------------------------------------------------
//  Use lipo to separate out the currently selected arch from a unibin.

- (IBAction)thinFile: (id)sender
{
    NSString*   theThinOutputPath   = nil;
    NSString*   archExt             = nil;

    switch (iSelectedArchCPUType)
    {
        case CPU_TYPE_POWERPC:
            archExt  = @"_ppc";
            break;
        case CPU_TYPE_POWERPC64:
            archExt  = @"_ppc64";
            break;
        case CPU_TYPE_I386:
            archExt  = @"_i386";
            break;
        case CPU_TYPE_X86_64:
            archExt  = @"_x86_64";
            break;

        default:
            break;
    }

    if ([[NSUserDefaults standardUserDefaults] boolForKey: AskOutputDirKey])
    {
        NSSavePanel*    thePanel    = [NSSavePanel savePanel];
        NSString*       theFileName =
            [iExeName stringByAppendingString: archExt];

        [thePanel setTreatsFilePackagesAsDirectories: YES];

        if ([thePanel runModalForDirectory: nil
            file: theFileName]  != NSFileHandlingPanelOKButton)
            return;

        theThinOutputPath   = [thePanel filename];
    }
    else
    {
        theThinOutputPath   =
            [[iOutputFilePath stringByDeletingLastPathComponent]
            stringByAppendingPathComponent:
            [iExeName stringByAppendingString: archExt]];
    }

    const NXArchInfo* selectedArchInfo = NXGetArchInfoFromCpuType(
        iSelectedArchCPUType, iSelectedArchCPUSubType);

    if (selectedArchInfo == NULL)
    {
        printf("otx: Unable to get arch info for CPU type %u, subtype %u\n",
            iSelectedArchCPUType, iSelectedArchCPUSubType);
        return;
    }

    NSString*   lipoString  = [NSString stringWithFormat:
        @"lipo \"%@\" -output \"%@\" -thin %s", [iObjectFile path],
        theThinOutputPath, selectedArchInfo->name];

    if (system(UTF8STRING(lipoString)) != 0)
        [self reportError: @"lipo was not found."
               suggestion: @"Please install lipo and try again."];
}

#pragma mark -
//  verifyNops:
// ----------------------------------------------------------------------------
//  Create an instance of xxxProcessor to search for obfuscated nops. If any
//  are found, let user decide to fix them or not.

- (IBAction)verifyNops: (id)sender
{
    switch (iSelectedArchCPUType)
    {
        case CPU_TYPE_I386:
        case CPU_TYPE_X86_64:
        {
            ProcOptions     opts    = {0};
            X86Processor*   theProcessor    =
                [[X86Processor alloc] initWithURL: iObjectFile controller: self
                options: &opts];

            if (!theProcessor)
            {
                fprintf(stderr, "otx: -[AppController verifyNops]: "
                    "unable to create processor.\n");
                return;
            }

            unsigned char** foundList   = nil;
            uint32_t          foundCount  = 0;
            NSAlert*        theAlert    = [[NSAlert alloc] init];

            if ([theProcessor verifyNops: &foundList
                numFound: &foundCount])
            {
                NopList*    theInfo = malloc(sizeof(NopList));

                theInfo->list   = foundList;
                theInfo->count  = foundCount;

                [theAlert addButtonWithTitle: @"Fix"];
                [theAlert addButtonWithTitle: @"Cancel"];
                [theAlert setMessageText: @"Broken nop's found."];
                [theAlert setInformativeText: [NSString stringWithFormat:
                    @"otx found %d broken nop's. Would you like to save "
                    @"a copy of the executable with fixed nop's?",
                    foundCount]];
                [theAlert beginSheetModalForWindow: iMainWindow
                    modalDelegate: self didEndSelector:
                    @selector(nopAlertDidEnd:returnCode:contextInfo:)
                    contextInfo: theInfo];
            }
            else
            {
                [theAlert addButtonWithTitle: @"OK"];
                [theAlert setMessageText: @"No broken nop's."];
                [theAlert setInformativeText: @"The executable is healthy."];
                [theAlert beginSheetModalForWindow: iMainWindow
                    modalDelegate: nil didEndSelector: nil contextInfo: nil];
            }

            [theAlert release];
            [theProcessor release];

            break;
        }

        default:
            break;
    }
}

//  nopAlertDidEnd:returnCode:contextInfo:
// ----------------------------------------------------------------------------
//  Respond to user's decision to fix obfuscated nops.

- (void)nopAlertDidEnd: (NSAlert*)alert
            returnCode: (int)returnCode
           contextInfo: (void*)contextInfo
{
    if (returnCode == NSAlertSecondButtonReturn)
        return;

    if (!contextInfo)
    {
        fprintf(stderr, "otx: tried to fix nops with nil contextInfo\n");
        return;
    }

    NopList*    theNops = (NopList*)contextInfo;

    if (!theNops->list)
    {
        fprintf(stderr, "otx: tried to fix nops with nil NopList.list\n");
        free(theNops);
        return;
    }

    switch (iSelectedArchCPUType)
    {
        case CPU_TYPE_I386:
        {
            ProcOptions     opts    = {0};
            X86Processor*   theProcessor    =
                [[X86Processor alloc] initWithURL: iObjectFile controller: self
                options: &opts];

            if (!theProcessor)
            {
                fprintf(stderr, "otx: -[AppController nopAlertDidEnd]: "
                    "unable to create processor.\n");
                return;
            }

            NSURL* fixedFile = [theProcessor fixNops: theNops toPath: iOutputFilePath];

            [theProcessor release];

            if (fixedFile)
            {
                iIgnoreArch = YES;
                [self newOFile: fixedFile needsPath: YES];
            }
            else
                fprintf(stderr, "otx: unable to fix nops\n");

            break;
        }

        default:
            break;
    }

    free(theNops->list);
    free(theNops);
}

//  validateMenuItem:
// ----------------------------------------------------------------------------

- (BOOL)validateMenuItem: (NSMenuItem*)menuItem
{
    if ([menuItem action] == @selector(attemptToProcessFile:))
    {
        NSUserDefaults* theDefaults = [NSUserDefaults standardUserDefaults];

        if ([theDefaults boolForKey: AskOutputDirKey])
            [menuItem setTitle: [NSString stringWithCString: "Save…"
                      encoding: NSMacOSRomanStringEncoding]];
        else
            [menuItem setTitle: @"Save"];

        return iFileIsValid;
    }

    return YES;
}

//  dupeFileAlertDidEnd:returnCode:contextInfo:
// ----------------------------------------------------------------------------

#pragma mark -
- (void)dupeFileAlertDidEnd: (NSAlert*)alert
                 returnCode: (int)returnCode
                contextInfo: (void*)contextInfo
{
    if (returnCode == NSAlertSecondButtonReturn)
        return;

    [self processFile];
}

#pragma mark -
//  refreshMainWindow
// ----------------------------------------------------------------------------

- (void)refreshMainWindow
{
    [iArchPopup removeAllItems];

    NSFileHandle*   theFileH            =
        [NSFileHandle fileHandleForReadingAtPath: [iObjectFile path]];
    NSData* fileData;

    // Read a generous number of bytes from the executable.
    @try
    {
        fileData = [theFileH readDataOfLength:
            MAX(sizeof(mach_header), sizeof(fat_header)) +
            (sizeof(fat_arch) * 10)];
    }
    @catch (NSException* e)
    {
        fprintf(stderr, "otx: -[AppController syncDescriptionText]: "
            "unable to read from executable file. %s\n",
            UTF8STRING([e reason]));
        return;
    }

    if ([fileData length] < sizeof(mach_header))
    {
        fprintf(stderr, "otx: -[AppController syncDescriptionText]: "
            "truncated executable file.\n");
        return;
    }

    const char* fileBytes   = [fileData bytes];

    iFileArchMagic = *(uint32_t*)fileBytes;

    // Handle non-Mach-O files
    switch (iFileArchMagic)
    {
        case MH_MAGIC:
        case MH_MAGIC_64:
        case MH_CIGAM:
        case MH_CIGAM_64:
        case FAT_MAGIC:
        case FAT_CIGAM:
            break;
        default:
            return;
    }

    iFileIsValid = YES;
    [iPathText setStringValue: [iObjectFile path]];
    [self applyShadowToText: iPathText];

    mach_header mh = *(mach_header*)fileBytes;
    NSMenu*     archMenu    = [iArchPopup menu];
    NSMenuItem* menuItem    = NULL;

    iSelectedArchCPUType    = iHostInfo.cpu_type;
    iSelectedArchCPUSubType = 0;

    if (mh.magic == FAT_MAGIC || mh.magic == FAT_CIGAM)
    {
        fat_header* fhp = (fat_header*)fileBytes;
        fat_arch*   fap = (fat_arch*)(fhp + 1);
        uint32_t      i;

        fat_header  fatHeader   = *fhp;
        fat_arch    fatArch;

#if TARGET_RT_LITTLE_ENDIAN
        swap_fat_header(&fatHeader, OSLittleEndian);
#endif

        memset(iCPUIDs, '\0', sizeof(iCPUIDs));

        for (i = 0; i < fatHeader.nfat_arch; i++, fap += 1)
        {
            fatArch = *fap;

#if TARGET_RT_LITTLE_ENDIAN
            swap_fat_arch(&fatArch, 1, OSLittleEndian);
#endif

            // Save this CPUID for later.
            iCPUIDs[i].type = fatArch.cputype;
            iCPUIDs[i].subtype = fatArch.cpusubtype;

            // Get the arch name for the popup.
            const NXArchInfo* archInfo = NXGetArchInfoFromCpuType(
                fatArch.cputype, fatArch.cpusubtype);
            NSString* archName = [NSString stringWithUTF8String: archInfo->name];

            // Add the menu item with refcon.
            menuItem = [[NSMenuItem alloc] initWithTitle: archName
                action: NULL keyEquivalent: @""];
            [menuItem setTag: (NSInteger)&iCPUIDs[i]];
            [archMenu addItem: menuItem];
        }
    }
    else   // Not a unibin, insert a single item into the (disabled) popup.
    {
        if (mh.magic == MH_CIGAM || mh.magic == MH_CIGAM_64)
             swap_mach_header(&mh, OSHostByteOrder());

        // Get the arch name for the popup.
        const NXArchInfo* archInfo = NXGetArchInfoFromCpuType(
            mh.cputype, mh.cpusubtype);
        NSString* archName = nil;

        if (archInfo != NULL)
            archName = [NSString stringWithUTF8String: archInfo->name];

        if (archName)
        {   // Add the menu item with refcon.
            menuItem = [[NSMenuItem alloc] initWithTitle: archName
                action: NULL keyEquivalent: @""];
            [archMenu addItem: menuItem];
            iSelectedArchCPUType = mh.cputype;
            iSelectedArchCPUSubType = mh.cpusubtype;
        }
    }

    BOOL shouldEnableArch = NO;

    if (!theFileH)
    {
        fprintf(stderr, "otx: -[AppController syncDescriptionText]: "
            "unable to open executable file.\n");
        return;
    }

    // If we just loaded a deobfuscated copy, skip the rest.
    if (iIgnoreArch)
    {
        iIgnoreArch = NO;
        return;
    }

    if (iOutputFileLabel)
    {
        [iOutputFileLabel release];
        iOutputFileLabel    = nil;
    }

    NSString*   tempString;
    NSString*   menuItemTitleToSelect   = NULL;

    iExeIsFat   = NO;

    switch (mh.magic)
    {
        case MH_CIGAM:
        case MH_CIGAM_64:
            swap_mach_header(&mh, OSHostByteOrder());
        case MH_MAGIC:
        case MH_MAGIC_64:
        {
            const NXArchInfo* archInfo = NXGetArchInfoFromCpuType(mh.cputype, mh.cpusubtype);

            if (iSelectedArchCPUType == mh.cputype)
                iSelectedArchCPUSubType = mh.cpusubtype;

            if (archInfo != NULL)
                tempString = [NSString stringWithUTF8String: archInfo->name];

            break;
        }

        default:
            break;
    }

    switch (iFileArchMagic)
    {
        case MH_MAGIC:
            if (iHostInfo.cpu_type == CPU_TYPE_POWERPC)
                [iVerifyButton setEnabled: NO];
            else if (iHostInfo.cpu_type == CPU_TYPE_I386)
                [iVerifyButton setEnabled: YES];

            menuItemTitleToSelect = tempString;

            break;

        case MH_CIGAM:
            if (iHostInfo.cpu_type == CPU_TYPE_POWERPC)
                [iVerifyButton setEnabled: YES];
            else if (iHostInfo.cpu_type == CPU_TYPE_I386)
                [iVerifyButton setEnabled: NO];

            menuItemTitleToSelect = tempString;

            break;

        case MH_MAGIC_64:
            if (iHostInfo.cpu_type == CPU_TYPE_POWERPC)
                [iVerifyButton setEnabled: NO];
            else if (iHostInfo.cpu_type == CPU_TYPE_I386)
                [iVerifyButton setEnabled: YES];

            menuItemTitleToSelect = tempString;

            break;

        case MH_CIGAM_64:
            if (iHostInfo.cpu_type == CPU_TYPE_POWERPC)
                [iVerifyButton setEnabled: YES];
            else if (iHostInfo.cpu_type == CPU_TYPE_I386)
                [iVerifyButton setEnabled: NO];

            menuItemTitleToSelect = tempString;

            break;

        case FAT_MAGIC:
        case FAT_CIGAM:
        {
            fat_header fh = *(fat_header*)fileBytes;

#if __LITTLE_ENDIAN__
            swap_fat_header(&fh, OSHostByteOrder());
#endif

            uint32_t archArraySize = sizeof(fat_arch) * fh.nfat_arch;
            fat_arch* archArray = (fat_arch*)malloc(archArraySize);
            memcpy(archArray, fileBytes + sizeof(fat_header), archArraySize);

#if __LITTLE_ENDIAN__
            swap_fat_arch(archArray, fh.nfat_arch, OSHostByteOrder());
#endif

            fat_arch* fa = NXFindBestFatArch(iHostInfo.cpu_type, iHostInfo.cpu_subtype,
                archArray, fh.nfat_arch);

            if (fa == NULL)
                fa = archArray;

            const NXArchInfo* bestArchInfo = NXGetArchInfoFromCpuType(fa->cputype, fa->cpusubtype);
            NSString* faName = nil;

            if (bestArchInfo != NULL)
                faName = [NSString stringWithFormat: @"%s", bestArchInfo->name];

            if (faName != nil)
            {
                iOutputFileLabel = [NSString stringWithFormat: @"_%@", faName];
                [iVerifyButton setEnabled: (iHostInfo.cpu_type == CPU_TYPE_I386)];
                menuItemTitleToSelect = faName;
            }

            iExeIsFat               = YES;
            shouldEnableArch        = YES;
            tempString              = @"Fat";

            break;
        }

        default:
            iFileIsValid = NO;
            iSelectedArchCPUType = 0;
            tempString = @"Not a Mach-O file";
            [iVerifyButton setEnabled: NO];
            break;
    }

    [iTypeText setStringValue: tempString];
    [self applyShadowToText: iTypeText];

    if (iOutputFileLabel)
        [iOutputFileLabel retain];

    if (menuItemTitleToSelect != NULL)
        [iArchPopup selectItemWithTitle: menuItemTitleToSelect];

    [iThinButton setEnabled: shouldEnableArch];
    [iArchPopup setEnabled: shouldEnableArch];
    [iArchPopup synchronizeTitleAndSelectedItem];
}

//  syncSaveButton
// ----------------------------------------------------------------------------

- (void)syncSaveButton
{
    [iSaveButton setEnabled: (iFileIsValid && !iProcessing &&
        [[iOutputText stringValue] length] > 0)];
}

//  syncOutputText:
// ----------------------------------------------------------------------------

- (IBAction)syncOutputText: (id)sender
{
    if (!iFileIsValid || iProcessing)
        return;

    NSUserDefaults* theDefaults = [NSUserDefaults standardUserDefaults];
    NSString*       theString   = nil;

    if ([theDefaults boolForKey: UseCustomNameKey])
        theString   = [theDefaults objectForKey: OutputFileNameKey];
    else
        theString   = iExeName;

    if (!theString)
        theString   = @"error";

    NSString*   theExt  = [theDefaults objectForKey: OutputFileExtensionKey];

    if (!theExt)
        theExt  = @"error";

    if (iOutputFileLabel)
        theString   = [theString stringByAppendingString: iOutputFileLabel];

    theString   = [theString stringByAppendingPathExtension: theExt];

    if (theString)
        [iOutputText setStringValue: theString];
    else
        [iOutputText setStringValue: @"ERROR.FUKT"];
}

#pragma mark -
//  setupPrefsWindow
// ----------------------------------------------------------------------------

- (void)setupPrefsWindow
{
    // Setup toolbar.
    NSToolbar*  toolbar = [[[NSToolbar alloc]
        initWithIdentifier: OTXPrefsToolbarID] autorelease];

    [toolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
    [toolbar setDelegate: self];

    [iPrefsWindow setToolbar: toolbar];
    [iPrefsWindow setShowsToolbarButton: NO];

    // Load views.
    uint32_t  numViews    = [[toolbar items] count];
    uint32_t  i;

    iPrefsViews     = calloc(numViews, sizeof(NSView*));
    iPrefsViews[0]  = iPrefsGeneralView;
    iPrefsViews[1]  = iPrefsOutputView;

    // Set the General panel as selected.
    [toolbar setSelectedItemIdentifier: PrefsGeneralToolbarItemID];

    // Set window size.
    // Maybe it's just me, but when I have to tell an object something by
    // first asking the object something, I always think there's an instance
    // method missing.
    [iPrefsWindow setFrame: [iPrefsWindow frameRectForContentRect:
        [iPrefsViews[iPrefsCurrentViewIndex] frame]] display: NO];

    for (i = 0; i < numViews; i++)
        [[iPrefsWindow contentView] addSubview: iPrefsViews[i]];
}

//  showPrefs
// ----------------------------------------------------------------------------

- (IBAction)showPrefs: (id)sender
{
    // Set window position only if the window is not already onscreen.
    if (![iPrefsWindow isVisible])
        [iPrefsWindow center];

    [iPrefsWindow makeKeyAndOrderFront: nil];
}

//  switchPrefsViews:
// ----------------------------------------------------------------------------

- (IBAction)switchPrefsViews: (id)sender
{
    NSToolbarItem*  item        = (NSToolbarItem*)sender;
    uint32_t          newIndex    = [item tag];

    if (newIndex == iPrefsCurrentViewIndex)
        return;

    NSRect  targetViewFrame = [iPrefsViews[newIndex] frame];

    // Calculate the new window size.
    NSRect  origWindowFrame     = [iPrefsWindow frame];
    NSRect  targetWindowFrame   = origWindowFrame;

    targetWindowFrame.size.height   = targetViewFrame.size.height;
    targetWindowFrame               =
        [iPrefsWindow frameRectForContentRect: targetWindowFrame];

    float   windowHeightDelta   =
        targetWindowFrame.size.height - origWindowFrame.size.height;

    targetWindowFrame.origin.y  -= windowHeightDelta;

    // Create dictionary for new window size.
    NSMutableDictionary*    newWindowDict =
        [NSMutableDictionary dictionaryWithCapacity: 5];

    [newWindowDict setObject: iPrefsWindow
        forKey: NSViewAnimationTargetKey];
    [newWindowDict setObject: [NSValue valueWithRect: targetWindowFrame]
        forKey: NSViewAnimationEndFrameKey];

    [newWindowDict setObject: [NSNumber numberWithUnsignedInt:
        NSXViewAnimationFadeOutAndSwapEffect]
        forKey: NSXViewAnimationCustomEffectsKey];
    [newWindowDict setObject: iPrefsViews[iPrefsCurrentViewIndex]
        forKey: NSXViewAnimationSwapOldKey];
    [newWindowDict setObject: iPrefsViews[newIndex]
        forKey: NSXViewAnimationSwapNewKey];

    // Create animation.
    SmoothViewAnimation*    windowAnim  = [[SmoothViewAnimation alloc]
        initWithViewAnimations: [NSArray arrayWithObject:
        newWindowDict]];

    [windowAnim setDelegate: self];
    [windowAnim setDuration: kPrefsAnimationTime];
    [windowAnim setAnimationCurve: NSAnimationLinear];

    iPrefsCurrentViewIndex  = newIndex;

    // Do the deed.
    [windowAnim startAnimation];
    [windowAnim autorelease];
}

#pragma mark -
//  cancel:
// ----------------------------------------------------------------------------

- (IBAction)cancel: (id)sender
{
    NSDictionary*   progDict    = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithBool: YES], PRIndeterminateKey,
        @"Cancelling", PRDescriptionKey,
        nil];

    [self reportProgress: progDict];

    gCancel = YES;
}

#pragma mark -
//  nudgeIndeterminateProgBar:
// ----------------------------------------------------------------------------

- (void)nudgeIndeterminateProgBar: (NSTimer*)timer
{
    if ([iProgBar isIndeterminate])
        [iProgBar animate: self];
}

#pragma mark -
#pragma mark ErrorReporter protocol
//  reportError:suggestion:
// ----------------------------------------------------------------------------

- (void)reportError: (NSString*)inMessageText
         suggestion: (NSString*)inInformativeText
{
    NSAlert*    theAlert    = [[NSAlert alloc] init];

    [theAlert addButtonWithTitle: @"OK"];
    [theAlert setMessageText: inMessageText];
    [theAlert setInformativeText: inInformativeText];
    [theAlert beginSheetModalForWindow: iMainWindow
        modalDelegate: nil didEndSelector: nil contextInfo: nil];
    [theAlert release];
}

#pragma mark -
#pragma mark ProgressReporter protocol
//  reportProgress:
// ----------------------------------------------------------------------------

- (void)reportProgress: (NSDictionary*)inDict
{
    if (!inDict)
    {
        fprintf(stderr, "otx: [AppController reportProgress:] nil inDict\n");
        return;
    }

    NSString*   description     = [inDict objectForKey: PRDescriptionKey];
    NSNumber*   indeterminate   = [inDict objectForKey: PRIndeterminateKey];
    NSNumber*   value           = [inDict objectForKey: PRValueKey];

    if (description)
    {
        [iProgText setStringValue: description];
        [self applyShadowToText: iProgText];
    }

    if (value)
        [iProgBar setDoubleValue: [value doubleValue]];

    if (indeterminate)
        [iProgBar setIndeterminate: [indeterminate boolValue]];

    // This is a workaround for the bug mentioned by Mike Ash here:
    // http://mikeash.com/blog/pivot/entry.php?id=25 In our case, it causes
    // the progress bar to freeze when processing more than once per launch.
    // In other words, the first time you process an exe, everything is fine.
    // Subsequent processing of any exe displays a retarded progress bar.
    NSEvent*    pingUI  = [NSEvent otherEventWithType: NSApplicationDefined
        location: NSMakePoint(0, 0) modifierFlags: 0 timestamp: 0
        windowNumber: 0 context: nil subtype: 0 data1: 0 data2: 0];

    [[NSApplication sharedApplication] postEvent: pingUI atStart: NO];
}

#pragma mark -
#pragma mark DropBox delegates
//  dropBox:dragDidEnter:
// ----------------------------------------------------------------------------

- (NSDragOperation)dropBox: (DropBox*)inDropBox
              dragDidEnter: (id <NSDraggingInfo>)inItem
{
    if (inDropBox != iDropBox || iProcessing)
        return NSDragOperationNone;

    NSPasteboard*   pasteBoard  = [inItem draggingPasteboard];

    // Bail if not a file.
    if (![[pasteBoard types] containsObject: NSFilenamesPboardType])
        return NSDragOperationNone;

    NSArray*    files   = [pasteBoard
        propertyListForType: NSFilenamesPboardType];

    // Bail if not a single file.
    if ([files count] != 1)
        return NSDragOperationNone;

    // Bail if a folder.
    NSFileManager*  fileMan = [NSFileManager defaultManager];
    BOOL            isDirectory = NO;
    NSString*       filePath = [files objectAtIndex: 0];
    NSString*       oFilePath = filePath;

    if ([fileMan fileExistsAtPath: filePath
        isDirectory: &isDirectory] == YES)
    {
        if (isDirectory)
        {
            if ([[NSWorkspace sharedWorkspace] isFilePackageAtPath: filePath])
            {
                NSBundle*   exeBundle   = [NSBundle bundleWithPath: filePath];

                oFilePath = [exeBundle executablePath];

                if (oFilePath == nil)
                    return NSDragOperationNone;
            }
            else
                return NSDragOperationNone;
        }
    }
    else
        return NSDragOperationNone;

    // Bail if not a Mach-O file.
    NSFileHandle*   oFile = [NSFileHandle fileHandleForReadingAtPath: oFilePath];
    NSData* fileData;
    uint32_t magic;

    @try
    {
        fileData = [oFile readDataOfLength: sizeof(uint32_t)];
    }
    @catch (NSException* e)
    {
        fprintf(stderr, "otx: -[AppController dropBox:dragDidEnter:]: "
            "unable to read from executable file: %s\n",
            [filePath UTF8String]);
        return NSDragOperationNone;
    }

    magic = *(uint32_t*)[fileData bytes];

    switch (magic)
    {
        case MH_MAGIC:
        case MH_MAGIC_64:
        case MH_CIGAM:
        case MH_CIGAM_64:
        case FAT_MAGIC:
        case FAT_CIGAM:
            break;

        default:
            return NSDragOperationNone;
    }

    NSDragOperation sourceDragMask  = [inItem draggingSourceOperationMask];

    // Bail if modifier keys pressed.
    if (!(sourceDragMask & NSDragOperationLink))
        return NSDragOperationNone;

    return NSDragOperationLink;
}

//  dropBox:didReceiveItem:
// ----------------------------------------------------------------------------

- (BOOL)dropBox: (DropBox*)inDropBox
 didReceiveItem: (id<NSDraggingInfo>)inItem
{
    if (inDropBox != iDropBox || iProcessing)
        return NO;

    NSURL*  theURL  = [NSURL URLFromPasteboard: [inItem draggingPasteboard]];

    if (!theURL)
        return NO;

    if ([[NSWorkspace sharedWorkspace] isFilePackageAtPath: [theURL path]])
        [self newPackageFile: theURL];
    else
        [self newOFile: theURL needsPath: YES];

    return YES;
}

#pragma mark -
#pragma mark NSAnimation delegates
//  animationShouldStart:
// ----------------------------------------------------------------------------
//  We're only hooking this to perform custom effects with NSViewAnimations,
//  not to determine whether to start the animation. For this reason, we
//  always return YES, even if a sanity check fails.

- (BOOL)animationShouldStart: (NSAnimation*)animation
{
    if (![animation isKindOfClass: [NSViewAnimation class]])
        return YES;

    NSArray*    animatedViews   = [(NSViewAnimation*)animation viewAnimations];

    if (!animatedViews)
        return YES;

    NSWindow*   animatingWindow = [[animatedViews objectAtIndex: 0]
        objectForKey: NSViewAnimationTargetKey];

    if (animatingWindow != iMainWindow  &&
        animatingWindow != iPrefsWindow)
        return YES;

    uint32_t i;
    uint32_t numAnimations = [animatedViews count];
    id animObject = nil;

    for (i = 0; i < numAnimations; i++)
    {
        animObject  = [animatedViews objectAtIndex: i];

        if (!animObject)
            continue;

        NSNumber*   effectsNumber   =
            [animObject objectForKey: NSXViewAnimationCustomEffectsKey];

        if (!effectsNumber)
            continue;

        uint32_t  effects = [effectsNumber unsignedIntValue];

        if (effects & NSXViewAnimationSwapAtBeginningEffect)
        {   // Hide/show 2 views.
            NSView* oldView = [animObject
                objectForKey: NSXViewAnimationSwapOldKey];
            NSView* newView = [animObject
                objectForKey: NSXViewAnimationSwapNewKey];

            if (oldView)
                [oldView setHidden: YES];

            if (newView)
                [newView setHidden: NO];
        }
        else if (effects & NSXViewAnimationSwapAtBeginningAndEndEffect)
        {   // Hide a view.
            NSView* oldView = [animObject objectForKey: NSXViewAnimationSwapOldKey];

            if (oldView)
                [oldView setHidden: YES];
        }
        else if (effects & NSXViewAnimationFadeOutAndSwapEffect)
        {  // Fade out a view.
            NSView* oldView = [animObject objectForKey: NSXViewAnimationSwapOldKey];

            if (oldView)
            {   // Create a new animation to fade out the view.
                NSMutableDictionary* newAnimDict = [NSMutableDictionary dictionary];

                [newAnimDict setObject: oldView
                                forKey: NSViewAnimationTargetKey];
                [newAnimDict setObject: NSViewAnimationFadeOutEffect
                                forKey: NSViewAnimationEffectKey];

                SmoothViewAnimation *viewFadeOutAnim = [[SmoothViewAnimation alloc]
                    initWithViewAnimations: [NSArray arrayWithObject: newAnimDict]];

                [viewFadeOutAnim setDuration: [animation duration]];
                [viewFadeOutAnim setAnimationCurve: [animation animationCurve]];
                [viewFadeOutAnim setAnimationBlockingMode: [animation animationBlockingMode]];
                [viewFadeOutAnim setFrameRate: [animation frameRate]];

                // Do the deed.
                [viewFadeOutAnim startAnimation];
                [viewFadeOutAnim autorelease];
            }
        }
    }

    return YES;
}

//  animationDidEnd:
// ----------------------------------------------------------------------------

- (void)animationDidEnd: (NSAnimation*)animation
{
    if (![animation isKindOfClass: [NSViewAnimation class]])
        return;

    NSArray*    animatedViews   = [(NSViewAnimation*)animation viewAnimations];

    if (!animatedViews)
        return;

    NSWindow*   animatingWindow = [[animatedViews objectAtIndex: 0]
        objectForKey: NSViewAnimationTargetKey];

    if (animatingWindow != iMainWindow  &&
        animatingWindow != iPrefsWindow)
        return;

    uint32_t  i;
    uint32_t  numAnimations   = [animatedViews count];
    id      animObject      = nil;

    for (i = 0; i < numAnimations; i++)
    {
        animObject  = [animatedViews objectAtIndex: i];

        if (!animObject)
            continue;

        NSNumber*   effectsNumber   =
            [animObject objectForKey: NSXViewAnimationCustomEffectsKey];

        if (!effectsNumber)
            continue;

        uint32_t  effects = [effectsNumber unsignedIntValue];

        if (effects & NSXViewAnimationSwapAtEndEffect)
        {   // Hide/show 2 views.
            NSView* oldView = [animObject
                objectForKey: NSXViewAnimationSwapOldKey];
            NSView* newView = [animObject
                objectForKey: NSXViewAnimationSwapNewKey];

            if (oldView)
                [oldView setHidden: YES];

            if (newView)
                [newView setHidden: NO];
        }
        else if (effects & NSXViewAnimationSwapAtBeginningAndEndEffect ||
                 effects & NSXViewAnimationFadeOutAndSwapEffect)
        {   // Show a view.
            NSView* newView = [animObject
                objectForKey: NSXViewAnimationSwapNewKey];

            if (newView)
                [newView setHidden: NO];
        }

        // Adjust multiple views' resize masks.
        if (effects & NSXViewAnimationUpdateResizeMasksAtEndEffect)
        {
            NSArray*    masks   = [animObject
                objectForKey: NSXViewAnimationResizeMasksArrayKey];
            NSArray*    views   = [animObject
                objectForKey: NSXViewAnimationResizeViewsArrayKey];

            if (!masks || !views)
                continue;

            NSView*     view;
            NSNumber*   mask;
            uint32_t      i;
            uint32_t      numMasks    = [masks count];
            uint32_t      numViews    = [views count];

            if (numMasks != numViews)
                continue;

            for (i = 0; i < numMasks; i++)
            {
                mask    = [masks objectAtIndex: i];
                view    = [views objectAtIndex: i];

                if (!mask || !view)
                    continue;

                [view setAutoresizingMask: [mask unsignedIntValue]];
            }
        }

        // Update the window's min and/or max sizes.
        if (effects & NSXViewAnimationUpdateWindowMinMaxSizesAtEndEffect)
        {
            NSValue*    minSizeValue    = [animObject objectForKey:
                NSXViewAnimationWindowMinSizeKey];
            NSValue*    maxSizeValue    = [animObject objectForKey:
                NSXViewAnimationWindowMaxSizeKey];

            if (minSizeValue)
                [animatingWindow setContentMinSize:
                    [minSizeValue sizeValue]];

            if (maxSizeValue)
                [animatingWindow setContentMaxSize:
                    [maxSizeValue sizeValue]];
        }

        // Perform a selector. The method's return value is ignored, and the
        // method must take no arguments. For any other kind of method, use
        // NSInvocation instead.
        if (effects & NSXViewAnimationPerformSelectorAtEndEffect)
        {
            NSValue*    selValue    = [animObject objectForKey:
                NSXViewAnimationSelectorKey];

            if (selValue)
            {
                SEL theSel;

                [selValue getValue: &theSel];

                NSNumber*   newThread   = [animObject objectForKey:
                    NSXViewAnimationPerformInNewThreadKey];

                if (newThread)
                    [NSThread detachNewThreadSelector: theSel
                        toTarget: self withObject: nil];
                else
                    [self performSelector: theSel];
            }
        }

        // Open a file in another application.
        if (effects & NSXViewAnimationOpenFileWithAppAtEndEffect)
        {
            NSString*   filePath    = [animObject objectForKey:
                NSXViewAnimationFilePathKey];
            NSString*   appName     = [animObject objectForKey:
                NSXViewAnimationAppNameKey];

            if (filePath && appName)
                [[NSWorkspace sharedWorkspace] openFile: filePath
                    withApplication: appName];
        }
    }
}

#pragma mark -
#pragma mark NSApplication delegates
//  applicationWillFinishLaunching:
// ----------------------------------------------------------------------------

- (void)applicationWillFinishLaunching: (NSNotification*)inNotification
{
    // Set mArchSelector to the host architecture by default. This code was
    // lifted from http://developer.apple.com/technotes/tn/tn2086.html
    mach_msg_type_number_t  infoCount   = HOST_BASIC_INFO_COUNT;

    host_info(mach_host_self(), HOST_BASIC_INFO,
        (host_info_t)&iHostInfo, &infoCount);

    iSelectedArchCPUType    = iHostInfo.cpu_type;

    if (iSelectedArchCPUType != CPU_TYPE_POWERPC    &&
        iSelectedArchCPUType != CPU_TYPE_I386)
    {   // We're running on a machine that doesn't exist.
        fprintf(stderr, "otx: I shouldn't be here...\n");
    }

    // Setup our text shadow ivar.
    iTextShadow = [[NSShadow alloc] init];

    [iTextShadow setShadowColor: [NSColor
        colorWithCalibratedRed: 1.0f green: 1.0f blue: 1.0f alpha: 0.5f]];
    [iTextShadow setShadowOffset: NSMakeSize(0.0f, -1.0f)];
    [iTextShadow setShadowBlurRadius: 0.0f];

    // Setup the windows.
    [self setupPrefsWindow];
    [self setupMainWindow];

    // Show the main window.
    [iMainWindow center];
    [self showMainWindow: self];
}

//  application:openFile:
// ----------------------------------------------------------------------------
//  Open by drag n drop from Finder.

- (BOOL)application: (NSApplication*)sender
           openFile: (NSString*)filename
{
    if ([[NSWorkspace sharedWorkspace] isFilePackageAtPath: filename])
        [self newPackageFile: [NSURL fileURLWithPath: filename]];
    else
        [self newOFile: [NSURL fileURLWithPath: filename] needsPath: YES];

    return YES;
}

//  applicationShouldTerminateAfterLastWindowClosed:
// ----------------------------------------------------------------------------

- (BOOL)applicationShouldTerminateAfterLastWindowClosed: (NSApplication*)inApp
{
    return YES;
}

#pragma mark -
#pragma mark NSControl delegates
//  controlTextDidChange:
// ----------------------------------------------------------------------------

- (void)controlTextDidChange: (NSNotification*)inNotification
{
    switch ([[inNotification object] tag])
    {
        case kOutputTextTag:
            [self syncSaveButton];
            break;

        case kOutputFileBaseTag:
        case kOutputFileExtTag:
            [self syncOutputText: nil];
            break;

        default:
            break;
    }
}

#pragma mark -
#pragma mark NSToolbar delegates
//  toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:
// ----------------------------------------------------------------------------

- (NSToolbarItem*)toolbar: (NSToolbar*)toolbar
    itemForItemIdentifier: (NSString*)itemIdent
willBeInsertedIntoToolbar: (BOOL)willBeInserted
{
    NSToolbarItem*  item = [[[NSToolbarItem alloc]
        initWithItemIdentifier: itemIdent] autorelease];

    if ([itemIdent isEqual: PrefsGeneralToolbarItemID])
    {
        [item setLabel: @"General"];
        [item setImage: [NSImage imageNamed: @"Prefs General Icon"]];
        [item setTarget: self];
        [item setAction: @selector(switchPrefsViews:)];
        [item setTag: 0];
    }
    else if ([itemIdent isEqual: PrefsOutputToolbarItemID])
    {
        [item setLabel: @"Output"];
        [item setImage: [NSImage imageNamed: @"Prefs Output Icon"]];
        [item setTarget: self];
        [item setAction: @selector(switchPrefsViews:)];
        [item setTag: 1];
    }
    else
        item = nil;

    return item;
}

//  toolbarDefaultItemIdentifiers:
// ----------------------------------------------------------------------------

- (NSArray*)toolbarDefaultItemIdentifiers: (NSToolbar*)toolbar
{
    return PrefsToolbarItemsArray;
}

//  toolbarAllowedItemIdentifiers:
// ----------------------------------------------------------------------------

- (NSArray*)toolbarAllowedItemIdentifiers: (NSToolbar*)toolbar
{
    return PrefsToolbarItemsArray;
}

//  toolbarSelectableItemIdentifiers:
// ----------------------------------------------------------------------------

- (NSArray*)toolbarSelectableItemIdentifiers: (NSToolbar*)toolbar
{
    return PrefsToolbarItemsArray;
}

//  validateToolbarItem:
// ----------------------------------------------------------------------------

- (BOOL)validateToolbarItem: (NSToolbarItem*)toolbarItem
{
    return YES;
}

#pragma mark -
#pragma mark NSWindow delegates
//  windowDidResize:
// ----------------------------------------------------------------------------
//  Implemented to avoid artifacts from the NSBox.

- (void)windowDidResize: (NSNotification*)inNotification
{
    if ([inNotification object] == iMainWindow)
        [iMainWindow display];
}

@end
