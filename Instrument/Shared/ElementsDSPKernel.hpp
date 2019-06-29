//
//  ElementsDSPKernel.hpp
//  Spectrum
//
//  Created by tom on 2019-05-28.
//

#ifndef ElementsDSPKernel_h
#define ElementsDSPKernel_h

#import "peaks/multistage_envelope.h"
#import "DSPKernel.hpp"
#import <vector>
#import "elements/dsp/part.h"
#import "lfo.hpp"
#import "converter.hpp"

#import "MIDIProcessor.hpp"
#import "ModulationEngine.hpp"

const size_t kAudioBlockSize = 16;
const size_t kPolyphony = 1;
const size_t kNumModulationRules = 10;

enum {
    ElementsParamExciterEnvShape = 0,
    ElementsParamBowLevel = 1,
    ElementsParamBowTimbre = 2,
    ElementsParamBlowLevel = 3,
    ElementsParamBlowMeta = 4,
    ElementsParamBlowTimbre = 5,
    ElementsParamStrikeLevel = 6,
    ElementsParamStrikeMeta = 7,
    ElementsParamStrikeTimbre = 8,
    ElementsParamResonatorGeometry = 9,
    ElementsParamResonatorBrightness = 10,
    ElementsParamResonatorDamping = 11,
    ElementsParamResonatorPosition = 12,
    ElementsParamSpace = 13,
    ElementsParamVolume = 14,
    ElementsParamMode = 15,
    ElementsParamPitch = 16,
    ElementsParamDetune = 17,
    ElementsParamLfoRate = 18,
    ElementsParamLfoShape = 19,
    ElementsParamLfoShapeMod = 20,
    ElementsParamEnvAttack = 22,
    ElementsParamEnvDecay = 23,
    ElementsParamEnvSustain = 24,
    ElementsParamEnvRelease = 25,
    ElementsParamInputGain = 26,
    ElementsParamInputResonator = 27,
    ElementsParamModMatrixStart = 400,
    ElementsParamModMatrixEnd = 400 + (kNumModulationRules * 4), // 26 + 40 = 66
    
    ElementsMaxParameters
};

enum {
    ModInDirect = 0,
    ModInLFO,
    ModInEnvelope,
    ModInNote,
    ModInVelocity,
    ModInModwheel,
    ModInOut,
    NumModulationInputs
};

enum {
    ModOutDisabled = 0,
    ModOutTune,
    ModOutFrequency,
    ModOutExciterEnvShape,
    ModOutBowLevel,
    ModOutBowTimbre,
    ModOutBlowLevel,
    ModOutBlowMeta,
    ModOutBlowTimbre,
    ModOutStrikeLevel,
    ModOutStrikeMeta,
    ModOutStrikeTimbre,
    ModOutResonatorGeometry,
    ModOutResonatorBrightness,
    ModOutResonatorDamping,
    ModOutResonatorPosition,
    ModOutSpace,
    ModOutLFORate,
    ModOutLFOAmount,
    ModOutLevel,
    
    NumModulationOutputs
};

/*
 InstrumentDSPKernel
 Performs our filter signal processing.
 As a non-ObjC class, this is safe to use from render thread.
 */
class ElementsDSPKernel : public DSPKernel, public MIDIVoice {
public:
    // MARK: Member Functions
    
    ElementsDSPKernel() : midiProcessor(1), modEngine(NumModulationInputs, NumModulationOutputs), modulationEngineRules(kNumModulationRules, NumModulationInputs, NumModulationOutputs)
    {
        midiProcessor.noteStack.voices.push_back(this);
        
        part.Init(reverb_buffer);
        
        patch = part.mutable_patch();
        
        std::fill(&silence[0], &silence[kAudioBlockSize], 0.0f);
        
        basePatch.exciter_envelope_shape = 0.0f;
        basePatch.exciter_bow_level = 0.0f;
        basePatch.exciter_bow_timbre = 0.0f;
        basePatch.exciter_blow_level = 0.0f;
        basePatch.exciter_blow_meta = 0.0f;
        basePatch.exciter_blow_timbre = 0.0f;
        basePatch.exciter_strike_level = 0.5f;
        basePatch.exciter_strike_meta = 0.5f;
        basePatch.exciter_strike_timbre = 0.3f;
        basePatch.resonator_geometry = 0.4f;
        basePatch.resonator_brightness = 0.7f;
        basePatch.resonator_damping = 0.8f;
        basePatch.resonator_position = 0.3f;
        basePatch.space = 0.1f;
    }
    
    void init(int channelCount, double inSampleRate) {
        if (inputSrc) {
            delete inputSrc;
        }
        if (outputSrc) {
            delete outputSrc;
        }
        inputSrc = new Converter((int) inSampleRate, 32000);
        outputSrc = new Converter(32000, (int) inSampleRate);
        
        midiAllNotesOff();
        envelope.Init();
        lfo.Init();
        
        modEngine.rules = &modulationEngineRules;
        modEngine.in[ModInDirect] = 1.0f;
    }
    
    void setupModulationRules() {
        modulationEngineRules.rules[0].input1 = ModInLFO;
        modulationEngineRules.rules[1].input1 = ModInLFO;
        modulationEngineRules.rules[2].input1 = ModInEnvelope;
        modulationEngineRules.rules[3].input1 = ModInEnvelope;
    }
    
    void setParameter(AUParameterAddress address, AUValue value) {
        if (address >= ElementsParamModMatrixStart && address <= ElementsParamModMatrixEnd) {
            modulationEngineRules.setParameter(address - ElementsParamModMatrixStart, value);
            return;
        }
        
        switch (address) {
            case ElementsParamPitch:
                pitch = round(clamp(value, -12.0f, 12.0f));
                break;
            case ElementsParamExciterEnvShape:
                basePatch.exciter_envelope_shape = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamBowLevel:
                basePatch.exciter_bow_level = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamBowTimbre:
                basePatch.exciter_bow_timbre = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamBlowLevel:
                basePatch.exciter_blow_level = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamBlowMeta:
                basePatch.exciter_blow_meta = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamBlowTimbre:
                basePatch.exciter_blow_timbre = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamStrikeLevel:
                basePatch.exciter_strike_level = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamStrikeMeta:
                basePatch.exciter_strike_meta = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamStrikeTimbre:
                basePatch.exciter_strike_timbre = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamResonatorGeometry:
                basePatch.resonator_geometry = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamResonatorBrightness:
                basePatch.resonator_brightness = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamResonatorDamping:
                basePatch.resonator_damping = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamResonatorPosition:
                basePatch.resonator_position = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamSpace:
                basePatch.space = clamp(value, 0.0f, 2.0f);
                break;
            case ElementsParamVolume:
                volume = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamInputGain:
                inputGain = clamp(value, 0.0f, 2.0f);
                break;
                
            case ElementsParamInputResonator:
                inputResonator = (value > 0.7);
                break;
                
            case ElementsParamMode:
                part.set_resonator_model((elements::ResonatorModel) clamp(value, 0.0f, 3.0f));
                break;
                
            case ElementsParamDetune:
                detune = clamp(value, -1.0f, 1.0f);
                break;
                
            case ElementsParamLfoShape: {
                uint16_t newShape = round(clamp(value, 0.0f, 4.0f));
                if (newShape != lfoShape) {
                    lfoShape = newShape;
                    lfo.set_shape((peaks::LfoShape) lfoShape);
                }
                break;
            }
                
            case ElementsParamLfoShapeMod: {
                float newShape = clamp(value, -1.0f, 1.0f);
                if (newShape != lfoShapeMod) {
                    lfoShapeMod = newShape;
                    uint16_t par = (newShape * 32767.0f);
                    lfo.set_parameter(par);
                }
                break;
            }
                
            case ElementsParamLfoRate: {
                float newRate = clamp(value, 0.0f, 1.0f);
                
                if (newRate != lfoBaseRate) {
                    lfoBaseRate = newRate;
                    updateLfoRate(0.0f);
                }
                break;
            }
            
            case ElementsParamEnvAttack: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != envParameters[0]) {
                    envParameters[0] = newValue;
                    envelope.Configure(envParameters);
                }
                break;
            }
                
            case ElementsParamEnvDecay: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != envParameters[1]) {
                    envParameters[1] = newValue;
                    envelope.Configure(envParameters);
                }
                break;
            }
                
            case ElementsParamEnvSustain: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != envParameters[2]) {
                    envParameters[2] = newValue;
                    envelope.Configure(envParameters);
                }
                break;
            }
                
            case ElementsParamEnvRelease: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != envParameters[3]) {
                    envParameters[3] = newValue;
                    envelope.Configure(envParameters);
                }
                break;
            }
        }
    }
    
    AUValue getParameter(AUParameterAddress address) {
        if (address >= ElementsParamModMatrixStart && address <= ElementsParamModMatrixEnd) {
            return modulationEngineRules.getParameter(address - ElementsParamModMatrixStart);
        }
        
        switch (address) {
            case ElementsParamPitch:
                return pitch;
                
            case ElementsParamExciterEnvShape:
                return basePatch.exciter_envelope_shape;
                
            case ElementsParamBowLevel:
                return basePatch.exciter_bow_level;
                
            case ElementsParamBowTimbre:
                return basePatch.exciter_bow_timbre;
                
            case ElementsParamBlowLevel:
                return basePatch.exciter_blow_level;
                
            case ElementsParamBlowMeta:
                return basePatch.exciter_blow_meta;
                
            case ElementsParamBlowTimbre:
                return basePatch.exciter_blow_timbre;
                
            case ElementsParamStrikeLevel:
                return basePatch.exciter_strike_level;
                
            case ElementsParamStrikeMeta:
                return basePatch.exciter_strike_meta;
                
            case ElementsParamStrikeTimbre:
                return basePatch.exciter_strike_timbre;
                
            case ElementsParamResonatorGeometry:
                return basePatch.resonator_geometry;
                
            case ElementsParamResonatorBrightness:
                return basePatch.resonator_brightness;
                
            case ElementsParamResonatorDamping:
                return basePatch.resonator_damping;
                
            case ElementsParamResonatorPosition:
                return basePatch.resonator_position;
                
            case ElementsParamSpace:
                return basePatch.space;
                
            case ElementsParamMode:
                if (part.easter_egg_) {
                    return 3.0f;
                } else {
                    return (float) part.resonator_model();
                }
                
            case ElementsParamDetune:
                return detune;
                
            case ElementsParamLfoRate:
                return lfoBaseRate;
                
            case ElementsParamLfoShape:
                return lfoShape;
                
            case ElementsParamLfoShapeMod:
                return lfoShapeMod;
                
            case ElementsParamEnvAttack:
                return ((float) envParameters[0]) / (float) UINT16_MAX;
                
            case ElementsParamEnvDecay:
                return ((float) envParameters[1]) / (float) UINT16_MAX;
                
            case ElementsParamEnvSustain:
                return ((float) envParameters[2]) / (float) UINT16_MAX;
                
            case ElementsParamEnvRelease:
                return ((float) envParameters[3]) / (float) UINT16_MAX;
                
            case ElementsParamVolume:
                return volume;
                
            case ElementsParamInputResonator:
                return inputResonator ? 1.0f : 0.0f;
                
            case ElementsParamInputGain:
                return inputGain;
                
            default:
                return 0.0f;
        }
    }
    
    void startRamp(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) override {
        // The attack and release parameters are not ramped.
        setParameter(address, value);
    }
    
    void setBuffers(AudioBufferList* inBufferList, AudioBufferList* outBufferList) {
        inBufferListPtr = inBufferList;
        outBufferListPtr = outBufferList;
    }
    
    // =========== MIDI
    
    virtual void midiNoteOff() {
        state = NoteStateReleasing;
        gate = false;
        envelope.TriggerLow();
    }
    
    void add() {
        if (state == NoteStateUnused) {
            gate = true;
            envelope.TriggerHigh();
        } else {
            delayed_trigger = true;
        }
        state = NoteStatePlaying;
    }
    
    virtual void midiNoteOn(uint8_t note, uint8_t vel) {
        currentNote = note;
        currentVelocity = ((float) vel) / 127.0;
        modEngine.in[ModInNote] = ((float) currentNote) / 127.0f;
        modEngine.in[ModInVelocity] = currentVelocity;

        add();
    }
    
    virtual void midiAllNotesOff() {
        state = NoteStateUnused;
        gate = false;
    }
    
    virtual uint8_t Note() {
        return currentNote;
    }
    
    virtual int State() {
        return state;
    }
    
    virtual void handleMIDIEvent(AUMIDIEvent const& midiEvent) override {
        midiProcessor.handleMIDIEvent(midiEvent);
    }
    
    // ================= Modulations
    void updateLfoRate(float modulationAmount) {
        float calculatedRate = clamp(lfoBaseRate + modulationAmount, 0.0f, 1.0f);
        uint16_t rateParameter = (uint16_t) (calculatedRate * (float) UINT16_MAX);
        lfo.set_rate(rateParameter);
    }
    
    void runModulations(int blockSize) {
        envelope.Process(blockSize);
        
        float lfoAmount = 1.0;
        if (modulationEngineRules.isPatched(ModOutLFOAmount)) {
            lfoAmount = modEngine.out[ModOutLFOAmount];
        }
        
        lfoOutput = lfoAmount * ((float) lfo.Process(blockSize)) / INT16_MAX;
        
        modEngine.in[ModInLFO] = lfoOutput;
        modEngine.in[ModInEnvelope] = envelope.value;
        modEngine.in[ModInModwheel] = midiProcessor.modwheelAmount;
        
        modEngine.run();
        
        if (modulationEngineRules.isPatched(ModOutLFORate)) {
            updateLfoRate(modEngine.out[ModOutLFORate]);
        }
        
        patch->exciter_envelope_shape = clamp(basePatch.exciter_envelope_shape + modEngine.out[ModOutExciterEnvShape], 0.0f, 1.0f);
        patch->exciter_bow_level = clamp(basePatch.exciter_bow_level + modEngine.out[ModOutBowLevel], 0.0f, 1.0f);
        patch->exciter_bow_timbre = clamp(basePatch.exciter_bow_timbre + modEngine.out[ModOutBowTimbre], 0.0f, 0.9995f);
        patch->exciter_blow_level = clamp(basePatch.exciter_blow_level + modEngine.out[ModOutBlowLevel], 0.0f, 1.0f);
        
        ONE_POLE(patch->exciter_blow_meta, clamp(basePatch.exciter_blow_meta + modEngine.out[ModOutBlowMeta], 0.0f, 0.9995f), 0.05f); // LP
        
        patch->exciter_blow_timbre = clamp(basePatch.exciter_blow_timbre + modEngine.out[ModOutBlowTimbre], 0.0f, 0.9995f);
        patch->exciter_strike_level = clamp(basePatch.exciter_strike_level + modEngine.out[ModOutStrikeLevel], 0.0f, 1.0f);
        ONE_POLE(patch->exciter_strike_meta, clamp(basePatch.exciter_strike_meta + modEngine.out[ModOutStrikeMeta], 0.0f, 0.9995f),  0.05f); //LP
        patch->exciter_strike_timbre = clamp(basePatch.exciter_strike_timbre + modEngine.out[ModOutStrikeTimbre], 0.0f, 0.9995f);
        ONE_POLE(patch->resonator_geometry, clamp(basePatch.resonator_geometry + modEngine.out[ModOutResonatorGeometry], 0.0f, 0.9995f), 0.05f); // LP
        patch->resonator_brightness = clamp(basePatch.resonator_brightness + modEngine.out[ModOutResonatorBrightness], 0.0f, 0.9995f);
        patch->resonator_damping = clamp(basePatch.resonator_damping + modEngine.out[ModOutResonatorDamping], 0.0f, 0.9995f);
        ONE_POLE(patch->resonator_position, clamp(basePatch.resonator_position + modEngine.out[ModOutResonatorPosition], 0.0f, 0.9995f), 0.01f); // LP
        ONE_POLE(patch->space, clamp(basePatch.space + modEngine.out[ModOutSpace], 0.0f, 2.0f), 0.01f); // LP
    }
    
    void process(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) override {
        float* outL = (float*)outBufferListPtr->mBuffers[0].mData + bufferOffset;
        float* outR = (float*)outBufferListPtr->mBuffers[1].mData + bufferOffset;
        float *inL = (float *)inBufferListPtr->mBuffers[0].mData + bufferOffset;
        float *inR = (float *)inBufferListPtr->mBuffers[1].mData + bufferOffset;
        
        float mixedInput[kAudioBlockSize];
        
        float *extInputPtr = &silence[0];
        float *resInputPtr = extInputPtr;
        
        int outputFramesRemaining = frameCount;
        int inputFramesRemaining = frameCount;
        
        while (outputFramesRemaining) {
            if (renderedFramesPos == kAudioBlockSize) {
                runModulations(kAudioBlockSize);
                
                if (useAudioInput) {
                    ConverterResult result;
                    inputSrc->convert(inL, inR, inputFramesRemaining, processedL + carriedInputFrames, processedR + carriedInputFrames, kAudioBlockSize - carriedInputFrames, &result);
                    inL += result.inputConsumed;
                    inR += result.inputConsumed;
                    inputFramesRemaining -= result.inputConsumed;
                    
                    for (int i = 0; i < kAudioBlockSize; i++) {
                        mixedInput[i] = ((processedL[i] + processedR[i]) / 2.0f) * inputGain;
                    }
                    
                    extInputPtr = !inputResonator ? &mixedInput[0] : &silence[0];
                    resInputPtr = inputResonator ? &mixedInput[0] : &silence[0];
                }
                
                //voice->Render(kernel->patch, modulations, &frames[0], kAudioBlockSize);
                elements::PerformanceState performance;
                performance.note = currentNote + pitch + detune + 12.0f + modEngine.out[ModOutTune] + (modEngine.out[ModOutFrequency] * 120.0f);
                
                performance.modulation = 0.0f; /*i & 16 ? 60.0f : -60.0f;
                                                if (i > ::kSampleRate * 5) {
                                                performance.modulation = 0;
                                                }*/
                performance.strength = currentVelocity;
                performance.gate = gate;
                float finalVolume = clamp(volume + modEngine.out[ModOutLevel], 0.0f, 1.0f);
                
                part.Process(performance, extInputPtr, resInputPtr, renderedL, renderedR, kAudioBlockSize);
                
                if (delayed_trigger) {
                    gate = true;
                    delayed_trigger = false;
                    envelope.TriggerHigh();
                }
                
                for (int i = 0; i < kAudioBlockSize; i++) {
                    renderedL[i] *= finalVolume;
                    renderedR[i] *= finalVolume;
                }
                
                modEngine.in[ModInOut] = renderedL[kAudioBlockSize-1];
                renderedFramesPos = 0;
            }
            
            ConverterResult result;
            
            outputSrc->convert(renderedL + renderedFramesPos, renderedR + renderedFramesPos, kAudioBlockSize - renderedFramesPos, outL, outR, outputFramesRemaining, &result);
            
            outL += result.outputLength;
            outR += result.outputLength;
            
            renderedFramesPos += result.inputConsumed;
            outputFramesRemaining -= result.outputLength;
        }
        
        if (inputFramesRemaining > 0) {
            ConverterResult result;
            inputSrc->convert(inL, inR, inputFramesRemaining, processedL, processedR, kAudioBlockSize, &result);
            carriedInputFrames = result.outputLength;
        }
    }
    
    // MARK: Member Variables
    
private:
    AudioBufferList* inBufferListPtr = nullptr;
    AudioBufferList* outBufferListPtr = nullptr;
    
    unsigned int activePolyphony = 1;
    
public:
    elements::Part part;
    elements::Patch *patch;
    elements::Patch basePatch;
    
    Converter *inputSrc = 0;
    float processedL[kAudioBlockSize] = {};
    float processedR[kAudioBlockSize] = {};
    int carriedInputFrames = 0;
    
    Converter *outputSrc = 0;
    float renderedL[kAudioBlockSize] = {};
    float renderedR[kAudioBlockSize] = {};
    int renderedFramesPos = 0;
    
    float silence[kAudioBlockSize];
    uint16_t reverb_buffer[32768];
    
    MIDIProcessor midiProcessor;
    bool gate;
    uint8_t currentNote;
    float currentVelocity;
    int state;
    bool delayed_trigger = false;
    int pitch = 0;
    float detune = 0;
    int bendRange = 0;
    float bendAmount = 0.0f;
    bool useAudioInput = false;
    
    ModulationEngine modEngine;
    ModulationEngineRuleList modulationEngineRules;

    uint16_t envParameters[4];
    peaks::MultistageEnvelope envelope;
    peaks::Lfo lfo;
    float lfoOutput;
    float lfoBaseRate;
    float lfoShape;
    float lfoShapeMod;
    float lfoBaseAmount;
    float volume;
    float inputGain;
    bool inputResonator;
};

#endif /* ElementsDSPKernel_h */
