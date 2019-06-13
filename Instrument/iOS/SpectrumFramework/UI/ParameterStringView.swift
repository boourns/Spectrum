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

protocol ParameterStringViewDelegate: NSObject {
    func parameterStringView(didUpdate: ParameterStringView)
}

class ParameterStringView: UIView, ParameterView {
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
    weak var delegate: ParameterStringViewDelegate? = nil
    
    init(param: AUParameter) {
        self.param = param
        self.valueStrings = param.valueStrings!
        self.value = param.value
        
        super.init(frame: CGRect.zero)
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
            label.topAnchor.constraint(equalToSystemSpacingBelow: topAnchor, multiplier: 0.5),
            bottomAnchor.constraint(equalToSystemSpacingBelow: label.bottomAnchor, multiplier: 0.5),
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
            this.delegate?.parameterStringView(didUpdate: this)
        }
        
        rightButton.addControlEvent(.touchUpInside) { [weak self] in
            guard let this = self else { return }
            let newValue = this.value + 1.0
            if (newValue > Float(this.valueStrings.count - 1)) {
                this.value = 0.0
            } else {
                this.value = newValue
            }
            this.delegate?.parameterStringView(didUpdate: this)
        }
    }
    
    private func updateDisplay() {
        let index = Int(round(value)) % valueStrings.count
        valueLabel.text = valueStrings[index]
    }
}
