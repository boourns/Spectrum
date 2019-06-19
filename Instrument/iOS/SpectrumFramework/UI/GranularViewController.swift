//
//  GranularViewController.swift
//  Granular
//
//  Created by tom on 2019-06-12.
//

import UIKit
import AVFoundation
import CoreAudioKit

enum CloudsParam: AUParameterAddress {
    case Position = 0
    case Size = 1
    case Density = 2
    case Texture = 3
    case Feedback = 4
    case Wet = 5
    case Reverb = 6
    case Stereo = 7
    case InputGain = 8
    case Trigger = 9
    case Freeze = 10
    case Pitch = 16
    case Detune = 17
    case LfoRate = 18
    case LfoShape = 19
    case LfoShapeMod = 20
    case EnvAttack = 22
    case EnvDecay = 23
    case EnvSustain = 24
    case EnvRelease = 25
    case ModMatrixStart = 26
    case ModMatrixEnd = 66
};

let big = CGFloat(80)

class GranularViewController: BaseAudioUnitViewController {
    override func buildUI() -> UI {
        return UI([
            Page("Spectrum",
                 CStack([
                    Stack([
                        Panel(HStack([
                            //Picker(PlaitsParam.Algorithm.rawValue),
                            ])),
                        Stack([Panel2(HStack([
                            Knob(CloudsParam.Position.rawValue, size: big),
                            Knob(CloudsParam.Size.rawValue, size: big),
                            Knob(CloudsParam.Pitch.rawValue, size: big),
                            ])),
                               Panel2(HStack([
                                Knob(CloudsParam.InputGain.rawValue),
                                Knob(CloudsParam.Density.rawValue),
                                Knob(CloudsParam.Texture.rawValue),
                                ])),
                            ]),
                        ]),
                    Stack([
                        Panel2(HStack([
                            Knob(CloudsParam.Wet.rawValue, size: big),
                            Knob(CloudsParam.Stereo.rawValue, size: big),
                            ])),
                        Panel2(HStack([
                            Knob(CloudsParam.Feedback.rawValue, size: big),
                            Knob(CloudsParam.Reverb.rawValue, size: big),
                            ]))
                        ]),
                    ])
                ),
            
            SpectrumUI.modulationPage(lfoStart: CloudsParam.LfoRate.rawValue, envStart: CloudsParam.EnvAttack.rawValue, modStart: CloudsParam.ModMatrixStart.rawValue),
            SpectrumUI.modMatrixPage(modStart: CloudsParam.ModMatrixStart.rawValue + 16, numberOfRules: 6)
            
            ]) // ui page list
        
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
