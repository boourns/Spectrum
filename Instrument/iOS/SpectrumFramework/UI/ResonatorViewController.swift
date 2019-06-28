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
    case Structure = 1
    case Brightness = 2
    case Damping = 3
    case Position = 4
    case Volume = 5
    case Mode = 6
    case Polyphony = 7
    case Pitch = 8
    case Detune = 9
    case LfoRate = 10
    case LfoShape = 11
    case LfoShapeMod = 12
    case EnvAttack = 13
    case EnvDecay = 14
    case EnvSustain = 15
    case EnvRelease = 16
    case InputGain = 17
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
                    Panel2(Stack([
                        HStack([
                            IntKnob(RingsParam.Pitch.rawValue),
                            Knob(RingsParam.Detune.rawValue),
                            Picker(RingsParam.Mode.rawValue)
                            ]),
                        HStack(main),
                        CStack([
                            HStack([
                                Knob(RingsParam.Damping.rawValue),
                                Knob(RingsParam.Position.rawValue),
                                ]),
                            HStack([
                                Knob(RingsParam.Volume.rawValue),
                                ])
                            ]),
                        ])) //stack
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
