//
//  GranularAudioUnit.h
//  Spectrum
//
//  Created by tom on 2019-06-12.
//

#ifndef GranularAudioUnit_h
#define GranularAudioUnit_h

#import <AudioToolbox/AudioToolbox.h>
#import <BurnsAudioUnit/MIDIProcessorWrapper.h>


@interface GranularAudioUnit : AUAudioUnit
- (NSArray<NSNumber *> *)drawLFO;
- (bool) lfoDrawingDirty;

- (MIDIProcessorWrapper *) midiProcessor;
- (void) saveDefaults;
- (void) loadFromDefaults;

- (void) reloadCloudsBufferFromState:(NSDictionary *)state;
- (void) storeCloudsBufferInState:(NSMutableDictionary *)state;

@end

#endif /* GranularAudioUnit_h */
