//
//  ResonatorAudioUnit.m
//  iOSSpectrumFramework
//
//  Created by tom on 2019-06-27.
//

#import "ResonatorAudioUnit.h"
#import <AVFoundation/AVFoundation.h>
#import "RingsDSPKernel.hpp"
#import "BufferedAudioBus.hpp"

@interface ResonatorAudioUnit ()

@property AUAudioUnitBus *outputBus;
@property AUAudioUnitBusArray *outputBusArray;
@property AUAudioUnitBusArray *inputBusArray;

@property (nonatomic, readwrite) AUParameterTree *parameterTree;

@end

@implementation ResonatorAudioUnit {
    // C++ members need to be ivars; they would be copied on access if they were properties.
    RingsDSPKernel _kernel;
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
@synthesize factoryPresets = _presets;

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
                  @"PadX",
                  @"PadY",
                  @"PadGate",
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
                   @"Structure",
                   @"Brightness",
                   @"Damping",
                   @"Position",
                   @"LFORate",
                   @"LFOAmount",
                   @"Level",
                   ];
    
    AUParameter *inputGain = [AUParameterTree createParameterWithIdentifier:@"inputGain" name:@"Input Gain"
                                                                    address:RingsParamInputGain
                                                                        min:0.0 max:2.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                      flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameterGroup *inputPage = [AUParameterTree createGroupWithIdentifier:@"input" name:@"Input" children:@[inputGain]];
    
    AUParameter *structure = [AUParameterTree createParameterWithIdentifier:@"structure" name:@"Structure"
                                                                   address:RingsParamStructure
                                                                       min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                     flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *brightness = [AUParameterTree createParameterWithIdentifier:@"brightness" name:@"Brightness"
                                                                     address:RingsParamBrightness
                                                                         min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                       flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *damping = [AUParameterTree createParameterWithIdentifier:@"damping" name:@"Damping"
                                                                  address:RingsParamDamping
                                                                      min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                    flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *position = [AUParameterTree createParameterWithIdentifier:@"position" name:@"Position"
                                                                   address:RingsParamPosition
                                                                       min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                     flags: flags valueStrings:nil dependentParameters:nil];

    
    AUParameter *volume = [AUParameterTree createParameterWithIdentifier:@"volume" name:@"Volume"
                                                                 address:RingsParamVolume
                                                                     min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                   flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *stereo = [AUParameterTree createParameterWithIdentifier:@"stereoSpread" name:@"Stereo Spread"
                                                                 address:RingsParamStereoSpread
                                                                     min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                   flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameterGroup *resonatorGroup = [AUParameterTree createGroupWithIdentifier:@"resonator" name:@"Resonator" children:@[structure, brightness, position, damping, volume, stereo]];
    
    AUParameterGroup *resonatorPage = [AUParameterTree createGroupWithIdentifier:@"resonator" name:@"Resonator" children:@[resonatorGroup]];
    
    // LFO
    AUParameter *lfoRate = [AUParameterTree createParameterWithIdentifier:@"lfoRate" name:@"LFO Rate"
                                                                  address:RingsParamLfoRate
                                                                      min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                    flags: flags valueStrings:nil dependentParameters:nil];
    
    NSArray *lfoShapes = @[@"Sine", @"Slope", @"Pulse", @"Stepped", @"Random"];
    
    AUParameter *lfoShape = [AUParameterTree createParameterWithIdentifier:@"lfoShape" name:@"LFO Shape"
                                                                   address:RingsParamLfoShape
                                                                       min:0.0 max:4.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                     flags: flags valueStrings:lfoShapes dependentParameters:nil];
    
    AUParameter *lfoShapeMod = [AUParameterTree createParameterWithIdentifier:@"lfoShapeMod" name:@"ShapeMod"
                                                                      address:RingsParamLfoShapeMod
                                                                          min:-1.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *padX = [AUParameterTree createParameterWithIdentifier:@"padX" name:@"Pad X"
                                                               address:RingsParamPadX
                                                                   min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                 flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *padY = [AUParameterTree createParameterWithIdentifier:@"padY" name:@"Pad Y"
                                                               address:RingsParamPadY
                                                                   min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                 flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *padGate = [AUParameterTree createParameterWithIdentifier:@"padGate" name:@"Pad Gate"
                                                                  address:RingsParamPadGate
                                                                      min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                    flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameterGroup *lfoSettings = [AUParameterTree createGroupWithIdentifier:@"lfo" name:@"LFO" children:@[lfoRate, lfoShape, lfoShapeMod, padX, padY, padGate]];
    
    
    AUParameterGroup *lfoPage = [AUParameterTree createGroupWithIdentifier:@"lfo" name:@"LFO" children:@[lfoSettings]];
    
    
    
    
    // Env
    AUParameter *envAttack = [AUParameterTree createParameterWithIdentifier:@"envAttack" name:@"Attack"
                                                                    address:RingsParamEnvAttack
                                                                        min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                      flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *envDecay = [AUParameterTree createParameterWithIdentifier:@"envDecay" name:@"Decay"
                                                                   address:RingsParamEnvDecay
                                                                       min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                     flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *envSustain = [AUParameterTree createParameterWithIdentifier:@"envSustain" name:@"Sustain"
                                                                     address:RingsParamEnvSustain
                                                                         min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                       flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *envRelease = [AUParameterTree createParameterWithIdentifier:@"envRelease" name:@"Release"
                                                                     address:RingsParamEnvRelease
                                                                         min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                       flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameterGroup *envSettings = [AUParameterTree createGroupWithIdentifier:@"env" name:@"Env" children: @[envAttack, envDecay, envSustain, envRelease]];
    
    AUParameterGroup *modMatrixPage = [AUParameterTree createGroupWithIdentifier:@"modMatrix" name:@"Matrix"
                                                                        children:@[[self modMatrixRule:0 parameterOffset:RingsParamModMatrixStart],
                                                                                   [self modMatrixRule:1 parameterOffset:RingsParamModMatrixStart],
                                                                                   [self modMatrixRule:2 parameterOffset:RingsParamModMatrixStart],
                                                                                   [self modMatrixRule:3 parameterOffset:RingsParamModMatrixStart],
                                                                                   [self modMatrixRule:4 parameterOffset:RingsParamModMatrixStart],
                                                                                   [self modMatrixRule:5 parameterOffset:RingsParamModMatrixStart],
                                                                                   [self modMatrixRule:6 parameterOffset:RingsParamModMatrixStart],
                                                                                   [self modMatrixRule:7 parameterOffset:RingsParamModMatrixStart],
                                                                                   [self modMatrixRule:8 parameterOffset:RingsParamModMatrixStart],
                                                                                   [self modMatrixRule:9 parameterOffset:RingsParamModMatrixStart],
                                                                                   ]];
    
    //AUParameterGroup *envModulations = [AUParameterTree createGroupWithIdentifier:@"envMod" name:@"Modulations" children: @[envAmountFM, envAmountHarmonics, envAmountTimbre, envAmountMorph, envAmountLFORate, envAmountLFOAmount]];
    
    AUParameterGroup *envPage = [AUParameterTree createGroupWithIdentifier:@"env" name:@"Env" children:@[envSettings]];
    
    
    AUParameter *modeParam = [AUParameterTree createParameterWithIdentifier:@"mode" name:@"Mode"
                                                                    address:RingsParamMode min:0.0 max:6.0
                                                                       unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                      flags:flags valueStrings:@[
                                                                                                 @"Modal",
                                                                                                 @"Sympathetic",
                                                                                                 @"String",
                                                                                                 @"FM",
                                                                                                 @"Quantized",
                                                                                                 @"Stringverb",
                                                                                                 @"Disastrous Peace",
                                                                        
                                                                                                 ]
                                                        dependentParameters:nil];
    
    AUParameter *pitchParam = [AUParameterTree createParameterWithIdentifier:@"pitch" name:@"Pitch"
                                                                     address:RingsParamPitch
                                                                         min:-12.0 max:12.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                       flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *detuneParam = [AUParameterTree createParameterWithIdentifier:@"detune" name:@"Detune"
                                                                      address:RingsParamDetune
                                                                          min:-1.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameterGroup *settingsGroup = [AUParameterTree createGroupWithIdentifier:@"settings" name:@"Settings" children:@[modeParam, pitchParam, detuneParam]];
    
    AUParameterGroup *settingsPage = [AUParameterTree createGroupWithIdentifier:@"settings" name:@"Settings" children:@[settingsGroup]];
    
    // Create the parameter tree.
    _parameterTree = [AUParameterTree createTreeWithChildren:@[inputPage, resonatorPage, lfoPage, envPage, modMatrixPage, settingsPage]];
    
    _inputBus.init(defaultFormat, 8);

    // Create the input and output busses.
    if (loadAsEffect) {
        _inputBusArray  = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeInput busses: @[_inputBus.bus]];
    }
    
    _outputBus = [[AUAudioUnitBus alloc] initWithFormat:defaultFormat error:nil];
    // Create the input and output bus arrays.
    _outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeOutput busses: @[_outputBus]];
    
    
    // Make a local pointer to the kernel to avoid capturing self.
    __block RingsDSPKernel *instrumentKernel = &_kernel;
    
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
            case RingsParamVolume:
                param.value = 1.0f;
                break;
            
            case RingsParamInputGain:
                param.value = 1.0;
                break;
            default:
                param.value = 0.0f;
                break;
        }
    }
    
    [self setDefaultMIDIMap];
    
    // Create factory preset array.
    _currentFactoryPresetIndex = 0;
    
    _presets = @[NewAUPreset(0, ringsPresets[0].name),
                 NewAUPreset(1, ringsPresets[1].name),
                 ];
    
    self.currentPreset = _presets.firstObject;
    
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


-(void)dealloc {
    // Deallocate resources as required.
}

-(NSString*) audioUnitShortName {
    return @"Res";
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
    __block RingsDSPKernel *state = &_kernel;
    __block BufferedInputBus *input = &_inputBus;
    __block bool isEffect = loadAsEffect;
    
    return ^AUAudioUnitStatus(
                              AudioUnitRenderActionFlags *actionFlags,
                              const AudioTimeStamp       *timestamp,
                              AVAudioFrameCount           frameCount,
                              NSInteger                   outputBusNumber,
                              AudioBufferList            *outputData,
                              const AURenderEvent        *realtimeEventListHead,
                              AURenderPullInputBlock      pullInputBlock) {
        
        AudioUnitRenderActionFlags pullFlags = 0;
        AudioBufferList *inAudioBufferList = nil;
        if (isEffect) {
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
    _kernel.setupModulationRules();
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

static const UInt8 kRingsNumPresets = 2;
static const FactoryPreset ringsPresets[kRingsNumPresets] =
{
        {
            @"Init",
            @"{\"414\":0,\"421\":0,\"407\":0,\"408\":0,\"415\":0,\"422\":1.1399997472763062,\"409\":0,\"416\":1,\"423\":3,\"430\":0,\"0\":0.24367509782314301,\"417\":0,\"424\":3,\"431\":0,\"1\":0.31490787863731384,\"2\":0,\"418\":0.94999980926513672,\"4\":0.21000000834465027,\"425\":0,\"432\":0,\"5\":0.29000008106231689,\"6\":0.51749980449676514,\"433\":0,\"7\":0.48499956727027893,\"419\":4,\"426\":0.71999990940093994,\"8\":1,\"9\":1,\"11\":0,\"427\":5,\"434\":0,\"12\":0,\"13\":0.090000338852405548,\"428\":0,\"435\":0,\"400\":0,\"20\":1,\"21\":0.39749985933303833,\"14\":0,\"429\":0,\"401\":0,\"15\":0,\"436\":0,\"16\":0,\"437\":0,\"402\":0,\"17\":0,\"18\":0,\"438\":0,\"403\":1,\"410\":0,\"19\":0,\"439\":0,\"404\":0,\"411\":0,\"405\":0,\"412\":0,\"420\":2,\"406\":0,\"413\":0}"
        },
    {
        @"Blank",
        @"{\"414\":0,\"421\":0,\"407\":0,\"408\":0,\"415\":0,\"422\":0,\"409\":0,\"416\":0,\"423\":0,\"430\":0,\"0\":0,\"417\":0,\"424\":0,\"431\":0,\"1\":0,\"2\":0,\"418\":0,\"4\":0,\"425\":0,\"432\":0,\"5\":0,\"6\":0,\"433\":0,\"7\":0,\"419\":0,\"426\":0,\"8\":1,\"9\":0,\"11\":0,\"427\":0,\"434\":0,\"12\":0,\"13\":0,\"428\":0,\"435\":0,\"400\":0,\"20\":1,\"21\":0,\"14\":0,\"429\":0,\"401\":0,\"15\":0,\"436\":0,\"16\":0,\"437\":0,\"402\":0,\"17\":0,\"18\":0,\"438\":0,\"403\":0,\"410\":0,\"19\":0,\"439\":0,\"404\":0,\"411\":0,\"405\":0,\"412\":0,\"420\":0,\"406\":0,\"413\":0}"
    },
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
                NSData *objectData = [ringsPresets[factoryPreset.number].data dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:objectData
                                                                     options:NSJSONReadingMutableContainers
                                                                       error:&jsonError];
                
                [self loadData:json];
                
                // set factory preset as current
                _currentPreset = currentPreset;
                
                _kernel.setupModulationRules();
                
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
        if (_parameterTree.allParameters[i].address < 30) {
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
        if (address > 200) {
            continue;
        }
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
