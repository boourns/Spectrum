//
//  StateManager.m
//  iOSSpectrumFramework
//
//  Created by tom on 2019-07-16.
//

#import <Foundation/Foundation.h>
#import "StateManager.h"

//typedef struct {
//    NSString *name;
//    NSString *data;
//} FactoryPreset;

@implementation StateManager {
    AUAudioUnitPreset   *_currentPreset;
    NSInteger           _currentFactoryPresetIndex;
    NSArray<AUAudioUnitPreset *> *_presets;
    const FactoryPreset *_presetData;
    MIDIProcessorWrapper *_midiProcessor;
}

- (id) initWithParameterTree:(AUParameterTree *) tree presets:(NSArray<AUAudioUnitPreset *>*) presets presetData:(const FactoryPreset *)presetData {
    self = [super init];
    
    _presets = presets;
    _presetData = presetData;
    _parameterTree = tree;
    
    return self;
}

- (void) setMIDIProcessor:(MIDIProcessorWrapper *)midiProcessor {
    _midiProcessor = midiProcessor;
}

#pragma mark - fullstate - must override in order to call parameter observer when fullstate is reset.
- (NSDictionary *)fullStateWithDictionary: (NSDictionary *) parentState {
    NSMutableDictionary *state = [[NSMutableDictionary alloc] initWithDictionary:parentState];
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
                NSData *objectData = [_presetData[factoryPreset.number].data dataUsingEncoding:NSUTF8StringEncoding];
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

- (NSDictionary *)fullStateForDocumentWithDictionary: (NSDictionary *) parentState {
    NSMutableDictionary *state = [[NSMutableDictionary alloc] initWithDictionary:parentState];
    if (_midiProcessor != nil) {
        state[@"midi"] = [NSKeyedArchiver archivedDataWithRootObject:[_midiProcessor settings]];
    }
    return state;
}

- (void) setFullStateForDocument:(NSDictionary<NSString *,id> *)fullStateForDocument {
    if (_midiProcessor != nil) {
        NSData *data = (NSData *)fullStateForDocument[@"midi"];
        [_midiProcessor updateSettings: [NSKeyedUnarchiver unarchiveObjectWithData:data]];
    } else {
        NSLog(@"midiProcessor nil");
    }
}

//#pragma mark- MIDI CC Map

- (std::map<uint8_t, std::vector<MIDICCTarget>>) defaultMIDIMap {
    int skip = 2;
    
    NSMutableDictionary *midiCCMap = [[NSMutableDictionary alloc] init];
    
    for(int i = 0; i < _parameterTree.allParameters.count; i++) {
        if (_parameterTree.allParameters[i].address > 200) {
            continue;
        }
        if (_parameterTree.allParameters[i].address + skip == 32) {
            skip += 2;
        }
        if (_parameterTree.allParameters[i].address + skip == 64 || _parameterTree.allParameters[i].address + skip == 74) {
            skip++;
        }
        midiCCMap[@(_parameterTree.allParameters[i].address)] = @(_parameterTree.allParameters[i].address + skip);
    }
    
    return [self kernelMidiMapFor: midiCCMap];
}

- (std::map<uint8_t, std::vector<MIDICCTarget>>) kernelMidiMapFor: (NSMutableDictionary *) midiCCMap {
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
    
    return kernelMIDIMap;
}

@end
