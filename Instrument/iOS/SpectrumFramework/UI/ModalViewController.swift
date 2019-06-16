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
    case Mode = 15
    case Pitch = 16
    case Detune = 17
    case LfoShape = 18
    case LfoRate = 19
    case LfoShapeMod = 20
    case LfoAmount = 21
    case EnvAttack = 22
    case EnvDecay = 23
    case EnvSustain = 24
    case EnvRelease = 25
    case ModMatrixStart = 26
    case ModMatrixEnd = 66
};


class ModalViewController: BaseAudioUnitViewController {
    override func buildUI() -> UI {
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
                        Panel(HStack([
                            Knob(ElementsParam.BlowMeta.rawValue, size: 80),
                            Knob(ElementsParam.StrikeMeta.rawValue, size: 80),
                            ])),
                        Panel(HStack([
                            Knob(ElementsParam.BowTimbre.rawValue),
                            Knob(ElementsParam.BlowTimbre.rawValue),
                            Knob(ElementsParam.StrikeTimbre.rawValue),
                            ])),
                        ]),
                    Stack([
                        HStack([
                            Knob(ElementsParam.Pitch.rawValue),
                            Knob(ElementsParam.Detune.rawValue),
                            //Knob(ElementsParam.Harmonics.rawValue),
                            ]),
                        HStack([
                            Knob(ElementsParam.ResonatorGeometry.rawValue, size: 80),
                            Knob(ElementsParam.ResonatorBrightness.rawValue, size: 80),
                            ]),
                        HStack([
                            Knob(ElementsParam.ResonatorDamping.rawValue),
                            Knob(ElementsParam.ResonatorPosition.rawValue),
                            Knob(ElementsParam.Space.rawValue),
                            ]),
                        ]) //stack
                    ]) // cstack
            ) // page
            
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
        audioUnit = try ModalAudioUnit(componentDescription: componentDescription, options: [])
        
        return audioUnit!
    }
}
