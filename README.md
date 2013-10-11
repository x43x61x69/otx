otx
===

Mach-O disassembler

http://otx.osxninja.com/



Note
====

Apple made changes to the otool after Xcode 4.2, breaking the otx output format.

This repo was mean to fix it, also removed PowerPC arch so it will compile in Xocde 4.

Build number was fixed as well. (288 -> 561)

A pre-compiled binary was also inclouded.


OS X Mavericks & Xcode 5
------------------------

If you don't want to modify the source, you can copy "otool" from:

  /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin

to

  /Applications/Xcode.app/Contents/Developer/usr/bin

This will fix the error in 10.9 with Xcode 5.0.1.
