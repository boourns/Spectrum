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
        label.textAlignment = .center
        //valueLabel.backgroundColor = SpectrumUI.colours.background
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.textAlignment = .center
        valueLabel.textColor = UILabel.appearance().tintColor
        valueLabel.numberOfLines = 0
        valueLabel.lineBreakMode = .byWordWrapping
        
        let leftButton = UIButton()
        let rightButton = UIButton()
        //leftButton.setTitleColor(UIColor.black, for: .normal)
        //rightButton.setTitleColor(UIColor.black, for: .normal)

        leftButton.translatesAutoresizingMaskIntoConstraints = false
        rightButton.translatesAutoresizingMaskIntoConstraints = false
        
        leftButton.setTitle("◀︎", for: .normal)
        rightButton.setTitle("▶︎", for: .normal)
        
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)
        container.addSubview(leftButton)
        container.addSubview(rightButton)
        container.addSubview(valueLabel)

        addSubview(label)
        
        let constraints = [
            container.topAnchor.constraint(equalToSystemSpacingBelow: topAnchor, multiplier: Spacing.inner),
            container.leadingAnchor.constraint(equalToSystemSpacingAfter: leadingAnchor, multiplier: Spacing.inner),
            trailingAnchor.constraint(equalToSystemSpacingAfter: container.trailingAnchor, multiplier: Spacing.inner),
            label.topAnchor.constraint(equalToSystemSpacingBelow: container.bottomAnchor, multiplier: Spacing.inner),
            
            leftButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            leftButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            rightButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            rightButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            leftButton.topAnchor.constraint(greaterThanOrEqualTo: container.topAnchor),
            container.bottomAnchor.constraint(greaterThanOrEqualTo: leftButton.bottomAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
//            valueLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            valueLabel.leadingAnchor.constraint(equalTo: leftButton.trailingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: rightButton.leadingAnchor),
            bottomAnchor.constraint(equalToSystemSpacingBelow: label.bottomAnchor, multiplier: Spacing.margin),
            label.leadingAnchor.constraint(equalToSystemSpacingAfter: leadingAnchor, multiplier: Spacing.margin),
            trailingAnchor.constraint(equalToSystemSpacingAfter: label.trailingAnchor, multiplier: Spacing.margin),
            container.heightAnchor.constraint(lessThanOrEqualTo: container.widthAnchor)
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
