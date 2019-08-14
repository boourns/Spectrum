//
//  MIDIProcessorWrapper.h
//  Spectrum
//
//  Created by tom on 2019-08-12.
//

#ifndef MIDIProcessorWrapper_h
#define MIDIProcessorWrapper_h

#import <AVFoundation/AVFoundation.h>

@interface MIDIProcessorWrapper : NSObject

- (void) setMIDIProcessor: (void *) midiProcessor;
- (void) onSettingsUpdate: (void(^)(void))callback;

- (NSDictionary *) settings;
- (void) updateSettings: (NSDictionary *) settings;

- (int) channel;
- (void) setChannel: (int) ch;
@end

#endif /* MIDIProcessorWrapper_h */
