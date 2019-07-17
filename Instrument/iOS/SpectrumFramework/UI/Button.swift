//
//  Button.swift
//  iOSSpectrumFramework
//
//  Created by tom on 2019-06-19.
//

import Foundation
import UIKit
import CoreAudioKit

open class Button: UIView {
    let param: AUParameter
    let button = UIButton()
    let momentary: Bool
    
    var pressed: Bool {
        return (value > 0.9)
    }
    
    var value: Float {
        get {
            return param.value
        }
        
        set(val) {
            param.value = val
            updateButton()
        }
    }
    
    let state: SpectrumState
    
    init(_ state: SpectrumState, _ address: AUParameterAddress, momentary: Bool = false) {
        self.state = state
        guard let param = state.tree?.parameter(withAddress: address) else {
            fatalError("Could not find parameter for address \(address)")
        }
        
        self.param = param
        self.momentary = momentary
        
        super.init(frame: CGRect.zero)
        
        state.parameters[param.address] = (param, self)
        
        setup()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(param.displayName, for: .normal)
        button.setTitleColor(state.colours.primary, for: .normal)
        button.setTitleColor(state.colours.background, for: .highlighted)
        addSubview(button)
        button.layer.borderColor = state.colours.primary.cgColor
        button.layer.borderWidth = 1.0 / UIScreen.main.scale
        button.layer.cornerRadius = 10
        
        let constraints: [NSLayoutConstraint] = [
          button.leadingAnchor.constraint(equalToSystemSpacingAfter: leadingAnchor, multiplier: Spacing.margin),
          trailingAnchor.constraint(equalToSystemSpacingAfter: button.trailingAnchor, multiplier: Spacing.margin),
          button.centerYAnchor.constraint(equalTo: centerYAnchor),
          button.topAnchor.constraint(greaterThanOrEqualToSystemSpacingBelow: topAnchor, multiplier: Spacing.margin),
          bottomAnchor.constraint(greaterThanOrEqualToSystemSpacingBelow: button.bottomAnchor, multiplier: Spacing.margin)
        ]
        
        NSLayoutConstraint.activate(constraints)
        
        if momentary {
            button.addControlEvent(.touchDown) { [weak self] in
                guard let this = self else { return }
                this.value = 1.0
            }
            button.addControlEvent(.touchUpInside) { [weak self] in
                guard let this = self else { return }
                this.value = 0.0
            }
            button.addControlEvent(.touchUpOutside) { [weak self] in
                guard let this = self else { return }
                this.value = 0.0
            }
        } else {
            button.addControlEvent(.touchUpInside) { [weak self] in
                guard let this = self else { return }
                this.value = this.pressed ? 0.0 : 1.0
            }
        }
        
        updateButton()
    }
    
    func updateButton() {
        button.isHighlighted = pressed

        if pressed {
            button.backgroundColor = .white
        } else {
            button.backgroundColor = .black
        }
    }
}

extension Button: ParameterView { }
