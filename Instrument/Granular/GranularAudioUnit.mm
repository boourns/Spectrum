//
//  GranularAudioUnit.m
//  iOSSpectrumFramework
//
//  Created by tom on 2019-06-12.
//

#import "GranularAudioUnit.h"
#import <AVFoundation/AVFoundation.h>
#import "CloudsDSPKernel.hpp"
#import "BufferedAudioBus.hpp"
#import "AudioBuffers.h"
#import "StateManager.h"
#import "HostTransport.h"

@interface GranularAudioUnit ()

@property AudioBuffers *audioBuffers;
@property StateManager *stateManager;
@property HostTransport *hostTransport;

@property (nonatomic, readwrite) AUParameterTree *parameterTree;

@end

@implementation GranularAudioUnit {
    // C++ members need to be ivars; they would be copied on access if they were properties.
    CloudsDSPKernel _kernel;
}

@synthesize parameterTree = _parameterTree;

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription options:(AudioComponentInstantiationOptions)options error:(NSError **)outError {
    self = [super initWithComponentDescription:componentDescription options:options error:outError];
    
    if (self == nil) {
        return nil;
    }
    
    // Initialize a default format for the busses.
    AVAudioFormat *defaultFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100. channels:2];
    
    _audioBuffers = [[AudioBuffers alloc] initForAudioUnit:self isEffect:true withFormat:defaultFormat];
    
    // Create a DSP kernel to handle the signal processing.
    _kernel.init(defaultFormat.channelCount, defaultFormat.sampleRate);
    
    // Create a parameter object for the attack time.
    AudioUnitParameterOptions flags = kAudioUnitParameterFlag_IsWritable |
    kAudioUnitParameterFlag_IsReadable;
    
    // MAIN
    
    NSArray *modeStrings = @[
                           @"Granular",
                           @"Time Stretch",
                           @"Looping Delay",
                           @"Spectral",
                           ];
    
    // Main
    AUParameter *position = [AUParameterTree createParameterWithIdentifier:@"position" name:@"Position"
                                                                  address:CloudsParamPosition
                                                                      min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                    flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *mode = [AUParameterTree createParameterWithIdentifier:@"mode" name:@"Mode"
                                                                   address:CloudsParamMode
                                                                       min:0.0 max:3.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                     flags: flags valueStrings:modeStrings dependentParameters:nil];
    
    
    AUParameter *size = [AUParameterTree createParameterWithIdentifier:@"size" name:@"Size"
                                                                   address:CloudsParamSize
                                                                       min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                     flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *density = [AUParameterTree createParameterWithIdentifier:@"density" name:@"Density"
                                                                   address:CloudsParamDensity
                                                                       min:-1.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                     flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *texture = [AUParameterTree createParameterWithIdentifier:@"texture" name:@"Texture"
                                                                   address:CloudsParamTexture
                                                                       min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                     flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *inputGain = [AUParameterTree createParameterWithIdentifier:@"inputGain" name:@"Input Gain"
                                                                  address:CloudsParamInputGain
                                                                      min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                    flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *freeze = [AUParameterTree createParameterWithIdentifier:@"freeze" name:@"Freeze"
                                                                                                                                                                                             address:CloudsParamFreeze
                                                                                                                                                                                                 min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                                                                                                                                               flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *trigger = [AUParameterTree createParameterWithIdentifier:@"trigger" name:@"Trigger"
                                                                                                                                                                                                                                                                                                                        address:CloudsParamTrigger
                                                                                                                                                                                                                                                                                                                            min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                                                                                                                                                                                                                                                                          flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameterGroup *main = [AUParameterTree createGroupWithIdentifier:@"main" name:@"Main" children:@[mode, position, size, density, texture, inputGain, freeze, trigger]];

    AUParameter *wet = [AUParameterTree createParameterWithIdentifier:@"wet" name:@"Dry/Wet"
                                                                  address:CloudsParamWet
                                                                      min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                    flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *stereo = [AUParameterTree createParameterWithIdentifier:@"stereo" name:@"Stereo"
                                                                  address:CloudsParamStereo
                                                                      min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                    flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *feedback = [AUParameterTree createParameterWithIdentifier:@"feedback" name:@"Feedback"
                                                                  address:CloudsParamFeedback
                                                                      min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                    flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *reverb = [AUParameterTree createParameterWithIdentifier:@"reverb" name:@"Reverb"
                                                                  address:CloudsParamReverb
                                                                      min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                    flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *volume = [AUParameterTree createParameterWithIdentifier:@"volume" name:@"Volume"
                                                                 address:CloudsParamVolume
                                                                     min:0.0 max:1.5 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                   flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameterGroup *blend = [AUParameterTree createGroupWithIdentifier:@"blend" name:@"Blend" children:@[wet, stereo, feedback, reverb, volume]];

    AUParameterGroup *mainPage = [AUParameterTree createGroupWithIdentifier:@"main" name:@"Main" children:@[main, blend]];
    
    // LFO
    AUParameter *lfoRate = [AUParameterTree createParameterWithIdentifier:@"lfoRate" name:@"LFO Rate"
                                                                  address:CloudsParamLfoRate
                                                                      min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                    flags: flags valueStrings:nil dependentParameters:nil];
    
    NSArray *lfoShapes = @[@"Sine", @"Slope", @"Pulse", @"Stepped", @"Random"];
    
    AUParameter *lfoShape = [AUParameterTree createParameterWithIdentifier:@"lfoShape" name:@"LFO Shape"
                                                                   address:CloudsParamLfoShape
                                                                       min:0.0 max:4.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                     flags: flags valueStrings:lfoShapes dependentParameters:nil];
    
    AUParameter *lfoShapeMod = [AUParameterTree createParameterWithIdentifier:@"lfoShapeMod" name:@"ShapeMod"
                                                                      address:CloudsParamLfoShapeMod
                                                                          min:-1.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *lfoTempoSync = [AUParameterTree createParameterWithIdentifier:@"lfoTempoSync" name:@"Tempo Sync"
                                                                       address:CloudsParamLfoTempoSync
                                                                           min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                         flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *lfoResetPhase = [AUParameterTree createParameterWithIdentifier:@"lfoResetPhase" name:@"Reset Phase"
                                                                        address:CloudsParamLfoResetPhase
                                                                            min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                          flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *lfoKeyReset = [AUParameterTree createParameterWithIdentifier:@"lfoKeyReset" name:@"Key Reset"
                                                                      address:CloudsParamLfoKeyReset
                                                                          min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *padX = [AUParameterTree createParameterWithIdentifier:@"padX" name:@"Pad X"
                                                               address:CloudsParamPadX
                                                                   min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                 flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *padY = [AUParameterTree createParameterWithIdentifier:@"padY" name:@"Pad Y"
                                                               address:CloudsParamPadY
                                                                   min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                 flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *padGate = [AUParameterTree createParameterWithIdentifier:@"padGate" name:@"Pad Gate"
                                                                  address:CloudsParamPadGate
                                                                      min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                    flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameterGroup *lfoPage = [AUParameterTree createGroupWithIdentifier:@"lfo" name:@"LFO" children:@[lfoRate, lfoShape, lfoShapeMod, lfoTempoSync, lfoResetPhase, lfoKeyReset, padX, padY, padGate]];
    
    // Env
    AUParameter *envAttack = [AUParameterTree createParameterWithIdentifier:@"envAttack" name:@"Attack"
                                                                    address:CloudsParamEnvAttack
                                                                        min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                      flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *envDecay = [AUParameterTree createParameterWithIdentifier:@"envDecay" name:@"Decay"
                                                                   address:CloudsParamEnvDecay
                                                                       min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                     flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *envSustain = [AUParameterTree createParameterWithIdentifier:@"envSustain" name:@"Sustain"
                                                                     address:CloudsParamEnvSustain
                                                                         min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                       flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *envRelease = [AUParameterTree createParameterWithIdentifier:@"envRelease" name:@"Release"
                                                                     address:CloudsParamEnvRelease
                                                                         min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                       flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameterGroup *envPage = [AUParameterTree createGroupWithIdentifier:@"env" name:@"Env" children: @[envAttack, envDecay, envSustain, envRelease]];
    
    //AUParameterGroup *envModulations = [AUParameterTree createGroupWithIdentifier:@"envMod" name:@"Modulations" children: @[envAmountFM, envAmountHarmonics, envAmountTimbre, envAmountMorph, envAmountLFORate, envAmountLFOAmount]];
    
    AUParameter *pitchParam = [AUParameterTree createParameterWithIdentifier:@"pitch" name:@"Pitch"
                                                                     address:CloudsParamPitch
                                                                         min:-12.0 max:12.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                       flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *detuneParam = [AUParameterTree createParameterWithIdentifier:@"detune" name:@"Detune"
                                                                      address:CloudsParamDetune
                                                                          min:-1.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameterGroup *settingsGroup = [AUParameterTree createGroupWithIdentifier:@"settings" name:@"Settings" children:@[ pitchParam, detuneParam]];
    
    AUParameterGroup *settingsPage = [AUParameterTree createGroupWithIdentifier:@"settings" name:@"Settings" children:@[settingsGroup]];
    
    AUParameterGroup *modMatrixPage = [AUParameterTree createGroupWithIdentifier:@"modMatrix" name:@"Matrix"
                                                                        children:@[[self modMatrixRule:0 parameterOffset:CloudsParamModMatrixStart],
                                                                                   [self modMatrixRule:1 parameterOffset:CloudsParamModMatrixStart],
                                                                                   [self modMatrixRule:2 parameterOffset:CloudsParamModMatrixStart],
                                                                                   [self modMatrixRule:3 parameterOffset:CloudsParamModMatrixStart],
                                                                                   [self modMatrixRule:4 parameterOffset:CloudsParamModMatrixStart],
                                                                                   [self modMatrixRule:5 parameterOffset:CloudsParamModMatrixStart],
                                                                                   [self modMatrixRule:6 parameterOffset:CloudsParamModMatrixStart],
                                                                                   [self modMatrixRule:7 parameterOffset:CloudsParamModMatrixStart],
                                                                                   [self modMatrixRule:8 parameterOffset:CloudsParamModMatrixStart],
                                                                                   [self modMatrixRule:9 parameterOffset:CloudsParamModMatrixStart],
                                                                                   
                                                                                   ]];
    
    // Create the parameter tree.
    _parameterTree = [AUParameterTree createTreeWithChildren:@[mainPage, lfoPage, envPage, settingsPage, modMatrixPage]];
    
    // Make a local pointer to the kernel to avoid capturing self.
    __block CloudsDSPKernel *instrumentKernel = &_kernel;
    
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
        
        char valueString[32];
        
        if (instrumentKernel->getParameterValueString(param.address, value, &valueString[0])) {
            return [NSString stringWithUTF8String:valueString];
        } else {
            if (param.valueStrings != nil) {
                int index = round(value);
                return param.valueStrings[index];
            } else {
                return [NSString stringWithFormat:@"%.1f", value];
            }
        }
    };
    
    for(int i = 0; i < _parameterTree.allParameters.count; i++) {
        AUParameter *param = _parameterTree.allParameters[i];
        
        switch(param.address) {
            case CloudsParamInputGain:
                param.value = 1.0f;
                break;
            case CloudsParamPosition:
                param.value = 0.3f;
                break;
            case CloudsParamSize:
                param.value = 0.5f;
                break;
            case CloudsParamWet:
                param.value = 0.3;
                break;
            case CloudsParamReverb:
                param.value = 0.3;
                break;
            case CloudsParamVolume:
                param.value = 1.0;
                break;
            default:
                param.value = 0.0f;
                break;
        }
    }
    
    self.maximumFramesToRender = 512;
    
    _hostTransport = [HostTransport alloc];
    
    _stateManager = [[StateManager alloc] initWithParameterTree:_parameterTree presets:@[NewAUPreset(0, cloudsPresets[0].name),
                                                                                         NewAUPreset(1, cloudsPresets[1].name),
                                                                                         ]
                                                     presetData: &cloudsPresets[0]];
    
    [self setCurrentPreset:[[_stateManager presets] objectAtIndex:0]];
    
    _kernel.midiProcessor.setCCMap([_stateManager defaultMIDIMap]);
    
    _kernel.setupModulationRules();
    
    return self;
}

NSArray *modInputs = @[
                       @"Direct",
                       @"LFO",
                       @"Envelope",
                       @"Note",
                       @"Velocity",
                       @"Modwheel",
                       @"PadX",
                       @"PadY",
                       @"Pad Gate",
                       @"Out",
                       @"Aftertouch",
                       @"Sustain",
                       ];

NSArray *modOutputs = @[
                        @"Disabled",
                        @"Tune",
                        @"Frequency",
                        @"Position",
                        @"Size",
                        @"Density",
                        @"Texture",
                        @"Trigger",
                        @"Freeze",
                        @"Feedback",
                        @"Wet",
                        @"Reverb",
                        @"Stereo",
                        @"LFORate",
                        @"LFOAmount",
                        @"Volume",
                        ];

- (AUParameterGroup *)modMatrixRule:(int) ruleNumber parameterOffset:(int) parameterOffset {
    
    
    
    AudioUnitParameterOptions flags = kAudioUnitParameterFlag_IsWritable |
    kAudioUnitParameterFlag_IsReadable;
    
    int start = parameterOffset + (ruleNumber*4);
    
    AUParameter *input1Param = [AUParameterTree createParameterWithIdentifier:[NSString stringWithFormat:@"rule%iIn1", ruleNumber+1]
                                                                         name:@"Input 1"
                                                                      address:start + 0
                                                                          min:0.0 max:((float) [modInputs count])
                                                                         unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:modInputs dependentParameters:nil];
    
    AUParameter *input2Param = [AUParameterTree createParameterWithIdentifier:[NSString stringWithFormat:@"rule%iIn2", ruleNumber+1]
                                                                         name:@"Input 2"
                                                                      address:start + 1
                                                                          min:0.0 max:((float) [modInputs count])
                                                                         unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:modInputs dependentParameters:nil];
    
    AUParameter *depthParam = [AUParameterTree createParameterWithIdentifier:[NSString stringWithFormat:@"rule%iDepth", ruleNumber+1]
                                                                        name:@"Depth"
                                                                     address:start + 2
                                                                         min:-2.0 max:2.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                       flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *outParam = [AUParameterTree createParameterWithIdentifier:[NSString stringWithFormat:@"rule%io=Out", ruleNumber+1]
                                                                      name:@"Out"
                                                                   address:start + 3
                                                                       min:0.0 max:((float) [modOutputs count])
                                                                      unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                     flags: flags valueStrings:modOutputs dependentParameters:nil];
    
    return [AUParameterTree createGroupWithIdentifier:[NSString stringWithFormat:@"rule%i", ruleNumber+1]
                                                 name:[NSString stringWithFormat:@"Rule %i", ruleNumber+1]
                                             children:@[input1Param, input2Param, depthParam, outParam]];
}


-(void)dealloc {
    // Deallocate resources as required.
}

-(NSString*) audioUnitShortName {
    return @"Gran";
}

#pragma mark - AUAudioUnit (Overrides)

- (AUAudioUnitBusArray *)inputBusses {
    return [_audioBuffers inputBusses];
}

- (AUAudioUnitBusArray *)outputBusses {
    return [_audioBuffers outputBusses];
}


- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError {
    if (![super allocateRenderResourcesAndReturnError:outError]) {
        return NO;
    }
    
    if (![_audioBuffers allocateRenderResourcesAndReturnError:outError withMaximumFrames:self.maximumFramesToRender]) {
        self.renderResourcesAllocated = NO;
        
        return NO;
    }
    
    _kernel.init(_audioBuffers.outputBus.format.channelCount, _audioBuffers.outputBus.format.sampleRate);
    _kernel.midiAllNotesOff();
    
    if (self.musicalContextBlock) {
        [_hostTransport setMusicalContextBlock: self.musicalContextBlock];
    }
    
    if (self.transportStateBlock) {
        [_hostTransport setTransportStateBlock: self.transportStateBlock];
    }
    
    return YES;
}

- (void)deallocateRenderResources {
    [_audioBuffers deallocateRenderResources];
    
    _hostTransport = nil;

    [super deallocateRenderResources];
}

#pragma mark - AUAudioUnit (AUAudioUnitImplementation)

- (AUInternalRenderBlock)internalRenderBlock {
    /*
     Capture in locals to avoid ObjC member lookups. If "self" is captured in
     render, we're doing it wrong.
     */
    __block CloudsDSPKernel *state = &_kernel;
    __block BufferedInputBus *input = [_audioBuffers inputBus];
    
    __block HostTransport *hostTransport = _hostTransport;

    return ^AUAudioUnitStatus(
                              AudioUnitRenderActionFlags *actionFlags,
                              const AudioTimeStamp       *timestamp,
                              AVAudioFrameCount           frameCount,
                              NSInteger                   outputBusNumber,
                              AudioBufferList            *outputData,
                              const AURenderEvent        *realtimeEventListHead,
                              AURenderPullInputBlock      pullInputBlock) {
        
        AudioUnitRenderActionFlags pullFlags = 0;
        AUAudioUnitStatus err = input->pullInput(&pullFlags, timestamp, frameCount, 0, pullInputBlock);
        if (err != 0) { return err; }
        
        AudioBufferList *inAudioBufferList = input->mutableAudioBufferList;
        
        AudioBufferList *outAudioBufferList = outputData;
        if (outAudioBufferList->mBuffers[0].mData == nullptr) {
            for (UInt32 i = 0; i < outAudioBufferList->mNumberBuffers; ++i) {
                outAudioBufferList->mBuffers[i].mData = inAudioBufferList->mBuffers[i].mData;
            }
        }
        
        [hostTransport updateTransportState];
        state->setTransportState([hostTransport kernelTransportState]);
        
        state->setBuffers(inAudioBufferList, outAudioBufferList);
        state->processWithEvents(timestamp, frameCount, realtimeEventListHead);
        
        return noErr;
    };
}

#pragma mark- Preset Management

static const UInt8 kCloudsNumPresets = 2;
static const FactoryPreset cloudsPresets[kCloudsNumPresets] =
{
        {
            @"Init",
            @"{\"414\":0,\"421\":0,\"407\":0,\"408\":0,\"415\":0,\"422\":1.239999532699585,\"409\":0,\"416\":6,\"423\":4,\"430\":0.67999964952468872,\"0\":0.19707056879997253,\"417\":0,\"424\":8,\"1\":0.27749577164649963,\"431\":9,\"2\":0,\"3\":0.70249950885772705,\"418\":0.75000011920928955,\"4\":0,\"425\":0,\"432\":0,\"5\":0.30000001192092896,\"6\":0.44499987363815308,\"419\":5,\"7\":0,\"426\":1.0199995040893555,\"10\":0,\"8\":1,\"433\":0,\"9\":0,\"11\":0,\"427\":11,\"434\":0,\"12\":0.30000001192092896,\"13\":0.5,\"400\":0,\"20\":0,\"428\":7,\"435\":0,\"14\":0.41499996185302734,\"429\":0,\"401\":0,\"22\":0,\"436\":0,\"23\":0,\"16\":12,\"437\":0,\"402\":0.13999910652637482,\"24\":0,\"17\":0,\"25\":0,\"18\":0.94999945163726807,\"438\":0,\"403\":1,\"410\":0,\"26\":1,\"19\":0,\"439\":0,\"404\":0,\"411\":0,\"405\":0,\"412\":0,\"420\":7,\"406\":0,\"413\":0}"
        },
    {
        @"Blank",
        @"{\"414\":0,\"421\":0,\"407\":0,\"408\":0,\"415\":0,\"422\":0,\"409\":0,\"416\":0,\"423\":0,\"430\":0,\"0\":0,\"417\":0,\"424\":0,\"1\":0,\"431\":0,\"2\":0,\"3\":0,\"418\":0,\"4\":0,\"425\":0,\"432\":0,\"5\":0.30000001192092896,\"6\":0.30000001192092896,\"419\":0,\"7\":0,\"426\":0,\"10\":0,\"8\":1,\"433\":0,\"9\":0,\"11\":0,\"427\":0,\"434\":0,\"12\":0.30000001192092896,\"13\":0.5,\"400\":0,\"20\":0,\"428\":0,\"435\":0,\"14\":0,\"429\":0,\"401\":0,\"22\":0,\"436\":0,\"23\":0,\"16\":0,\"437\":0,\"402\":0,\"24\":0,\"17\":0,\"25\":0,\"18\":0,\"438\":0,\"403\":0,\"410\":0,\"26\":1,\"19\":0,\"439\":0,\"404\":0,\"411\":0,\"405\":0,\"412\":0,\"420\":0,\"406\":0,\"413\":0}"
    },
};

static AUAudioUnitPreset* NewAUPreset(NSInteger number, NSString *name)
{
    AUAudioUnitPreset *aPreset = [AUAudioUnitPreset new];
    aPreset.number = number;
    aPreset.name = name;
    return aPreset;
}

- (NSDictionary *)fullState {
    return [_stateManager fullStateWithDictionary:[super fullState]];
}

- (void)setFullState:(NSDictionary *)fullState {
    [_stateManager setFullState:fullState];
    
    _kernel.setupModulationRules();
}

// MARK - preset management

- (NSArray*)factoryPresets {
    return [_stateManager presets];
}

- (AUAudioUnitPreset *)currentPreset {
    return [_stateManager currentPreset];
}

- (void)setCurrentPreset:(AUAudioUnitPreset *)currentPreset {
    [_stateManager setCurrentPreset:currentPreset];
    
    _kernel.setupModulationRules();
}

@end
