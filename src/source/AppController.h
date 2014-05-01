/*
    AppController.h

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "DropBox.h"
#import "ErrorReporter.h"
#import "ProgressReporter.h"

#define kOutputTextTag      100
#define kOutputFileBaseTag  200
#define kOutputFileExtTag   201

#define kPrefsAnimationTime 0.12
#define kMainAnimationTime  0.15

#define NSXViewAnimationCustomEffectsKey    @"NSXViewAnimationCustomEffectsKey"

// There can be only one swap effect per animation in this implementation.
#define NSXViewAnimationSwapAtBeginningEffect               (1 << 0)
#define NSXViewAnimationSwapAtEndEffect                     (1 << 1)
#define NSXViewAnimationSwapAtBeginningAndEndEffect         (1 << 2)
#define NSXViewAnimationFadeOutAndSwapEffect                (1 << 3)

// These effects can be combined.
#define NSXViewAnimationUpdateResizeMasksAtEndEffect        (1 << 10)
#define NSXViewAnimationUpdateWindowMinMaxSizesAtEndEffect  (1 << 11)
#define NSXViewAnimationPerformSelectorAtEndEffect          (1 << 12)
#define NSXViewAnimationOpenFileWithAppAtEndEffect          (1 << 13)

#define NSXViewAnimationSwapOldKey              \
      @"NSXViewAnimationSwapOldKey"             // NSView*
#define NSXViewAnimationSwapNewKey              \
      @"NSXViewAnimationSwapNewKey"             // NSView*

#define NSXViewAnimationResizeMasksArrayKey     \
      @"NSXViewAnimationResizeMasksArrayKey"    // NSArray* (uint32_t)
#define NSXViewAnimationResizeViewsArrayKey     \
      @"NSXViewAnimationResizeViewsArrayKey"    // NSArray* (uint32_t)

#define NSXViewAnimationWindowMinSizeKey        \
      @"NSXViewAnimationWindowMinSizeKey"       // NSValue* (NSSize*)
#define NSXViewAnimationWindowMaxSizeKey        \
      @"NSXViewAnimationWindowMaxSizeKey"       // NSValue* (NSSize*)

#define NSXViewAnimationSelectorKey             \
      @"NSXViewAnimationSelectorKey"            // NSValue* (SEL)
#define NSXViewAnimationPerformInNewThreadKey   \
      @"NSXViewAnimationPerformInNewThreadKey"  // NSNumber* (BOOL)

#define NSXViewAnimationFilePathKey             \
      @"NSXViewAnimationFilePathKey"            // NSString*
#define NSXViewAnimationAppNameKey              \
      @"NSXViewAnimationAppNameKey"             // NSString*

#define OTXPrefsToolbarID           @"OTX Preferences Window Toolbar"
#define PrefsGeneralToolbarItemID   @"General Toolbar Item"
#define PrefsOutputToolbarItemID    @"Output Toolbar Item"

#define PrefsToolbarItemsArray                                  \
    [NSArray arrayWithObjects: PrefsGeneralToolbarItemID,       \
    PrefsOutputToolbarItemID, nil]

typedef struct
{
    cpu_type_t      type;
    cpu_subtype_t   subtype;
}
CPUID;

// ============================================================================

@interface AppController : NSObject<ProgressReporter, ErrorReporter, NSAnimationDelegate, NSToolbarDelegate>
{
@private
// main window
    IBOutlet NSWindow*              iMainWindow;
    IBOutlet NSPopUpButton*         iArchPopup;
    IBOutlet NSButton*              iThinButton;
    IBOutlet NSButton*              iVerifyButton;
    IBOutlet NSTextField*           iOutputText;
    IBOutlet NSTextField*           iOutputLabelText;
    IBOutlet NSTextField*           iPathText;
    IBOutlet NSTextField*           iPathLabelText;
    IBOutlet NSTextField*           iProgText;
    IBOutlet NSTextField*           iTypeText;
    IBOutlet NSTextField*           iTypeLabelText;
    IBOutlet NSProgressIndicator*   iProgBar;
    IBOutlet NSButton*              iSaveButton;
    IBOutlet DropBox*               iDropBox;
    IBOutlet NSView*                iMainView;
    IBOutlet NSView*                iProgView;

// prefs window
    IBOutlet NSWindow*  iPrefsWindow;
    IBOutlet NSView*    iPrefsGeneralView;
    IBOutlet NSView*    iPrefsOutputView;

    NSURL*                  iObjectFile;
    cpu_type_t              iSelectedArchCPUType;
    cpu_subtype_t           iSelectedArchCPUSubType;
    CPUID                   iCPUIDs[4];     // refcons for iArchPopup
    uint32_t                  iFileArchMagic;
    BOOL                    iFileIsValid;
    BOOL                    iIgnoreArch;
    BOOL                    iExeIsFat;
    BOOL                    iProcessing;
    NSString*               iExeName;
    NSString*               iOutputFileLabel;
    NSString*               iOutputFileName;
    NSString*               iOutputFilePath;
    NSView**                iPrefsViews;
    uint32_t                  iPrefsCurrentViewIndex;
    host_basic_info_data_t  iHostInfo;
    NSShadow*               iTextShadow;
    NSTimer*                iIndeterminateProgBarMainThreadTimer;
}

// main window
- (void)setupMainWindow;
- (IBAction)showMainWindow: (id)sender;
- (void)applyShadowToText: (NSTextField*)inText;
- (IBAction)selectArch: (id)sender;
- (IBAction)openExe: (id)sender;
- (IBAction)syncOutputText: (id)sender;
- (IBAction)attemptToProcessFile: (id)sender;
- (IBAction)cancel: (id)sender;
- (void)processFile;
- (void)continueProcessingFile;
- (void)adjustInterfaceForMultiThread;
- (void)adjustInterfaceForSingleThread;
- (void)processingThreadDidFinish: (NSString*)result;
- (void)nudgeIndeterminateProgBar: (NSTimer*)timer;

- (IBAction)thinFile: (id)sender;
- (IBAction)verifyNops: (id)sender;

- (void)refreshMainWindow;
- (void)syncSaveButton;

- (void)newPackageFile: (NSURL*)inPackageFile;
- (void)newOFile: (NSURL*)inOFile
       needsPath: (BOOL)inNeedsPath;
- (void)nopAlertDidEnd: (NSAlert*)alert
            returnCode: (int)returnCode
           contextInfo: (void*)contextInfo;
- (void)showProgView;
- (void)hideProgView: (BOOL)inAnimate
            openFile: (BOOL)inOpenFile;

- (void)dupeFileAlertDidEnd: (NSAlert*)alert
                 returnCode: (int)returnCode
                contextInfo: (void*)contextInfo;

// prefs window
- (void)setupPrefsWindow;
- (IBAction)showPrefs: (id)sender;
- (IBAction)switchPrefsViews: (id)sender;

@end
