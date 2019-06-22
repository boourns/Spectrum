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

class SpectrumUI {
    static var tree: AUParameterTree?
    static var parameters: [AUParameterAddress: (AUParameter, ParameterView)] = [:]
    static var isVertical: Bool = false
    static var colours = blue
    
    class func update(address: AUParameterAddress, value: Float) {
        guard let uiParam = SpectrumUI.parameters[address] else { return }
        DispatchQueue.main.async {
            uiParam.1.value = value
        }
    }
    
    static var cStacks: [UIStackView] = []
    
    static func modulationPage(lfoStart: AUParameterAddress, envStart: AUParameterAddress, modStart: AUParameterAddress) -> Page {
        return Page("Modulation",
            CStack([
                Stack([
                    Panel(Stack([
                        HStack([
                            Knob(lfoStart), // LFO Speed
                            Picker(lfoStart+1), // LFO Wave
                            Knob(lfoStart+2), // LFO Shape Mod
                            ]),
                        ])),
                    Panel2(Stack([
                        Slider(envStart),
                        Slider(envStart+1),
                        Slider(envStart+2),
                        Slider(envStart+3),
                        ]))
                    ]),
                Stack([
                    Panel(HStack([
                        ModTarget("LFO -> 1", modStart),
                        ModTarget("LFO -> 2", modStart+4),
                        ])),
                Panel2(Stack([
                    HStack([
                        ModTarget("Env -> 1", modStart+8),
                        ModTarget("Env -> 2", modStart+12),
                        ]),
                    ])),
                ])
        ]))
    }
    
    static func modMatrixPage(modStart: AUParameterAddress, numberOfRules: Int) -> Page {
        let ruleStack: [Panel] = (0...numberOfRules-1).map { index in
            let start: AUParameterAddress = modStart + UInt64(index*4)
            return Panel(CStack([HStack([Picker(start + 0), Picker(start + 1)]), HStack([Knob(start + 2), Picker(start+3)])]))
        }
        ruleStack.enumerated().forEach { index, panel in
            if index % 2 == 1 {
                panel.outline?.backgroundColor = SpectrumUI.colours.panel2
            }
        }

        return Page("Matrix", Stack(ruleStack), requiresScroll: true)
    }
    
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
    let containerView = UIScrollView()
    let navigationView = UIStackView()
    let pages: [Page]
    var currentPage: Page
    var stackVertically = false
    
    init(_ pages: [Page]) {
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
                button.backgroundColor = SpectrumUI.colours.panel2
                button.setTitleColor(UIColor.white, for: .normal)
            } else {
                button.backgroundColor = SpectrumUI.colours.background
                button.setTitleColor(SpectrumUI.colours.primary, for: .normal)
            }
        }
    }
    
    func updateScroll() {
        containerView.isScrollEnabled = (SpectrumUI.isVertical || currentPage.requiresScroll)
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
    convenience init(_ children: [UIView]) {
        self.init()
        
        axis = .horizontal
        alignment = .fill
        distribution = .fillEqually
        spacing = 1.0/UIScreen.main.scale
        translatesAutoresizingMaskIntoConstraints = false
        
        children.forEach { addArrangedSubview($0) }
        
        SpectrumUI.cStacks.append(self)
    }
}

class Panel: UIView {
    var outline: UIView? = nil
    
    convenience init(_ child: UIView) {
        self.init()
        setup(child: child)
    }
    
    func setup(child: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        let outline = UIView()
        outline.translatesAutoresizingMaskIntoConstraints = false
        outline.addSubview(child)
        addSubview(outline)
        NSLayoutConstraint.activate(child.constraints(insideWithSystemSpacing: outline, multiplier: 0.05))
        NSLayoutConstraint.activate(outline.constraints(insideWithSystemSpacing: self, multiplier: 0.05))
        outline.backgroundColor = SpectrumUI.colours.panel1
        outline.layer.borderColor = UIColor.black.cgColor
        outline.layer.borderWidth = 1.0 / UIScreen.main.scale
        self.outline = outline
    }
}

class Panel2: Panel {
    init(_ child: UIView) {
        super.init(frame: CGRect.zero)
        setup(child: child)
        outline?.backgroundColor = SpectrumUI.colours.panel2
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
