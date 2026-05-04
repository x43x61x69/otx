/*
    main.swift

    Entry point for both the GUI (otx.app) and CLI (otx) targets.
    The CLI target defines OTX_CLI in SWIFT_ACTIVE_COMPILATION_CONDITIONS.

    This file is in the public domain.
*/

import AppKit

#if OTX_CLI

autoreleasepool {
    let controller = CLIController(args: CommandLine.unsafeArgv,
                                   count: Int32(CommandLine.argc))
    controller?.processFile()
}

#else

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)

#endif
