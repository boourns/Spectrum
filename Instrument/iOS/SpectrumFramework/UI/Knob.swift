//
//  Knob.swift
//  iOSSpectrumApp
//
//  Created by tom on 2019-06-15.
//

import Foundation
import UIKit
import CoreAudioKit

class Knob: UIView, ParameterView {
    let param: AUParameter
    let label = UILabel()
    let knob: LiveKnob = LiveKnob()
    
    var value: Float {
        get {
            return knob.value
        }
        
        set(val) {
            knob.value = val
        }
    }
    
    let size: CGFloat
    
    init(_ address: AUParameterAddress, size: CGFloat = 60.0) {
        guard let param = SpectrumUI.tree?.parameter(withAddress: address) else {
            fatalError("Could not find parameter for address \(address)")
        }
        
        self.param = param
        self.size = size
        
        super.init(frame: CGRect.zero)
        
        SpectrumUI.parameters[param.address] = (param, self)
        
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        
        label.textColor = UILabel.appearance().tintColor
        label.text = param.displayName
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer() { [weak self] in
            guard let this = self else { return }
            this.param.value = 0.0
        }
        label.addGestureRecognizer(tapGesture)
        
        knob.minimumValue = param.minValue
        knob.maximumValue = param.maxValue
        knob.continuous = true
        knob.controlType = .horizontalAndVertical
        
        knob.addControlEvent(.valueChanged) { [weak self] in
            guard let this = self else { return }
            this.param.value = this.knob.value
        }
        
        label.translatesAutoresizingMaskIntoConstraints = false
        knob.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(knob)
        addSubview(label)
        
        let constraints: [NSLayoutConstraint] = [
            knob.topAnchor.constraint(equalToSystemSpacingBelow: topAnchor, multiplier: 1.0),
            knob.widthAnchor.constraint(equalToConstant: size),
            knob.heightAnchor.constraint(equalToConstant: size),
            knob.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.topAnchor.constraint(equalToSystemSpacingBelow: knob.bottomAnchor, multiplier: 0.3),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            bottomAnchor.constraint(greaterThanOrEqualToSystemSpacingBelow: label.bottomAnchor, multiplier: 1.0),
            bottomAnchor.constraint(greaterThanOrEqualToSystemSpacingBelow: knob.bottomAnchor, multiplier: 1.0)
        ]
        
        NSLayoutConstraint.activate(constraints)
        value = param.value
    }
}
