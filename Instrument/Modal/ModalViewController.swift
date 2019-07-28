//
//  ModalViewController.swift
//  iOSSpectrumFramework
//
//  Created by tom on 2019-05-28.
//

import UIKit
import AVFoundation
import CoreAudioKit
import SpectrumFramework

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
    case LfoTempoSync = 28
    case LfoResetPhase = 29
    case LfoKeyReset = 30
    case ModMatrixStart = 400
    case ModMatrixEnd = 440
};


class ModalViewController: BaseAudioUnitViewController {
    var loadAsEffect = false
    
    override func buildUI() -> UI {
        state.colours = SpectrumUI.blue
        
        var main = [
            knob(ElementsParam.BlowMeta.rawValue, size: 70),
            knob(ElementsParam.StrikeMeta.rawValue, size: 70),
            ]
        
        var timbre: UIView = HStack([
            knob(ElementsParam.BowTimbre.rawValue),
            knob(ElementsParam.BlowTimbre.rawValue),
            knob(ElementsParam.StrikeTimbre.rawValue),
        ])
        
        if loadAsEffect {
            main = [
                knob(ElementsParam.InputGain.rawValue, size: 70),
            ] + main
            
            timbre = cStack([
                HStack([
                    picker(ElementsParam.InputResonator.rawValue),
                    knob(ElementsParam.BowTimbre.rawValue),
                    ]),
                HStack([
                    knob(ElementsParam.BlowTimbre.rawValue),
                    knob(ElementsParam.StrikeTimbre.rawValue),
                    ]),
                ])
            
        }
        
        
        return UI(state: state, [
            Page("Main",
                 cStack([
                    Stack([
                        panel(cStack([
                            HStack([
                                knob(ElementsParam.ExciterEnvShape.rawValue),
                                knob(ElementsParam.BowLevel.rawValue),
                                ]),
                            HStack([
                                knob(ElementsParam.BlowLevel.rawValue),
                                knob(ElementsParam.StrikeLevel.rawValue),
                                ]),
                            ])),
                        panel(HStack(main)),
                        panel(timbre),
                        ]),
                    panel2(Stack([
                        HStack([
                            intKnob(ElementsParam.Pitch.rawValue),
                            knob(ElementsParam.Detune.rawValue),
                            picker(ElementsParam.Mode.rawValue)
                            ]),
                        HStack([
                            knob(ElementsParam.ResonatorGeometry.rawValue, size: 70),
                            knob(ElementsParam.ResonatorBrightness.rawValue, size: 70),
                            ]),
                        cStack([
                            HStack([
                                knob(ElementsParam.ResonatorDamping.rawValue),
                                knob(ElementsParam.ResonatorPosition.rawValue),
                                ]),
                            HStack([
                                knob(ElementsParam.Space.rawValue),
                                knob(ElementsParam.Volume.rawValue),
                                ])
                            ]),
                        ])) //stack
                    ]) // cstack
            ), // page
            
            lfoPage(rate: ElementsParam.LfoRate.rawValue, shape: ElementsParam.LfoShape.rawValue, shapeMod: ElementsParam.LfoShapeMod.rawValue, tempoSync: ElementsParam.LfoTempoSync.rawValue, resetPhase: ElementsParam.LfoResetPhase.rawValue, keyReset: ElementsParam.LfoKeyReset.rawValue, modStart: ElementsParam.ModMatrixStart.rawValue),
            
            envPage(envStart: ElementsParam.EnvAttack.rawValue, modStart: ElementsParam.ModMatrixStart.rawValue),
            
            modMatrixPage(modStart: ElementsParam.ModMatrixStart.rawValue + 16, numberOfRules: 6)
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