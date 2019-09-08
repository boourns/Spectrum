//
//  AKTouchPadView.swift
//  AudioKit
//
//  Created by AudioKit Contributors, revision history on Github.
//  Copyright © 2017 AudioKit. All rights reserved.
//

import UIKit

public class AKTouchPadView: UIView {
    
    // touch properties
    var firstTouch: UITouch?
    var touching = false
    
    public typealias AKTouchPadCallback = (Double, Double, Bool) -> Void
    var callback: AKTouchPadCallback = { _, _, _ in }

    var x: CGFloat = 0
    var y: CGFloat = 0
    private var lastX: CGFloat = 0
    private var lastY: CGFloat = 0
    
    public var horizontalValue: Double = 0 {
        didSet {
            horizontalValue = max(0.0, min(1.0, horizontalValue))
            x = CGFloat(horizontalValue)
        }
    }
    
    public var verticalValue: Double = 0 {
        didSet {
            verticalValue = max(0.0, min(1.0, verticalValue))
            y = CGFloat(verticalValue)
        }
    }
    
    var touchPointView = UIView()
    var guideX = UIView()
    var guideY = UIView()
    
    var touchCenter: CGPoint {
        get {
            return touchPointView.center
        }
        set(val) {
            touchPointView.center = val
            guideX.frame = CGRect(x: val.x, y: 0.0, width: 1.0 / UIScreen.main.scale, height: frame.height)
            guideY.frame = CGRect(x: 0.0, y: val.y, width: frame.width, height: 1.0 / UIScreen.main.scale)
        }
    }
    
    init() {
        // Setup Touch Visual Indicators
        let width = 20.0
        
        touchPointView = UIView(frame: CGRect(x: -200, y: -200, width: width, height: width))
        touchPointView.backgroundColor = UIColor.white
        guideX = UIView()
        guideX.backgroundColor = UIColor.white
        guideY = UIView()
        guideY.backgroundColor = UIColor.white
        touchPointView.layer.cornerRadius = 6.0
        
        super.init(frame: CGRect.zero)

        touchCenter = CGPoint(x: self.bounds.size.width / 2, y: self.bounds.size.height / 2)
        touchPointView.isOpaque = false
        guideY.isOpaque = false
        guideY.isOpaque = false
        addSubview(touchPointView)
        addSubview(guideY)
        addSubview(guideX)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        resetToPosition(horizontalValue, verticalValue)
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let touchPoint = touch.location(in: self)
            lastX = touchPoint.x
            lastY = touchPoint.y
            setPercentagesWithTouchPoint(touchPoint, pressed: true)
        }
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let touchPoint = touch.location(in: self)
            NSLog("%f", touch.majorRadius)
            setPercentagesWithTouchPoint(touchPoint, pressed: true)
        }
    }
    
    // return indicator to center of view
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let touchPoint = touch.location(in: self)
            setPercentagesWithTouchPoint(touchPoint, pressed: false)
        }
    }
    
    func resetToCenter() {
        resetToPosition(0.5, 0.5)
    }
    
    func resetToPosition(_ newPercentX: Double, _ newPercentY: Double) {
        let centerPointX = self.bounds.size.width * CGFloat(newPercentX)
        let centerPointY = self.bounds.size.height * CGFloat(1 - newPercentY)
        UIView.animate(
            withDuration: 0.05,
            delay: 0.0,
            options: UIView.AnimationOptions(),
            animations: {
                self.touchCenter = CGPoint(x: centerPointX, y: centerPointY)
        },
            completion: { _ in
                self.x = CGFloat(newPercentX)
                self.y = CGFloat(newPercentY)
                self.horizontalValue = Double(self.x)
                self.verticalValue = Double(self.y)
                self.callback(self.horizontalValue, self.verticalValue, false)
        })
    }
    
    func updateTouchPoint(_ newX: Double, _ newY: Double) {
        let centerPointX = self.bounds.size.width * CGFloat(newX)
        let centerPointY = self.bounds.size.height * CGFloat(1 - newY)
        x = CGFloat(newX)
        y = CGFloat(newY)
        touchCenter = CGPoint(x: centerPointX, y: centerPointY)
    }
    
    func setPercentagesWithTouchPoint(_ touchPoint: CGPoint, pressed: Bool = false) {
        x = CGFloat(max(0.0, min(1.0, touchPoint.x / self.bounds.size.width)))
        y = CGFloat(max(0.0, min(1.0, 1 - touchPoint.y / self.bounds.size.height)))
        touchCenter = CGPoint(
            x: max(0.0, min(touchPoint.x, self.bounds.size.width)),
            y: max(0.0, min(touchPoint.y, self.bounds.size.height)))
        horizontalValue = Double(x)
        verticalValue = Double(y)
        callback(horizontalValue, verticalValue, pressed)
        touching = pressed
    }
}
