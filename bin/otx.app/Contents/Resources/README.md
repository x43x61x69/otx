otx
===

The Mach-O disassembler.

~~[Original Site](http://otx.osxninja.com/)~~ *(Down)*

![screenshot](https://dl.dropboxusercontent.com/s/tjixljauua7dx7i/otx.png)


Description
-----------

This is an updated version of the original otx, which has the 
following new features:

* Works with new otool came with Xcode 4.2 and above.
* Compatible with Xcode 5.1.
* Based on 10.9 SDK.
* Now use 64bit only binaries.
* Outdated APIs updated.
* Minor bugs fix.
* Pre-compiled binaries included.

If the GUI version crashed on certain targets, consider using the 
CLI version. Usually it works without problems.


Changelog
---------

Build 563:
* Minor GUI updates.

Build 562:
* Update base SDK to 10.9 and Xcode 5.1.

Build 561:
* Initial release.


Issues with OS X Mavericks & Xcode 5
------------------------------------

If otx crashed when calling otool on your OS X Mavericks with Xcode 5 setup, use the following command:

```sh
sudo ln -s /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/otool /Applications/Xcode.app/Contents/Developer/usr/bin/otool
```

You will have to run this every time Xcode updates.


License
-------

The otx project and all original otx source files are in the public domain.