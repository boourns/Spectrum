/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 View controller for the InstrumentDemo audio unit. This is the app extension's principal class, responsible for creating both the audio unit and its view. Manages the interactions between a InstrumentView and the audio unit's parameters.
 */

import UIKit
import AVFoundation
import CoreAudioKit

public class SpectrumViewController: AUViewController { //, InstrumentViewDelegate {
    // MARK: Properties
    
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
    
    public override func loadView() {
        super.loadView()
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
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor)
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
            let paramView = ParameterSliderView(param: param)
            
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
    }
}

extension SpectrumViewController: ParameterStringViewDelegate {
    func parameterStringView(didUpdate parameterView: ParameterStringView) {
        parameterView.param.value = parameterView.value
    }
}

extension SpectrumViewController: AUAudioUnitFactory {
    /*
     This implements the required `NSExtensionRequestHandling` protocol method.
     Note that this may become unnecessary in the future, if `AUViewController`
     implements the override.
     */
    public override func beginRequest(with context: NSExtensionContext) { }
    
    /*
     This implements the required `AUAudioUnitFactory` protocol method.
     When this view controller is instantiated in an extension process, it
     creates its audio unit.
     */
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        audioUnit = try SpectrumAudioUnit(componentDescription: componentDescription, options: [])
        
        return audioUnit!
    }
}

