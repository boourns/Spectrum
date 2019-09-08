//
//  UIView+extensions.swift
//  Granular
//
//  Created by tom on 2019-06-15.
//

import Foundation
import UIKit

public extension UIView {

    func constraints(filling: UIView) -> [NSLayoutConstraint] {
        return [
            topAnchor.constraint(equalTo: filling.topAnchor),
            leadingAnchor.constraint(equalTo: filling.leadingAnchor),
            trailingAnchor.constraint(equalTo: filling.trailingAnchor),
            bottomAnchor.constraint(equalTo: filling.bottomAnchor)
        ]
    }
    
    func constraints(safelyFilling filling: UIView) -> [NSLayoutConstraint] {
        return [
            topAnchor.constraint(equalTo: filling.safeAreaLayoutGuide.topAnchor),
            leadingAnchor.constraint(equalTo: filling.safeAreaLayoutGuide.leadingAnchor),
            trailingAnchor.constraint(equalTo: filling.safeAreaLayoutGuide.trailingAnchor),
            bottomAnchor.constraint(equalTo: filling.safeAreaLayoutGuide.bottomAnchor)
        ]
    }
    
    func constraints(insideWithSystemSpacing parent: UIView, multiplier: CGFloat) -> [NSLayoutConstraint] {
        return [
            topAnchor.constraint(equalToSystemSpacingBelow: parent.topAnchor, multiplier: multiplier),
            leadingAnchor.constraint(equalToSystemSpacingAfter: parent.leadingAnchor, multiplier: multiplier),
            parent.trailingAnchor.constraint(equalToSystemSpacingAfter: trailingAnchor, multiplier: multiplier),
            parent.bottomAnchor.constraint(equalToSystemSpacingBelow: bottomAnchor, multiplier: multiplier)
        ]
    }
}
