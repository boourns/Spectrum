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

@property (nonatomic, readwrite) AUParameterTree *parameterTree;

@end

@implementation ModalAudioUnit {
    // C++ members need to be ivars; they would be copied on access if they were properties.
    ElementsDSPKernel _kernel;
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
    
    
    enum {
        ElementsParamExciterEnvShape = 0,
        ElementsParamBowLevel = 1,
        ElementsParamBowTimbre = 2,
        ElementsParamBlowLevel = 3,
        ElementsParamBlowMeta = 4,
        ElementsParamBlowTimbre = 5,
        ElementsParamStrikeLevel = 6,
        ElementsParamStrikeMeta = 7,
        ElementsParamStrikeTimbre = 8,
        ElementsParamResonatorGeometry = 9,
        ElementsParamResonatorBrightness = 10,
        ElementsParamResonatorDamping = 11,
        ElementsParamResonatorPosition = 12,
        ElementsParamSpace = 13,
        ElementsMaxParameters
    };

    AUParameter *pitchParam = [AUParameterTree createParameterWithIdentifier:@"pitch" name:@"Pitch"
                                                                     address:ElementsParamPitch
                                                                         min:0.0 max:24.0 unit:kAudioUnitParameterUnit_Generic unitName:nil
                                                                       flags: flags valueStrings:pitchRange dependentParameters:nil];
    
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
    
    AUParameterGroup *bowGroup = [AUParameterTree createGroupWithIdentifier:@"bow" name:@"Bow" children:@[pitchParam, exciterEnvShape, bowLevel, bowTimbre]];
    
    AUParameterGroup *blowGroup = [AUParameterTree createGroupWithIdentifier:@"blow" name:@"Blow" children:@[blowLevel, blowMeta, blowTimbre]];
    
    AUParameterGroup *strikeGroup = [AUParameterTree createGroupWithIdentifier:@"strike" name:@"Strike" children:@[strikeLevel, strikeMeta, strikeTimbre]];
    
    AUParameterGroup *exciterPage = [AUParameterTree createGroupWithIdentifier:@"exciter" name:@"Exciter" children:@[bowGroup, blowGroup, strikeGroup]];
    
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
    
    AUParameterGroup *resonatorGroup = [AUParameterTree createGroupWithIdentifier:@"resonator" name:@"Resonator" children:@[geometry, brightness, position, damping, space]];
    
    AUParameterGroup *resonatorPage = [AUParameterTree createGroupWithIdentifier:@"resonator" name:@"Resonator" children:@[resonatorGroup]];
    
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
    
    AUParameterGroup *settingsGroup = [AUParameterTree createGroupWithIdentifier:@"settings" name:@"Settings" children:@[modeParam]];
    
    AUParameterGroup *settingsPage = [AUParameterTree createGroupWithIdentifier:@"settings" name:@"Settings" children:@[settingsGroup]];
    
    // Create the parameter tree.
    _parameterTree = [AUParameterTree createTreeWithChildren:@[exciterPage, resonatorPage, settingsPage]];
    
    // Create the output bus.
    _outputBusBuffer.init(defaultFormat, 2);
    _outputBus = _outputBusBuffer.bus;
    
    // Create the input and output bus arrays.
    _outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self
                                                             busType:AUAudioUnitBusTypeOutput
                                                              busses: @[_outputBus]];
    
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
    _kernel.midiAllNotesOff();
    
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
    __block ElementsDSPKernel *state = &_kernel;
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
