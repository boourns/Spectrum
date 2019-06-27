//
//  ModalViewController.swift
//  iOSSpectrumFramework
//
//  Created by tom on 2019-05-28.
//

import UIKit
import AVFoundation
import CoreAudioKit

enum ElementsParam: AUParameterAddress {
    case ExciterEnvShape = 0
    case BowLevel = 1
    case BowTimbre = 2
    case BlowLevel = 3
    case BlowMeta = 4
    case BlowTimbre = 5
    case StrikeLevel = 6
    case StrikeMeta = 7
    case StrikeTimbre = 8
    case ResonatorGeometry = 9
    case ResonatorBrightness = 10
    case ResonatorDamping = 11
    case ResonatorPosition = 12
    case Space = 13
    case Volume = 14
    case Mode = 15
    case Pitch = 16
    case Detune = 17
    case LfoRate = 18
    case LfoShape = 19
    case LfoShapeMod = 20
    case EnvAttack = 22
    case EnvDecay = 23
    case EnvSustain = 24
    case EnvRelease = 25
    case InputGain = 26
    case InputResonator = 27
    case ModMatrixStart = 400
    case ModMatrixEnd = 440
};


class ModalViewController: BaseAudioUnitViewController {
    var loadAsEffect = false
    
    override func buildUI() -> UI {
        SpectrumUI.colours = SpectrumUI.blue
        
        var main = [
            Knob(ElementsParam.BlowMeta.rawValue, size: 70),
            Knob(ElementsParam.StrikeMeta.rawValue, size: 70),
            ]
        
        var timbre: UIView = HStack([
            Knob(ElementsParam.BowTimbre.rawValue),
            Knob(ElementsParam.BlowTimbre.rawValue),
            Knob(ElementsParam.StrikeTimbre.rawValue),
        ])
        
        if loadAsEffect {
            main = [
                Knob(ElementsParam.InputGain.rawValue, size: 70),
            ] + main
            
            timbre = CStack([
                HStack([
                    Picker(ElementsParam.InputResonator.rawValue),
                    Knob(ElementsParam.BowTimbre.rawValue),
                    ]),
                HStack([
                    Knob(ElementsParam.BlowTimbre.rawValue),
                    Knob(ElementsParam.StrikeTimbre.rawValue),
                    ]),
                ])
            
        }
        
        
        return UI([
            Page("Main",
                 CStack([
                    Stack([
                        Panel(CStack([
                            HStack([
                                Knob(ElementsParam.ExciterEnvShape.rawValue),
                                Knob(ElementsParam.BowLevel.rawValue),
                                ]),
                            HStack([
                                Knob(ElementsParam.BlowLevel.rawValue),
                                Knob(ElementsParam.StrikeLevel.rawValue),
                                ]),
                            ])),
                        Panel(HStack(main)),
                        Panel(timbre),
                        ]),
                    Panel2(Stack([
                        HStack([
                            IntKnob(ElementsParam.Pitch.rawValue),
                            Knob(ElementsParam.Detune.rawValue),
                            Picker(ElementsParam.Mode.rawValue)
                            ]),
                        HStack([
                            Knob(ElementsParam.ResonatorGeometry.rawValue, size: 70),
                            Knob(ElementsParam.ResonatorBrightness.rawValue, size: 70),
                            ]),
                        CStack([
                            HStack([
                                Knob(ElementsParam.ResonatorDamping.rawValue),
                                Knob(ElementsParam.ResonatorPosition.rawValue),
                                ]),
                            HStack([
                                Knob(ElementsParam.Space.rawValue),
                                Knob(ElementsParam.Volume.rawValue),
                                ])
                            ]),
                        ])) //stack
                    ]) // cstack
            ), // page
            SpectrumUI.modulationPage(lfoStart: ElementsParam.LfoRate.rawValue, envStart: ElementsParam.EnvAttack.rawValue, modStart: ElementsParam.ModMatrixStart.rawValue),
            
            SpectrumUI.modMatrixPage(modStart: ElementsParam.ModMatrixStart.rawValue + 16, numberOfRules: 6)
            //LFOPage(),
            //EnvPage(),
            //Page("Amp", UIView()),
            //ModMatrixPage(),
            ]) // ui page list
        
    }
}

extension ModalViewController: AUAudioUnitFactory {
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
            
        audioUnit = try ModalAudioUnit(componentDescription: componentDescription, options: [])
        
        return audioUnit!
    }
}
