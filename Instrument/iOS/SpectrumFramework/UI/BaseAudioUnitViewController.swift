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

open class BaseAudioUnitViewController: AUViewController { //, InstrumentViewDelegate {
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
    public var state: SpectrumState = SpectrumState()
    
    var ui: UI?

    open override func loadView() {
        super.loadView()
        view.backgroundColor = state.colours.background
        
        UILabel.appearance().tintColor = state.colours.primary
        UISlider.appearance().tintColor = state.colours.primary
        UIButton.appearance().tintColor = state.colours.primary
    }
    
    open override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        layout()
    }
    
    open override func viewDidLoad() {
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
        state.tree = paramTree
        
        NSLog("Connecting with AU")
        
        ui = buildUI()
        
        NSLog("Registering parameter callback")
        
        parameterObserverToken = paramTree.token(byAddingParameterObserver: { [weak self] address, value in
            self?.state.update(address: address, value: value)
        })
        
        paramTree.allParameters.forEach { [weak self] param in
            self?.state.update(address: param.address, value: param.value)
        }
        
        view.addSubview(ui!)
        NSLayoutConstraint.activate(view.constraints(filling: ui!))
        
        layout()

        ui?.selectPage(0)
    }
    
    func layout() {
        var pageAxis: NSLayoutConstraint.Axis = .horizontal
        var pageDistribution: UIStackView.Distribution = .fillEqually

        if view.frame.width < ResponsiveBreak {
            pageAxis = .vertical
            pageDistribution = .equalCentering
        }
        
        state.isVertical = (view.frame.width < ResponsiveBreak)
        
        state.cStacks.forEach { view in
            view.axis = pageAxis
            view.distribution = pageDistribution
        }
    }
    
    open func buildUI() -> UI {
        fatalError("Override buildUI() in child VC")
    }
    
    public func knob(_ address: AUParameterAddress, size: CGFloat = 60.0) -> Knob {
        return Knob(state, address, size: size)
    }
    
    public func intKnob(_ address: AUParameterAddress, size: CGFloat = 60.0) -> IntKnob {
        return IntKnob(state, address, size: size)
    }
    
    public func picker(_ address: AUParameterAddress) -> Picker {
        return Picker( state, address)
    }
    
    public func slider(_ address: AUParameterAddress) -> Slider {
        return Slider( state, address)
    }
    
    public func touchPad(_ xAddress: AUParameterAddress, _ yAddress: AUParameterAddress, _ gateAddress: AUParameterAddress) -> TouchPad {
        return TouchPad(state, xAddress, yAddress, gateAddress)
    }
    
    public func modTarget(_ name: String, _ address: AUParameterAddress) -> ModTarget {
        return ModTarget(state, name, address)
    }
    
    public func panel(_ child: UIView) -> Panel {
        return Panel(state, child)
    }
    
    public func panel2(_ child: UIView) -> Panel2 {
        return Panel2(state, child)
    }
    
    public func cStack(_ children: [UIView]) -> CStack {
        return CStack(state, children)
    }
    
    public func button(_ address: AUParameterAddress, momentary: Bool = false) -> Button {
        return Button(state, address, momentary: momentary)
    }
    
    public func lfoPage(rate: AUParameterAddress, shape: AUParameterAddress, shapeMod: AUParameterAddress, tempoSync: AUParameterAddress, resetPhase: AUParameterAddress, keyReset: AUParameterAddress, modStart: AUParameterAddress) -> Page {
        return Page("LFO",
            cStack([
                Stack([
                    panel(Stack([
                        HStack([
                            knob(rate), // LFO Speed
                            picker(shape), // LFO Wave
                            knob(shapeMod), // LFO Shape Mod
                            ]),
                        ])),
                    panel2(HStack([
                        button(tempoSync, momentary: false),
                        knob(resetPhase),
                        button(keyReset, momentary: false)
                        ]))
                    ]),
                Stack([
                    panel(HStack([
                        modTarget("LFO -> 1", modStart),
                        modTarget("LFO -> 2", modStart+4),
                        ])),
                ])
            ])
        )
    }
    
    public func envPage(envStart: AUParameterAddress, modStart: AUParameterAddress) -> Page {
        return Page("Env",
                    cStack([
                        Stack([
                            panel2(Stack([
                                slider(envStart),
                                slider(envStart+1),
                                slider(envStart+2),
                                slider(envStart+3),
                                ]))
                            ]),
                            panel(Stack([
                                HStack([
                                    ]),
                                ])),
                        Stack([
                            panel2(Stack([
                                HStack([
                                    modTarget("Env -> 1", modStart+8),
                                    modTarget("Env -> 2", modStart+12),
                                    ]),
                                ])),
                            ]),
                            panel(HStack([
                                ])),
                        ]))
    }
    
    public func modMatrixPage(modStart: AUParameterAddress, numberOfRules: Int) -> Page {
        let ruleStack: [Panel] = (0...numberOfRules-1).map { index in
            let start: AUParameterAddress = modStart + UInt64(index*4)
            return panel(cStack([HStack([picker(start + 0), picker(start + 1)]), HStack([knob(start + 2), picker(start+3)])]))
        }
        ruleStack.enumerated().forEach { index, panel in
            if index % 2 == 1 {
                panel.outline?.backgroundColor = state.colours.panel2
            }
        }
        
        return Page("Matrix", Stack(ruleStack), requiresScroll: true)
    }
    
}
