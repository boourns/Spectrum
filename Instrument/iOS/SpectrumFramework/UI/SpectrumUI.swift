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
    let panel2: UIColor
    let panel1: UIColor
    let background: UIColor
}

class SpectrumState {
    var tree: AUParameterTree?
    var parameters: [AUParameterAddress: (AUParameter, ParameterView)] = [:]
    var isVertical: Bool = false
    var colours: SpectrumColours = SpectrumUI.blue
    var cStacks: [UIStackView] = []
    
    func update(address: AUParameterAddress, value: Float) {
        guard let uiParam = parameters[address] else { return }
        DispatchQueue.main.async {
            uiParam.1.value = value
        }
    }
}

class SpectrumUI {
    
    static let greyscale = SpectrumColours(
        primary: UIColor.init(hex: "#d0d6d9ff")!,
        panel2: UIColor.init(hex: "#38393bff")!,
        panel1: UIColor.init(hex: "#292a30ff")!, //"#313335ff")!,
        background: UIColor.init(hex: "#1e2022ff")!
    )
    
    static let blue = SpectrumColours(
        primary: UIColor.init(hex: "#d0d6d9ff")!,
        panel2: UIColor.init(hex: "#092d81ff")!,
        panel1: UIColor.init(hex: "#072364ff")!, //"#313335ff")!,
        background: UIColor.init(hex: "#111111ff")!
    )
    
    static let red = SpectrumColours(
        primary: UIColor.init(hex: "#d0d6d9ff")!,
        panel2: UIColor.init(hex: "#890916ff")!,
        panel1: UIColor.init(hex: "#640710ff")!, //"#313335ff")!,
        background: UIColor.init(hex: "#111111ff")!
    )
    
    static let purple = SpectrumColours(
        primary: UIColor.init(hex: "#d0d6d9ff")!,
        panel2: UIColor.init(hex: "#890948ff")!,
        panel1: UIColor.init(hex: "#640735ff")!, //"#313335ff")!,
        background: UIColor.init(hex: "#111111ff")!
    )
    
    static let green = SpectrumColours(
        primary: UIColor.init(hex: "#d0d6d9ff")!,
        panel2: UIColor.init(hex: "#147129ff")!,
        panel1: UIColor.init(hex: "#00570Fff")!, //"#313335ff")!,
        background: UIColor.init(hex: "#111111ff")!
    )
}

class UI: UIView {
    let state: SpectrumState
    let containerView = UIScrollView()
    let navigationView = UIStackView()
    let pages: [Page]
    var currentPage: Page
    var stackVertically = false
    
    init(state: SpectrumState, _ pages: [Page]) {
        self.state = state
        self.pages = pages
        self.currentPage = self.pages[0]
        
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
                page.bottomAnchor.constraint(greaterThanOrEqualTo: containerView.bottomAnchor)
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
                
                currentPage = page
            }
        }
        
        updateScroll()
        
        navigationView.arrangedSubviews.enumerated().forEach { index, view in
            guard let button = view as? UIButton else { return }
            if index == selectedIndex {
                button.backgroundColor = state.colours.panel2
                button.setTitleColor(UIColor.white, for: .normal)
            } else {
                button.backgroundColor = state.colours.background
                button.setTitleColor(state.colours.primary, for: .normal)
            }
        }
    }
    
    func updateScroll() {
        containerView.isScrollEnabled = (state.isVertical || currentPage.requiresScroll)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class Page: UIView {
    public let name: String
    public let requiresScroll: Bool
    
    init(_ name: String, _ child: UIView, requiresScroll: Bool = false) {
        self.name = name
        self.requiresScroll = requiresScroll
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
        distribution = .equalCentering
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
    let state: SpectrumState
    
    init(_ state: SpectrumState, _ children: [UIView]) {
        self.state = state
        super.init(frame: CGRect.zero)
        
        axis = .horizontal
        alignment = .fill
        distribution = .fillEqually
        spacing = 1.0/UIScreen.main.scale
        translatesAutoresizingMaskIntoConstraints = false
        
        children.forEach { addArrangedSubview($0) }
        
        state.cStacks.append(self)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class Panel: UIView {
    var outline: UIView? = nil
    
    let state: SpectrumState
    
    init(_ state: SpectrumState, _ child: UIView) {
        self.state = state
        
        super.init(frame: CGRect.zero)
        setup(child: child)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setup(child: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        let outline = UIView()
        outline.translatesAutoresizingMaskIntoConstraints = false
        outline.addSubview(child)
        addSubview(outline)
        NSLayoutConstraint.activate(child.constraints(insideWithSystemSpacing: outline, multiplier: 0.05))
        NSLayoutConstraint.activate(outline.constraints(insideWithSystemSpacing: self, multiplier: 0.05))
        outline.backgroundColor = state.colours.panel1
        outline.layer.borderColor = UIColor.black.cgColor
        outline.layer.borderWidth = 1.0 / UIScreen.main.scale
        self.outline = outline
    }
}

class Panel2: Panel {
    override init(_ state: SpectrumState, _ child: UIView) {
        super.init(state, child)
        setup(child: child)
        outline?.backgroundColor = state.colours.panel2
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
