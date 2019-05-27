//
//  ParameterSliderView.swift
//  iOSInstrumentDemoFramework
//
//  Created by tom on 2019-05-20.
//

import Foundation
import UIKit
import CoreAudioKit

let SliderHeight: Int = 42

class PSlider: UISlider {
    let bipolar: Bool
    let barLayer = CALayer()
    
    init(bipolar: Bool) {
        self.bipolar = bipolar
        super.init(frame: CGRect.zero)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setup() {
        setMinimumTrackImage(UIImage.from(color: UIColor.clear), for: .normal)
        setMaximumTrackImage(UIImage.from(color: UIColor.clear), for: .normal)
        setThumbImage(UIImage.from(color: UIColor.clear), for: .normal)
        layer.addSublayer(barLayer)
        barLayer.backgroundColor = UIColor.black.cgColor
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.borderWidth = 1.0
        layer.borderColor = UIColor.darkGray.cgColor
        let x: CGFloat = CGFloat((value - minimumValue) / (maximumValue - minimumValue)) * frame.width
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // change layer properties that you don't want to animate
        if (bipolar) {
            let middle: CGFloat = frame.width / 2.0

            if value < 0.0 {
                barLayer.frame = CGRect(x: x, y: 0.0, width: middle - x, height: frame.height)
            } else {
                barLayer.frame = CGRect(x: middle, y: 0.0, width: x - middle, height: frame.height)
            }
        } else {
            barLayer.frame = CGRect(x: 0.0, y: 0.0, width: x, height: frame.height)
        }
        CATransaction.commit()

    }
    
    override open var intrinsicContentSize: CGSize {
        return CGSize(width: super.intrinsicContentSize.width, height: CGFloat(SliderHeight))
    }
    
    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        let original = super.trackRect(forBounds: bounds)
        return CGRect(x: original.minX - 1.0, y: original.minY - CGFloat(SliderHeight/2), width: original.width + 2.0, height: CGFloat(SliderHeight))
    }
    
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        return true
    }
}

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
        return String(format:"%.02f", val)
      }
    } else  {
      return param.displayName
    }
  }
}

extension ParameterSliderView: ParameterView { }
