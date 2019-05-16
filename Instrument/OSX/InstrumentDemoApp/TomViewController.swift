//
//  ViewController.swift
//  iOSInstrumentDemoApp
//
//  Created by tom on 2019-05-15.
//

import Foundation
import Cocoa
import AudioUnit
import AudioToolbox
import InstrumentDemoFramework

class TomViewController : NSViewController {
    @IBOutlet var playButton: NSButton?
    @IBOutlet var containerView: NSView?
    
    var auV3ViewController: InstrumentDemoViewController?
    var playEngine: SimplePlayEngine?

//    override func loadView() {
//        super.loadView()
//        let view = NSView(frame: NSMakeRect(0,0,100,100))
//        view.wantsLayer = true
//        view.layer?.borderWidth = 2
//        view.layer?.borderColor = NSColor.red.cgColor
//        self.view = view
//    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        embedPluginView()
        
        let desc = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice,
            componentSubType: fourCC("sin3"),
            componentManufacturer: fourCC("Demo"),
            componentFlags: 0, componentFlagsMask: 0)
        
        AUAudioUnit.registerSubclass(AUv3InstrumentDemo.self, as: desc, name: "BurnsAudio: MacroOscillator", version: 1)
        
        playEngine = SimplePlayEngine(componentType: desc.componentType)
        playEngine?.selectAudioUnitWithComponentDescription2(desc) {
            self.connectParametersToControls()
        }
    }
    
    func connectParametersToControls() {
        guard let playEngine = playEngine else { return }
        auV3ViewController?.audioUnit = (playEngine.testAudioUnit as! AUv3InstrumentDemo)
    }
    
    @IBAction func togglePlay(sender: AnyObject) {
        let isPlaying = playEngine?.togglePlay() ?? false
        
        playButton?.title = isPlaying ? "Stop" : "Play"
    }
    
    func embedPluginView() {
        /*
         NSURL *builtInPlugInURL = [[NSBundle mainBundle] builtInPlugInsURL];
         NSURL *pluginURL = [builtInPlugInURL URLByAppendingPathComponent: @"InstrumentDemoAppExtension.appex"];
         NSBundle *appExtensionBundle = [NSBundle bundleWithURL: pluginURL];
         
         auV3ViewController = [[InstrumentDemoViewController alloc] initWithNibName: @"InstrumentDemoViewController" bundle: appExtensionBundle];
         
         NSView *view = auV3ViewController.view;
         view.frame = _containerView.bounds;
         
         [_containerView addSubview: view];
         
         view.translatesAutoresizingMaskIntoConstraints = NO;
         
         NSArray *constraints = [NSLayoutConstraint constraintsWithVisualFormat: @"H:|-[view]-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(view)];
         [_containerView addConstraints: constraints];
         
         constraints = [NSLayoutConstraint constraintsWithVisualFormat: @"V:|-[view]-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(view)];
         [_containerView addConstraints: constraints];
         */
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
