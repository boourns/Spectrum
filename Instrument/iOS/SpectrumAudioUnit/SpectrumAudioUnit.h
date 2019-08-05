#ifndef SpectrumAudioUnit_h
#define SpectrumAudioUnit_h

#import <AudioToolbox/AudioToolbox.h>

@interface SpectrumAudioUnit : AUAudioUnit
- (NSArray<NSNumber *> *)drawLFO;
- (bool) lfoDrawingDirty;
@end

#endif /* InstrumentDemo_h */
