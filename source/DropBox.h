/*
    DropBox.h

    A subclass of NSBox that implements drag n drop. Drag hiliting mimics
    NSTextField's focus border.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

// Keep these <= 255 please.
#define kBorderWidth            6
#define kTexturedBorderWidth    7

#define kFillAlpha              0.06f

// Alpha values for each one-pixel frame, from outer to inner. The
// outermost frame(s) overlay NSBox's border.
static const float gAlphas[4][kBorderWidth] =
    {{0.9f, 0.7f, 0.5f, 0.3f, 0.2f, 0.0f},    // NSNoBorder
     {0.4f, 0.9f, 0.6f, 0.3f, 0.2f, 0.0f},    // NSLineBorder
     {0.4f, 0.4f, 0.8f, 0.6f, 0.4f, 0.2f},    // NSBezelBorder
     {0.4f, 0.4f, 0.8f, 0.6f, 0.4f, 0.2f}};   // NSGrooveBorder

// Textured windows require a bit more.
static const float gTexturedAlphas[4][kTexturedBorderWidth] =
    {{1.0f, 0.9f, 0.8f, 0.6f, 0.4f, 0.2f, 0.0f},   // NSNoBorder
     {0.4f, 1.0f, 0.8f, 0.6f, 0.4f, 0.2f, 0.0f},   // NSLineBorder
     {0.4f, 0.4f, 1.0f, 0.8f, 0.6f, 0.4f, 0.2f},   // NSBezelBorder
     {0.4f, 0.4f, 1.0f, 0.8f, 0.6f, 0.4f, 0.2f}};  // NSGrooveBorder

// Leopard textured windows require a bit less.
static const float gLeopardTexturedAlphas[4][kTexturedBorderWidth] =
   {{1.0f, 0.8f, 0.6f, 0.4f, 0.2f, 0.0f, 0.0f},    // NSNoBorder
    {0.4f, 0.8f, 0.6f, 0.4f, 0.2f, 0.0f, 0.0f},    // NSLineBorder
    {0.4f, 0.4f, 0.8f, 0.6f, 0.4f, 0.2f, 0.0f},    // NSBezelBorder
    {0.4f, 0.4f, 0.8f, 0.6f, 0.4f, 0.2f, 0.0f}};   // NSGrooveBorder

// ============================================================================

@interface DropBox : NSBox
{
    IBOutlet id iDelegate;

    BOOL        iShowHilite;
    BOOL        iFillRect;
}

- (void)setFillsRect: (BOOL)inFill;

@end

@interface NSObject(DropBoxDelegate)

- (NSDragOperation)dropBox: (DropBox*)inDropBox
              dragDidEnter: (id <NSDraggingInfo>)inItem;
- (void)dropBox: (DropBox*)inDropBox
    dragDidExit: (id <NSDraggingInfo>)inItem;
- (BOOL)dropBox: (DropBox*)inDropBox
 didReceiveItem: (id <NSDraggingInfo>)inItem;

@end