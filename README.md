otx
===

The Mach-O disassembler.

~~[Original Site](http://otx.osxninja.com/)~~ *(Down)*

![screenshot](https://dl.dropboxusercontent.com/s/tjixljauua7dx7i/otx.png)

[Bug report and feedback][] | [Donation (PayPal)][] | [Follow Me on Twitter (@x43x61x69)][]

[Bug report and feedback]: https://github.com/x43x61x69/OTX/issues "GitHub"
[Follow Me on Twitter (@x43x61x69)]: https://twitter.com/x43x61x69 "Twitter"
[Donation (PayPal)]: https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=N29VTZVBZLZA4

Description
-----------

This is an updated version of the original otx, which has the 
following new features:

* Works with new otool came with Xcode 4.2 and above.
* Compatible with Xcode 5 and Xcode 6 beta 2.
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


Issues with OS X Yosemite, Xcode 6 beta and Swift
-------------------------------------------------

Xcode 6 beta 1 has issues and won't be able to work with otx, while beta 2 seems working. So far, otx can't analyse Swift binaries. You can use otool instead.

If otx crashed when calling otool on your OS X Yosemite with Xcode 6 setup, use the following command: (beta 2)

```sh
	sudo ln -s /Applications/Xcode6-beta2.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/otool /Applications/Xcode6-beta2.app/Contents/Developer/usr/bin/otool
```

You will have to run this every time Xcode updates and change the command accordingly.


License
-------

The otx project and all original otx source files are in the public domain.
