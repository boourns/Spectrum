/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	View controller for the FilterDemo audio unit. Manages the interactions between a FilterView and the audio unit's parameters.
*/

import UIKit
import CoreAudioKit

public class FilterDemoViewController: AUViewController, FilterViewDelegate {
    // MARK: Properties

    @IBOutlet weak var filterView: FilterView!
	@IBOutlet weak var frequencyLabel: UILabel!
	@IBOutlet weak var resonanceLabel: UILabel!
	
    /*
		When this view controller is instantiated within the FilterDemoApp, its 
        audio unit is created independently, and passed to the view controller here.
	*/
    public var audioUnit: AUv3FilterDemo? {
        didSet {
			/*
				We may be on a dispatch worker queue processing an XPC request at 
                this time, and quite possibly the main queue is busy creating the 
                view. To be thread-safe, dispatch onto the main queue.
				
				It's also possible that we are already on the main queue, so to
                protect against deadlock in that case, dispatch asynchronously.
			*/
			DispatchQueue.main.async {
				if self.isViewLoaded {
					self.connectViewWithAU()
				}
			}
        }
    }
	
    var cutoffParameter: AUParameter?
	var resonanceParameter: AUParameter?
	var parameterObserverToken: AUParameterObserverToken?

	public override func viewDidLoad() {
		super.viewDidLoad()
		
		// Respond to changes in the filterView (frequency and/or response changes).
        filterView.delegate = self
		
        guard audioUnit != nil else { return }

        connectViewWithAU()
	}
    
    // MARK: FilterViewDelegate
    
    func updateFilterViewFrequencyAndMagnitudes() {
        guard let audioUnit = audioUnit else { return }
        
        // Get an array of frequencies from the view.
        let frequencies = filterView.frequencyDataForDrawing()
        
        // Get the corresponding magnitudes from the AU.
        let magnitudes = audioUnit.magnitudes(forFrequencies: frequencies as [NSNumber]!).map { $0.doubleValue }
        
        filterView.setMagnitudes(magnitudes)
    }
    
    func filterView(_ filterView: FilterView, didChangeResonance resonance: Float) {

        resonanceParameter?.value = resonance
        
        updateFilterViewFrequencyAndMagnitudes()
    }
    
    func filterView(_ filterView: FilterView, didChangeFrequency frequency: Float) {
    
        cutoffParameter?.value = frequency
        
        updateFilterViewFrequencyAndMagnitudes()
    }
    
    func filterView(_ filterView: FilterView, didChangeFrequency frequency: Float, andResonance resonance: Float) {
        
        cutoffParameter?.value = frequency
        resonanceParameter?.value = resonance
        
        updateFilterViewFrequencyAndMagnitudes()
    }
    
    func filterViewDataDidChange(_ filterView: FilterView) {
        updateFilterViewFrequencyAndMagnitudes()
    }
	
	/*
		We can't assume anything about whether the view or the AU is created first.
		This gets called when either is being created and the other has already 
        been created.
	*/
	func connectViewWithAU() {
		guard let paramTree = audioUnit?.parameterTree else { return }

		cutoffParameter = paramTree.value(forKey: "cutoff") as? AUParameter
		resonanceParameter = paramTree.value(forKey: "resonance") as? AUParameter
		
        parameterObserverToken = paramTree.token(byAddingParameterObserver: { [weak self] address, value in
            guard let strongSelf = self else { return }

			DispatchQueue.main.async {
				if address == strongSelf.cutoffParameter!.address {
					strongSelf.filterView.frequency = value
					strongSelf.frequencyLabel.text = strongSelf.cutoffParameter!.string(fromValue: nil)
				}
				else if address == strongSelf.resonanceParameter!.address {
					strongSelf.filterView.resonance = value
					strongSelf.resonanceLabel.text = strongSelf.resonanceParameter!.string(fromValue: nil)
				}
				
				strongSelf.updateFilterViewFrequencyAndMagnitudes()
			}
		})
        
        filterView.frequency = cutoffParameter!.value;
        filterView.resonance = resonanceParameter!.value;
		
        updateFilterViewFrequencyAndMagnitudes()
        
        self.resonanceLabel.text = resonanceParameter!.string(fromValue: nil)
        self.frequencyLabel.text = cutoffParameter!.string(fromValue: nil)
	}
}
