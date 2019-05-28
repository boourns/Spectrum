//
//  ParameterSliderView.swift
//  iOSInstrumentDemoFramework
//
//  Created by tom on 2019-05-20.
//

import Foundation
import UIKit
import CoreAudioKit

class ParameterSliderView: UIView {
  let param: AUParameter
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
  
  init(param: AUParameter) {
    self.param = param
    
    if (param.minValue < 0) {
        self.slider = PSlider(bipolar: true)
    } else {
        self.slider = PSlider(bipolar: false)
    }
    
    super.init(frame: CGRect.zero)
    setup()
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    translatesAutoresizingMaskIntoConstraints = false
    
    label.text = param.displayName
    
    slider.minimumValue = param.minValue
    slider.maximumValue = param.maxValue
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
    
    addSubview(label)
    addSubview(slider)
    label.translatesAutoresizingMaskIntoConstraints = false
    slider.translatesAutoresizingMaskIntoConstraints = false

    let constraints = [
        label.leadingAnchor.constraint(equalToSystemSpacingAfter: leadingAnchor, multiplier:0.5),
        slider.topAnchor.constraint(equalToSystemSpacingBelow: topAnchor, multiplier: 0.5),
        bottomAnchor.constraint(equalToSystemSpacingBelow: slider.bottomAnchor, multiplier: 0.5),
        label.widthAnchor.constraint(equalToConstant: 100.0),
        slider.leadingAnchor.constraint(equalToSystemSpacingAfter: label.trailingAnchor, multiplier:0.5),
        slider.centerYAnchor.constraint(equalTo: label.centerYAnchor),
        trailingAnchor.constraint(equalToSystemSpacingAfter: slider.trailingAnchor, multiplier: 0.5)
    ]
    
    // nice big vertically stacked label + slider
//    let constraints = [
//      label.leadingAnchor.constraint(equalToSystemSpacingAfter: leadingAnchor, multiplier:0.5),
//      label.topAnchor.constraint(equalToSystemSpacingBelow: topAnchor, multiplier: 0.5),
//      trailingAnchor.constraint(equalToSystemSpacingAfter: label.trailingAnchor, multiplier: 0.5),
//      slider.topAnchor.constraint(equalToSystemSpacingBelow: label.bottomAnchor, multiplier: 0.5),
//      slider.leadingAnchor.constraint(equalToSystemSpacingAfter: leadingAnchor, multiplier:0.5),
//      trailingAnchor.constraint(equalToSystemSpacingAfter: slider.trailingAnchor, multiplier: 0.5),
//      bottomAnchor.constraint(equalToSystemSpacingBelow: slider.bottomAnchor, multiplier: 0.5)
//    ]
    NSLayoutConstraint.activate(constraints)
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
        return String(format:"%.02f", val)
      }
    } else  {
      return param.displayName
    }
  }
}

extension ParameterSliderView: ParameterView { }
