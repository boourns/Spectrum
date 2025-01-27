
#import "OrgoneAudioUnit.h"
#import <AVFoundation/AVFoundation.h>
#import "OrgoneDSPKernel.hpp"
#import "BufferedAudioBus.hpp"
#import "AudioBuffers.h"
#import "StateManager.h"
#import "HostTransport.h"
#import "MIDIProcessor.hpp"

#ifdef DEBUG
#define DEBUG_LOG(...) NSLog(__VA_ARGS__);
#else
#define DEBUG_LOG(...)
#endif

@interface OrgoneAudioUnit ()

@property AudioBuffers *audioBuffers;
@property StateManager *stateManager;
@property HostTransport *hostTransport;
@property MIDIProcessorWrapper *midiProcessor;

@property (nonatomic, readwrite) AUParameterTree *parameterTree;

@end

@implementation OrgoneAudioUnit {
    // C++ members need to be ivars; they would be copied on access if they were properties.
    OrgoneDSPKernel _kernel;
}

@synthesize parameterTree = _parameterTree;

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription options:(AudioComponentInstantiationOptions)options error:(NSError **)outError {
    self = [super initWithComponentDescription:componentDescription options:options error:outError];
    
    if (self == nil) {
        return nil;
    }
    
    DEBUG_LOG(@"initWithComponentDescription")
    
    // Initialize a default format for the busses.
    AVAudioFormat *defaultFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100. channels:2];
    
    _audioBuffers = [[AudioBuffers alloc] initForAudioUnit:self isEffect:false withFormat:defaultFormat];
    
    // Create a DSP kernel to handle the signal processing.
    _kernel.init(defaultFormat.channelCount, defaultFormat.sampleRate);
    
    // Create a parameter object for the attack time.
    AudioUnitParameterOptions flags = kAudioUnitParameterFlag_IsWritable |
    kAudioUnitParameterFlag_IsReadable;
    
    //struct AudioUnitParameterNameInfo name;
    //self.audioUnitShortName = @"SPEC";
    // MAIN
    
    AUParameter *pitchParam = [AUParameterTree createParameterWithIdentifier:@"pitch" name:@"Pitch"
                                                                     address:OrgoneParamPitch
                                                                         min:-12.0 max:12.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                       flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *detuneParam = [AUParameterTree createParameterWithIdentifier:@"detune" name:@"Detune"
                                                                      address:OrgoneParamDetune
                                                                          min:-1.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *positionParam = [AUParameterTree createParameterWithIdentifier:@"position" name:@"Position"
                                                                      address:OrgoneParamPosition
                                                                          min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *effectParam = [AUParameterTree createParameterWithIdentifier:@"effect" name:@"Effect"
                                                                        address:OrgoneParamEffect
                                                                            min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                          flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *waveLowParam = [AUParameterTree createParameterWithIdentifier:@"waveLow" name:@"Low Wave"
                                                                        address:OrgoneParamWaveLow
                                                                            min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                          flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *waveMidParam = [AUParameterTree createParameterWithIdentifier:@"waveMid" name:@"Mid Wave"
                                                                       address:OrgoneParamWaveMid
                                                                           min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                         flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *waveHighParam = [AUParameterTree createParameterWithIdentifier:@"waveHigh" name:@"High Wave"
                                                                       address:OrgoneParamWaveHigh
                                                                           min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                         flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *modulationParam = [AUParameterTree createParameterWithIdentifier:@"modulation" name:@"Modulation"
                                                                        address:OrgoneParamModulation
                                                                            min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                          flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *indexParam = [AUParameterTree createParameterWithIdentifier:@"index" name:@"Index"
                                                                        address:OrgoneParamIndex
                                                                            min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                          flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *freqParam = [AUParameterTree createParameterWithIdentifier:@"freq" name:@"Freq"
                                                                     address:OrgoneParamFreq
                                                                         min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                       flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *fxParam = [AUParameterTree createParameterWithIdentifier:@"fxAlgorithm" name:@"FX Algorithm" address:OrgoneParamFXAlgorithm min:0.0 max:7.0 unit:kAudioUnitParameterUnit_Generic unitName:nil flags:flags valueStrings:@[@"Detune", @"Twin", @"Dist1", @"Dist2", @"Detune?", @"Spectrum", @"Delay", @"Drum"]
                                                             dependentParameters:nil];
    
    //AUParameterGroup *lpgGroup = [AUParameterTree createGroupWithIdentifier:@"main2" name:@"Main" children:@[pitchParam, detuneParam]];
    
    AUParameterGroup *mainPage = [AUParameterTree createGroupWithIdentifier:@"main" name:@"Main" children:@[pitchParam, detuneParam, positionParam, effectParam, waveLowParam, waveMidParam, waveHighParam, modulationParam, indexParam, freqParam, fxParam]];
    
    // LFO
    
    // Env
    AUParameter *envAttack = [AUParameterTree createParameterWithIdentifier:@"envAttack" name:@"Attack"
                                                                    address:OrgoneParamEnvAttack
                                                                        min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                      flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *envDecay = [AUParameterTree createParameterWithIdentifier:@"envDecay" name:@"Decay"
                                                                   address:OrgoneParamEnvDecay
                                                                       min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                     flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *envSustain = [AUParameterTree createParameterWithIdentifier:@"envSustain" name:@"Sustain"
                                                                     address:OrgoneParamEnvSustain
                                                                         min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                       flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *envRelease = [AUParameterTree createParameterWithIdentifier:@"envRelease" name:@"Release"
                                                                     address:OrgoneParamEnvRelease
                                                                         min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                       flags: flags valueStrings:nil dependentParameters:nil];
    
    
    AUParameterGroup *envPage = [AUParameterTree createGroupWithIdentifier:@"env" name:@"Env" children: @[envAttack, envDecay, envSustain, envRelease]];
    
    // MARK - Amp
    
    AUParameter *ampEnvAttack = [AUParameterTree createParameterWithIdentifier:@"ampEnvAttack" name:@"Attack"
                                                                       address:OrgoneParamAmpEnvAttack
                                                                           min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                         flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *ampEnvDecay = [AUParameterTree createParameterWithIdentifier:@"ampEnvDecay" name:@"Decay"
                                                                      address:OrgoneParamAmpEnvDecay
                                                                          min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *ampEnvSustain = [AUParameterTree createParameterWithIdentifier:@"ampEnvSustain" name:@"Sustain"
                                                                        address:OrgoneParamAmpEnvSustain
                                                                            min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                          flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *ampEnvRelease = [AUParameterTree createParameterWithIdentifier:@"ampEnvRelease" name:@"Release"
                                                                        address:OrgoneParamAmpEnvRelease
                                                                            min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                          flags: flags valueStrings:nil dependentParameters:nil];
    
    
    AUParameter *volumeParam = [AUParameterTree createParameterWithIdentifier:@"volume" name:@"Volume"
                                                                      address:OrgoneParamVolume
                                                                          min:0.0 max:1.5 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *panParam = [AUParameterTree createParameterWithIdentifier:@"pan" name:@"Pan"
                                                                   address:OrgoneParamPan
                                                                       min:-1.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                     flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *panSpreadParam = [AUParameterTree createParameterWithIdentifier:@"panSpread" name:@"Pan Spread"
                                                                         address:OrgoneParamPanSpread
                                                                             min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                           flags: flags valueStrings:nil dependentParameters:nil];
    
    
    AUParameterGroup *ampEnvSettings = [AUParameterTree createGroupWithIdentifier:@"env" name:@"Env" children: @[ampEnvAttack, ampEnvDecay, ampEnvSustain, ampEnvRelease]];
    
    AUParameterGroup *outGroup = [AUParameterTree createGroupWithIdentifier:@"out" name:@"Out" children:@[volumeParam, panParam, panSpreadParam]];
    
    AUParameterGroup *ampPage = [AUParameterTree createGroupWithIdentifier:@"amp" name:@"Amp" children:@[ampEnvSettings, outGroup]];
    
    // Voice Settings
    
    
    AUParameter *slopParam = [AUParameterTree createParameterWithIdentifier:@"slop" name:@"Slop"
                                                                    address:OrgoneParamSlop
                                                                        min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                      flags: flags valueStrings:nil dependentParameters:nil];
    
    
    
    
    AUParameter *polyphonyParam = [AUParameterTree createParameterWithIdentifier:@"polyphony" name:@"Polyphony" address:OrgoneParamPolyphony min:0.0 max:7.0 unit:kAudioUnitParameterUnit_Generic unitName:nil flags:flags valueStrings:@[@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8"]
                                                             dependentParameters:nil];
    
    AUParameter *unisonParam = [AUParameterTree createParameterWithIdentifier:@"unison" name:@"Unison" address:OrgoneParamUnison min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil flags:flags valueStrings:@[@"Off", @"On"]
                                                          dependentParameters:nil];
    
    AUParameter *pitchBendRangeParam = [AUParameterTree createParameterWithIdentifier:@"pitchRange" name:@"Bend Range"
                                                                              address:OrgoneParamPitchBendRange
                                                                                  min:0.0 max:12.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                                flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *portamento = [AUParameterTree createParameterWithIdentifier:@"portamento" name:@"Portamento"
                                                                     address:OrgoneParamPortamento
                                                                         min:0.0 max:0.9995 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                       flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *padX = [AUParameterTree createParameterWithIdentifier:@"padX" name:@"Pad X"
                                                               address:OrgoneParamPadX
                                                                   min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                 flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *padY = [AUParameterTree createParameterWithIdentifier:@"padY" name:@"Pad Y"
                                                               address:OrgoneParamPadY
                                                                   min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                 flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *padGate = [AUParameterTree createParameterWithIdentifier:@"padGate" name:@"Pad Gate"
                                                                  address:OrgoneParamPadGate
                                                                      min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                    flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *lfoRate = [AUParameterTree createParameterWithIdentifier:@"lfoRate" name:@"LFO Rate"
                                                                  address:OrgoneParamLfoRate
                                                                      min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                    flags: flags valueStrings:nil dependentParameters:nil];
    
    NSArray *lfoShapes = @[@"Sine", @"Slope", @"Pulse", @"Stepped", @"Random"];
    
    AUParameter *lfoShape = [AUParameterTree createParameterWithIdentifier:@"lfoShape" name:@"LFO Shape"
                                                                   address:OrgoneParamLfoShape
                                                                       min:0.0 max:4.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                     flags: flags valueStrings:lfoShapes dependentParameters:nil];
    
    AUParameter *lfoShapeMod = [AUParameterTree createParameterWithIdentifier:@"lfoShapeMod" name:@"ShapeMod"
                                                                      address:OrgoneParamLfoShapeMod
                                                                          min:-1.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *lfoTempoSync = [AUParameterTree createParameterWithIdentifier:@"lfoTempoSync" name:@"Tempo Sync"
                                                                       address:OrgoneParamLfoTempoSync
                                                                           min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                         flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *lfoResetPhase = [AUParameterTree createParameterWithIdentifier:@"lfoResetPhase" name:@"Reset Phase"
                                                                        address:OrgoneParamLfoResetPhase
                                                                            min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                          flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *lfoKeyReset = [AUParameterTree createParameterWithIdentifier:@"lfoKeyReset" name:@"Key Reset"
                                                                      address:OrgoneParamLfoKeyReset
                                                                          min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:nil dependentParameters:nil];
    
    
    AUParameterGroup *voiceGroup = [AUParameterTree createGroupWithIdentifier:@"voice" name:@"Voice" children:@[unisonParam, polyphonyParam, slopParam, pitchBendRangeParam, portamento]];
    
    
    AUParameterGroup *lfoPage = [AUParameterTree createGroupWithIdentifier:@"modulation" name:@"Modulation" children:@[lfoRate, lfoShape, lfoShapeMod, lfoTempoSync, lfoResetPhase, lfoKeyReset, padX, padY, padGate]];
    
    AUParameterGroup *modMatrixPage = [AUParameterTree createGroupWithIdentifier:@"modMatrix" name:@"Matrix"
                                                                        children:@[[self modMatrixRule:0 parameterOffset:OrgoneParamModMatrixStart],
                                                                                   [self modMatrixRule:1 parameterOffset:OrgoneParamModMatrixStart],
                                                                                   [self modMatrixRule:2 parameterOffset:OrgoneParamModMatrixStart],
                                                                                   [self modMatrixRule:3 parameterOffset:OrgoneParamModMatrixStart],
                                                                                   [self modMatrixRule:4 parameterOffset:OrgoneParamModMatrixStart],
                                                                                   [self modMatrixRule:5 parameterOffset:OrgoneParamModMatrixStart],
                                                                                   [self modMatrixRule:6 parameterOffset:OrgoneParamModMatrixStart],
                                                                                   [self modMatrixRule:7 parameterOffset:OrgoneParamModMatrixStart],
                                                                                   [self modMatrixRule:8 parameterOffset:OrgoneParamModMatrixStart],
                                                                                   [self modMatrixRule:9 parameterOffset:OrgoneParamModMatrixStart],
                                                                                   [self modMatrixRule:10 parameterOffset:OrgoneParamModMatrixStart],
                                                                                   [self modMatrixRule:11 parameterOffset:OrgoneParamModMatrixStart],
                                                                                   ]];
    
    AUParameterGroup *settingsPage = [AUParameterTree createGroupWithIdentifier:@"settings" name:@"Settings" children:@[voiceGroup]];
    
    DEBUG_LOG(@"registering parameter tree")
    
    // Create the parameter tree.
    _parameterTree = [AUParameterTree createTreeWithChildren:@[mainPage, lfoPage, envPage, ampPage, modMatrixPage, settingsPage]];
    
    // Make a local pointer to the kernel to avoid capturing self.
    __block OrgoneDSPKernel *instrumentKernel = &_kernel;
    
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
                return [NSString stringWithFormat:@"%.3f", value];
            }
        }
    };
    
    DEBUG_LOG(@"initializing variables")
    
    for(int i = 0; i < _parameterTree.allParameters.count; i++) {
        AUParameter *param = _parameterTree.allParameters[i];
        
        switch(param.address) {
            case OrgoneParamVolume:
                param.value = 1.0f;
                break;
            case OrgoneParamPolyphony:
                param.value = 7.0f;
                break;
            case OrgoneParamEnvRelease:
                param.value = 0.3f;
                break;
            case OrgoneParamPitchBendRange:
                param.value = 12.0;
                break;
            default:
                param.value = 0.0f;
                break;
        }
    }
    
    _hostTransport = [HostTransport alloc];
    
    self.maximumFramesToRender = 512;
    
    _stateManager = [[StateManager alloc] initWithParameterTree:_parameterTree presets:@[NewAUPreset(0, OrgonePresets[0].name),
                                                                                         NewAUPreset(1, OrgonePresets[1].name),
                                                                                         ]
                                                     presetData: &OrgonePresets[0]];
    
    [self setCurrentPreset:[[_stateManager presets] objectAtIndex:0]];
    
    _kernel.midiProcessor.setCCMap([_stateManager kernelMIDIMap]);
    
    _kernel.setupModulationRules();
    
    _midiProcessor = [MIDIProcessorWrapper alloc];
    
    [_midiProcessor setMIDIProcessor: &_kernel.midiProcessor];
    
    [_stateManager setMIDIProcessor: _midiProcessor];
    
    [self loadFromDefaults];
    
    return self;
}

-(void)dealloc {
    // Deallocate resources as required.
}

-(NSString*) audioUnitShortName {
    return @"Spec";
}

- (AUParameter *)unipolar:(AUParameterAddress) address name:(NSString*) name {
    return [AUParameterTree createParameterWithIdentifier:name name:name
                                                  address:address
                                                      min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                    flags: kAudioUnitParameterFlag_IsWritable|kAudioUnitParameterFlag_IsReadable valueStrings:nil dependentParameters:nil];
}

#pragma mark - AUAudioUnit (Overrides)

- (AUParameterGroup *)modMatrixRule:(int) ruleNumber parameterOffset:(int) parameterOffset {
    
    NSArray *modInputs = @[@"Direct",
                           @"LFO",
                           @"Envelope",
                           @"Note",
                           @"Velocity",
                           @"Gate",
                           @"Modwheel",
                           @"Out",
                           @"Pad X",
                           @"Pad Y",
                           @"Pad Gate",
                           @"Aftertouch",
                           @"Sustain",
                           @"Slide",
                           @"Lift",
                           ];
    
    NSArray *modOutputs = @[
                            @"Disabled",
                            @"Tune",
                            @"Frequency",
                            @"Position",
                            @"Effect",
                            @"Modulation",
                            @"Index",
                            @"Freq",
                            @"LFORate",
                            @"LFOAmount",
                            @"Pan",
                            @"Level",
                            @"Portamento",
                            ];
    
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
    _kernel.reset();
    
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
    __block OrgoneDSPKernel *state = &_kernel;
    __block HostTransport *hostTransport = _hostTransport;
    
    return ^AUAudioUnitStatus(
                              AudioUnitRenderActionFlags *actionFlags,
                              const AudioTimeStamp       *timestamp,
                              AVAudioFrameCount           frameCount,
                              NSInteger                   outputBusNumber,
                              AudioBufferList            *outputData,
                              const AURenderEvent        *realtimeEventListHead,
                              AURenderPullInputBlock      pullInputBlock) {
        
        [hostTransport updateTransportState];
        state->setTransportState([hostTransport kernelTransportState]);
        
        state->setBuffers(outputData);
        state->processWithEvents(timestamp, frameCount, realtimeEventListHead);
        
        return noErr;
    };
}

static const UInt8 kOrgoneNumPresets = 2;
static const FactoryPreset OrgonePresets[kOrgoneNumPresets] =
{
    {
        @"Init",
        @"{\"414\":0,\"421\":0,\"407\":0,\"408\":2,\"415\":0,\"422\":0,\"409\":0,\"416\":0,\"423\":0,\"430\":0.46999862790107727,\"0\":0.16291390359401703,\"417\":0,\"424\":9,\"1\":0.25301206111907959,\"431\":9,\"2\":0,\"418\":0,\"4\":0,\"425\":0,\"432\":10,\"5\":0,\"6\":0,\"419\":0,\"7\":0.61749958992004395,\"426\":0.68999946117401123,\"10\":0.53999972343444824,\"8\":0,\"433\":0,\"440\":0,\"9\":0.7350003719329834,\"11\":1,\"427\":4,\"434\":0.73999977111816406,\"441\":0,\"12\":0,\"13\":0,\"400\":1,\"20\":0.88545054197311401,\"428\":10,\"435\":10,\"21\":0,\"14\":0,\"442\":0,\"429\":0,\"401\":0,\"22\":1,\"15\":0.30749991536140442,\"436\":1,\"443\":0,\"30\":0.93453878164291382,\"23\":0.65999847650527954,\"16\":0.69499963521957397,\"437\":2,\"402\":0,\"31\":0.63818180561065674,\"17\":1,\"444\":0,\"24\":12,\"18\":0,\"32\":0.082459814846515656,\"438\":0.40999928116798401,\"403\":3,\"410\":0,\"445\":0,\"33\":0,\"34\":7,\"439\":1,\"404\":1,\"411\":0,\"446\":0,\"28\":0,\"35\":0.062500067055225372,\"29\":0,\"405\":0,\"412\":2,\"447\":0,\"420\":0,\"406\":0,\"413\":0}"
    },
    {
        @"Blank",
        @"{\"414\":0,\"421\":0,\"407\":0,\"408\":0,\"415\":0,\"422\":0,\"409\":0,\"416\":0,\"423\":0,\"430\":0,\"0\":0,\"417\":0,\"424\":0,\"1\":0,\"431\":0,\"2\":0,\"418\":0,\"4\":0,\"425\":0,\"432\":0,\"5\":0,\"6\":0,\"419\":0,\"7\":0,\"426\":0,\"10\":0,\"8\":0,\"433\":0,\"440\":0,\"9\":0,\"11\":1,\"427\":0,\"434\":0,\"441\":0,\"12\":0,\"13\":0,\"400\":0,\"20\":0,\"428\":0,\"435\":0,\"21\":0,\"14\":0,\"442\":0,\"429\":0,\"401\":0,\"22\":0,\"15\":0,\"436\":0,\"443\":0,\"30\":0,\"23\":0.29999238252639771,\"16\":0,\"437\":0,\"402\":0,\"31\":0,\"17\":0,\"444\":0,\"24\":12,\"18\":0,\"32\":0,\"438\":0,\"403\":0,\"410\":0,\"445\":0,\"33\":0,\"34\":7,\"439\":0,\"404\":0,\"411\":0,\"446\":0,\"28\":0,\"35\":0,\"29\":0,\"405\":0,\"412\":0,\"447\":0,\"420\":0,\"406\":0,\"413\":0}",
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
    DEBUG_LOG(@"fullState")
    
    return [_stateManager fullStateWithDictionary:[super fullState]];
}

- (void)setFullState:(NSDictionary *)fullState {
    DEBUG_LOG(@"setFullState start")
    
    [_stateManager setFullState:fullState];
    
    _kernel.setupModulationRules();
    DEBUG_LOG(@"setFullState end")
    
}

- (NSDictionary *)fullStateForDocument {
    DEBUG_LOG(@"fullStateForDocument")
    
    return [_stateManager fullStateForDocumentWithDictionary:[super fullStateForDocument]];
}

- (void)setFullStateForDocument:(NSDictionary *)fullStateForDocument {
    DEBUG_LOG(@"setFullStateForDocument start")
    
    [_stateManager setFullStateForDocument:fullStateForDocument];
    [super setFullStateForDocument:fullStateForDocument];
    
    _kernel.setupModulationRules();
    DEBUG_LOG(@"setFullStateForDocument end")
    
}

- (void) saveDefaults {
    [_stateManager saveDefaultsForName:@"Orgone"];
}

- (void) loadFromDefaults {
    [_stateManager loadDefaultsForName:@"Orgone"];
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

// MARK - lfo graphic
- (NSArray<NSNumber *> *)drawLFO {
    float pt[100];
    _kernel.drawLFO(&pt[0], 100);
    NSMutableArray *result = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < 100; i++) {
        NSNumber *number = [NSNumber numberWithFloat:pt[i]];
        [result addObject:number];
    }
    
    return result;
}

- (bool) lfoDrawingDirty {
    return _kernel.lfoDrawingDirty();
}

@end

