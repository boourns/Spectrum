//
//  AudioUnitViewController.swift
//  SpectrumAudioUnit
//
//  Created by tom on 2019-05-27.
//

import CoreAudioKit

public class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
    var audioUnit: AUAudioUnit?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        if audioUnit == nil {
            return
        }
        
        // Get the parameter tree and add observers for any parameters that the UI needs to keep in sync with the AudioUnit
    }
    
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        audioUnit = try SpectrumAudioUnitAudioUnit(componentDescription: componentDescription, options: [])
        
        return audioUnit!
    }
    
}
