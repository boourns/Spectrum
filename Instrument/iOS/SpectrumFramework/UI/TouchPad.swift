//
//  TouchPad.swift
//  iOSSpectrumApp
//
//  Created by tom on 2019-06-18.
//

import Foundation
import UIKit

class TouchPad: UIView {
    fileprivate struct Params {
        let x: AUParameter
        let y: AUParameter
        let gate: AUParameter
    }
    fileprivate let params: Params
    let pad = AKTouchPadView()
    
    init(_ xAddress: AUParameterAddress, _ yAddress: AUParameterAddress, _ gateAddress: AUParameterAddress) {
        guard let x = SpectrumUI.tree?.parameter(withAddress: xAddress),
            let y = SpectrumUI.tree?.parameter(withAddress: yAddress),
            let gate = SpectrumUI.tree?.parameter(withAddress: gateAddress) else {
            fatalError("Could not find parameter for touchpad")
        }
        self.params = Params(x: x, y: y, gate: gate)
        super.init(frame: CGRect.zero)
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
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
