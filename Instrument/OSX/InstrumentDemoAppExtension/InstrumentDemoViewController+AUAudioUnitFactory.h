/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	`InstrumentDemoViewController` is the app extension's principal class, responsible for creating both the audio unit and its view.
*/

#ifndef InstrumentDemoOSXViewController_AUAudioUnitFactory_h
#define InstrumentDemoOSXViewController_AUAudioUnitFactory_h

#import <CoreAudioKit/AUViewController.h>
#import <InstrumentDemoFramework/InstrumentDemoFramework.h>

@interface InstrumentDemoViewController (AUAudioUnitFactory) <AUAudioUnitFactory>

@end

#endif /* InstrumentDemoViewController_AUAudioUnitFactory_h */
