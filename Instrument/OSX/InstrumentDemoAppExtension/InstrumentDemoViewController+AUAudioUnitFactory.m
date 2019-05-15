/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	`InstrumentDemoViewController` is the app extension's principal class, responsible for creating both the audio unit and its view.
*/

#import "InstrumentDemoViewController+AUAudioUnitFactory.h"

@implementation InstrumentDemoViewController (AUAudioUnitFactory)

- (AUv3InstrumentDemo *) createAudioUnitWithComponentDescription:(AudioComponentDescription) desc error:(NSError **)error {
    self.audioUnit = [[AUv3InstrumentDemo alloc] initWithComponentDescription:desc error:error];
    return self.audioUnit;
}

@end
