//
//  BaseAudioUnitViewController.swift
//  iOSSpectrumFramework
//
//  Created by tom on 2019-05-28.
//

import UIKit
import AVFoundation
import CoreAudioKit



let ResponsiveBreak = CGFloat(540.0)

public class BaseAudioUnitViewController: AUViewController { //, InstrumentViewDelegate {
    // MARK: Properties
    
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
        view.backgroundColor = SpectrumUI.colours.background
        
        UILabel.appearance().tintColor = SpectrumUI.colours.primary
        UISlider.appearance().tintColor = SpectrumUI.colours.secondary
        UIButton.appearance().tintColor = SpectrumUI.colours.secondary
    }
    
    public override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        layout()
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
        
        layout()

        ui?.selectPage(0)
        
        parameterObserverToken = paramTree.token(byAddingParameterObserver: { address, value in
            SpectrumUI.update(address: address, value: value)
        })
    }
    
    func layout() {
        var pageAxis: NSLayoutConstraint.Axis = .horizontal
        var pageDistribution: UIStackView.Distribution = .fillEqually

        if view.frame.width < ResponsiveBreak {
            pageAxis = .vertical
            pageDistribution = .equalCentering
        }

        SpectrumUI.cStacks.forEach { view in
            view.axis = pageAxis
            view.distribution = pageDistribution
        }
    }
    
    func buildUI() -> UI {
        fatalError("Override buildUI() in child VC")
    }
}
