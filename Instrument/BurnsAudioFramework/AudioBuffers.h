//
//  AudioBuffers.h
//  Spectrum
//
//  Created by tom on 2019-07-16.
//

#ifndef AudioBuffers_h
#define AudioBuffers_h

#import <AVFoundation/AVFoundation.h>
#import "BufferedAudioBus.hpp"

@interface AudioBuffers : NSObject

@property AUAudioUnitBus *outputBus;
@property AUAudioUnitBusArray *outputBusArray;
@property AUAudioUnitBusArray *inputBusArray;

-(id) initForAudioUnit:(AUAudioUnit*) audioUnit isEffect:(bool) isEffect withFormat:(AVAudioFormat*) format;

- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError withMaximumFrames:(int)maximumFrames;
- (void)deallocateRenderResources;

- (BufferedInputBus *) inputBus;
- (AUAudioUnitBusArray *)inputBusses;
- (AUAudioUnitBusArray *)outputBusses;

@end

#endif /* AudioBuffers_h */
