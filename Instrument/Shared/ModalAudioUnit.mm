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

@interface ModalAudioUnit ()

@property AUAudioUnitBus *outputBus;
@property AUAudioUnitBusArray *outputBusArray;
@property AUAudioUnitBusArray *inputBusArray;

@property (nonatomic, readwrite) AUParameterTree *parameterTree;

@end

@implementation ModalAudioUnit {
    // C++ members need to be ivars; they would be copied on access if they were properties.
    ElementsDSPKernel _kernel;
    BufferedInputBus _inputBus;

    AUAudioUnitPreset   *_currentPreset;
    NSInteger           _currentFactoryPresetIndex;
    NSArray<AUAudioUnitPreset *> *_presets;
    
    NSMutableDictionary *midiCCMap;
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
                                                                        min:0.0 max:1.5 unit:kAudioUnitParameterUnit_Generic unitName:nil
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
    
    // Create the input and output busses.
    _inputBus.init(defaultFormat, 8);
    _outputBus = [[AUAudioUnitBus alloc] initWithFormat:defaultFormat error:nil];
    
    // Create the input and output bus arrays.
    _inputBusArray  = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeInput busses: @[_inputBus.bus]];
    _outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeOutput busses: @[_outputBus]];
    
    
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
    
    _kernel.setupModulationRules();
    
    [self setDefaultMIDIMap];
    
    // Create factory preset array.
    //    _currentFactoryPresetIndex = 0;
    //    _presets = @[NewAUPreset(0, spectrumPresets[0].name),
    //                 ];
    //    self.currentPreset = _presets.firstObject;

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


-(void)dealloc {
    // Deallocate resources as required.
}

#pragma mark - AUAudioUnit (Overrides)

- (AUAudioUnitBusArray *)inputBusses {
    return _inputBusArray;
}

- (AUAudioUnitBusArray *)outputBusses {
    return _outputBusArray;
}

- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError {
    if (![super allocateRenderResourcesAndReturnError:outError]) {
        return NO;
    }
    
    if (self.outputBus.format.channelCount != _inputBus.bus.format.channelCount) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_FailedInitialization userInfo:nil];
        }
        // Notify superclass that initialization was not successful
        self.renderResourcesAllocated = NO;
        
        return NO;
    }
    
    _inputBus.allocateRenderResources(self.maximumFramesToRender);
    
    _kernel.init(self.outputBus.format.channelCount, self.outputBus.format.sampleRate);
    _kernel.midiAllNotesOff();
    
    return YES;
}

- (void)deallocateRenderResources {
    _inputBus.deallocateRenderResources();

    [super deallocateRenderResources];
}

#pragma mark - AUAudioUnit (AUAudioUnitImplementation)

- (AUInternalRenderBlock)internalRenderBlock {
    /*
     Capture in locals to avoid ObjC member lookups. If "self" is captured in
     render, we're doing it wrong.
     */
    __block ElementsDSPKernel *state = &_kernel;
    __block BufferedInputBus *input = &_inputBus;

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
        
        state->setBuffers(inAudioBufferList, outAudioBufferList);
        state->processWithEvents(timestamp, frameCount, realtimeEventListHead);
        
        return noErr;
    };
}

#pragma mark - fullstate - must override in order to call parameter observer when fullstate is reset.
- (NSDictionary *)fullState {
    NSMutableDictionary *state = [[NSMutableDictionary alloc] initWithDictionary:super.fullState];
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    
    for(int i = 0; i < _parameterTree.allParameters.count; i++) {
        params[[@(_parameterTree.allParameters[i].address) stringValue]] = @(_parameterTree.allParameters[i].value);
    }
    
    NSError* error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:params options:0 error:&error];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSLog(@"===========START============");
    NSLog([jsonString stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]);
    NSLog(@"===========END============");
    
    state[@"data"] = [NSKeyedArchiver archivedDataWithRootObject:params];
    return state;
}

- (void)setFullState:(NSDictionary *)fullState {
    NSData *data = (NSData *)fullState[@"data"];
    if (data != nil) {
        NSDictionary *params = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    
        [self loadData:params];
    }
}

- (void)loadData:(NSDictionary *)data {
    for(int i = 0; i < _parameterTree.allParameters.count; i++) {
        NSNumber *savedValue = [data objectForKey: [@(_parameterTree.allParameters[i].address) stringValue]];
        if (savedValue != nil) {
            _parameterTree.allParameters[i].value = savedValue.floatValue;
        }
    }
}

#pragma mark- Preset Management

typedef struct {
    NSString *name;
    NSString *data;
} FactoryPreset;

static const UInt8 kElementsNumPresets = 0;
static const FactoryPreset elementsPresets[kElementsNumPresets] =
{
//    {
//        @"Init",
//        @"{\"3\":0.58764940500259399,\"12\":0.43492692708969116,\"21\":0,\"4\":0,\"30\":0,\"13\":0.63545817136764526,\"5\":12,\"22\":12,\"6\":0,\"31\":0,\"14\":0,\"7\":0,\"23\":0,\"40\":0,\"32\":0,\"15\":0.20650728046894073,\"41\":0,\"24\":0.50530248880386353,\"50\":0,\"33\":0,\"16\":0,\"42\":0,\"25\":0.54248875379562378,\"8\":0,\"34\":0,\"17\":0.25165179371833801,\"43\":0,\"26\":0.51725029945373535,\"9\":7,\"35\":0,\"18\":0,\"44\":0,\"27\":0.24235904216766357,\"36\":0,\"19\":0,\"45\":0,\"28\":0,\"37\":0,\"46\":0,\"29\":0,\"38\":1,\"47\":0,\"39\":0,\"48\":0,\"49\":0,\"10\":0.99203187227249146,\"0\":0,\"1\":0.50265598297119141,\"11\":0,\"2\":0,\"20\":0}"
//    },
};

static AUAudioUnitPreset* NewAUPreset(NSInteger number, NSString *name)
{
    AUAudioUnitPreset *aPreset = [AUAudioUnitPreset new];
    aPreset.number = number;
    aPreset.name = name;
    return aPreset;
}

- (AUAudioUnitPreset *)currentPreset
{
    if (_currentPreset.number >= 0) {
        NSLog(@"Returning Current Factory Preset: %ld\n", (long)_currentFactoryPresetIndex);
        return [_presets objectAtIndex:_currentFactoryPresetIndex];
    } else {
        NSLog(@"Returning Current Custom Preset: %ld, %@\n", (long)_currentPreset.number, _currentPreset.name);
        return _currentPreset;
    }
}

- (void)setCurrentPreset:(AUAudioUnitPreset *)currentPreset
{
    if (nil == currentPreset) { NSLog(@"nil passed to setCurrentPreset!"); return; }
    
    if (currentPreset.number >= 0) {
        // factory preset
        for (AUAudioUnitPreset *factoryPreset in _presets) {
            if (currentPreset.number == factoryPreset.number) {
                
                NSError *jsonError;
                NSData *objectData = [elementsPresets[factoryPreset.number].data dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:objectData
                                                                     options:NSJSONReadingMutableContainers
                                                                       error:&jsonError];
                
                [self loadData:json];
                
                // set factory preset as current
                _currentPreset = currentPreset;
                
                break;
            }
        }
    } else if (nil != currentPreset.name) {
        // set custom preset as current
        _currentPreset = currentPreset;
        NSLog(@"currentPreset Custom: %ld, %@\n", (long)_currentPreset.number, _currentPreset.name);
    } else {
        NSLog(@"setCurrentPreset not set! - invalid AUAudioUnitPreset\n");
    }
}

//#pragma mark- MIDI CC Map
//- (NSDictionary *)fullStateForDocument {
//    NSMutableDictionary *state = [[NSMutableDictionary alloc] initWithDictionary:super.fullStateForDocument];
//    state[@"midiMap"] = [NSKeyedArchiver archivedDataWithRootObject:midiCCMap];
//    return state;
//}
//
//- (void) setFullStateForDocument:(NSDictionary<NSString *,id> *)fullStateForDocument {
//    NSData *data = (NSData *)fullStateForDocument[@"midiMap"];
//    midiCCMap = [NSKeyedUnarchiver unarchiveObjectWithData:data];
//    [self updateKernelMIDIMap];
//}

- (void)setDefaultMIDIMap {
    int skip;
    
    midiCCMap = [[NSMutableDictionary alloc] init];
    
    for(int i = 0; i < _parameterTree.allParameters.count; i++) {
        if (_parameterTree.allParameters[i].address > 200) {
            continue;
        }
        if (i < 30) {
            skip = 2;
        } else {
            skip = 4;
        }
        midiCCMap[@(_parameterTree.allParameters[i].address)] = @(_parameterTree.allParameters[i].address + skip);
    }
    
    [self updateKernelMIDIMap];
}

- (void)updateKernelMIDIMap {
    std::map<uint8_t, std::vector<MIDICCTarget>> kernelMIDIMap;
    
    for(int i = 0; i < _parameterTree.allParameters.count; i++) {
        AUParameterAddress address = _parameterTree.allParameters[i].address;
        uint8_t controller = [[midiCCMap objectForKey: @(address)] intValue];
        
        std::map<uint8_t, std::vector<MIDICCTarget>>::iterator existing = kernelMIDIMap.find(controller);
        
        MIDICCTarget target;
        target.parameter = _parameterTree.allParameters[i];
        target.minimum = _parameterTree.allParameters[i].minValue;
        target.maximum = _parameterTree.allParameters[i].maxValue;
        
        if(existing == kernelMIDIMap.end())
        {
            std::vector<MIDICCTarget> params;
            params.push_back(target);
            kernelMIDIMap[controller] = params;
        } else {
            existing->second.push_back(target);
        }
    }
    
    _kernel.midiProcessor.setCCMap(kernelMIDIMap);
}


@end
