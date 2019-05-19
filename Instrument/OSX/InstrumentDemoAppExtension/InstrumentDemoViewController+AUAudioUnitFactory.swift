//
//  InstrumentDemoViewController+AUAudioUnitFactory.swift
//  iOSInstrumentDemoApp
//
//  Created by tom on 2019-05-19.
//

import InstrumentDemoFramework

extension InstrumentDemoViewController: AUAudioUnitFactory {
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
    audioUnit = try AUv3InstrumentDemo(componentDescription: componentDescription, options: [])
    
    return audioUnit!
  }
}
