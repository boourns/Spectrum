/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 View controller for the InstrumentDemo audio unit. This is the app extension's principal class, responsible for creating both the audio unit and its view. Manages the interactions between a InstrumentView and the audio unit's parameters.
 */

import UIKit
import AVFoundation
import CoreAudioKit
import SpectrumFramework

// TODO:  HACK :( having to copy params enum into swift land
enum PlaitsParam: AUParameterAddress {
    case PadX = 0
    case PadY = 1
    case PadGate = 2
    case Algorithm = 4
    case Pitch = 5
    case Detune = 6
    case LPGColour = 7
    case Timbre = 8
    case Harmonics = 9
    case Morph = 10
    case Volume = 11
    case Source = 12
    case SourceSpread = 13
    case Pan = 14
    case PanSpread = 15
    case LfoRate = 16
    case LfoShape = 17
    case LfoShapeMod = 18
    case EnvAttack = 20
    case EnvDecay = 21
    case EnvSustain = 22
    case EnvRelease = 23
    case PitchBendRange = 24
    case AmpEnvAttack = 28
    case AmpEnvDecay = 29
    case AmpEnvSustain = 30
    case AmpEnvRelease = 31
    case Portamento = 32
    case Unison = 33
    case Polyphony = 34
    case Slop = 35
    case LfoTempoSync = 36
    case LfoResetPhase = 37
    case LfoKeyReset = 38
    case ModMatrixStart = 400
    case ModMatrixEnd = 448
};

extension UILabel {
    convenience init(text: String) {
        self.init()
        self.text = text
        translatesAutoresizingMaskIntoConstraints = false
    }
}

class SpectrumViewController: BaseAudioUnitViewController {
    let big = CGFloat(70.0)
    let small = CGFloat(50.0)
    var lfoImage: LFOImage!
    
    @objc func step(displaylink: CADisplayLink) {
        guard let audioUnit = audioUnit as? SpectrumAudioUnit else { return }
        if audioUnit.lfoDrawingDirty() {
            lfoImage.setNeedsDisplay()
        }
    }
    
    override func buildUI() -> UI {
        state.colours = SpectrumUI.purple
        
        lfoImage = LFOImage(
            renderLfo: { [weak self] in
            guard let this = self else { return nil }
            return (this.audioUnit as? SpectrumAudioUnit)?.drawLFO()
        })
        
        let displaylink = CADisplayLink(target: self,
                                        selector: #selector(step))
            
        displaylink.add(to: .current,
                        forMode: RunLoop.Mode.default)

        return UI(state: state, [
            Page("Spectrum",
                 cStack([
                   Stack([
                     panel(HStack([
                        picker(PlaitsParam.Algorithm.rawValue),
                        intKnob(PlaitsParam.Pitch.rawValue),
                        knob(PlaitsParam.Detune.rawValue),
                     ])),
                        Stack([panel2(HStack([
                            knob(PlaitsParam.Harmonics.rawValue, size: big),
                            knob(PlaitsParam.Timbre.rawValue, size: big),
                            knob(PlaitsParam.Morph.rawValue, size: big),
                         ])),
                         panel2(HStack([
                            knob(PlaitsParam.Slop.rawValue, size: small),
                            knob(PlaitsParam.Portamento.rawValue, size: small),
                            intKnob(PlaitsParam.PitchBendRange.rawValue, size: small),
                         ])),
                         ]),
                   ]),
                   Stack([
                     touchPad(PlaitsParam.PadX.rawValue, PlaitsParam.PadY.rawValue, PlaitsParam.PadGate.rawValue)
                   ]),
                ]) //stack
            ), // page
            Page("Amp",
                        cStack([
                            Stack([
                                panel2(Stack([
                                    HStack([
                                        knob(PlaitsParam.Volume.rawValue),
                                        knob(PlaitsParam.LPGColour.rawValue),
                                        ]),
                                    ])),
                                panel2(Stack([
                                    slider(PlaitsParam.AmpEnvAttack.rawValue),
                                    slider(PlaitsParam.AmpEnvDecay.rawValue),
                                    slider(PlaitsParam.AmpEnvSustain.rawValue),
                                    slider(PlaitsParam.AmpEnvRelease.rawValue),
                                    ]))
                                ]),
                            panel(Stack([
                                HStack([
                                    knob(PlaitsParam.Pan.rawValue),
                                    knob(PlaitsParam.PanSpread.rawValue),
                                    ]),
                                Stack([
                                    HStack([
                                        knob(PlaitsParam.Source.rawValue),
                                        knob(PlaitsParam.SourceSpread.rawValue),
                                        ]),
                                    ]),
                                Stack([
                                    HStack([
                                        picker(PlaitsParam.Unison.rawValue),
                                        intKnob(PlaitsParam.Polyphony.rawValue),
                                        ]),
                                    ]),
                                ])
                            )])),
            
            lfoPage(rate: PlaitsParam.LfoRate.rawValue, shape: PlaitsParam.LfoShape.rawValue, shapeMod: PlaitsParam.LfoShapeMod.rawValue, tempoSync: PlaitsParam.LfoTempoSync.rawValue, resetPhase: PlaitsParam.LfoResetPhase.rawValue, keyReset: PlaitsParam.LfoKeyReset.rawValue, modStart: PlaitsParam.ModMatrixStart.rawValue,
                    injectedView: lfoImage),
            
            envPage(envStart: PlaitsParam.EnvAttack.rawValue, modStart: PlaitsParam.ModMatrixStart.rawValue),
            
            modMatrixPage(modStart: PlaitsParam.ModMatrixStart.rawValue + 24, numberOfRules: 6),
            
            settingsPage()

            ]) // ui page list
        
    }
    
    func settingsPage() -> Page {
        guard let audioUnit = audioUnit as? SpectrumAudioUnit else { fatalError("Wrong audiounit class") }
        let processor = audioUnit.midiProcessor()!
        
        let midiChannel = Picker(name: "MIDI Channel", value: Float(processor.channel() + 1), valueStrings: ["Omni"] + (1...16).map { "Ch \($0)" }, horizontal: true)
        
        midiChannel.addControlEvent(.valueChanged) {
            processor.setChannel(Int32(midiChannel.value - 1))
        }
        
        let midiCC = Picker(name: "MIDI CC Control", value: processor.automation() ? 1.0 : 0.0, valueStrings: ["Disabled", "Enabled"], horizontal: true)
        midiCC.addControlEvent(.valueChanged) {
            processor.setAutomation(midiCC.value > 0.9)
        }
        
        processor.onSettingsUpdate() {
            midiChannel.value = Float(processor.channel() + 1)
            midiCC.value = processor.automation() ? 1.0 : 0.0
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
        
        let exportPreset = SettingsButton()
        exportPreset.button.setTitle("Export", for: .normal)
        exportPreset.button.addControlEvent(.touchUpInside) {[weak self] in
            guard let this = self else { return }
            let result = PresetExporter.init(audioUnit: audioUnit, name: "Spectrum").saveAndPresent(filename: "preset.specs")
            switch(result) {
            case .error(let message):
                this.showToast(message: message, font: UIFont.preferredFont(forTextStyle: .subheadline))
            case .success(let activity):
                activity.popoverPresentationController?.sourceView = exportPreset
                this.present(activity, animated: true, completion: nil)
                print("Success exporting preset")
            }
        }
        
        return Page("⚙︎", Stack([
//            Header("Presets"),
//            HStack([exportPreset]),
            Header("MIDI"),
            midiChannel,
            midiCC,
            HStack([loadDefault, saveDefault]),
            ]), requiresScroll: true)
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
