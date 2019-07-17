//
//  ModalAudioUnit.m
//  iOSSpectrumFramework
//
//  Created by tom on 2019-05-28.
//

#import "ModalAudioUnit.h"
#import <AVFoundation/AVFoundation.h>
#import "ElementsDSPKernel.hpp"
#import "BufferedAudioBus.hpp"
#import "AudioBuffers.h"
#import "StateManager.h"

@interface ModalAudioUnit ()

@property AudioBuffers *audioBuffers;
@property StateManager *stateManager;

@property (nonatomic, readwrite) AUParameterTree *parameterTree;

@end

@implementation ModalAudioUnit {
    // C++ members need to be ivars; they would be copied on access if they were properties.
    ElementsDSPKernel _kernel;
    
    NSArray *modInputs;
    NSArray *modOutputs;
    bool loadAsEffect;
}

@synthesize parameterTree = _parameterTree;

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription options:(AudioComponentInstantiationOptions)options error:(NSError **)outError {
    self = [super initWithComponentDescription:componentDescription options:options error:outError];
    
    if (self == nil) {
        return nil;
    }

    if (componentDescription.componentType == 1635085670) {
        printf("Loading as effect");
        loadAsEffect = true;
    } else {
        printf("Loading as instrument");
        loadAsEffect = false;
    }
    
    // Initialize a default format for the busses.
    AVAudioFormat *defaultFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100. channels:2];
    
    // Create a DSP kernel to handle the signal processing.
    _kernel.init(defaultFormat.channelCount, defaultFormat.sampleRate);
    _kernel.useAudioInput = loadAsEffect;
    
    _audioBuffers = [[AudioBuffers alloc] initForAudioUnit:self isEffect:loadAsEffect withFormat:defaultFormat];
    
    // Create a parameter object for the attack time.
    AudioUnitParameterOptions flags = kAudioUnitParameterFlag_IsWritable |
    kAudioUnitParameterFlag_IsReadable;
    
    // MAIN
    
    modInputs = @[
                           @"Direct",
                           @"LFO",
                           @"Envelope",
                           @"Note",
                           @"Velocity",
                           @"Modwheel",
                           @"Out",
                           ];
    
    modOutputs = @[
                            @"Disabled",
                            @"Tune",
                            @"Frequency",
                            @"ExciterEnvShape",
                            @"BowLevel",
                            @"BowTimbre",
                            @"BlowLevel",
                            @"BlowMeta",
                            @"BlowTimbre",
                            @"StrikeLevel",
                            @"StrikeMeta",
                            @"StrikeTimbre",
                            @"ResonatorGeometry",
                            @"ResonatorBrightness",
                            @"ResonatorDamping",
                            @"ResonatorPosition",
                            @"Space",
                            @"LFORate",
                            @"LFOAmount",
                            @"Level",
                            ];
    
    NSArray *bendRange = @[ @"0", @"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"10", @"11", @"12"];
    
    NSArray *inputs = @[ @"Env", @"Res"];
    
    AUParameter *exciterEnvShape = [AUParameterTree createParameterWithIdentifier:@"exciterEnvShape" name:@"Env Shape"
                                                                      address:ElementsParamExciterEnvShape
                                                                          min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *bowLevel = [AUParameterTree createParameterWithIdentifier:@"bowLevel" name:@"Bow Level"
                                                                          address:ElementsParamBowLevel
                                                                              min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                            flags: flags valueStrings:nil dependentParameters:nil];
    
    
    AUParameter *bowTimbre = [AUParameterTree createParameterWithIdentifier:@"bowTimbre" name:@"Bow Timbre"
                                                                   address:ElementsParamBowTimbre
                                                                       min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                     flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *blowLevel = [AUParameterTree createParameterWithIdentifier:@"blowLevel" name:@"Blow Level"
                                                                   address:ElementsParamBlowLevel
                                                                       min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                     flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *blowMeta = [AUParameterTree createParameterWithIdentifier:@"blow" name:@"Blow"
                                                                     address:ElementsParamBlowMeta
                                                                         min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                       flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *blowTimbre = [AUParameterTree createParameterWithIdentifier:@"blowTimbre" name:@"Blow Timbre"
                                                                    address:ElementsParamBlowTimbre
                                                                        min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                      flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *strikeLevel = [AUParameterTree createParameterWithIdentifier:@"strikeLevel" name:@"Strike Level"
                                                                    address:ElementsParamStrikeLevel
                                                                        min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                      flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *strikeMeta = [AUParameterTree createParameterWithIdentifier:@"strike" name:@"Strike"
                                                                   address:ElementsParamStrikeMeta
                                                                       min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                     flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *strikeTimbre = [AUParameterTree createParameterWithIdentifier:@"strikeTimbre" name:@"Strike Timbre"
                                                                     address:ElementsParamStrikeTimbre
                                                                         min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                       flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *inputGain = [AUParameterTree createParameterWithIdentifier:@"inputGain" name:@"Input Gain"
                                                                    address:ElementsParamInputGain
                                                                        min:0.0 max:2.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                      flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *inputDest = [AUParameterTree createParameterWithIdentifier:@"inputDest" name:@"Input Dest"
                                                                    address:ElementsParamInputResonator
                                                                        min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                      flags: flags valueStrings:inputs dependentParameters:nil];
    
    AUParameterGroup *bowGroup = [AUParameterTree createGroupWithIdentifier:@"bow" name:@"Bow" children:@[exciterEnvShape, bowLevel, bowTimbre]];
    
    AUParameterGroup *blowGroup = [AUParameterTree createGroupWithIdentifier:@"blow" name:@"Blow" children:@[blowLevel, blowMeta, blowTimbre]];
    
    AUParameterGroup *strikeGroup = [AUParameterTree createGroupWithIdentifier:@"strike" name:@"Strike" children:@[strikeLevel, strikeMeta, strikeTimbre]];
    
    AUParameterGroup *exciterPage = [AUParameterTree createGroupWithIdentifier:@"exciter" name:@"Exciter" children:@[bowGroup, blowGroup, strikeGroup, inputGain, inputDest]];
    
    AUParameter *geometry = [AUParameterTree createParameterWithIdentifier:@"geometry" name:@"Geometry"
                                                                       address:ElementsParamResonatorGeometry
                                                                           min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                         flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *brightness = [AUParameterTree createParameterWithIdentifier:@"brightness" name:@"Brightness"
                                                                   address:ElementsParamResonatorBrightness
                                                                       min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                     flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *damping = [AUParameterTree createParameterWithIdentifier:@"damping" name:@"Damping"
                                                                   address:ElementsParamResonatorDamping
                                                                       min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                     flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *position = [AUParameterTree createParameterWithIdentifier:@"position" name:@"Position"
                                                                   address:ElementsParamResonatorPosition
                                                                       min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                     flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *space = [AUParameterTree createParameterWithIdentifier:@"space" name:@"Space"
                                                                   address:ElementsParamSpace
                                                                       min:0.0 max:2.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                     flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *volume = [AUParameterTree createParameterWithIdentifier:@"volume" name:@"Volume"
                                                                address:ElementsParamVolume
                                                                    min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                  flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameterGroup *resonatorGroup = [AUParameterTree createGroupWithIdentifier:@"resonator" name:@"Resonator" children:@[geometry, brightness, position, damping, space, volume]];
    
    AUParameterGroup *resonatorPage = [AUParameterTree createGroupWithIdentifier:@"resonator" name:@"Resonator" children:@[resonatorGroup]];
    
    // LFO
    AUParameter *lfoRate = [AUParameterTree createParameterWithIdentifier:@"lfoRate" name:@"LFO Rate"
                                                                  address:ElementsParamLfoRate
                                                                      min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                    flags: flags valueStrings:nil dependentParameters:nil];
    
    NSArray *lfoShapes = @[@"Sine", @"Slope", @"Pulse", @"Stepped", @"Random"];
    
    AUParameter *lfoShape = [AUParameterTree createParameterWithIdentifier:@"lfoShape" name:@"LFO Shape"
                                                                   address:ElementsParamLfoShape
                                                                       min:0.0 max:4.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                     flags: flags valueStrings:lfoShapes dependentParameters:nil];
    
    AUParameter *lfoShapeMod = [AUParameterTree createParameterWithIdentifier:@"lfoShapeMod" name:@"ShapeMod"
                                                                      address:ElementsParamLfoShapeMod
                                                                          min:-1.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameterGroup *lfoSettings = [AUParameterTree createGroupWithIdentifier:@"lfo" name:@"LFO" children:@[lfoRate, lfoShape, lfoShapeMod]];
    
    
    AUParameterGroup *lfoPage = [AUParameterTree createGroupWithIdentifier:@"lfo" name:@"LFO" children:@[lfoSettings]];

    

    
    // Env
    AUParameter *envAttack = [AUParameterTree createParameterWithIdentifier:@"envAttack" name:@"Attack"
                                                                    address:ElementsParamEnvAttack
                                                                        min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                      flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *envDecay = [AUParameterTree createParameterWithIdentifier:@"envDecay" name:@"Decay"
                                                                   address:ElementsParamEnvDecay
                                                                       min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                     flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *envSustain = [AUParameterTree createParameterWithIdentifier:@"envSustain" name:@"Sustain"
                                                                     address:ElementsParamEnvSustain
                                                                         min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                       flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *envRelease = [AUParameterTree createParameterWithIdentifier:@"envRelease" name:@"Release"
                                                                     address:ElementsParamEnvRelease
                                                                         min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                       flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameterGroup *envSettings = [AUParameterTree createGroupWithIdentifier:@"env" name:@"Env" children: @[envAttack, envDecay, envSustain, envRelease]];
    
    AUParameterGroup *modMatrixPage = [AUParameterTree createGroupWithIdentifier:@"modMatrix" name:@"Matrix"
                                                                        children:@[[self modMatrixRule:0 parameterOffset:ElementsParamModMatrixStart],
                                                                                   [self modMatrixRule:1 parameterOffset:ElementsParamModMatrixStart],
                                                                                   [self modMatrixRule:2 parameterOffset:ElementsParamModMatrixStart],
                                                                                   [self modMatrixRule:3 parameterOffset:ElementsParamModMatrixStart],
                                                                                   [self modMatrixRule:4 parameterOffset:ElementsParamModMatrixStart],
                                                                                   [self modMatrixRule:5 parameterOffset:ElementsParamModMatrixStart],
                                                                                   [self modMatrixRule:6 parameterOffset:ElementsParamModMatrixStart],
                                                                                   [self modMatrixRule:7 parameterOffset:ElementsParamModMatrixStart],
                                                                                   [self modMatrixRule:8 parameterOffset:ElementsParamModMatrixStart],
                                                                                   [self modMatrixRule:9 parameterOffset:ElementsParamModMatrixStart],                                                             
                                                                                   ]];
    
    //AUParameterGroup *envModulations = [AUParameterTree createGroupWithIdentifier:@"envMod" name:@"Modulations" children: @[envAmountFM, envAmountHarmonics, envAmountTimbre, envAmountMorph, envAmountLFORate, envAmountLFOAmount]];
    
    AUParameterGroup *envPage = [AUParameterTree createGroupWithIdentifier:@"env" name:@"Env" children:@[envSettings]];
    
    
    AUParameter *modeParam = [AUParameterTree createParameterWithIdentifier:@"mode" name:@"Mode"
                                                                       address:ElementsParamMode min:0.0 max:4.0
                                                                          unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                         flags:flags valueStrings:@[
                                                                                                    @"Modal",
                                                                                                    @"Non-linear",
                                                                                                    @"Chords",
                                                                                                    @"Ominous",
                                                                                                    ]
                                                           dependentParameters:nil];
    
    AUParameter *pitchParam = [AUParameterTree createParameterWithIdentifier:@"pitch" name:@"Pitch"
                                                                     address:ElementsParamPitch
                                                                         min:-12.0 max:12.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                       flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *detuneParam = [AUParameterTree createParameterWithIdentifier:@"detune" name:@"Detune"
                                                                      address:ElementsParamDetune
                                                                          min:-1.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameterGroup *settingsGroup = [AUParameterTree createGroupWithIdentifier:@"settings" name:@"Settings" children:@[modeParam, pitchParam, detuneParam]];
    
    AUParameterGroup *settingsPage = [AUParameterTree createGroupWithIdentifier:@"settings" name:@"Settings" children:@[settingsGroup]];
    
    // Create the parameter tree.
    _parameterTree = [AUParameterTree createTreeWithChildren:@[exciterPage, resonatorPage, lfoPage, envPage, modMatrixPage, settingsPage]];
    
    // Make a local pointer to the kernel to avoid capturing self.
    __block ElementsDSPKernel *instrumentKernel = &_kernel;
    
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
        
        if (param.valueStrings != nil) {
            int index = round(value);
            return param.valueStrings[index];
        } else {
            return [NSString stringWithFormat:@"%.1f", value];
        }
    };
    
    for(int i = 0; i < _parameterTree.allParameters.count; i++) {
        AUParameter *param = _parameterTree.allParameters[i];
        
        switch(param.address) {
            case ElementsParamVolume:
                param.value = 1.0f;
                break;
            case ElementsParamStrikeLevel:
                param.value = 0.3f;
                break;
            case ElementsParamInputGain:
                param.value = 1.0;
                break;
            default:
                param.value = 0.0f;
                break;
        }
    }
    
    _stateManager = [[StateManager alloc] initWithParameterTree:_parameterTree presets:@[NewAUPreset(0, elementsPresets[0].name),
                                                                                         NewAUPreset(1, elementsPresets[1].name),
                                                                                         ]
                                                     presetData: &elementsPresets[0]];
    
    [self setCurrentPreset:[[_stateManager presets] objectAtIndex:0]];
    _kernel.midiProcessor.setCCMap([_stateManager defaultMIDIMap]);
    
    _kernel.setupModulationRules();
    

    self.maximumFramesToRender = 512;
    
    return self;
}

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

-(NSString*) audioUnitShortName {
    return @"Modal";
}

-(void)dealloc {
    // Deallocate resources as required.
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
    
    return YES;
}

- (void)deallocateRenderResources {
    [_audioBuffers deallocateRenderResources];

    [super deallocateRenderResources];
}

#pragma mark - AUAudioUnit (AUAudioUnitImplementation)

- (AUInternalRenderBlock)internalRenderBlock {
    /*
     Capture in locals to avoid ObjC member lookups. If "self" is captured in
     render, we're doing it wrong.
     */
    __block ElementsDSPKernel *state = &_kernel;
    __block BufferedInputBus *input = [_audioBuffers inputBus];
    __block bool isEffect = loadAsEffect;

    return ^AUAudioUnitStatus(
                              AudioUnitRenderActionFlags *actionFlags,
                              const AudioTimeStamp       *timestamp,
                              AVAudioFrameCount           frameCount,
                              NSInteger                   outputBusNumber,
                              AudioBufferList            *outputData,
                              const AURenderEvent        *realtimeEventListHead,
                              AURenderPullInputBlock      pullInputBlock) {
        
        AudioBufferList *inAudioBufferList = 0;
        
        if (isEffect) {
            AudioUnitRenderActionFlags pullFlags = 0;
            AUAudioUnitStatus err = input->pullInput(&pullFlags, timestamp, frameCount, 0, pullInputBlock);
            if (err != 0) { return err; }
            
            inAudioBufferList = input->mutableAudioBufferList;
        }
        
        AudioBufferList *outAudioBufferList = outputData;
        if (outAudioBufferList->mBuffers[0].mData == nullptr) {
            for (UInt32 i = 0; i < outAudioBufferList->mNumberBuffers; ++i) {
                outAudioBufferList->mBuffers[i].mData = inAudioBufferList->mBuffers[i].mData;
            }
        }
        
        state->setBuffers(inAudioBufferList, outAudioBufferList);
        state->processWithEvents(timestamp, frameCount, realtimeEventListHead);
        
        return noErr;
    };
}

#pragma mark- Preset Management

static const UInt8 kElementsNumPresets = 2;
static const FactoryPreset elementsPresets[kElementsNumPresets] =
{
    {
        @"Init",
        @"{\"414\":0,\"421\":0,\"407\":0,\"408\":0,\"415\":0,\"422\":0,\"409\":0,\"416\":0,\"423\":0,\"430\":0,\"0\":0.14999997615814209,\"417\":0,\"424\":0,\"1\":0.22249987721443176,\"431\":0,\"2\":0,\"3\":0.4124998152256012,\"418\":0,\"4\":0.26749992370605469,\"425\":0,\"432\":0,\"5\":0,\"6\":0.66749972105026245,\"419\":0,\"7\":0.27749988436698914,\"426\":0,\"10\":0.58749997615814209,\"8\":0.24249991774559021,\"433\":0,\"9\":0.48499986529350281,\"11\":0.66999977827072144,\"427\":0,\"434\":0,\"12\":0.62749969959259033,\"13\":1.1949994564056396,\"428\":0,\"400\":0,\"20\":-1,\"435\":0,\"14\":0.34250062704086304,\"429\":0,\"401\":0,\"22\":0,\"436\":0,\"15\":1,\"23\":0,\"16\":0,\"437\":0,\"402\":1.1999995708465576,\"24\":0,\"17\":0,\"25\":0,\"18\":0.29749980568885803,\"438\":0,\"403\":13,\"410\":0,\"26\":1,\"19\":1,\"27\":0,\"439\":0,\"404\":0,\"411\":0,\"405\":0,\"412\":0,\"420\":0,\"406\":0,\"413\":0}"
    },
    {
        @"Blank",
        @"{\"414\":0,\"421\":0,\"407\":0,\"408\":0,\"415\":0,\"422\":0,\"409\":0,\"416\":0,\"423\":0,\"430\":0,\"0\":0,\"417\":0,\"424\":0,\"1\":0,\"431\":0,\"2\":0,\"3\":0,\"418\":0,\"4\":0,\"425\":0,\"432\":0,\"5\":0,\"6\":0.30000001192092896,\"419\":0,\"7\":0.21499945223331451,\"426\":0,\"10\":0.29749971628189087,\"8\":0,\"433\":0,\"9\":0.51999980211257935,\"11\":0.39250010251998901,\"427\":0,\"434\":0,\"12\":0.35249999165534973,\"13\":0.43500036001205444,\"428\":0,\"400\":0,\"20\":0,\"435\":0,\"14\":1,\"429\":0,\"401\":0,\"22\":0,\"436\":0,\"15\":0,\"23\":0,\"16\":0,\"437\":0,\"402\":0,\"24\":0,\"17\":0,\"25\":0,\"18\":0,\"438\":0,\"403\":0,\"410\":0,\"26\":1,\"19\":0,\"27\":0,\"439\":0,\"404\":0,\"411\":0,\"405\":0,\"412\":0,\"420\":0,\"406\":0,\"413\":0}",
    }
};

static AUAudioUnitPreset* NewAUPreset(NSInteger number, NSString *name)
{
    AUAudioUnitPreset *aPreset = [AUAudioUnitPreset new];
    aPreset.number = number;
    aPreset.name = name;
    return aPreset;
}

// MARK - state management

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
