otx
===

Mach-O disassembler

http://otx.osxninja.com/



Note
----

Apple made changes to the otool after Xcode 4.2, breaking the otx output format.

This repo was mean to fix it, also removed PowerPC arch so it will compile in Xocde 4.

Build number was fixed as well. (288 -> 561)

A pre-compiled binary was also inclouded.


OS X Mavericks & Xcode 5
------------------------

In terminal, use the following command:

```sh
sudo ln -s /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/otool /Applications/Xcode.app/Contents/Developer/usr/bin/otool
```

This will fix the error in *10.9* with Xcode *5.0.1*.
