//
//  KnobUI.swift
//  Granular
//
//  Created by tom on 2019-06-15.
//

import Foundation
import UIKit

struct SpectrumColours {
    let primary: UIColor
    let secondary: UIColor
    let secondBackground: UIColor
    let background: UIColor
}

class SpectrumUI {
    static var tree: AUParameterTree?
    static var parameters: [AUParameterAddress: (AUParameter, ParameterView)] = [:]
    static var colours = SpectrumColours(
        primary: UIColor.init(hex: "#d0d6d9ff")!,
        secondary: UIColor.init(hex: "#bfc0c0ff")!,
        secondBackground: UIColor.init(hex: "#0d1b7aff")!, //"#313335ff")!,
        background: UIColor.init(hex: "#181b1cff")!
    )
    class func update(address: AUParameterAddress, value: Float) {
        guard let uiParam = SpectrumUI.parameters[address] else { return }
        DispatchQueue.main.async {
            uiParam.1.value = value
        }
    }
    
    static var cStacks: [UIStackView] = []
}

class UI: UIView {
    let containerView = UIScrollView()
    let navigationView = UIStackView()
    let pages: [Page]
    var stackVertically = false
    
    init(_ pages: [Page]) {
        self.pages = pages
        super.init(frame: CGRect.zero)
        translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(containerView)
        addSubview(navigationView)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        navigationView.translatesAutoresizingMaskIntoConstraints = false
        //containerView.contentMode = .scaleAspectFill
        containerView.isDirectionalLockEnabled = true
        navigationView.axis = .horizontal
        navigationView.distribution = .fillEqually
        
        let constraints = [
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: navigationView.topAnchor),
            navigationView.leadingAnchor.constraint(equalTo: leadingAnchor),
            navigationView.trailingAnchor.constraint(equalTo: trailingAnchor),
            navigationView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ]
        NSLayoutConstraint.activate(constraints)
        
        containerView.isScrollEnabled = true
        
        pages.enumerated().forEach { index, page in
            containerView.addSubview(page)
            
            let constraints = [
                page.topAnchor.constraint(equalTo: containerView.topAnchor),
                page.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                page.trailingAnchor.constraint(equalTo: trailingAnchor),
                containerView.bottomAnchor.constraint(greaterThanOrEqualTo: page.bottomAnchor)
            ]
            NSLayoutConstraint.activate(constraints)
            
            let button = UIButton()
            button.setTitle(page.name, for: .normal)
            button.setTitleColor(UIColor.black, for: .normal)
            
            button.addControlEvent(.touchUpInside) { [weak self] in
                self?.selectPage(index)
            }
            
            navigationView.addArrangedSubview(button)
        }
    }
    
    func selectPage(_ selectedIndex: Int) {
        pages.enumerated().forEach { index, page in
            page.isHidden = (selectedIndex != index)
            if selectedIndex == index {
                containerView.contentSize = CGSize(width: containerView.bounds.size.width,
                                                   height: page.bounds.height + 10)
            }
        }
        
        navigationView.arrangedSubviews.enumerated().forEach { index, view in
            guard let button = view as? UIButton else { return }
            if index == selectedIndex {
                button.backgroundColor = SpectrumUI.colours.secondary
                button.setTitleColor(UIColor.white, for: .normal)
            } else {
                button.backgroundColor = SpectrumUI.colours.background
                button.setTitleColor(SpectrumUI.colours.primary, for: .normal)
            }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class Page: UIView {
    public let name: String
    
    init(_ name: String, _ child: UIView) {
        self.name = name
        super.init(frame: CGRect.zero)
        
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(child)
        NSLayoutConstraint.activate(child.constraints(filling: self))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class Stack: UIStackView {
    convenience init(_ children: [UIView]) {
        self.init()
        
        axis = .vertical
        alignment = .fill
        spacing = 1.0/UIScreen.main.scale
        translatesAutoresizingMaskIntoConstraints = false
        
        children.forEach { addArrangedSubview($0) }
    }
}

class HStack: UIStackView {
    convenience init(_ children: [UIView]) {
        self.init()
        
        axis = .horizontal
        alignment = .fill
        distribution = .fillEqually
        spacing = 1.0/UIScreen.main.scale
        translatesAutoresizingMaskIntoConstraints = false
        
        children.forEach { addArrangedSubview($0) }
    }
}

class CStack: UIStackView {
    convenience init(_ children: [UIView]) {
        self.init()
        
        axis = .horizontal
        alignment = .firstBaseline
        distribution = .fillEqually
        spacing = 1.0/UIScreen.main.scale
        translatesAutoresizingMaskIntoConstraints = false
        
        children.forEach { addArrangedSubview($0) }
        
        SpectrumUI.cStacks.append(self)
    }
}

class Panel: UIView {
    convenience init(_ child: UIView) {
        self.init()
        
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(child)
        NSLayoutConstraint.activate(child.constraints(filling: self))
        backgroundColor = SpectrumUI.colours.secondBackground
    }
}