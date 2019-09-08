//
//  ResonatorViewController.swift
//  iOSSpectrumApp
//
//  Created by tom on 2019-06-27.
//

import UIKit
import AVFoundation
import CoreAudioKit
import BurnsAudioFramework

enum RingsParam: AUParameterAddress {
    case PadX = 0
    case PadY = 1
    case PadGate = 2
    case Structure = 4
    case Brightness = 5
    case Damping = 6
    case Position = 7
    case Volume = 8
    case Mode = 9
    case Polyphony = 10
    case Pitch = 11
    case Detune = 12
    case LfoRate = 13
    case LfoShape = 14
    case LfoShapeMod = 15
    case EnvAttack = 16
    case EnvDecay = 17
    case EnvSustain = 18
    case EnvRelease = 19
    case InputGain = 20
    case StereoSpread = 21
    case LfoTempoSync = 22
    case LfoResetPhase = 23
    case LfoKeyReset = 24
    
    case ModMatrixStart = 400
    case ModMatrixEnd = 440 // 26 + 40 = 66
}

class ResonatorViewController: BaseAudioUnitViewController {
    var loadAsEffect = false
    var lfoImage: LFOImage!
    
    @objc func step(displaylink: CADisplayLink) {
        guard let audioUnit = audioUnit as? ResonatorAudioUnit else { return }
        if audioUnit.lfoDrawingDirty() {
            lfoImage.setNeedsDisplay()
        }
    }
    
    override func buildUI() -> UI {
        state.colours = SpectrumUI.red
        
        lfoImage = LFOImage(
            renderLfo: { [weak self] in
                guard let this = self else { return nil }
                return (this.audioUnit as? ResonatorAudioUnit)?.drawLFO()
        })
        
        let displaylink = CADisplayLink(target: self,
                                        selector: #selector(step))
        
        displaylink.add(to: .current,
                        forMode: RunLoop.Mode.default)
        
        var main = [
            knob(RingsParam.Structure.rawValue, size: 70),
            knob(RingsParam.Brightness.rawValue, size: 70),
        ]
        
        if (loadAsEffect) {
            main = [
                knob(RingsParam.InputGain.rawValue, size: 70),
            ] + main
        }
        
        return UI(state: state, [
            Page("Main",
                 cStack([
                    Stack([
                        panel(HStack([
                            intKnob(RingsParam.Pitch.rawValue),
                            knob(RingsParam.Detune.rawValue),
                            picker(RingsParam.Mode.rawValue)
                            ])),
                        panel(HStack(main)),
                        panel(cStack([
                            HStack([
                                knob(RingsParam.Damping.rawValue),
                                knob(RingsParam.Position.rawValue),
                                ]),
                            HStack([
                                knob(RingsParam.StereoSpread.rawValue),
                                knob(RingsParam.Volume.rawValue),
                                
                                ])
                            ])),
                        ]), //stack
                    Stack([
                        panel(touchPad(RingsParam.PadX.rawValue, RingsParam.PadY.rawValue, RingsParam.PadGate.rawValue))
                        ]),
                    ]) // cstack
            ), // page
            
            lfoPage(rate: RingsParam.LfoRate.rawValue, shape: RingsParam.LfoShape.rawValue, shapeMod: RingsParam.LfoShapeMod.rawValue, tempoSync: RingsParam.LfoTempoSync.rawValue, resetPhase: RingsParam.LfoResetPhase.rawValue, keyReset: RingsParam.LfoKeyReset.rawValue, modStart: RingsParam.ModMatrixStart.rawValue, injectedView: lfoImage),
                
            envPage(envStart: RingsParam.EnvAttack.rawValue, modStart: RingsParam.ModMatrixStart.rawValue),
            
            modMatrixPage(modStart: RingsParam.ModMatrixStart.rawValue + 16, numberOfRules: 6),
            
            settingsPage()

            ]) // ui page list
    }
    
    func settingsPage() -> Page {
        guard let audioUnit = audioUnit as? ResonatorAudioUnit else { fatalError("Wrong audiounit class") }
        let processor = audioUnit.midiProcessor()!
        
        let midiChannel = Picker(name: "MIDI Channel", value: Float(processor.channel() + 1), valueStrings: ["Omni"] + (1...16).map { "Ch \($0)" }, horizontal: true)
        
        midiChannel.addControlEvent(.valueChanged) {
            processor.setChannel(Int32(midiChannel.value - 1))
        }
        
        let midiCC = Picker(name: "MIDI CC Control", value: processor.automation() ? 1.0 : 0.0, valueStrings: ["Disabled", "Enabled"], horizontal: true)
        midiCC.addControlEvent(.valueChanged) {
            processor.setAutomation(midiCC.value > 0.9)
        }
        
        let loadDefault = SettingsButton()
        loadDefault.button.setTitle("Load Defaults", for: .normal)
        loadDefault.button.addControlEvent(.touchUpInside) { [weak self] in
            guard let this = self else { return }
            audioUnit.loadFromDefaults()
            this.showToast(message: "Settings loaded", font: UIFont.preferredFont(forTextStyle: .subheadline))
        }
        
        let saveDefault = SettingsButton()
        saveDefault.button.setTitle("Save as Default", for: .normal)
        saveDefault.button.addControlEvent(.touchUpInside) {[weak self] in
            guard let this = self else { return }
            audioUnit.saveDefaults()
            this.showToast(message: "Settings saved", font: UIFont.preferredFont(forTextStyle: .subheadline))
        }
        
        processor.onSettingsUpdate() {
            midiChannel.value = Float(processor.channel() + 1)
            midiCC.value = processor.automation() ? 1.0 : 0.0
        }
        
        return Page("⚙︎", Stack([
            Header("MIDI"),
            midiChannel,
            midiCC,
            HStack([loadDefault, saveDefault]),
            ]), requiresScroll: true)
    }
}

extension ResonatorViewController: AUAudioUnitFactory {
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
        if componentDescription.componentType == 1635085670 {
            loadAsEffect = true
        }
        
        audioUnit = try ResonatorAudioUnit(componentDescription: componentDescription, options: [])
        
        return audioUnit!
    }
}
