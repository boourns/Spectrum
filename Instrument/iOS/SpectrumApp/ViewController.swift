/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	View controller which registers an AUAudioUnit subclass in-process for easy development, connects sliders and text fields to its parameters, and embeds the audio unit's view into a subview. Uses SimplePlayEngine to audition the effect.
*/

import UIKit
import AudioToolbox
import SpectrumFramework

class ViewController: UIViewController {
    // MARK: Properties
  
  var audioUnit: AUAudioUnit? = nil
  var state: [String: Any?]? = [:]

	@IBOutlet weak var playButton: UIButton!
  @IBOutlet weak var loadButton: UIButton!
  @IBOutlet weak var saveButton: UIButton!
  
  /// Container for our custom view.
  @IBOutlet var auContainerView: UIView!

	/// The audio playback engine.
	var playEngine: SimplePlayEngine!

	/// Our plug-in's custom view controller. We embed its view into `viewContainer`.
	var filterDemoViewController: InstrumentDemoViewController!

    // MARK: View Life Cycle
    
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// Set up the plug-in's custom view.
		embedPlugInView()
		
		// Create an audio file playback engine.
		playEngine = SimplePlayEngine(componentType: kAudioUnitType_MusicDevice)
		
		/*
			Register the AU in-process for development/debugging.
			First, build an AudioComponentDescription matching the one in our 
            .appex's Info.plist.
		*/
        // MARK: AudioComponentDescription Important!
        // Ensure that you update the AudioComponentDescription for your AudioUnit type, manufacturer and creator type.
        var componentDescription = AudioComponentDescription()
        componentDescription.componentType = kAudioUnitType_MusicDevice
        componentDescription.componentSubType = fourCC("spec") /*'sin3'*/
        componentDescription.componentManufacturer = fourCC("Brns") /*'Demo'*/
        componentDescription.componentFlags = 0
        componentDescription.componentFlagsMask = 0
		
		/*
			Register our `AUAudioUnit` subclass, `AUv3InstrumentDemo`, to make it able 
            to be instantiated via its component description.
			
			Note that this registration is local to this process.
		*/
        AUAudioUnit.registerSubclass(SpectrumAudioUnit.self, as: componentDescription, name: "Demo: Local InstrumentDemo", version: UInt32.max)

		// Instantiate and insert our audio unit effect into the chain.
		playEngine.selectAudioUnitWithComponentDescription(componentDescription) { [weak self] in
      guard let this = self else { return }
			// This is an asynchronous callback when complete. Finish audio unit setup.
      let audioUnit = this.playEngine.testAudioUnit as! SpectrumAudioUnit
      this.filterDemoViewController.audioUnit = audioUnit
		}
	}
	
	/// Called from `viewDidLoad(_:)` to embed the plug-in's view into the app's view.
	func embedPlugInView() {
        /*
			Locate the app extension's bundle, in the app bundle's PlugIns
			subdirectory. Load its MainInterface storyboard, and obtain the
            `InstrumentDemoViewController` from that.
        */
        let builtInPlugInsURL = Bundle.main.builtInPlugInsURL!
        let pluginURL = builtInPlugInsURL.appendingPathComponent("SpectrumAudioUnit.appex")
        let appExtensionBundle = Bundle(url: pluginURL)
        let storyboard = UIStoryboard(name: "MainInterface", bundle: appExtensionBundle)
        filterDemoViewController = storyboard.instantiateInitialViewController() as? InstrumentDemoViewController
    
        // Present the view controller's view.
        if let view = filterDemoViewController.view {
          addChild(filterDemoViewController)
          view.frame = auContainerView.bounds
          auContainerView.addSubview(view)
          filterDemoViewController.didMove(toParent: self)
        }
	}

    // MARK: IBActions

	/// Handles Play/Stop button touches.
    @IBAction func togglePlay(_ sender: AnyObject?) {
		let isPlaying = playEngine.togglePlay()

        let titleText = isPlaying ? "Stop" : "Play"

		playButton.setTitle(titleText, for: .normal)
	}
  
  @IBAction func savePressed(_ sender: Any) {
    print("save")
    guard let unit = playEngine.testAudioUnit else { return }
    state = unit.fullState
  }
  
  @IBAction func loadPressed(_ sender: Any) {
    print("load")
    guard let state = state, let unit = playEngine.testAudioUnit else { return }
    unit.fullState = state
  }
    
    public func fourCC(_ string: String) -> UInt32 {
        let utf8 = string.utf8
        precondition(utf8.count == 4, "Must be a 4 char string")
        var out: UInt32 = 0
        for char in utf8 {
            out <<= 8
            out |= UInt32(char)
        }
        return out
    }
}
