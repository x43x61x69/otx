/*
    DropBox.m

    A subclass of NSBox that implements drag n drop. Drag hiliting mimics
    NSTextField's focus border.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "DropBox.h"

@implementation DropBox

//  awakeFromNib
// ----------------------------------------------------------------------------

- (void)awakeFromNib
{
    [self registerForDraggedTypes:
        [NSArray arrayWithObject: NSFilenamesPboardType]];
}

//  setFillsRect:
// ----------------------------------------------------------------------------
//  Call setFillsRect: YES to draw the entire frame hilited with kFillAlpha.

- (void)setFillsRect: (BOOL)inFill
{
    iFillRect   = inFill;
}

//  draggingEntered:
// ----------------------------------------------------------------------------

- (NSDragOperation)draggingEntered: (id<NSDraggingInfo>)sender
{
    NSDragOperation dragOp  = NSDragOperationNone;

    if (iDelegate && [iDelegate respondsToSelector:
        @selector(dropBox:dragDidEnter:)])
        dragOp  = [iDelegate dropBox: self dragDidEnter: sender];

    if (dragOp == NSDragOperationNone)
        return dragOp;

    iShowHilite = YES;
    [self setNeedsDisplay: YES];

    return dragOp;
}

//  draggingExited:
// ----------------------------------------------------------------------------

- (void)draggingExited: (id<NSDraggingInfo>)sender
{
    iShowHilite = NO;
    [self setNeedsDisplay: YES];

    if (iDelegate && [iDelegate respondsToSelector:
        @selector(dropBox:dragDidExit:)])
        [iDelegate dropBox: self dragDidExit: sender];
}

//  performDragOperation:
// ----------------------------------------------------------------------------

- (BOOL)performDragOperation: (id<NSDraggingInfo>)sender
{
    iShowHilite = NO;
    [self setNeedsDisplay: YES];

    if (!iDelegate)
        return NO;

    if ([iDelegate respondsToSelector: @selector(dropBox:didReceiveItem:)])
        return [iDelegate dropBox: self didReceiveItem: sender];

    return NO;
}

//  drawRect:
// ----------------------------------------------------------------------------

- (void)drawRect: (NSRect)rect
{
    [super drawRect: rect];

    if (!iShowHilite)
        return;

    NSBorderType    borderType  = [self borderType];

    if (borderType < 0 || borderType > 3)
    {
        fprintf(stderr, "DropBox: invalid NSBorderType: %d\n", borderType);
        return;
    }

    NSWindow*   window  = [self window];
    UInt8       borderWidth;
    BOOL        isTextured;

    if (window && ([window styleMask] & NSTexturedBackgroundWindowMask))
    {
        isTextured  = YES;
        borderWidth = kTexturedBorderWidth;
    }
    else
    {
        isTextured  = NO;
        borderWidth = kBorderWidth;
    }

    NSRect      innerRect   = rect;
    NSColor*    baseColor   = [NSColor keyboardFocusIndicatorColor];
    NSColor*    color;
    UInt8       i;

    for (i = 0; i < borderWidth; i++)
    {
        color = [baseColor colorWithAlphaComponent: (isTextured) ?
            ((OS_IS_POST_TIGER) ? gLeopardTexturedAlphas[borderType][i] :
            gTexturedAlphas[borderType][i]) : gAlphas[borderType][i]];
        [color set];
        NSFrameRectWithWidthUsingOperation(
            innerRect, 1.0f, NSCompositeSourceOver);
        innerRect = NSInsetRect(innerRect, 1.0f, 1.0f);
    }

    if (iFillRect)
    {
        if (borderType == NSNoBorder || borderType == NSLineBorder)
            innerRect = NSInsetRect(innerRect, -1.0f, -1.0f);

        color = [baseColor colorWithAlphaComponent: kFillAlpha];
        [color set];
        NSRectFillUsingOperation(innerRect, NSCompositeSourceOver);
    }
}

@end
