//
//  HostTransport.m
//  iOSSpectrumFramework
//
//  Created by tom on 2019-07-17.
//

#import <Foundation/Foundation.h>

#import "HostTransport.h"

@implementation HostTransport {
}

@synthesize musicalContextBlock;
@synthesize transportStateBlock;
@synthesize kernelTransportState;

-(int) updateTransportState {
    if (!musicalContextBlock || !transportStateBlock) {
        return -1;
    }
    
    if (musicalContextBlock(
                             &kernelTransportState.currentTempo,
                             &kernelTransportState.timeSignatureNumerator,
                             &kernelTransportState.timeSignatureDenominator,
                             &kernelTransportState.currentBeatPosition,
                             &kernelTransportState.sampleOffsetToNextBeat,
                             &kernelTransportState.currentMeasureDownbeatPosition) == false) {
        return -1;
    }
    
    // Check if it is playing.
    if (transportStateBlock(&kernelTransportState.transportStateFlags, &kernelTransportState.currentSamplePosition, &kernelTransportState.cycleStartBeatPosition, &kernelTransportState.cycleEndBeatPosition) == false) {
        return -1;
    }
    
    return 0;
}


@end
