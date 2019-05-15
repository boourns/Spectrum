/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	View controller which registers an AUAudioUnit subclass in-process for easy development, connects sliders and text fields to its parameters, and embeds the audio unit's view into a subview. Uses SimplePlayEngine to audition the effect.
*/

import UIKit
import AudioToolbox
import FilterDemoFramework

class ViewController: UIViewController {
    // MARK: Properties

	@IBOutlet var playButton: UIButton!

	@IBOutlet var cutoffSlider: UISlider!
	@IBOutlet var resonanceSlider: UISlider!
	
	@IBOutlet var cutoffTextField: UITextField!
	@IBOutlet var resonanceTextField: UITextField!

    /// Container for our custom view.
    @IBOutlet var auContainerView: UIView!
    
    static let defaultMinHertz: Double = 12.0
    static let defaultMaxHertz: Double = 20000.0
    
    let logBase = 2

	/// The audio playback engine.
	var playEngine: SimplePlayEngine!

	/// The audio unit's filter cutoff frequency parameter object.
	var cutoffParameter: AUParameter!

	/// The audio unit's filter resonance parameter object.
	var resonanceParameter: AUParameter!

	/// A token for our registration to observe parameter value changes.
	var parameterObserverToken: AUParameterObserverToken!

	/// Our plug-in's custom view controller. We embed its view into `viewContainer`.
	var filterDemoViewController: FilterDemoViewController!

    // MARK: View Life Cycle
    
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// Set up the plug-in's custom view.
		embedPlugInView()
		
		// Create an audio file playback engine.
		playEngine = SimplePlayEngine(componentType: kAudioUnitType_Effect)
		
		/*
			Register the AU in-process for development/debugging.
			First, build an AudioComponentDescription matching the one in our 
            .appex's Info.plist.
		*/
        // MARK: AudioComponentDescription Important!
        // Ensure that you update the AudioComponentDescription for your AudioUnit type, manufacturer and creator type.
        var componentDescription = AudioComponentDescription()
        componentDescription.componentType = kAudioUnitType_Effect
        componentDescription.componentSubType = 0x666c7472 /*'fltr'*/
        componentDescription.componentManufacturer = 0x44656d6f /*'Demo'*/
        componentDescription.componentFlags = 0
        componentDescription.componentFlagsMask = 0
		
		/*
			Register our `AUAudioUnit` subclass, `AUv3FilterDemo`, to make it able 
            to be instantiated via its component description.
			
			Note that this registration is local to this process.
		*/
        AUAudioUnit.registerSubclass(AUv3FilterDemo.self, as: componentDescription, name:"Demo: Local FilterDemo", version: UInt32.max)

		// Instantiate and insert our audio unit effect into the chain.
		playEngine.selectAudioUnitWithComponentDescription(componentDescription) {
			// This is an asynchronous callback when complete. Finish audio unit setup.
			self.connectParametersToControls()
		}
	}
	
	/// Called from `viewDidLoad(_:)` to embed the plug-in's view into the app's view.
	func embedPlugInView() {
        /*
			Locate the app extension's bundle, in the app bundle's PlugIns
			subdirectory. Load its MainInterface storyboard, and obtain the
            `FilterDemoViewController` from that.
        */
        let builtInPlugInsURL = Bundle.main.builtInPlugInsURL!
        let pluginURL = builtInPlugInsURL.appendingPathComponent("FilterDemoAppExtension.appex")
		let appExtensionBundle = Bundle(url: pluginURL)

        let storyboard = UIStoryboard(name: "MainInterface", bundle: appExtensionBundle)
		filterDemoViewController = storyboard.instantiateInitialViewController() as! FilterDemoViewController
        
        // Present the view controller's view.
        if let view = filterDemoViewController.view {
            addChildViewController(filterDemoViewController)
            view.frame = auContainerView.bounds
            
            auContainerView.addSubview(view)
            filterDemoViewController.didMove(toParentViewController: self)
        }
	}
	
	/**
        Called after instantiating our audio unit, to find the AU's parameters and
        connect them to our controls.
    */
	func connectParametersToControls() {
		// Find our parameters by their identifiers.
        guard let parameterTree = playEngine.testAudioUnit?.parameterTree else { return }

        let audioUnit = playEngine.testAudioUnit as! AUv3FilterDemo
        filterDemoViewController.audioUnit = audioUnit
        
        cutoffParameter = parameterTree.value(forKey: "cutoff") as? AUParameter
        resonanceParameter = parameterTree.value(forKey: "resonance") as? AUParameter
        
        parameterObserverToken = parameterTree.token(byAddingParameterObserver: { [unowned self] address, value in
            /*
                This is called when one of the parameter values changes.
                
                We can only update UI from the main queue.
            */
            DispatchQueue.main.async {
                if address == self.cutoffParameter.address {
                    self.updateCutoff()
                }
                else if address == self.resonanceParameter.address {
                    self.updateResonance()
                }
            }
        })
        
        updateCutoff()
        updateResonance()
	}
    
    func logValueForNumber(_ number: Double)->Double {
        let value = log(number)/log(2);
        return value;
    }
    
    func frequencyValueForSliderLocation(_ location: Float)->Float {
        var value = pow(2, location)
        value = (value - 1)/511
        
        value *= Float(ViewController.defaultMaxHertz - ViewController.defaultMinHertz)
        
        return value + Float(ViewController.defaultMinHertz)
    }
    
	// Callbacks to update controls from parameters.
	func updateCutoff() {
		cutoffTextField.text = cutoffParameter.string(fromValue: nil)
        
        // normalize the vaue from 0-1
        let value = Double(cutoffParameter.value)
        var normalizedValue = (value - ViewController.defaultMinHertz)/(ViewController.defaultMaxHertz - ViewController.defaultMinHertz)
        
        // map to 2^0 - 2^9 (slider range)
        normalizedValue = (normalizedValue * 511.0) + 1
        
		cutoffSlider.value = Float(logValueForNumber(normalizedValue))
	}

	func updateResonance() {
		resonanceTextField.text = resonanceParameter.string(fromValue: nil)
		resonanceSlider.value = resonanceParameter.value
	}

    // MARK: IBActions

	/// Handles Play/Stop button touches.
    @IBAction func togglePlay(_ sender: AnyObject?) {
		let isPlaying = playEngine.togglePlay()

        let titleText = isPlaying ? "Stop" : "Play"

		playButton.setTitle(titleText, for: UIControlState())
	}
	
	@IBAction func changedCutoff(_ sender: AnyObject?) {
        guard sender === cutoffSlider else { return }
        
        let value = frequencyValueForSliderLocation(cutoffSlider.value)
        // Set the parameter's value from the slider's value.
        cutoffParameter.value = value
	}

	@IBAction func changedResonance(_ sender: AnyObject?) {
        guard sender === resonanceSlider else { return }

        // Set the parameter's value from the slider's value.
        resonanceParameter.value = resonanceSlider.value
	}
}
