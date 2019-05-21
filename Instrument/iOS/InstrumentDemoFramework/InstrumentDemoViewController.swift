/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	View controller for the InstrumentDemo audio unit. This is the app extension's principal class, responsible for creating both the audio unit and its view. Manages the interactions between a InstrumentView and the audio unit's parameters.
*/

import UIKit
import CoreAudioKit
import ActionKit

public class InstrumentDemoViewController: AUViewController { //, InstrumentViewDelegate {
    // MARK: Properties
	
    public var audioUnit: AUv3InstrumentDemo? {
      didSet {
        DispatchQueue.main.async {
          if self.isViewLoaded {
            self.connectViewWithAU()
          }
        }
      }
    }
  
	var parameterObserverToken: AUParameterObserverToken?
  let stack = UIStackView()
  var params: [AUParameterAddress: (AUParameter, ParameterView)] = [:]
  
  public override func loadView() {
    super.loadView()
    stack.axis = .vertical
    view.addSubview(stack)
    stack.translatesAutoresizingMaskIntoConstraints = false
    
    let constraints = [
      stack.topAnchor.constraint(equalTo: view.topAnchor),
      stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: view.trailingAnchor)
    ]
    
    NSLayoutConstraint.activate(constraints)
  }
	
	public override func viewDidLoad() {
		super.viewDidLoad()
		
		// Respond to changes in the instrumentView (attack and/or release changes).
		
        guard audioUnit != nil else { return }

        connectViewWithAU()
	}
    
	/*
		We can't assume anything about whether the view or the AU is created first.
		This gets called when either is being created and the other has already 
        been created.
	*/
	func connectViewWithAU() {
		guard let paramTree = audioUnit?.parameterTree else { return }
    
    let groupStack = UIStackView()
    groupStack.axis = .vertical
    groupStack.spacing = 8.0
    stack.addArrangedSubview(groupStack)
    
    paramTree.children.forEach { group in
      guard let group = group as? AUParameterGroup else { return }
      group.allParameters.forEach { param in
        let paramView = ParameterView(param: param)
        
        groupStack.addArrangedSubview(paramView)
        paramView.slider.addControlEvent(.valueChanged) {
          param.value = paramView.slider.value
        }
        
        params[param.address] = (param, paramView)
        update(param: param, view: paramView)
      }
    }

		parameterObserverToken = paramTree.token(byAddingParameterObserver: { [weak self] address, value in
            guard let this = self, let uiParam = this.params[address] else { return }
			DispatchQueue.main.async {
        this.update(param: uiParam.0, view: uiParam.1)
			}
		})
  }
  
  func update(param: AUParameter, view: ParameterView) {
    view.displayValue = param.value
  }
}
