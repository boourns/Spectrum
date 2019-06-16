//
//  BaseAudioUnitViewController.swift
//  iOSSpectrumFramework
//
//  Created by tom on 2019-05-28.
//

import UIKit
import AVFoundation
import CoreAudioKit

struct SpectrumColours {
    let primary: UIColor
    let secondary: UIColor
    let secondBackground: UIColor
    let background: UIColor
}

let ResponsiveBreak = CGFloat(540.0)

public class BaseAudioUnitViewController: AUViewController { //, InstrumentViewDelegate {
    // MARK: Properties
    var colours = SpectrumColours(
        primary: UIColor.init(hex: "#d0d6d9ff")!,
        secondary: UIColor.init(hex: "#bfc0c0ff")!,
        secondBackground: UIColor.init(hex: "#313335ff")!,
        background: UIColor.init(hex: "#181b1cff")!
    )
    
    public var audioUnit: AUAudioUnit? {
        didSet {
            DispatchQueue.main.async {
                if self.isViewLoaded {
                    self.connectViewWithAU()
                }
            }
        }
    }
    var parameterObserverToken: AUParameterObserverToken?
    
    var ui: UI?

    public override func loadView() {
        super.loadView()
        view.backgroundColor = colours.background
        
        UILabel.appearance().tintColor = colours.primary
        UISlider.appearance().tintColor = colours.secondary
        UIButton.appearance().tintColor = colours.secondary
    }
    
    public override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        ui?.layout()
    }
    
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
        SpectrumUI.tree = paramTree
        
        ui = buildUI()
        view.addSubview(ui!)
        NSLayoutConstraint.activate(view.constraints(filling: ui!))
        
        ui?.layout()

        ui?.selectPage(0)
        
        parameterObserverToken = paramTree.token(byAddingParameterObserver: { address, value in
            SpectrumUI.update(address: address, value: value)
        })
    }
    
    func buildUI() -> UI {
        fatalError("Override buildUI() in child VC")
    }
}
