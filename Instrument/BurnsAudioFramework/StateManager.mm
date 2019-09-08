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
    NSDictionary *_midiMap;
}

- (id) initWithParameterTree:(AUParameterTree *) tree presets:(NSArray<AUAudioUnitPreset *>*) presets presetData:(const FactoryPreset *)presetData {
    self = [super init];
    
    _presets = presets;
    _presetData = presetData;
    _parameterTree = tree;
    [self setCustomMIDIMap:@{}];
    
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

- (void) saveDefaultsForName: (NSString *)name {
    NSDictionary *settings = [self fullStateForDocumentWithDictionary: @{}];
    
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.burnsAudio.spectrum"];
    [sharedDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:settings] forKey:name];
    [sharedDefaults synchronize];
}

- (void) loadDefaultsForName: (NSString *)name {
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.burnsAudio.spectrum"];
    NSData *data = (NSData *) [sharedDefaults objectForKey:name];
    if (data != nil) {
        [self setFullStateForDocument: [NSKeyedUnarchiver unarchiveObjectWithData:data]];
    }
}

- (std::map<uint8_t, std::vector<MIDICCTarget>>) kernelMIDIMap {
    std::map<uint8_t, std::vector<MIDICCTarget>> kernelMIDIMap;
    
    for(int i = 0; i < _parameterTree.allParameters.count; i++) {
        AUParameterAddress address = _parameterTree.allParameters[i].address;
        if (address > 200) {
            continue;
        }
        NSNumber *mapping = [_midiMap objectForKey: @(address)];
        assert(mapping != nil);
        uint8_t controller = [[_midiMap objectForKey: @(address)] intValue];
        
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
            assert(false);
        }
    }
    
    return kernelMIDIMap;
}

- (void)setCustomMIDIMap:(NSDictionary<NSNumber*, NSNumber*> *) inputMap {
    NSMutableDictionary <NSNumber*, NSNumber*> *map = [[NSMutableDictionary alloc] init];
    
    NSArray<AUParameter *> *params = [_parameterTree.allParameters sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSNumber *first = @([(AUParameter*)a address]);
        NSNumber *second = @([(AUParameter*)b address]);
        return [first compare: second];
    }];
    
    NSArray *blacklist = @[@0, @1, @6, @7, @8, @10, @32, @33, @38, @64, @74, @96, @97, @98, @99, @100, @101, @120, @121, @122, @123, @124, @125, @126, @127];
    
    bool used[128];
    for (int i = 0; i < 128; i++) {
        used[i] = false;
    }
    for (int i = 0; i < blacklist.count; i++) {
        used[[blacklist[i] intValue]] = true;
    }
    
    for (int i = 0; i < inputMap.allKeys.count; i++) {
        uint8_t cc = (uint8_t) [inputMap[inputMap.allKeys[i]] intValue];
        used[cc] = true;
    }
    
    uint8_t count = 0;
    for(int i = 0; i < params.count; i++) {
        if (inputMap[@(params[i].address)] != nil) {
            map[@(params[i].address)] = inputMap[@(params[i].address)];
        } else {
            do {
                count++;
            } while (used[count]);
            if (count >= 128) {
                assert(false);
            }
            map[@(params[i].address)] = @(count);
        }
    }
    
    _midiMap = map;
}

@end
