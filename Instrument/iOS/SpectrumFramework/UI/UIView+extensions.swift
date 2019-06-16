//
//  UIView+extensions.swift
//  Granular
//
//  Created by tom on 2019-06-15.
//

import Foundation
import UIKit

extension UIView {

    func constraints(filling: UIView) -> [NSLayoutConstraint] {
        return [
            topAnchor.constraint(equalTo: filling.topAnchor),
            leadingAnchor.constraint(equalTo: filling.leadingAnchor),
            trailingAnchor.constraint(equalTo: filling.trailingAnchor),
            bottomAnchor.constraint(equalTo: filling.bottomAnchor)
        ]
    }
}
