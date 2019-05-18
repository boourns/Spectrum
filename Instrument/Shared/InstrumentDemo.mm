/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	An AUAudioUnit subclass implementing a simple instrument.
*/

#import "InstrumentDemo.h"
#import <AVFoundation/AVFoundation.h>
#import "PlaitsDSPKernel.hpp"
#import "BufferedAudioBus.hpp"

@interface AUv3InstrumentDemo ()

@property AUAudioUnitBus *outputBus;
@property AUAudioUnitBusArray *outputBusArray;

@property (nonatomic, readwrite) AUParameterTree *parameterTree;

@end

#pragma mark - AUv3InstrumentDemo : AUAudioUnit

@implementation AUv3InstrumentDemo {
	// C++ members need to be ivars; they would be copied on access if they were properties.
    PlaitsDSPKernel _kernel;
	BufferedOutputBus _outputBusBuffer;
}
@synthesize parameterTree = _parameterTree;

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription options:(AudioComponentInstantiationOptions)options error:(NSError **)outError {
    self = [super initWithComponentDescription:componentDescription options:options error:outError];

    if (self == nil) {
    	return nil;
    }
	
	// Initialize a default format for the busses.
    AVAudioFormat *defaultFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100. channels:2];

	// Create a DSP kernel to handle the signal processing.
	_kernel.init(defaultFormat.channelCount, defaultFormat.sampleRate);
	
	// Create a parameter object for the attack time.
	AudioUnitParameterOptions flags = kAudioUnitParameterFlag_IsWritable |
                                      kAudioUnitParameterFlag_IsReadable |
                                      kAudioUnitParameterFlag_DisplayLogarithmic;
    
	AUParameter *attackParam = [AUParameterTree createParameterWithIdentifier:@"attack" name:@"Attack"
			address:InstrumentParamAttack
			min:0.001 max:10.0 unit:kAudioUnitParameterUnit_Seconds unitName:nil
			flags: flags valueStrings:nil dependentParameters:nil];
	
	// Create a parameter object for the release time.
	AUParameter *releaseParam = [AUParameterTree createParameterWithIdentifier:@"release" name:@"Release"
			address:InstrumentParamRelease
			min:0.001 max:10.0 unit:kAudioUnitParameterUnit_Seconds unitName:nil
			flags: flags valueStrings:nil dependentParameters:nil];
	
	// Initialize the parameter values.
	attackParam.value = 0.01;
	releaseParam.value = 0.1;
	_kernel.setParameter(InstrumentParamAttack, attackParam.value);
	_kernel.setParameter(InstrumentParamRelease, releaseParam.value);
	
	// Create the parameter tree.
    _parameterTree = [AUParameterTree createTreeWithChildren:@[attackParam, releaseParam]];

	// Create the output bus.
	_outputBusBuffer.init(defaultFormat, 2);
	_outputBus = _outputBusBuffer.bus;
	
	// Create the input and output bus arrays.
	_outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self
                                                             busType:AUAudioUnitBusTypeOutput
                                                              busses: @[_outputBus]];

	// Make a local pointer to the kernel to avoid capturing self.
	__block PlaitsDSPKernel *instrumentKernel = &_kernel;

	// implementorValueObserver is called when a parameter changes value.
	_parameterTree.implementorValueObserver = ^(AUParameter *param, AUValue value) {
		instrumentKernel->setParameter(param.address, value);
	};
	
	// implementorValueProvider is called when the value needs to be refreshed.
	_parameterTree.implementorValueProvider = ^(AUParameter *param) {
		return instrumentKernel->getParameter(param.address);
	};
	
	// A function to provide string representations of parameter values.
	_parameterTree.implementorStringFromValueCallback = ^(AUParameter *param, const AUValue *__nullable valuePtr) {
		AUValue value = valuePtr == nil ? param.value : *valuePtr;
	
		switch (param.address) {
			case InstrumentParamAttack:
			case InstrumentParamRelease:
				return [NSString stringWithFormat:@"%.3f", value];
			
			default:
				return @"?";
		}
	};

	self.maximumFramesToRender = 512;
	
	return self;
}

-(void)dealloc {
    // Deallocate resources as required.
}

#pragma mark - AUAudioUnit (Overrides)

- (AUAudioUnitBusArray *)outputBusses {
    return _outputBusArray;
}

- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError {
	if (![super allocateRenderResourcesAndReturnError:outError]) {
		return NO;
	}
	
	_outputBusBuffer.allocateRenderResources(self.maximumFramesToRender);
	
	_kernel.init(self.outputBus.format.channelCount, self.outputBus.format.sampleRate);
	_kernel.reset();
	
	return YES;
}
	
- (void)deallocateRenderResources {
	_outputBusBuffer.deallocateRenderResources();
    
    [super deallocateRenderResources];
}

#pragma mark - AUAudioUnit (AUAudioUnitImplementation)

- (AUInternalRenderBlock)internalRenderBlock {
	/*
		Capture in locals to avoid ObjC member lookups. If "self" is captured in
        render, we're doing it wrong.
	*/
	__block PlaitsDSPKernel *state = &_kernel;
    
    return ^AUAudioUnitStatus(
			 AudioUnitRenderActionFlags *actionFlags,
			 const AudioTimeStamp       *timestamp,
			 AVAudioFrameCount           frameCount,
			 NSInteger                   outputBusNumber,
			 AudioBufferList            *outputData,
			 const AURenderEvent        *realtimeEventListHead,
			 AURenderPullInputBlock      pullInputBlock) {
		
		_outputBusBuffer.prepareOutputBufferList(outputData, frameCount, true);
		state->setBuffers(outputData);		
		state->processWithEvents(timestamp, frameCount, realtimeEventListHead);

		return noErr;
	};
}

@end
