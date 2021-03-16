# Spectrum
AudioUnit ports of popular open source eurorack modules

Available on App Store for iOS: https://apps.apple.com/us/app/spectrum-synthesizer-bundle/id1467384251

# Building

Spectrum depends on two other git repositories to build: BurnsAudioCore and BurnsAudioUnit.  The Spectrum xcode workspace expects these three git repositories to all be siblings in a directory.  So for example,

```Bash
mkdir auv3
cd auv3
git clone git@github.com:boourns/Spectrum.git
git clone git@github.com:boourns/BurnsAudioCore.git
git clone git@github.com:boourns/BurnsAudioUnit.git
open Spectrum/Spectrum.xcworkspace
```

# Exploring the code

Each AudioUnit is broken down into the following components.  You can find the code under the [Instrument](https://github.com/boourns/Spectrum/tree/master/Instrument) subdirectory.  Audio Units with both an Effect and an Instrument version have a Shared folder holding the shared code.  For example, [here](https://github.com/boourns/Spectrum/tree/master/Instrument/iOS/SpectrumAudioUnit) is the code for the Spectrum instrument.

### AudioUnit.mm / AudioUnit.h (Objective-C)
Root AudioUnit class.  Responsible for parameter registration, initializing and managing buffers, instantiating the C++ "kernel" where the DSP code is written.  The `internalRenderBlock` callback is in this class, which the host calls for every render block.

### ViewController (swift)
Provides the UI for the Audio Unit.  The parent class, `BaseAudioUnitViewController`, is provided in BurnsAudioCore and handles connecting the UI to the Audio Unit instance.

### Kernel (C++)
The exciting DSP code.  Reads/writes parameter values into the C++ engine, contains the DSP render block.  In our case it mostly manages the Mutable Instruments code and calls those DSP engines.

# License
MIT
