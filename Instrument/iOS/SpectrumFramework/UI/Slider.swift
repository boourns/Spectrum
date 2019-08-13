//
//  ParameterSliderView.swift
//  iOSInstrumentDemoFramework
//
//  Created by tom on 2019-05-20.
//

import Foundation
import UIKit
import CoreAudioKit

open class ParameterSlider: Slider, ParameterView {
    let param: AUParameter
    let spectrumState: SpectrumState

    init(_ state: SpectrumState, _ address: AUParameterAddress) {
        self.spectrumState = state
        guard let param = state.tree?.parameter(withAddress: address) else {
            fatalError("Could not find parameter for address \(address)")
        }
        
        self.param = param
        
        super.init(name: param.displayName, value: param.value, minValue: param.minValue, maxValue: param.maxValue, stackVertically: false)
        
        spectrumState.parameters[param.address] = (param, self)
        
        addControlEvent(.valueChanged) { [weak self] in
            guard let this = self else { return }
            this.param.value = this.value
        }
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func displayString(_ val: Float) -> String {
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

open class Slider: UIControl {
    let label = UILabel()
    let slider: PSlider
    var pressed = false {
        didSet {
            label.text = displayString(slider.value)
        }
    }
    
    var value: Float {
        get {
            return slider.value
        }
        
        set(val) {
            slider.value = val
            label.text = displayString(val)
        }
    }
    
    let stackVertically: Bool
    let name: String
    let minValue: Float
    let maxValue: Float
    
    init(name: String, value: Float, minValue: Float, maxValue: Float, stackVertically: Bool) {
        self.name = name
        self.minValue = minValue
        self.maxValue = maxValue
        self.stackVertically = stackVertically
        
        if (minValue < 0) {
            self.slider = PSlider(bipolar: true)
        } else {
            self.slider = PSlider(bipolar: false)
        }
        
        super.init(frame: CGRect.zero)
        
        self.value = value
        
        setup()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        
        label.textColor = UILabel.appearance().tintColor
        label.text = name
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.isUserInteractionEnabled = true
        
        let tapGesture = UITapGestureRecognizer() { [weak self] in
            guard let this = self else { return }
            this.value = 0.0
            
        }
        label.addGestureRecognizer(tapGesture)
        
        slider.minimumValue = minValue
        slider.maximumValue = maxValue
        slider.isContinuous = true
        
        slider.addControlEvent(.touchDown) { [weak self] in
            self?.pressed = true
        }
        
        slider.addControlEvent(.touchUpInside) { [weak self] in
            self?.pressed = false
        }
        
        slider.addControlEvent(.touchUpOutside) { [weak self] in
            self?.pressed = false
        }
        
        slider.addControlEvent(.valueChanged) { [weak self] in
            guard let this = self else { return }
            this.sendActions(for: .valueChanged)
        }
        
        label.translatesAutoresizingMaskIntoConstraints = false
        slider.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(slider)
        addSubview(label)

        var constraints: [NSLayoutConstraint] = []
        
        if stackVertically {
            constraints = [
                slider.leadingAnchor.constraint(equalTo: label.leadingAnchor, constant: 7.0/UIScreen.main.scale),
                label.topAnchor.constraint(equalToSystemSpacingBelow: topAnchor, multiplier: 0.5),
                trailingAnchor.constraint(equalToSystemSpacingAfter: slider.trailingAnchor, multiplier: 0.5),
                slider.topAnchor.constraint(equalToSystemSpacingBelow: label.bottomAnchor, multiplier: 0.5),
                label.leadingAnchor.constraint(equalToSystemSpacingAfter: leadingAnchor, multiplier:0.5),
                trailingAnchor.constraint(equalToSystemSpacingAfter: label.trailingAnchor, multiplier: 0.5),
                bottomAnchor.constraint(equalToSystemSpacingBelow: slider.bottomAnchor, multiplier: 0.5)
            ]
        } else {
            constraints = [
                label.leadingAnchor.constraint(equalToSystemSpacingAfter: leadingAnchor, multiplier:0.5),
                slider.topAnchor.constraint(equalToSystemSpacingBelow: topAnchor, multiplier: 0.5),
                bottomAnchor.constraint(equalToSystemSpacingBelow: slider.bottomAnchor, multiplier: 0.5),
                label.widthAnchor.constraint(equalToConstant: 100.0),
                slider.leadingAnchor.constraint(equalToSystemSpacingAfter: label.trailingAnchor, multiplier:0.5),
                slider.centerYAnchor.constraint(equalTo: label.centerYAnchor),
                trailingAnchor.constraint(equalToSystemSpacingAfter: slider.trailingAnchor, multiplier: 0.5)
            ]
        }
        NSLayoutConstraint.activate(constraints)
    }
    
    func displayString(_ val: Float) -> String {
        if pressed {
            return String(format:"%.03f", val)
        } else  {
            return name
        }
    }
}
