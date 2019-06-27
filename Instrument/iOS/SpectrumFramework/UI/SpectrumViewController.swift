/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 View controller for the InstrumentDemo audio unit. This is the app extension's principal class, responsible for creating both the audio unit and its view. Manages the interactions between a InstrumentView and the audio unit's parameters.
 */

import UIKit
import AVFoundation
import CoreAudioKit

// TODO:  HACK :( having to copy params enum into swift land
enum PlaitsParam: AUParameterAddress {
    case Timbre = 0
    case Harmonics = 1
    case Morph = 2
    case Algorithm = 4
    case Pitch = 5
    case Detune = 6
    case LPGColour = 7
    case Unison = 8
    case Polyphony = 9
    case Volume = 10
    case Slop = 11
    case LeftSource = 12
    case RightSource = 13
    case Pan = 14
    case PanSpread = 15
    case LfoRate = 16
    case LfoShape = 17
    case LfoShapeMod = 18
    case LfoAmount = 19
    case EnvAttack = 20
    case EnvDecay = 21
    case EnvSustain = 22
    case EnvRelease = 23
    case PitchBendRange = 24
    case AmpEnvAttack = 28
    case AmpEnvDecay = 29
    case AmpEnvSustain = 30
    case AmpEnvRelease = 31
    case Portamento = 88
    case PadX = 89
    case PadY = 90
    case PadGate = 91
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
    
    override func buildUI() -> UI {
        SpectrumUI.colours = SpectrumUI.purple

        return UI([
            Page("Spectrum",
                 CStack([
                   Stack([
                     Panel(HStack([
                        Picker(PlaitsParam.Algorithm.rawValue),
                        IntKnob(PlaitsParam.Pitch.rawValue),
                        Knob(PlaitsParam.Detune.rawValue),
                     ])),
                        Stack([Panel2(HStack([
                            Knob(PlaitsParam.Harmonics.rawValue, size: big),
                            Knob(PlaitsParam.Timbre.rawValue, size: big),
                            Knob(PlaitsParam.Morph.rawValue, size: big),
                         ])),
                         Panel2(HStack([
                            Knob(PlaitsParam.Slop.rawValue, size: small),
                            Knob(PlaitsParam.Portamento.rawValue, size: small),
                            IntKnob(PlaitsParam.PitchBendRange.rawValue, size: small),
                         ])),
                         ]),
                   ]),
                   Stack([
                     TouchPad(PlaitsParam.PadX.rawValue, PlaitsParam.PadY.rawValue, PlaitsParam.PadGate.rawValue)
                   ]),
                ]) //stack
            ), // page
            Page("Amp",
                        CStack([
                            Stack([
                                Panel2(Stack([
                                    HStack([
                                        Knob(PlaitsParam.Volume.rawValue),
                                        Knob(PlaitsParam.LPGColour.rawValue),
                                        ]),
                                    ])),
                                Panel2(Stack([
                                    Slider(PlaitsParam.AmpEnvAttack.rawValue),
                                    Slider(PlaitsParam.AmpEnvDecay.rawValue),
                                    Slider(PlaitsParam.AmpEnvSustain.rawValue),
                                    Slider(PlaitsParam.AmpEnvRelease.rawValue),
                                    ]))
                                ]),
                            Panel(Stack([
                                HStack([
                                    Knob(PlaitsParam.Pan.rawValue),
                                    Knob(PlaitsParam.PanSpread.rawValue),
                                    ]),
                                Stack([
                                    HStack([
                                        Knob(PlaitsParam.LeftSource.rawValue),
                                        Knob(PlaitsParam.RightSource.rawValue),
                                        ]),
                                    ]),
                                Stack([
                                    HStack([
                                        Picker(PlaitsParam.Unison.rawValue),
                                        IntKnob(PlaitsParam.Polyphony.rawValue),
                                        ]),
                                    ]),
                                ])
                            )])),
            
            SpectrumUI.modulationPage(lfoStart: PlaitsParam.LfoRate.rawValue, envStart: PlaitsParam.EnvAttack.rawValue, modStart: PlaitsParam.ModMatrixStart.rawValue),
            SpectrumUI.modMatrixPage(modStart: PlaitsParam.ModMatrixStart.rawValue + 24, numberOfRules: 6)
        
            //LFOPage(),
            //EnvPage(),
            //Page("Amp", UIView()),
            //ModMatrixPage(),
            ]) // ui page list
        
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
