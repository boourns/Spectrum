//
//  InstrumentDemoViewController.swift
//  iOSInstrumentDemoApp
//
//  Created by tom on 2019-05-18.
//

import Foundation
import Cocoa
import CoreAudioKit

public class InstrumentDemoViewController: AUViewController {
  public var audioUnit: AUv3InstrumentDemo? {
    didSet {
      DispatchQueue.main.async {
        if self.isViewLoaded {
          self.connectViewWithAU()
        }
      }
    }
  }
  
  public override func loadView() {
    view = NSView()
  }
  
  var parameterObserverToken: AUParameterObserverToken?
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    
    // Respond to changes in the instrumentView (attack and/or release changes).
    
    guard audioUnit != nil else { return }
    
    connectViewWithAU()
  }
  
  /*
   We can't assume anything about whether the view or the AU is created first.
   This gets called when either is being created and the other has already
   been created.
   */
  func connectViewWithAU() {
    guard let paramTree = audioUnit?.parameterTree else { return }
    
  }
}

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
