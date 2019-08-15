//
//  MIDIProcessorWrapper.m
//  iOSSpectrumFramework
//
//  Created by tom on 2019-08-12.
//

#import <Foundation/Foundation.h>
#import "MIDIProcessorWrapper.h"
#import "MIDIProcessor.hpp"

@implementation MIDIProcessorWrapper {
    MIDIProcessor *processor;
    void (^settingsUpdateCallback)(void);
}


- (void) setMIDIProcessor: (void *) midiProcessor {
    processor = (MIDIProcessor *) midiProcessor;
}

- (void) onSettingsUpdate: (void(^)(void))callback {
    settingsUpdateCallback = callback;
}

- (NSDictionary *) settings {
    NSMutableDictionary *settings = [[NSMutableDictionary alloc] init];
    settings[@"channel"] = @(processor->channelSetting);
    settings[@"automation"] = @(processor->automation ? 1 : 0);
    return settings;
}

- (void) updateSettings:(NSDictionary *)settings {
    NSNumber *value;
    
    value = (NSNumber *) settings[@"channel"];
    if (value != nil) {
        processor->setChannel(value.intValue);
    }
    
    value = (NSNumber *) settings[@"automation"];
    if (value != nil) {
        processor->setAutomation(value.intValue == 1);
    }
    
    if (settingsUpdateCallback != nil) {
        settingsUpdateCallback();
    }
}

- (int) channel {
    return processor->channelSetting;
}

- (void) setChannel: (int) ch {
    processor->setChannel(ch);
}

- (bool) automation {
    return processor->automation;
}

- (void) setAutomation: (bool) automation {
    processor->setAutomation(automation);
}

@end
