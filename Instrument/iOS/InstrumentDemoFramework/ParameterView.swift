//
//  ParameterView.swift
//  iOSInstrumentDemoFramework
//
//  Created by tom on 2019-05-20.
//

import Foundation
import UIKit
import CoreAudioKit

class ParameterView: UIView {
  let param: AUParameter
  let label = UILabel()
  let slider = UISlider()
  var pressed = false {
    didSet {
      label.text = displayString(slider.value)
    }
  }
  
  var displayValue: Float {
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
      label.topAnchor.constraint(equalToSystemSpacingBelow: topAnchor, multiplier: 0.5),
      bottomAnchor.constraint(equalToSystemSpacingBelow: label.bottomAnchor, multiplier: 0.5),
      label.widthAnchor.constraint(equalToConstant: 100.0),
      slider.leadingAnchor.constraint(equalToSystemSpacingAfter: label.trailingAnchor, multiplier:0.5),
      slider.centerYAnchor.constraint(equalTo: label.centerYAnchor),
      trailingAnchor.constraint(equalToSystemSpacingAfter: slider.trailingAnchor, multiplier: 0.5)
    ]
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
        return "\(val)"
      }
    } else  {
      return param.displayName
    }
  }
}
