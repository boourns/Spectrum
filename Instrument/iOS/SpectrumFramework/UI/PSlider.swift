//
//  PSlider.swift
//  iOSInstrumentDemoFramework
//
//  Created by tom on 2019-05-27.
//

import Foundation
import UIKit

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
        barLayer.backgroundColor = UIColor.white.cgColor
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.borderWidth = 1.0
        layer.borderColor = UIColor.white.cgColor
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
        return CGSize(width: super.intrinsicContentSize.width, height: Spacing.sliderHeight)
    }
    
    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        let original = super.trackRect(forBounds: bounds)
        return CGRect(x: original.minX - 1.0, y: original.minY - Spacing.sliderHeight/2, width: original.width + 2.0, height: Spacing.sliderHeight)
    }
    
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        return true
    }
}
