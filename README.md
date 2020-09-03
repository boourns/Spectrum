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

# License
MIT
