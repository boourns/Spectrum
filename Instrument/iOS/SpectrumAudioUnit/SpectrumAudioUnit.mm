
#import "SpectrumAudioUnit.h"
#import <AVFoundation/AVFoundation.h>
#import "PlaitsDSPKernel.hpp"
#import <BurnsAudioUnit/BufferedAudioBus.hpp>
#import <BurnsAudioUnit/AudioBuffers.h>
#import <BurnsAudioUnit/StateManager.h>
#import <BurnsAudioUnit/HostTransport.h>
#import <BurnsAudioUnit/MIDIProcessor.hpp>

#ifdef DEBUG
#define DEBUG_LOG(...) NSLog(__VA_ARGS__);
#else
#define DEBUG_LOG(...)
#endif

@interface SpectrumAudioUnit ()

@property AudioBuffers *audioBuffers;
@property StateManager *stateManager;
@property HostTransport *hostTransport;
@property MIDIProcessorWrapper *midiProcessor;

@property (nonatomic, readwrite) AUParameterTree *parameterTree;

@end

@implementation SpectrumAudioUnit {
    // C++ members need to be ivars; they would be copied on access if they were properties.
    PlaitsDSPKernel _kernel;
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
    
    AUParameter *algorithmParam = [AUParameterTree createParameterWithIdentifier:@"algorithm" name:@"Algorithm"
                                                                         address:PlaitsParamAlgorithm min:0.0 max:15.4
                                                                            unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                           flags:flags valueStrings:@[
                                                                                                      @"Analog",
                                                                                                      @"Wave shape",
                                                                                                      @"FM",
                                                                                                      @"Grain",
                                                                                                      @"Additive",
                                                                                                      @"Wave table",
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
                                                                          min:-12.0 max:12.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:nil dependentParameters:nil];
    
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
                                                                                flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *portamento = [AUParameterTree createParameterWithIdentifier:@"portamento" name:@"Portamento"
                                                                     address:PlaitsParamPortamento
                                                                         min:0.0 max:0.9995 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                       flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *padX = [AUParameterTree createParameterWithIdentifier:@"padX" name:@"Pad X"
                                                               address:PlaitsParamPadX
                                                                   min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                 flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *padY = [AUParameterTree createParameterWithIdentifier:@"padY" name:@"Pad Y"
                                                               address:PlaitsParamPadY
                                                                   min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                 flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *padGate = [AUParameterTree createParameterWithIdentifier:@"padGate" name:@"Pad Gate"
                                                                  address:PlaitsParamPadGate
                                                                      min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                    flags: flags valueStrings:nil dependentParameters:nil];

    
    AUParameterGroup *mainPage = [AUParameterTree createGroupWithIdentifier:@"main" name:@"Main" children:@[pitchParam, detuneParam, algorithmParam, harmonicsParam, timbreParam, morphParam, unisonParam, polyphonyParam, slopParam, pitchBendRangeParam, portamento, padX, padY, padGate]];
    
    // LFO
    
    // Env
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
    
    
    AUParameterGroup *envPage = [AUParameterTree createGroupWithIdentifier:@"env" name:@"Env" children: @[envAttack, envDecay, envSustain, envRelease]];
    
    // MARK - Amp
    
    AUParameter *velocityDepth = [AUParameterTree createParameterWithIdentifier:@"velocityDepth" name:@"Velocity Depth"
                                                                       address:PlaitsParamVelocityDepth
                                                                           min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                         flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *ampEnvAttack = [AUParameterTree createParameterWithIdentifier:@"ampEnvAttack" name:@"Attack"
                                                                       address:PlaitsParamAmpEnvAttack
                                                                           min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                         flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *ampEnvDecay = [AUParameterTree createParameterWithIdentifier:@"ampEnvDecay" name:@"Decay"
                                                                      address:PlaitsParamAmpEnvDecay
                                                                          min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *ampEnvSustain = [AUParameterTree createParameterWithIdentifier:@"ampEnvSustain" name:@"Sustain"
                                                                        address:PlaitsParamAmpEnvSustain
                                                                            min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                          flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *ampEnvRelease = [AUParameterTree createParameterWithIdentifier:@"ampEnvRelease" name:@"Release"
                                                                        address:PlaitsParamAmpEnvRelease
                                                                            min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                          flags: flags valueStrings:nil dependentParameters:nil];
    
    
    AUParameter *volumeParam = [AUParameterTree createParameterWithIdentifier:@"volume" name:@"Volume"
                                                                      address:PlaitsParamVolume
                                                                          min:0.0 max:1.5 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *leftSourceParam = [AUParameterTree createParameterWithIdentifier:@"source" name:@"Source"
                                                                          address:PlaitsParamSource
                                                                              min:-1.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                            flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *rightSourceParam = [AUParameterTree createParameterWithIdentifier:@"sourceSpread" name:@"Source Spread"
                                                                           address:PlaitsParamSourceSpread
                                                                               min:-1.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                             flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *panParam = [AUParameterTree createParameterWithIdentifier:@"pan" name:@"Pan"
                                                                   address:PlaitsParamPan
                                                                       min:-1.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                     flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *panSpreadParam = [AUParameterTree createParameterWithIdentifier:@"panSpread" name:@"Pan Spread"
                                                                         address:PlaitsParamPanSpread
                                                                             min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                           flags: flags valueStrings:nil dependentParameters:nil];
    
    
    AUParameter *colourParam = [AUParameterTree createParameterWithIdentifier:@"colour" name:@"LPG Colour"
                                                                      address:PlaitsParamLPGColour
                                                                          min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                        flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameterGroup *ampPage = [AUParameterTree createGroupWithIdentifier:@"amp" name:@"Amp" children:@[ampEnvAttack, ampEnvDecay, ampEnvSustain, ampEnvRelease, colourParam, velocityDepth, volumeParam, leftSourceParam, rightSourceParam, panParam, panSpreadParam]];

    // Voice Settings

    
    
    AUParameter *lfoRate = [AUParameterTree createParameterWithIdentifier:@"lfoRate" name:@"LFO Rate"
                                                                         address:PlaitsParamLfoRate
                                                                             min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                           flags: flags valueStrings:nil dependentParameters:nil];
    
    NSArray *lfoShapes = @[@"Sine", @"Slope", @"Pulse", @"Stepped", @"Random"];
    
    AUParameter *lfoShape = [AUParameterTree createParameterWithIdentifier:@"lfoShape" name:@"LFO Shape"
                                                                  address:PlaitsParamLfoShape
                                                                      min:0.0 max:4.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                    flags: flags valueStrings:lfoShapes dependentParameters:nil];
    
    AUParameter *lfoShapeMod = [AUParameterTree createParameterWithIdentifier:@"lfoShapeMod" name:@"ShapeMod"
                                                                    address:PlaitsParamLfoShapeMod
                                                                        min:-1.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                      flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *lfoTempoSync = [AUParameterTree createParameterWithIdentifier:@"lfoTempoSync" name:@"Tempo Sync"
                                                                  address:PlaitsParamLfoTempoSync
                                                                      min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                    flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *lfoResetPhase = [AUParameterTree createParameterWithIdentifier:@"lfoResetPhase" name:@"Reset Phase"
                                                                  address:PlaitsParamLfoResetPhase
                                                                      min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                    flags: flags valueStrings:nil dependentParameters:nil];
    
    AUParameter *lfoKeyReset = [AUParameterTree createParameterWithIdentifier:@"lfoKeyReset" name:@"Key Reset"
                                                                  address:PlaitsParamLfoKeyReset
                                                                      min:0.0 max:1.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                    flags: flags valueStrings:nil dependentParameters:nil];
    
    
    AUParameterGroup *lfoPage = [AUParameterTree createGroupWithIdentifier:@"lfo" name:@"LFO" children:@[lfoRate, lfoShape, lfoShapeMod, lfoTempoSync, lfoResetPhase, lfoKeyReset]];
    
    AUParameterGroup *modMatrixPage = [AUParameterTree createGroupWithIdentifier:@"modMatrix" name:@"Matrix"
                                                                        children:@[[self modMatrixRule:0 parameterOffset:PlaitsParamModMatrixStart],
                                                                                   [self modMatrixRule:1 parameterOffset:PlaitsParamModMatrixStart],
                                                                                   [self modMatrixRule:2 parameterOffset:PlaitsParamModMatrixStart],
                                                                                   [self modMatrixRule:3 parameterOffset:PlaitsParamModMatrixStart],
                                                                                   [self modMatrixRule:4 parameterOffset:PlaitsParamModMatrixStart],
                                                                                   [self modMatrixRule:5 parameterOffset:PlaitsParamModMatrixStart],
                                                                                   [self modMatrixRule:6 parameterOffset:PlaitsParamModMatrixStart],
                                                                                   [self modMatrixRule:7 parameterOffset:PlaitsParamModMatrixStart],
                                                                                   [self modMatrixRule:8 parameterOffset:PlaitsParamModMatrixStart],
                                                                                   [self modMatrixRule:9 parameterOffset:PlaitsParamModMatrixStart],
                                                                                                                                                            [self modMatrixRule:10 parameterOffset:PlaitsParamModMatrixStart],
                                                                                                                                                                      [self modMatrixRule:11 parameterOffset:PlaitsParamModMatrixStart],
                                                                                   ]];
    
    DEBUG_LOG(@"registering parameter tree")

    // Create the parameter tree.
    _parameterTree = [AUParameterTree createTreeWithChildren:@[mainPage, lfoPage, envPage, ampPage, modMatrixPage]];
    
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
            case PlaitsParamVolume:
                param.value = 1.0f;
                break;
            case PlaitsParamPolyphony:
                param.value = 7.0f;
                break;
            case PlaitsParamEnvRelease:
                param.value = 0.3f;
                break;
            case PlaitsParamPitchBendRange:
                param.value = 12.0;
                break;
            default:
                param.value = 0.0f;
                break;
        }
    }
    
    _hostTransport = [HostTransport alloc];

    self.maximumFramesToRender = 512;
    
    _stateManager = [[StateManager alloc] initWithParameterTree:_parameterTree presets:@[NewAUPreset(0, spectrumPresets[0].name),
                                                                                         NewAUPreset(1, spectrumPresets[1].name),
                                                                                         NewAUPreset(2, spectrumPresets[2].name),
                                                                                         ]
                                                     presetData: &spectrumPresets[0]];
    
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
                               @"Aux",
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
    @"Harmonics",
    @"Timbre",
    @"Morph",
    @"Engine",
    @"LFORate",
    @"LFOAmount",
    @"Source",
    @"SourceSpread",
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
    __block PlaitsDSPKernel *state = &_kernel;
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

static const UInt8 kSpectrumNumPresets = 3;
static const FactoryPreset spectrumPresets[kSpectrumNumPresets] =
{
    {
        @"Init",
    @"{\"414\":0,\"421\":0,\"407\":0,\"408\":2,\"415\":0,\"422\":0,\"409\":0,\"416\":0,\"423\":0,\"430\":0.46999862790107727,\"0\":0.16291390359401703,\"417\":0,\"424\":9,\"1\":0.25301206111907959,\"431\":9,\"2\":0,\"418\":0,\"4\":0,\"425\":0,\"432\":10,\"5\":0,\"6\":0,\"419\":0,\"7\":0.61749958992004395,\"426\":0.68999946117401123,\"10\":0.53999972343444824,\"8\":0,\"433\":0,\"440\":0,\"9\":0.7350003719329834,\"11\":1,\"427\":4,\"434\":0.73999977111816406,\"441\":0,\"12\":0,\"13\":0,\"400\":1,\"20\":0.88545054197311401,\"428\":10,\"435\":10,\"21\":0,\"14\":0,\"442\":0,\"429\":0,\"401\":0,\"22\":1,\"15\":0.30749991536140442,\"436\":1,\"443\":0,\"30\":0.93453878164291382,\"23\":0.65999847650527954,\"16\":0.69499963521957397,\"437\":2,\"402\":0,\"31\":0.63818180561065674,\"17\":1,\"444\":0,\"24\":12,\"18\":0,\"32\":0.082459814846515656,\"438\":0.40999928116798401,\"403\":3,\"410\":0,\"445\":0,\"33\":0,\"34\":7,\"439\":1,\"404\":1,\"411\":0,\"446\":0,\"28\":0,\"35\":0.062500067055225372,\"29\":0,\"405\":0,\"412\":2,\"447\":0,\"420\":0,\"406\":0,\"413\":0}"
    },
    {
        @"Blank",
    @"{\"414\":0,\"421\":0,\"407\":0,\"408\":0,\"415\":0,\"422\":0,\"409\":0,\"416\":0,\"423\":0,\"430\":0,\"0\":0,\"417\":0,\"424\":0,\"1\":0,\"431\":0,\"2\":0,\"418\":0,\"4\":0,\"425\":0,\"432\":0,\"5\":0,\"6\":0,\"419\":0,\"7\":0,\"426\":0,\"10\":0,\"8\":0,\"433\":0,\"440\":0,\"9\":0,\"11\":1,\"427\":0,\"434\":0,\"441\":0,\"12\":0,\"13\":0,\"400\":0,\"20\":0,\"428\":0,\"435\":0,\"21\":0,\"14\":0,\"442\":0,\"429\":0,\"401\":0,\"22\":0,\"15\":0,\"436\":0,\"443\":0,\"30\":0,\"23\":0.29999238252639771,\"16\":0,\"437\":0,\"402\":0,\"31\":0,\"17\":0,\"444\":0,\"24\":12,\"18\":0,\"32\":0,\"438\":0,\"403\":0,\"410\":0,\"445\":0,\"33\":0,\"34\":7,\"439\":0,\"404\":0,\"411\":0,\"446\":0,\"28\":0,\"35\":0,\"29\":0,\"405\":0,\"412\":0,\"447\":0,\"420\":0,\"406\":0,\"413\":0}",
    },
    {
       @"Basic MPE",
    @"{\"414\":0,\"421\":0,\"407\":0,\"408\":2,\"415\":0,\"422\":0,\"409\":0,\"416\":0,\"423\":0,\"430\":1.140000581741333,\"0\":0.52847683429718018,\"417\":0,\"1\":0.41480207443237305,\"424\":12,\"431\":9,\"2\":0,\"418\":0,\"4\":3,\"425\":1,\"432\":4,\"5\":0,\"6\":0,\"419\":0,\"7\":0.72499948740005493,\"426\":0.3200002908706665,\"10\":0,\"8\":0,\"433\":0,\"440\":10,\"9\":0.30000019073486328,\"11\":1,\"427\":4,\"434\":0.19000011682510376,\"441\":0,\"12\":-1,\"13\":0.27000004053115845,\"400\":1,\"20\":0.88545054197311401,\"428\":14,\"435\":5,\"21\":0,\"14\":0,\"442\":0.70999979972839355,\"429\":0,\"401\":0,\"22\":1,\"15\":0.17749997973442078,\"436\":9,\"443\":3,\"30\":1,\"23\":0.65999847650527954,\"16\":0.51249998807907104,\"437\":0,\"402\":0,\"31\":0.42363637685775757,\"17\":0,\"444\":0,\"24\":12,\"18\":0,\"32\":0.082459814846515656,\"438\":0.67999988794326782,\"403\":3,\"410\":0,\"445\":0,\"33\":0,\"27\":0.56000006198883057,\"439\":9,\"404\":1,\"411\":0,\"446\":0,\"28\":0,\"34\":7,\"35\":0.062500067055225372,\"36\":0,\"405\":0,\"29\":0.25999847054481506,\"412\":2,\"447\":0,\"37\":0,\"420\":0,\"38\":0,\"406\":0,\"413\":0}"
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
    [_stateManager saveDefaultsForName:@"Spectrum"];
}

- (void) loadFromDefaults {
    [_stateManager loadDefaultsForName:@"Spectrum"];
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
