//
//  ResonatorViewController.swift
//  iOSSpectrumApp
//
//  Created by tom on 2019-06-27.
//

import UIKit
import AVFoundation
import CoreAudioKit
import SpectrumFramework

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
    case LfoTempoSync = 22
    case LfoResetPhase = 23
    case LfoKeyReset = 24
    
    case ModMatrixStart = 400
    case ModMatrixEnd = 440 // 26 + 40 = 66
}

class ResonatorViewController: BaseAudioUnitViewController {
    var loadAsEffect = false
    
    override func buildUI() -> UI {
        state.colours = SpectrumUI.red
        
        var main = [
            knob(RingsParam.Structure.rawValue, size: 70),
            knob(RingsParam.Brightness.rawValue, size: 70),
        ]
        
        if (loadAsEffect) {
            main = [
                knob(RingsParam.InputGain.rawValue, size: 70),
            ] + main
        }
        
        return UI(state: state, [
            Page("Main",
                 cStack([
                    Stack([
                        panel(HStack([
                            intKnob(RingsParam.Pitch.rawValue),
                            knob(RingsParam.Detune.rawValue),
                            picker(RingsParam.Mode.rawValue)
                            ])),
                        panel(HStack(main)),
                        panel(cStack([
                            HStack([
                                knob(RingsParam.Damping.rawValue),
                                knob(RingsParam.Position.rawValue),
                                ]),
                            HStack([
                                knob(RingsParam.StereoSpread.rawValue),
                                knob(RingsParam.Volume.rawValue),
                                
                                ])
                            ])),
                        ]), //stack
                    Stack([
                        panel(touchPad(RingsParam.PadX.rawValue, RingsParam.PadY.rawValue, RingsParam.PadGate.rawValue))
                        ]),
                    ]) // cstack
            ), // page
            
            lfoPage(rate: RingsParam.LfoRate.rawValue, shape: RingsParam.LfoShape.rawValue, shapeMod: RingsParam.LfoShapeMod.rawValue, tempoSync: RingsParam.LfoTempoSync.rawValue, resetPhase: RingsParam.LfoResetPhase.rawValue, keyReset: RingsParam.LfoKeyReset.rawValue, modStart: RingsParam.ModMatrixStart.rawValue),
                
            envPage(envStart: RingsParam.EnvAttack.rawValue, modStart: RingsParam.ModMatrixStart.rawValue),
            
            modMatrixPage(modStart: RingsParam.ModMatrixStart.rawValue + 16, numberOfRules: 6)

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