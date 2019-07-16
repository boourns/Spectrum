//
//  StateManager.h
//  Spectrum
//
//  Created by tom on 2019-07-16.
//

#ifndef StateManager_h
#define StateManager_h

#import <AVFoundation/AVFoundation.h>
#import "MIDIProcessor.hpp"

typedef struct {
    NSString *name;
    NSString *data;
} FactoryPreset;

@interface StateManager : NSObject

@property AUParameterTree *parameterTree;
@property NSArray *presets;

- (id) initWithParameterTree:(AUParameterTree *) tree presets:(NSArray<AUAudioUnitPreset *>*) presets presetData:(const FactoryPreset *)presetData;

// MARK - State
- (NSDictionary *)fullStateWithDictionary: (NSDictionary *) parentState;
- (void)setFullState:(NSDictionary *)fullState;

// MARK - Presets
- (AUAudioUnitPreset *)currentPreset;
- (void)setCurrentPreset:(AUAudioUnitPreset *)currentPreset;

// MARK - MIDI CC Map
- (std::map<uint8_t, std::vector<MIDICCTarget>>) defaultMIDIMap;

@end


#endif /* StateManager_h */
