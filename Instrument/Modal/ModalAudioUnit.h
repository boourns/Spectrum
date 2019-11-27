//
//  ModalAudioUnit.h
//  Spectrum
//
//  Created by tom on 2019-05-28.
//

#ifndef ModalAudioUnit_h
#define ModalAudioUnit_h

#import <AudioToolbox/AudioToolbox.h>
#import <BurnsAudioUnit/MIDIProcessorWrapper.h>

@interface ModalAudioUnit : AUAudioUnit
- (NSArray<NSNumber *> *)drawLFO;
- (bool) lfoDrawingDirty;

- (MIDIProcessorWrapper *) midiProcessor;
- (void) saveDefaults;
- (void) loadFromDefaults;
@end

#endif /* ModalAudioUnit_h */
