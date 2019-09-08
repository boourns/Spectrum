//
//  OrgoneAudioUnit.h
//  Orgone
//
//  Created by tom on 2019-09-07.
//

#import <AudioToolbox/AudioToolbox.h>
#import "MIDIProcessorWrapper.h"

@interface OrgoneAudioUnit : AUAudioUnit

- (NSArray<NSNumber *> *)drawLFO;
- (bool) lfoDrawingDirty;

- (MIDIProcessorWrapper *) midiProcessor;
- (void) saveDefaults;
- (void) loadFromDefaults;

@end
