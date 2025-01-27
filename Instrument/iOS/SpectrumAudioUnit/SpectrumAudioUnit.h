#ifndef SpectrumAudioUnit_h
#define SpectrumAudioUnit_h

#import <AudioToolbox/AudioToolbox.h>
#import <BurnsAudioUnit/MIDIProcessorWrapper.h>

@interface SpectrumAudioUnit : AUAudioUnit
- (NSArray<NSNumber *> *)drawLFO;
- (bool) lfoDrawingDirty;

- (MIDIProcessorWrapper *) midiProcessor;
- (void) saveDefaults;
- (void) loadFromDefaults;

@end

#endif /* InstrumentDemo_h */

