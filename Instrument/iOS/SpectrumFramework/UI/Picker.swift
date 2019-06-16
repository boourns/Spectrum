//
//  ParameterStringView.swift
//  iOSInstrumentDemoFramework
//
//  Created by tom on 2019-05-27.
//

import Foundation
import CoreAudio
import UIKit
import AVFoundation
import CoreAudioKit

class Picker: UIView, ParameterView {
    let param: AUParameter
    let valueStrings: [String]
    let valueLabel = UILabel()
    let label = UILabel()
    var value: Float {
        didSet {
            updateDisplay()
        }
    }
    
    init(_ address: AUParameterAddress) {
        guard let param = SpectrumUI.tree?.parameter(withAddress: address) else {
            fatalError("Could not find param for address \(address)")
        }
        self.param = param
        self.valueStrings = param.valueStrings!
        self.value = param.value
        
        super.init(frame: CGRect.zero)
        SpectrumUI.parameters[param.address] = (param, self)

        setup()
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.text = param.displayName
        label.textColor = UILabel.appearance().tintColor

        label.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        valueLabel.textAlignment = .center
        valueLabel.textColor = UILabel.appearance().tintColor
        
        let leftButton = UIButton()
        let rightButton = UIButton()
        //leftButton.setTitleColor(UIColor.black, for: .normal)
        //rightButton.setTitleColor(UIColor.black, for: .normal)

        leftButton.translatesAutoresizingMaskIntoConstraints = false
        rightButton.translatesAutoresizingMaskIntoConstraints = false
        
        leftButton.setTitle("◀︎", for: .normal)
        rightButton.setTitle("▶︎", for: .normal)
        
        addSubview(label)
        addSubview(leftButton)
        addSubview(rightButton)
        addSubview(valueLabel)
        
        let constraints = [
            leftButton.leadingAnchor.constraint(equalToSystemSpacingAfter: leadingAnchor, multiplier: 1.0),
            leftButton.topAnchor.constraint(equalToSystemSpacingBelow: topAnchor, multiplier: 1.0),
            trailingAnchor.constraint(equalToSystemSpacingAfter: rightButton.trailingAnchor, multiplier: 1.0),
            rightButton.topAnchor.constraint(equalToSystemSpacingBelow: topAnchor, multiplier: 1.0),
            valueLabel.centerYAnchor.constraint(equalTo: leftButton.centerYAnchor),
            valueLabel.leadingAnchor.constraint(equalToSystemSpacingAfter: leftButton.trailingAnchor, multiplier: 0.2),
            rightButton.leadingAnchor.constraint(equalToSystemSpacingAfter: valueLabel.trailingAnchor, multiplier: 0.2),
            label.topAnchor.constraint(lessThanOrEqualToSystemSpacingBelow: rightButton.bottomAnchor, multiplier: 1.0),
            label.topAnchor.constraint(lessThanOrEqualToSystemSpacingBelow: valueLabel.bottomAnchor, multiplier: 1.0),
        ]
        NSLayoutConstraint.activate(constraints)
        
        leftButton.addControlEvent(.touchUpInside) { [weak self] in
            guard let this = self else { return }
            let newValue = this.value - 1.0
            if (newValue < 0.0) {
                this.value = Float(this.valueStrings.count - 1)
            } else {
                this.value = newValue
            }
            this.param.value = this.value
        }
        
        rightButton.addControlEvent(.touchUpInside) { [weak self] in
            guard let this = self else { return }
            let newValue = this.value + 1.0
            if (newValue > Float(this.valueStrings.count - 1)) {
                this.value = 0.0
            } else {
                this.value = newValue
            }
            this.param.value = this.value
        }
        value = param.value
    }
    
    private func updateDisplay() {
        let index = Int(round(value)) % valueStrings.count
        valueLabel.text = valueStrings[index]
    }
}
