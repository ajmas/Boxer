![Boxer](http://boxerapp.com/static/images/gloves_96.png)

XXX 1

#### Some notes on building Boxer

The Boxer Xcode project is designed to be a painless one-click build. Here's a quick rundown of how it's set up:

#### Build requirements

To build the Boxer project you will need macOS 10.14 or higher and XCode 11.3 or higher.

All necessary frameworks and other dependencies are included in the Boxer repo, or as git submodules, so the project itself is all you'll need.

After cloning, run:

```bash
git submodule update --init --recursive
```

#### Build Targets

The Boxer project has three targets:

- "Boxer": the standard Boxer emulator you know and love, as seen on http://boxerapp.com. This is almost certainly the one you'll want to use.

- "Boxer Standalone": a cut-down version of Boxer that wraps up a gamebox into a single unified app. Game importing and settings UIs have been stripped out of this version, and it will only launch the gamebox that bundled inside it. This target is not meant to be used on its own: instead it's a build component for…

- "Boxer Bundler": a graphical tool for converting gameboxes into standalone apps using its own self-contained copy of Boxer Standalone.

#### Build Configurations

The Boxer target has 2 build configurations: Release and Debug. Both of them compile fully optimized 64-bit binaries using the LLVM compiler. Debug works almost exactly the same as Release but turns on console debug messages and additional error-checking.

#### App requirements

Boxer and Boxer Standalone both run on macOS 10.14.4 and above, while Boxer Bundler runs on OS X 10.8 and above.

OSX 10.5 and PowerPC support has been removed from the Boxer master branch: if you need these, use the older "leopard_legacy" maintenance branch from http://github.com/alunbestor/Boxer/tree/leopard_legacy/.

#### Having trouble?

If you have any problems building the Boxer project, or questions about Boxer's code, please get in touch with me at abestor@boxerapp.com and I'll help out as best I can.

#### License

The project is licensed using [GPLv2](./LICENSE). Originally developed
by Alun Bestor and other contributors.
