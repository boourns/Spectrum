//
//  ResonatorViewController.swift
//  iOSSpectrumApp
//
//  Created by tom on 2019-06-27.
//

import UIKit
import AVFoundation
import CoreAudioKit

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
    
    case ModMatrixStart = 400
    case ModMatrixEnd = 440 // 26 + 40 = 66
}

class ResonatorViewController: BaseAudioUnitViewController {
    var loadAsEffect = false
    
    override func buildUI() -> UI {
        SpectrumUI.colours = SpectrumUI.red
        
        var main = [
            Knob(RingsParam.Structure.rawValue, size: 70),
            Knob(RingsParam.Brightness.rawValue, size: 70),
        ]
        
        if (loadAsEffect) {
            main = [
                Knob(RingsParam.InputGain.rawValue, size: 70),
            ] + main
        }
        
        return UI([
            Page("Main",
                 CStack([
                    Stack([
                        Panel(HStack([
                            IntKnob(RingsParam.Pitch.rawValue),
                            Knob(RingsParam.Detune.rawValue),
                            Picker(RingsParam.Mode.rawValue)
                            ])),
                        Panel(HStack(main)),
                        Panel(CStack([
                            HStack([
                                Knob(RingsParam.Damping.rawValue),
                                Knob(RingsParam.Position.rawValue),
                                ]),
                            HStack([
                                Knob(RingsParam.StereoSpread.rawValue),
                                Knob(RingsParam.Volume.rawValue),
                                
                                ])
                            ])),
                        ]), //stack
                    Stack([
                        Panel(TouchPad(RingsParam.PadX.rawValue, RingsParam.PadY.rawValue, CloudsParam.PadGate.rawValue))
                        ]),
                    ]) // cstack
            ), // page
            SpectrumUI.modulationPage(lfoStart: RingsParam.LfoRate.rawValue, envStart: RingsParam.EnvAttack.rawValue, modStart: RingsParam.ModMatrixStart.rawValue),
            
            SpectrumUI.modMatrixPage(modStart: RingsParam.ModMatrixStart.rawValue + 16, numberOfRules: 6)

            ]) // ui page list
        
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
