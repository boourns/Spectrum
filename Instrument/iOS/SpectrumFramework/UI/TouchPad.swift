//
//  TouchPad.swift
//  iOSSpectrumApp
//
//  Created by tom on 2019-06-18.
//

import Foundation
import UIKit

class TouchPadParameterContainer: ParameterView {
    let param: AUParameter
    let touchpad: TouchPad
    
    var value: Float {
        get {
            return param.value
        }
        
        set(val) {
            if (!touchpad.pad.touching) {
                param.value = val
                touchpad.setFromParams()
            }
        }
    }
    
    init(param: AUParameter, touchpad: TouchPad) {
        self.param = param
        self.touchpad = touchpad
    }
}

class TouchPad: UIView {
    fileprivate struct Params {
        let x: AUParameter
        let y: AUParameter
        let gate: AUParameter
    }
    fileprivate let params: Params
    let pad = AKTouchPadView()
    let state: SpectrumState
    var updaters: [TouchPadParameterContainer] = []
    
    init(_ state: SpectrumState, _ xAddress: AUParameterAddress, _ yAddress: AUParameterAddress, _ gateAddress: AUParameterAddress) {
        self.state = state
        guard let x = state.tree?.parameter(withAddress: xAddress),
            let y = state.tree?.parameter(withAddress: yAddress),
            let gate = state.tree?.parameter(withAddress: gateAddress) else {
            fatalError("Could not find parameter for touchpad")
        }
        self.params = Params(x: x, y: y, gate: gate)
        
        super.init(frame: CGRect.zero)
        self.updaters = [
            TouchPadParameterContainer(param: x, touchpad: self),
            TouchPadParameterContainer(param: y, touchpad: self),
            TouchPadParameterContainer(param: gate, touchpad: self),
        ]
        
        state.parameters[x.address] = (x, updaters[0])
        state.parameters[y.address] = (y, updaters[1])
        state.parameters[gate.address] = (gate, updaters[2])
        addSubview(pad)
        pad.translatesAutoresizingMaskIntoConstraints = false
        translatesAutoresizingMaskIntoConstraints = false
        pad.backgroundColor = .black
        pad.layer.borderWidth = 1.0 / UIScreen.main.scale
        pad.layer.borderColor = UIColor.white.cgColor
        pad.clipsToBounds = true
        NSLayoutConstraint.activate(pad.constraints(insideWithSystemSpacing: self, multiplier: 0.4))
        
        pad.callback = { [weak self] x, y, gate in
            guard let this = self else { return }
            this.params.x.value = AUValue(x)
            this.params.y.value = AUValue(y)
            this.params.gate.value = gate ? 1.0 : 0.0
        }
    }
    
    func setFromParams() {
        pad.updateTouchPoint(Double(params.x.value), Double(params.y.value))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
