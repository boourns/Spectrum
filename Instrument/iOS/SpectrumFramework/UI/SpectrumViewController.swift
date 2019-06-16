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
enum PlaitsParam: AUParameterAddress  {
    case Timbre = 0
    case Harmonics = 1
    case Morph = 2
    case LfoShapeMod = 3
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
    case LfoShape = 16
    case LfoRate = 17
    case LfoAmountFM = 18
    case LfoAmountHarmonics = 19
    case LfoAmountTimbre = 20
    case LfoAmountMorph = 21
    case PitchBendRange = 22
    case EnvAttack = 24
    case EnvDecay = 25
    case EnvSustain = 26
    case EnvRelease = 27
    case AmpEnvAttack = 28
    case AmpEnvDecay = 29
    case AmpEnvSustain = 30
    case AmpEnvRelease = 31
    case EnvAmountFM = 32
    case EnvAmountHarmonics = 33
    case EnvAmountTimbre = 34
    case EnvAmountMorph = 35
    case EnvAmountLFORate = 36
    case EnvAmountLFOAmount = 37
    case LfoAmount = 38
    case ModMatrixStart = 39
    case ModMatrixEnd = 51 // Recompute if necessary!
    case Portamento = 52
}

extension UILabel {
    convenience init(text: String) {
        self.init()
        self.text = text
        translatesAutoresizingMaskIntoConstraints = false
    }
}

class SpectrumViewController: BaseAudioUnitViewController {
    
    override func buildUI() -> UI {
        return UI([
            Page("Main",
                 CStack([
                   Stack([
                     CStack([
                         HStack([
                            Picker(PlaitsParam.Algorithm.rawValue),
                            Knob(PlaitsParam.Harmonics.rawValue),
                            ]),
                         HStack([
                            Knob(PlaitsParam.Algorithm.rawValue),
                            Knob(PlaitsParam.Harmonics.rawValue),
                            ]),
                         ]),
                     HStack([
                        Knob(PlaitsParam.Algorithm.rawValue, size: 80),
                        Knob(PlaitsParam.Harmonics.rawValue, size: 80),
                        ]),
                     HStack([
                        Knob(PlaitsParam.Algorithm.rawValue),
                        Knob(PlaitsParam.Harmonics.rawValue),
                        Knob(PlaitsParam.Harmonics.rawValue),
                        ]),
                     ]),
                   Stack([
                    HStack([
                        Knob(PlaitsParam.Algorithm.rawValue),
                        Knob(PlaitsParam.Harmonics.rawValue),
                        Knob(PlaitsParam.Harmonics.rawValue),
                        ]),
                    HStack([
                        Knob(PlaitsParam.Algorithm.rawValue, size: 80),
                        Knob(PlaitsParam.Harmonics.rawValue, size: 80),
                        ]),
                    HStack([
                        Knob(PlaitsParam.Algorithm.rawValue),
                        Knob(PlaitsParam.Harmonics.rawValue),
                        Knob(PlaitsParam.Harmonics.rawValue),
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
