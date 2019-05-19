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

