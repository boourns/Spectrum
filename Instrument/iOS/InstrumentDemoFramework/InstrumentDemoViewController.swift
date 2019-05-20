/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	View controller for the InstrumentDemo audio unit. This is the app extension's principal class, responsible for creating both the audio unit and its view. Manages the interactions between a InstrumentView and the audio unit's parameters.
*/

import UIKit
import CoreAudioKit

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
    
    paramTree.allParameters.forEach { param in
      let label = UILabel()
      label.text = param.displayName
      groupStack.addArrangedSubview(label)
//      if let values = param.valueStrings {
//        print(values)
//      } else {
        let slider = UISlider()
        slider.minimumValue = param.minValue
        slider.maximumValue = param.maxValue
        slider.isContinuous = true
        groupStack.addArrangedSubview(slider)
//        slider.addControlEvent(.valueChanged) {
//          param.value = slider.value
//        }
      //}
    }

		//attackParameter = paramTree.value(forKey: "timbre") as? AUParameter

		parameterObserverToken = paramTree.token(byAddingParameterObserver: { [weak self] address, value in
            guard let strongSelf = self else { return }
			DispatchQueue.main.async {
//        if address == strongSelf.attackParameter!.address {
//                    strongSelf.updateAttack()
//        }
			}
		})
        
        //updateAttack()
	}
    
//    func updateAttack() {
//      guard let param = attackParameter else { return }
//        attackTextField.text = param.string(fromValue: nil)
//        attackSlider.value = (log10(param.value) + 3.0) * 100.0
//    }
  
    // MARK:
    // MARK: Actions
    
//  @IBAction func changedAttack(_ sender: AnyObject?) {
//        guard sender === attackSlider else { return }
//
//        // Set the parameter's value from the slider's value.
//        attackParameter!.value = pow(10.0, attackSlider.value * 0.01 - 3.0)
//  }
}
