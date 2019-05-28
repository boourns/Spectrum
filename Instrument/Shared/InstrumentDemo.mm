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
    kAudioUnitParameterFlag_IsReadable;
    
    // MAIN
    
    NSArray *pitchRange = @[
                            @"-12", @"-11", @"-10", @"-9", @"-8", @"-7", @"-6", @"-5", @"-4", @"-3", @"-2", @"-1", @"0", @"+1", @"+2", @"+3", @"+4", @"+5", @"+6", @"+7", @"+8", @"+9", @"+10", @"+11", @"+12"
                            ];
    
    NSArray *bendRange = @[ @"0", @"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"10", @"11", @"12"];
    
    AUParameter *algorithmParam = [AUParameterTree createParameterWithIdentifier:@"algorithm" name:@"Algorithm"
                                                                         address:PlaitsParamAlgorithm min:0.0 max:15.4
                                                                            unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                           flags:flags valueStrings:@[
                                                                                                      @"Analog",
                                                                                                      @"Waveshape",
                                                                                                      @"FM",
                                                                                                      @"Grain",
                                                                                                      @"Additive",
                                                                                                      @"Wavetable",
                                                                                                      @"Chord",
                                                                                                      @"Speech",
                                                                                                      @"Swarm",
                                                                                                      @"Noise",
                                                                                                      @"Particle",
                                                                                                      @"String",
                                                                                                      @"Modal",
                                                                                                      @"Bass",
                                                                                                      @"Snare",
                                                                                                      @"Hi Hat",
                                                                                                      ]
                                                             dependentParameters:nil];
    
    AUParameter *pitchParam = [AUParameterTree createParameterWithIdentifier:@"pitch" name:@"Pitch"
                                                                      address:PlaitsParamPitch
                                                                          min:0.0 max:24.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:pitchRange dependentParameters:nil];
    
    AUParameter *detuneParam = [AUParameterTree createParameterWithIdentifier:@"detune" name:@"Detune"
                                                                      address:PlaitsParamDetune
                                                                          min:-1.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *timbreParam = [AUParameterTree createParameterWithIdentifier:@"timbre" name:@"Timbre"
                                                                      address:PlaitsParamTimbre
                                                                          min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *harmonicsParam = [AUParameterTree createParameterWithIdentifier:@"harmonics" name:@"Harmonics"
                                                                         address:PlaitsParamHarmonics
                                                                             min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                           flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *morphParam = [AUParameterTree createParameterWithIdentifier:@"morph" name:@"Morph"
                                                                     address:PlaitsParamMorph
                                                                         min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                       flags: flags valueStrings:nil dependentParameters:nil];
    
    // LPG
    
    AUParameter *decayParam = [AUParameterTree createParameterWithIdentifier:@"decay" name:@"Decay"
                                                                     address:PlaitsParamDecay
                                                                         min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                       flags: flags valueStrings:nil dependentParameters:nil];
    
    
    AUParameter *colourParam = [AUParameterTree createParameterWithIdentifier:@"colour" name:@"Colour"
                                                                      address:PlaitsParamLPGColour
                                                                          min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:nil dependentParameters:nil];
    
    // Voice Settings

    
    AUParameter *slopParam = [AUParameterTree createParameterWithIdentifier:@"slop" name:@"Slop"
                                                                      address:PlaitsParamSlop
                                                                          min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:nil dependentParameters:nil];
    
    
    
    AUParameter *polyphonyParam = [AUParameterTree createParameterWithIdentifier:@"polyphony" name:@"Polyphony" address:PlaitsParamPolyphony min:0.0 max:7.0 unit:kAudioUnitParameterUnit_Generic unitName:nil flags:flags valueStrings:@[@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8"]
                                                             dependentParameters:nil];
    
    AUParameter *unisonParam = [AUParameterTree createParameterWithIdentifier:@"unison" name:@"Unison" address:PlaitsParamUnison min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil flags:flags valueStrings:@[@"Off", @"On"]
                                                          dependentParameters:nil];
    
    AUParameter *pitchBendRangeParam = [AUParameterTree createParameterWithIdentifier:@"pitchRange" name:@"Bend Range"
                                                                     address:PlaitsParamPitchBendRange
                                                                         min:0.0 max:12.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                                flags: flags valueStrings:bendRange dependentParameters:nil];

    
    // Amp
    AUParameter *volumeParam = [AUParameterTree createParameterWithIdentifier:@"volume" name:@"Volume"
                                                                      address:PlaitsParamVolume
                                                                          min:0.0 max:2.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:nil dependentParameters:nil];
    
    NSArray *ampSources = @[ @"LPG", @"ADSR", @"Drone"];
    AUParameter *ampSourceParam = [AUParameterTree createParameterWithIdentifier:@"ampSource" name:@"Amp Source"
                                                                              address:PlaitsParamAmpSource
                                                                                  min:0.0 max:2.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                                flags: flags valueStrings:ampSources dependentParameters:nil];
    
    
    AUParameter *leftSourceParam = [AUParameterTree createParameterWithIdentifier:@"leftSource" name:@"Left Source"
                                                                    address:PlaitsParamLeftSource
                                                                        min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                      flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *rightSourceParam = [AUParameterTree createParameterWithIdentifier:@"rightSource" name:@"Right Source"
                                                                    address:PlaitsParamRightSource
                                                                        min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                      flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *panParam = [AUParameterTree createParameterWithIdentifier:@"pan" name:@"Pan"
                                                                           address:PlaitsParamPan
                                                                               min:-1.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                             flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *panSpreadParam = [AUParameterTree createParameterWithIdentifier:@"panSpread" name:@"Pan Spread"
                                                                           address:PlaitsParamPanSpread
                                                                               min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                             flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *lfoRate = [AUParameterTree createParameterWithIdentifier:@"lfoRate" name:@"LFO Rate"
                                                                         address:PlaitsParamLfoRate
                                                                             min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                           flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *lfoShape = [AUParameterTree createParameterWithIdentifier:@"lfoShape" name:@"LFO Shape"
                                                                  address:PlaitsParamLfoShape
                                                                      min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                    flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *lfoAmountFM = [AUParameterTree createParameterWithIdentifier:@"lfoAmountFM" name:@"FM Amount"
                                                                   address:PlaitsParamLfoAmountFM
                                                                       min:0.0 max:120.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                     flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *lfoAmountHarmonics = [AUParameterTree createParameterWithIdentifier:@"lfoAmountHarmonics" name:@"Harmonics Amount"
                                                                      address:PlaitsParamLfoAmountHarmonics
                                                                          min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *lfoAmountTimbre = [AUParameterTree createParameterWithIdentifier:@"lfoAmountTimbre" name:@"Timbre Amount"
                                                                      address:PlaitsParamLfoAmountTimbre
                                                                          min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *lfoAmountMorph = [AUParameterTree createParameterWithIdentifier:@"lfoAmountMorph" name:@"Morph Amount"
                                                                      address:PlaitsParamLfoAmountMorph
                                                                          min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *envAttack = [AUParameterTree createParameterWithIdentifier:@"envAttack" name:@"Attack"
                                                                         address:PlaitsParamEnvAttack
                                                                             min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                           flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *envDecay = [AUParameterTree createParameterWithIdentifier:@"envDecay" name:@"Decay"
                                                                    address:PlaitsParamEnvDecay
                                                                        min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                      flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *envSustain = [AUParameterTree createParameterWithIdentifier:@"envSustain" name:@"Sustain"
                                                                    address:PlaitsParamEnvSustain
                                                                        min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                      flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *envRelease = [AUParameterTree createParameterWithIdentifier:@"envRelease" name:@"Release"
                                                                    address:PlaitsParamEnvRelease
                                                                        min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                      flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameterGroup *primaryGroup = [AUParameterTree createGroupWithIdentifier:@"main" name:@"Main" children:@[algorithmParam, harmonicsParam, timbreParam, morphParam]];
    
    AUParameterGroup *lpgGroup = [AUParameterTree createGroupWithIdentifier:@"main2" name:@"Main" children:@[pitchParam, detuneParam, decayParam, colourParam]];
    
    AUParameterGroup *voiceGroup = [AUParameterTree createGroupWithIdentifier:@"voice" name:@"Voice" children:@[unisonParam, polyphonyParam, slopParam, pitchBendRangeParam]];
    
    AUParameterGroup *outGroup = [AUParameterTree createGroupWithIdentifier:@"out" name:@"Out" children:@[volumeParam, ampSourceParam, leftSourceParam, rightSourceParam, panParam, panSpreadParam]];
    
    AUParameterGroup *lfoSettings = [AUParameterTree createGroupWithIdentifier:@"lfo" name:@"LFO" children:@[lfoRate, lfoShape]];
    AUParameterGroup *lfoModulations = [AUParameterTree createGroupWithIdentifier:@"lfoModulation" name:@"LFO Modulation" children:@[lfoAmountFM, lfoAmountHarmonics, lfoAmountTimbre, lfoAmountMorph]];
    
    AUParameterGroup *envSettings = [AUParameterTree createGroupWithIdentifier:@"env" name:@"Env" children: @[envAttack, envDecay, envSustain, envRelease]];
    
    AUParameterGroup *mainPage = [AUParameterTree createGroupWithIdentifier:@"main" name:@"Main" children:@[primaryGroup, lpgGroup]];

    AUParameterGroup *lfoPage = [AUParameterTree createGroupWithIdentifier:@"lfo" name:@"LFO" children:@[lfoSettings, lfoModulations]];

    AUParameterGroup *envPage = [AUParameterTree createGroupWithIdentifier:@"env" name:@"Env" children:@[envSettings]];
    
    AUParameterGroup *settingsPage = [AUParameterTree createGroupWithIdentifier:@"settings" name:@"Settings" children:@[voiceGroup, outGroup]];
    
    // Create the parameter tree.
    _parameterTree = [AUParameterTree createTreeWithChildren:@[mainPage, lfoPage, envPage, settingsPage]];
    
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
            case PlaitsParamTimbre:
            case PlaitsParamHarmonics:
            case PlaitsParamMorph:
            case PlaitsParamDecay:
            case PlaitsParamDetune:
                return [NSString stringWithFormat:@"%.1f", value];
                
            default:
                return @"?"; // TODO for all params
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
    __block BufferedOutputBus *outputBusBuffer = &_outputBusBuffer;
    
    return ^AUAudioUnitStatus(
                              AudioUnitRenderActionFlags *actionFlags,
                              const AudioTimeStamp       *timestamp,
                              AVAudioFrameCount           frameCount,
                              NSInteger                   outputBusNumber,
                              AudioBufferList            *outputData,
                              const AURenderEvent        *realtimeEventListHead,
                              AURenderPullInputBlock      pullInputBlock) {
        
        outputBusBuffer->prepareOutputBufferList(outputData, frameCount, true);
        state->setBuffers(outputData);
        state->processWithEvents(timestamp, frameCount, realtimeEventListHead);
        
        return noErr;
    };
}

#pragma mark - fullstate - must override in order to call parameter observer when fullstate is reset.
- (NSDictionary *)fullState {
    NSMutableDictionary *state = [[NSMutableDictionary alloc] initWithDictionary:super.fullState];
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    
    for(int i = 0; i < _parameterTree.allParameters.count; i++) {
        params[@(_parameterTree.allParameters[i].address)] = @(_parameterTree.allParameters[i].value);
    }
    
    state[@"data"] = [NSKeyedArchiver archivedDataWithRootObject:params];
    return state;
}

- (void)setFullState:(NSDictionary *)fullState {
    NSData *data = (NSData *)fullState[@"data"];
    NSDictionary *params = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    for(int i = 0; i < _parameterTree.allParameters.count; i++) {
        NSNumber *savedValue = [params objectForKey: @(_parameterTree.allParameters[i].address)];
        if (savedValue != nil) {
            _parameterTree.allParameters[i].value = savedValue.floatValue;
        }
    }
}

@end
