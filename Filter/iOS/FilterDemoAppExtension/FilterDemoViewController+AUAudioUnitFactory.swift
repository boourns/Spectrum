/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	FilterDemoViewController is the app extension's principal class, responsible for creating both the audio unit and its view.
*/

import CoreAudioKit
import FilterDemoFramework

extension FilterDemoViewController: AUAudioUnitFactory {
    /*
        This implements the required `NSExtensionRequestHandling` protocol method.
        Note that this may become unnecessary in the future, if `AUViewController`
        implements the override.
     */
    public override func beginRequest(with context: NSExtensionContext) { }
    
    /*
        This implements the required `AUAudioUnitFactory` protocol method.
        When this view controller is instantiated in an extension process, it
        creates its audio unit.
     */
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        audioUnit = try AUv3FilterDemo(componentDescription: componentDescription, options: [])
        
        return audioUnit!
    }
}
