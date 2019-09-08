//
//  HostTransport.h
//  Spectrum
//
//  Created by tom on 2019-07-17.
//

#ifndef HostTransport_h
#define HostTransport_h

#import <AVFoundation/AVFoundation.h>

#import "KernelTransportState.h"

@interface HostTransport : NSObject

@property AUHostMusicalContextBlock musicalContextBlock;
@property AUHostTransportStateBlock transportStateBlock;

@property KernelTransportState kernelTransportState;

-(int) updateTransportState;

@end

#endif /* HostTransport_h */
