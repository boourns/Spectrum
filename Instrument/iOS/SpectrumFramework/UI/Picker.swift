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
    let stack = UIStackView()
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
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        
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

        leftButton.setTitle("◀︎", for: .normal)
        rightButton.setTitle("▶︎", for: .normal)
        
        addSubview(label)
        addSubview(stack)
        stack.addArrangedSubview(leftButton)
        stack.addArrangedSubview(valueLabel)
        stack.addArrangedSubview(rightButton)
        
        let constraints = [
            label.leadingAnchor.constraint(equalToSystemSpacingAfter: leadingAnchor, multiplier:0.5),
            label.topAnchor.constraint(equalTo: topAnchor, constant: CGFloat(63.0)/UIScreen.main.scale),
            bottomAnchor.constraint(equalTo: label.bottomAnchor, constant: CGFloat(63.0)/UIScreen.main.scale),
            label.widthAnchor.constraint(equalToConstant: 100.0),
            stack.leadingAnchor.constraint(equalToSystemSpacingAfter: label.trailingAnchor, multiplier:0.5),
            valueLabel.widthAnchor.constraint(equalToConstant: 100.0),
            //stack.widthAnchor.constraint(equalToConstant: 140.0),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
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
