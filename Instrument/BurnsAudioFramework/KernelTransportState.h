//
//  KernelTransportState.h
//  Spectrum
//
//  Created by tom on 2019-07-18.
//

#ifndef KernelTransportState_h
#define KernelTransportState_h

#import <AVFoundation/AVFoundation.h>

typedef struct  {
    double currentTempo;
    double currentBeatPosition;
    double timeSignatureNumerator;
    long timeSignatureDenominator;
    long sampleOffsetToNextBeat;
    double currentMeasureDownbeatPosition;
    
    AUHostTransportStateFlags transportStateFlags;
    double currentSamplePosition;
    double cycleStartBeatPosition;
    double cycleEndBeatPosition;
} KernelTransportState;

#endif /* KernelTransportState_h */
