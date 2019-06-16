//
//  KnobUI.swift
//  Granular
//
//  Created by tom on 2019-06-15.
//

import Foundation
import UIKit

class SpectrumUI {
    static var tree: AUParameterTree?
    static var parameters: [AUParameterAddress: (AUParameter, ParameterView)] = [:]
    
    class func update(address: AUParameterAddress, value: Float) {
        guard let uiParam = SpectrumUI.parameters[address] else { return }
        DispatchQueue.main.async {
            uiParam.1.value = value
        }
    }
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
                //button.backgroundColor = colours.secondary
                //button.setTitleColor(UIColor.white, for: .normal)
            } else {
                //button.backgroundColor = colours.background
                //button.setTitleColor(colours.primary, for: .normal)
            }
        }
    }
    
    func layout() {
//        var pageAxis: NSLayoutConstraint.Axis = .horizontal
//        var pageAlignment: UIStackView.Alignment = .firstBaseline
//        var pageDistribution: UIStackView.Distribution = .fillEqually
//
//        if view.frame.width < ResponsiveBreak {
//            pageAxis = .vertical
//            pageAlignment = .fill
//            pageDistribution = .equalCentering
//        }
//
//        pages.forEach { page in
//            guard let view = page.view as? UIStackView else { return }
//            view.axis = pageAxis
//            view.alignment = pageAlignment
//            view.distribution = pageDistribution
//        }
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
        spacing = Spacing.betweenParameters
        translatesAutoresizingMaskIntoConstraints = false
        
        children.forEach { addArrangedSubview($0) }
    }
}

class HStack: UIStackView {
    convenience init(_ children: [UIView]) {
        self.init()
        
        axis = .horizontal
        alignment = .firstBaseline
        distribution = .fillEqually
        spacing = Spacing.betweenParameters
        translatesAutoresizingMaskIntoConstraints = false
        
        children.forEach { addArrangedSubview($0) }
    }
}
