//
//  Knob.swift
//  iOSSpectrumApp
//
//  Created by tom on 2019-06-15.
//

import Foundation
import UIKit
import CoreAudioKit

open class IntKnob : Knob {
    override init(_ state: SpectrumState, _ address: AUParameterAddress, size: CGFloat = 60.0) {
        super.init(state, address, size: size)
        knob.roundValue = true
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override
    func displayString(_ val: Float) -> String {
        if pressed {
            if let values = param.valueStrings {
                let index = Int(round(val))
                if values.count > index {
                    return values[index]
                } else {
                    return "??"
                }
            } else {
                return String(format:"%.0f", val)
            }
        } else  {
            return param.displayName
        }
    }
}

open class Knob: UIView, ParameterView {
    let param: AUParameter
    let label = UILabel()
    let knob: LiveKnob = LiveKnob()
    
    var pressed = false {
        didSet {
            label.text = displayString(knob.value)
        }
    }
    
    var value: Float {
        get {
            return knob.value
        }
        
        set(val) {
            if !pressed {
                knob.internalValue = val
            }
        }
    }
    
    let size: CGFloat
    let state: SpectrumState
    
    init(_ state: SpectrumState, _ address: AUParameterAddress, size: CGFloat = 60.0) {
        self.state = state
        guard let param = state.tree?.parameter(withAddress: address) else {
            fatalError("Could not find parameter for address \(address)")
        }
        
        self.param = param
        self.size = size
        
        super.init(frame: CGRect.zero)
        
        state.parameters[param.address] = (param, self)
        
        setup()
    }
    
    public required init?(coder aDecoder: NSCoder) {
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
            this.label.text = this.displayString(this.knob.value)
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
        
        knob.addControlEvent(.touchDown) { [weak self] in
            self?.pressed = true
        }
        
        knob.addControlEvent(.touchUpInside) { [weak self] in
            self?.pressed = false
        }
        
        knob.addControlEvent(.touchUpOutside) { [weak self] in
            self?.pressed = false
        }
        
        value = param.value
    }
    
    func displayString(_ val: Float) -> String {
        if pressed {
            if let values = param.valueStrings {
                let index = Int(round(val))
                if values.count > index {
                    return values[index]
                } else {
                    return "??"
                }
            } else {
                return String(format:"%.03f", val)
            }
        } else  {
            return param.displayName
        }
    }
}
