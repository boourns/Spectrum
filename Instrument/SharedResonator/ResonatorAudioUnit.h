//
//  ResonatorAudioUnit.h
//  iOSSpectrumFramework
//
//  Created by tom on 2019-06-27.
//

#ifndef ResonatorAudioUnit_h
#define ResonatorAudioUnit_h

#import <AudioToolbox/AudioToolbox.h>
#import "MIDIProcessorWrapper.h"

@interface ResonatorAudioUnit : AUAudioUnit
- (NSArray<NSNumber *> *)drawLFO;
- (bool) lfoDrawingDirty;

- (MIDIProcessorWrapper *) midiProcessor;
- (void) saveDefaults;
- (void) loadFromDefaults;

@end

#endif /* ResonatorAudioUnit_h */
