/*
    SmoothViewAnimation.m

    Adapted from the smooth animation example in
    http://developer.apple.com/documentation/Cocoa/Conceptual/AnimationGuide/AnimationGuide.pdf
    This version caches the window in the new init method. It also no longer
    tweaks the window's origin. Used only vertically, it has not been tested
    with horizontal resizement.

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

#import "SmoothViewAnimation.h"

@implementation SmoothViewAnimation

//  initWithViewAnimations:
// ----------------------------------------------------------------------------

- (id)initWithViewAnimations: (NSArray*)viewAnimations
{
    if ((self = [super initWithViewAnimations: viewAnimations]))
    {
        // Find the first window object in the array.
        uint32_t  numAnimations = [viewAnimations count];
        uint32_t  i;
        id      object;
        Class   windowClass = [NSWindow class];

        for (i = 0; i < numAnimations; i++)
        {
            object = [[viewAnimations objectAtIndex: i]
                objectForKey: NSViewAnimationTargetKey];

            if ([object isKindOfClass: windowClass])
            {
                iWindow = object;
                break;
            }
        }
    }

    return self;
}

//  setCurrentProgress:
// ----------------------------------------------------------------------------

- (void)setCurrentProgress: (NSAnimationProgress)progress
{
    // Call super to update the progress value.
    [super setCurrentProgress: progress];

    if (!iWindow)   // can't do much without a window
        return;

    // Update the window position. As stupid as this looks, [mWindow display]
    // just doesn't cut it.
    [iWindow setFrame: [iWindow frame] display: YES animate: YES];
}

@end
