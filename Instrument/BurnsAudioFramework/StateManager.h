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
#import "MIDIProcessorWrapper.h"

typedef struct {
    NSString *name;
    NSString *data;
} FactoryPreset;

@interface StateManager : NSObject

@property AUParameterTree *parameterTree;
@property NSArray *presets;

- (id) initWithParameterTree:(AUParameterTree *) tree presets:(NSArray<AUAudioUnitPreset *>*) presets presetData:(const FactoryPreset *)presetData;

- (void) setMIDIProcessor: (MIDIProcessorWrapper *)midiProcessor;

// MARK - State
- (NSDictionary *)fullStateWithDictionary: (NSDictionary *) parentState;
- (void)setFullState:(NSDictionary *)fullState;
- (NSDictionary *)fullStateForDocumentWithDictionary: (NSDictionary *) parentState;
- (void)setFullStateForDocument:(NSDictionary *)fullState;
- (void) loadDefaultsForName: (NSString *)name;
- (void) saveDefaultsForName: (NSString *)name;

// MARK - Presets
- (AUAudioUnitPreset *)currentPreset;
- (void)setCurrentPreset:(AUAudioUnitPreset *)currentPreset;

// MARK - MIDI CC Map
- (std::map<uint8_t, std::vector<MIDICCTarget>>) kernelMIDIMap;
- (void)setCustomMIDIMap:(NSDictionary<NSNumber*, NSNumber*> *) map;

@end


#endif /* StateManager_h */
