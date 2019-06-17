//
//  ModTarget.swift
//  iOSSpectrumFramework
//
//  Created by tom on 2019-06-16.
//

import Foundation
import CoreAudioKit

class ModTarget: Stack {
    convenience init(_ name: String, _ ruleAddress: AUParameterAddress) {
        let knob = Knob(ruleAddress+2)
        let picker = Picker(ruleAddress+3)
        self.init([
            knob,
            picker
        ])
        distribution = .equalCentering
        knob.label.removeFromSuperview()
        picker.label.text = name
        
        picker.label.isUserInteractionEnabled = true
        picker.label.isEnabled = true
        let tapGesture = UITapGestureRecognizer() {
            knob.param.value = 0.0
        }
        picker.label.addGestureRecognizer(tapGesture)
    }
}
