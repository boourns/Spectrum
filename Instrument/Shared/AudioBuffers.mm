//
//  AudioBuffers.m
//  iOSSpectrumApp
//
//  Created by tom on 2019-07-16.
//

#import <Foundation/Foundation.h>
#import "AudioBuffers.h"

@implementation AudioBuffers {
    BufferedInputBus _inputBus;
}

-(void) initForAudioUnit:(AUAudioUnit*) audioUnit isEffect:(bool) isEffect withFormat:(AVAudioFormat*) format {
    _inputBus.init(format, 8);
    
    // Create the input and output busses.
    if (isEffect) {
        _inputBusArray  = [[AUAudioUnitBusArray alloc] initWithAudioUnit:audioUnit busType:AUAudioUnitBusTypeInput busses: @[_inputBus.bus]];
    }
    
    _outputBus = [[AUAudioUnitBus alloc] initWithFormat:format error:nil];
    // Create the input and output bus arrays.
    
    _outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:audioUnit busType:AUAudioUnitBusTypeOutput busses: @[_outputBus]];
}

- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError withMaximumFrames:(int)maximumFrames{
    if (self.outputBus.format.channelCount != _inputBus.bus.format.channelCount) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_FailedInitialization userInfo:nil];
        }
        
        return NO;
    }

    _inputBus.allocateRenderResources(maximumFrames);
    return YES;
}

- (void)deallocateRenderResources {
    _inputBus.deallocateRenderResources();
}

- (BufferedInputBus *)inputBus {
    return &_inputBus;
}

- (AUAudioUnitBusArray *)inputBusses {
    return _inputBusArray;
}

- (AUAudioUnitBusArray *)outputBusses {
    return _outputBusArray;
}


@end
