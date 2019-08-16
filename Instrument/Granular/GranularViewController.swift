//
//  GranularViewController.swift
//  Granular
//
//  Created by tom on 2019-06-12.
//

import UIKit
import AVFoundation
import CoreAudioKit
import SpectrumFramework

enum CloudsParam: AUParameterAddress {
    case PadX = 0
    case PadY = 1
    case PadGate = 2
    case Texture = 3
    case Feedback = 4
    case Wet = 5
    case Reverb = 6
    case Stereo = 7
    case InputGain = 8
    case Trigger = 9
    case Freeze = 10
    case Mode = 11
    case Position = 12
    case Size = 13
    case Density = 14
    case Pitch = 16
    case Detune = 17
    case LfoRate = 18
    case LfoShape = 19
    case LfoShapeMod = 20
    case EnvAttack = 22
    case EnvDecay = 23
    case EnvSustain = 24
    case EnvRelease = 25
    case Volume = 26
    case LfoTempoSync = 27
    case LfoResetPhase = 28
    case LfoKeyReset = 29
    
    case ModMatrixStart = 400
    case ModMatrixEnd = 440
};

let big = CGFloat(80)

class GranularViewController: BaseAudioUnitViewController {
    var lfoImage: LFOImage!
    
    @objc func step(displaylink: CADisplayLink) {
        guard let audioUnit = audioUnit as? GranularAudioUnit else { return }
        if audioUnit.lfoDrawingDirty() {
            lfoImage.setNeedsDisplay()
        }
    }
    
    override func buildUI() -> UI {
        state.colours = SpectrumUI.green
        
        lfoImage = LFOImage(
            renderLfo: { [weak self] in
                guard let this = self else { return nil }
                return (this.audioUnit as? GranularAudioUnit)?.drawLFO()
        })
        
        let displaylink = CADisplayLink(target: self,
                                        selector: #selector(step))
        
        displaylink.add(to: .current,
                        forMode: RunLoop.Mode.default)
        
        return UI(state: state, [
            Page("Granular",
                 cStack([
                    Stack([
                        Stack([panel2(HStack([
                            knob(CloudsParam.Position.rawValue, size: big),
                            knob(CloudsParam.Size.rawValue, size: big),
                            knob(CloudsParam.Pitch.rawValue, size: big),
                            ])),
                               panel2(HStack([
                                knob(CloudsParam.InputGain.rawValue),
                                knob(CloudsParam.Density.rawValue),
                                knob(CloudsParam.Texture.rawValue),
                                ])),
                               panel2(HStack([
                                button(CloudsParam.Freeze.rawValue),
                                button(CloudsParam.Trigger.rawValue, momentary: true)
                                ])),
                            ]),
                        ]),
                    Stack([
                        panel(touchPad(CloudsParam.PadX.rawValue, CloudsParam.PadY.rawValue, CloudsParam.PadGate.rawValue))
                    ]),
                ])),
            Page("Blend",
                 cStack([
                    Stack([
                        panel(HStack([
                            picker(CloudsParam.Mode.rawValue)
                            ])),
                        panel2(HStack([
                            knob(CloudsParam.Wet.rawValue),
                            knob(CloudsParam.Stereo.rawValue),
                            ])),
                        panel2(HStack([
                            knob(CloudsParam.Feedback.rawValue),
                            knob(CloudsParam.Reverb.rawValue),
                            knob(CloudsParam.Volume.rawValue),
                            ]))
                    ]),
                    Stack([
                        
                    ])
                 ])
            ),
            
            lfoPage(rate: CloudsParam.LfoRate.rawValue, shape: CloudsParam.LfoShape.rawValue, shapeMod: CloudsParam.LfoShapeMod.rawValue, tempoSync: CloudsParam.LfoTempoSync.rawValue, resetPhase: CloudsParam.LfoResetPhase.rawValue, keyReset: CloudsParam.LfoKeyReset.rawValue, modStart: CloudsParam.ModMatrixStart.rawValue, injectedView: lfoImage),
            
            envPage(envStart: CloudsParam.EnvAttack.rawValue, modStart: CloudsParam.ModMatrixStart.rawValue),
            
            modMatrixPage(modStart: CloudsParam.ModMatrixStart.rawValue + 16, numberOfRules: 6),
            
            settingsPage()
            
            ]) // ui page list
        
    }
    
    func settingsPage() -> Page {
        guard let audioUnit = audioUnit as? GranularAudioUnit else { fatalError("Wrong audiounit class") }
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
        
        return Page("⚙︎", Stack([
            Header("MIDI"),
            midiChannel,
            midiCC
            ]), requiresScroll: true)
    }
}

extension GranularViewController: AUAudioUnitFactory {
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
        audioUnit = try GranularAudioUnit(componentDescription: componentDescription, options: [])
        
        return audioUnit!
    }
}
