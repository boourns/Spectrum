//
//  BaseAudioUnitViewController.swift
//  iOSSpectrumFramework
//
//  Created by tom on 2019-05-28.
//

import UIKit
import AVFoundation
import CoreAudioKit

struct SpectrumColours {
    let primary: UIColor
    let secondary: UIColor
    let background: UIColor
}

public class BaseAudioUnitViewController: AUViewController { //, InstrumentViewDelegate {
    // MARK: Properties
    var colours = SpectrumColours(
        primary: UIColor.init(hex: "#bfc0c0ff")!,
        secondary: UIColor.init(hex: "#bfc0c0ff")!,
        background: UIColor.init(hex: "#2d3142ff")!
    )
    
    public var audioUnit: AUAudioUnit? {
        didSet {
            DispatchQueue.main.async {
                if self.isViewLoaded {
                    self.connectViewWithAU()
                }
            }
        }
    }
    var params: [AUParameterAddress: (AUParameter, ParameterView)] = [:]
    var parameterObserverToken: AUParameterObserverToken?
    
    let containerView = UIView()
    let navigationView = UIStackView()
    var pages: [(name: String, view: UIView)] = []
    var stackVertically = false
    
    public override func loadView() {
        super.loadView()
        view.backgroundColor = colours.background
        
        UILabel.appearance().tintColor = colours.primary
        UISlider.appearance().tintColor = colours.secondary
        UIButton.appearance().tintColor = colours.secondary
        
        view.addSubview(containerView)
        view.addSubview(navigationView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        navigationView.translatesAutoresizingMaskIntoConstraints = false
        containerView.contentMode = .scaleAspectFill
        navigationView.axis = .horizontal
        navigationView.distribution = .fillEqually
        
        let constraints = [
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: navigationView.topAnchor),
            navigationView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navigationView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ]
        NSLayoutConstraint.activate(constraints)
    }
    
    func viewForPage(group: AUParameterGroup) -> UIStackView {
        let stack = UIStackView()
        
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .firstBaseline
        stack.spacing = 20.0
        containerView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let constraints = [
            stack.topAnchor.constraint(equalToSystemSpacingBelow: view.topAnchor, multiplier: 1.0),
            stack.leadingAnchor.constraint(equalToSystemSpacingAfter: view.leadingAnchor, multiplier: 1.0),
            view.trailingAnchor.constraint(equalToSystemSpacingAfter: stack.trailingAnchor, multiplier: 1.0),
        ]
        
        NSLayoutConstraint.activate(constraints)
        
        group.children.forEach { group in
            guard let group = group as? AUParameterGroup else { return }
            let groupStack = viewForGroup(group: group)
            stack.addArrangedSubview(groupStack)
        }
        
        return stack
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Respond to changes in the instrumentView (attack and/or release changes).
        
        guard audioUnit != nil else { return }
        
        connectViewWithAU()
    }
    
    func viewForGroup(group: AUParameterGroup) -> UIStackView {
        let groupStack = UIStackView()
        groupStack.axis = .vertical
        groupStack.spacing = Spacing.betweenParameters
        
        group.allParameters.forEach { param in
            let paramView = viewForParam(param)
            groupStack.addArrangedSubview(paramView)
            
            params[param.address] = (param, paramView)
            update(param: param, view: paramView)
        }
        return groupStack
    }
    
    func viewForParam(_ param: AUParameter) -> ParameterView {
        if param.valueStrings != nil {
            let paramView = ParameterStringView(param: param)
            paramView.delegate = self
            return paramView
        } else {
            let paramView = ParameterSliderView(param: param, stackVertically: stackVertically)
            
            paramView.slider.addControlEvent(.valueChanged) {
                param.value = paramView.slider.value
            }
            return paramView
        }
    }
    
    /*
     We can't assume anything about whether the view or the AU is created first.
     This gets called when either is being created and the other has already
     been created.
     */
    func connectViewWithAU() {
        guard let paramTree = audioUnit?.parameterTree else { return }
        
        paramTree.children.forEach { group in
            guard let group = group as? AUParameterGroup else { return }
            let pageView = viewForPage(group: group)
            pages.append((name: group.displayName, view: pageView))
        }
        
        pages.enumerated().forEach { index, page in
            let button = UIButton()
            button.setTitle(page.name, for: .normal)
            button.setTitleColor(UIColor.black, for: .normal)
            button.addControlEvent(.touchUpInside) { [weak self] in
                self?.selectPage(index)
            }
            navigationView.addArrangedSubview(button)
        }
        
        selectPage(0)
        
        parameterObserverToken = paramTree.token(byAddingParameterObserver: { [weak self] address, value in
            guard let this = self, let uiParam = this.params[address] else { return }
            DispatchQueue.main.async {
                this.update(param: uiParam.0, view: uiParam.1)
            }
        })
    }
    
    func update(param: AUParameter, view: ParameterView) {
        view.value = param.value
    }
    
    func selectPage(_ selectedIndex: Int) {
        pages.enumerated().forEach { index, page in
            page.view.isHidden = (selectedIndex != index)
        }
        navigationView.arrangedSubviews.enumerated().forEach { index, view in
            guard let button = view as? UIButton else { return }
            if index == selectedIndex {
                button.backgroundColor = colours.secondary
                button.setTitleColor(UIColor.white, for: .normal)
            } else {
                button.backgroundColor = colours.background
                button.setTitleColor(colours.primary, for: .normal)
            }
        }
    }
}

extension BaseAudioUnitViewController: ParameterStringViewDelegate {
    func parameterStringView(didUpdate parameterView: ParameterStringView) {
        parameterView.param.value = parameterView.value
    }
}
