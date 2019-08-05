//
//  LFOImage.swift
//  iOSSpectrumApp
//
//  Created by tom on 2019-07-30.
//

import Foundation
import UIKit

public class LFOImage: UIView {
    let renderLfo: ()->[NSNumber]?
    
    var data: [NSNumber] = []
    public private(set) var lfoLayer = CAShapeLayer()
    
    public init(renderLfo: @escaping ()->[NSNumber]?) {
        self.renderLfo = renderLfo
        
        super.init(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        setup()
    }
    
    func setup() {
        lfoLayer.fillColor = UIColor.orange.cgColor
        layer.addSublayer(lfoLayer)
        
        translatesAutoresizingMaskIntoConstraints = false
        
        let constraints = [
          widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
          heightAnchor.constraint(greaterThanOrEqualToConstant: 200)
        ]
        
        NSLayoutConstraint.activate(constraints)
    }
    
    // MARK: Lifecycle
    public override func draw(_ rect: CGRect) {
        super.draw(rect)

        data = renderLfo() ?? []
        lfoLayer.bounds = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        lfoLayer.position = CGPoint(x: bounds.width / 2.0, y: bounds.height/2.0)
        
        let lfoLine = UIBezierPath()
        
        lfoLine.move(to: CGPoint(x: 0, y: (bounds.height / 2) - (CGFloat(data[0].floatValue) * (bounds.height/2))))
        
        var xPos = CGFloat(0)
        
        let incr = bounds.width / CGFloat(data.count)
        
        for point in data {
            xPos += incr
            lfoLine.addLine(to: CGPoint(x: xPos, y: (bounds.height / 2) - (CGFloat(point.floatValue) * (bounds.height/2))))
        }
        
        lfoLayer.path = lfoLine.cgPath
        lfoLayer.lineCap = .round
        lfoLayer.lineWidth = 1.0
        lfoLayer.strokeColor = UIColor.orange.cgColor
        lfoLayer.fillColor = UIColor.clear.cgColor
        clipsToBounds = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
