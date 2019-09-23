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
    settings[@"mpeEnabled"] = @(processor->mpe.enabled ? 1 : 0);
    settings[@"mpeMasterChannel"] = @(processor->mpe.masterChannel);

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
    
    value = (NSNumber *) settings[@"mpeEnabled"];
    if (value != nil) {
        processor->setMPEEnabled(value.intValue == 1);
    }
    
    value = (NSNumber *) settings[@"mpeMasterChannel"];
    if (value != nil) {
        processor->mpe.setMasterChannel(value.intValue);
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

- (bool) mpeEnabled {
    return processor->mpe.enabled;
}

- (void) setMPEEnabled: (bool) enabled {
    processor->setMPEEnabled(enabled);
}

- (int) mpeMasterChannel {
    return processor->mpe.masterChannel;
}

- (void) setMPEMasterChannel: (int) channel {
    processor->mpe.setMasterChannel(channel);
}



@end
