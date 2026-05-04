/*
    SmoothViewAnimation.swift

    Adapted from the smooth animation example in Apple's Animation Guide.
    Forces the window to display at each animation step for smooth resizing.

    This file is in the public domain.
*/

import AppKit

class SmoothViewAnimation: NSViewAnimation {

    private weak var animatedWindow: NSWindow?

    override init(viewAnimations animations: [[NSViewAnimation.Key: Any]]) {
        super.init(viewAnimations: animations)
        for dict in animations {
            if let window = dict[.target] as? NSWindow {
                animatedWindow = window
                break
            }
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // Intercept each animation frame to force the window to display.
    override var currentProgress: NSAnimation.Progress {
        get { super.currentProgress }
        set {
            super.currentProgress = newValue
            guard let window = animatedWindow else { return }
            window.setFrame(window.frame, display: true, animate: false)
        }
    }
}
