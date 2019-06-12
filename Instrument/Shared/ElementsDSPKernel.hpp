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
#import "resampler.hpp"

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
    ElementsParamMode = 15,
    ElementsParamPitch = 16,
    ElementsParamDetune = 17,
    ElementsParamLfoShape = 18,
    ElementsParamLfoRate = 19,
    ElementsParamLfoShapeMod = 20,
    ElementsParamLfoAmount = 21,
    ElementsParamEnvAttack = 22,
    ElementsParamEnvDecay = 23,
    ElementsParamEnvSustain = 24,
    ElementsParamEnvRelease = 25,
    ElementsParamModMatrixStart = 26,
    ElementsParamModMatrixEnd = 26 + (kNumModulationRules * 4), // 26 + 40 = 66
    
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
    
    ElementsDSPKernel() : midiProcessor(1), modEngine(NumModulationInputs, NumModulationOutputs), modulationEngineRules(kNumModulationRules)
    {
        midiProcessor.noteStack.voices.push_back(this);
        
        part.Init(reverb_buffer);
        
        patch = part.mutable_patch();
        
        std::fill(&silence[0], &silence[kAudioBlockSize], 0.0f);
        
        patch->exciter_envelope_shape = 0.0f;
        patch->exciter_bow_level = 0.0f;
        patch->exciter_bow_timbre = 0.0f;
        patch->exciter_blow_level = 0.0f;
        patch->exciter_blow_meta = 0.0f;
        patch->exciter_blow_timbre = 0.0f;
        patch->exciter_strike_level = 0.5f;
        patch->exciter_strike_meta = 0.5f;
        patch->exciter_strike_timbre = 0.3f;
        patch->resonator_geometry = 0.4f;
        patch->resonator_brightness = 0.7f;
        patch->resonator_damping = 0.8f;
        patch->resonator_position = 0.3f;
        patch->space = 0.1f;
    }
    
    void init(int channelCount, double inSampleRate) {
        outputSrc.setRates(32000, (int) inSampleRate);
        
        midiAllNotesOff();
        envelope.Init();
        lfo.Init();
        
        modEngine.rules = &modulationEngineRules;
        modEngine.in[ModInDirect] = 1.0f;
    }
    
    void setParameter(AUParameterAddress address, AUValue value) {
        if (address >= ElementsParamModMatrixStart && address <= ElementsParamModMatrixEnd) {
            modulationEngineRules.setParameter(address - ElementsParamModMatrixStart, value);
            lfoRateIsPatched = modulationEngineRules.isPatched(ModOutLFORate);
            return;
        }
        
        switch (address) {
            case ElementsParamPitch:
                pitch = round(clamp(value, 0.0f, 24.0f)) - 12;
                break;
            case ElementsParamExciterEnvShape:
                patch->exciter_envelope_shape = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamBowLevel:
                patch->exciter_bow_level = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamBowTimbre:
                patch->exciter_bow_timbre = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamBlowLevel:
                patch->exciter_blow_level = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamBlowMeta:
                patch->exciter_blow_meta = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamBlowTimbre:
                patch->exciter_blow_timbre = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamStrikeLevel:
                patch->exciter_strike_level = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamStrikeMeta:
                patch->exciter_strike_meta = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamStrikeTimbre:
                patch->exciter_strike_timbre = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamResonatorGeometry:
                patch->resonator_geometry = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamResonatorBrightness:
                patch->resonator_brightness = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamResonatorDamping:
                patch->resonator_damping = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamResonatorPosition:
                patch->resonator_position = clamp(value, 0.0f, 1.0f);
                break;
            case ElementsParamSpace:
                patch->space = clamp(value, 0.0f, 2.0f);
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
                
            case ElementsParamLfoAmount:
                lfoBaseAmount = clamp(value, 0.0f, 1.0f);
                break;
            
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
                return pitch + 12;
                
            case ElementsParamExciterEnvShape:
                return patch->exciter_envelope_shape;
                
            case ElementsParamBowLevel:
                return patch->exciter_bow_level;
                
            case ElementsParamBowTimbre:
                return patch->exciter_bow_timbre;
                
            case ElementsParamBlowLevel:
                return patch->exciter_blow_level;
                
            case ElementsParamBlowMeta:
                return patch->exciter_blow_meta;
                
            case ElementsParamBlowTimbre:
                return patch->exciter_blow_timbre;
                
            case ElementsParamStrikeLevel:
                return patch->exciter_strike_level;
                
            case ElementsParamStrikeMeta:
                return patch->exciter_strike_meta;
                
            case ElementsParamStrikeTimbre:
                return patch->exciter_strike_timbre;
                
            case ElementsParamResonatorGeometry:
                return patch->resonator_geometry;
                
            case ElementsParamResonatorBrightness:
                return patch->resonator_brightness;
                
            case ElementsParamResonatorDamping:
                return patch->resonator_damping;
                
            case ElementsParamResonatorPosition:
                return patch->resonator_position;
                
            case ElementsParamSpace:
                return patch->space;
                
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
                
            case ElementsParamLfoAmount:
                return lfoBaseAmount;
                
            case ElementsParamEnvAttack:
                return ((float) envParameters[0]) / (float) UINT16_MAX;
                
            case ElementsParamEnvDecay:
                return ((float) envParameters[1]) / (float) UINT16_MAX;
                
            case ElementsParamEnvSustain:
                return ((float) envParameters[2]) / (float) UINT16_MAX;
                
            case ElementsParamEnvRelease:
                return ((float) envParameters[3]) / (float) UINT16_MAX;
                
            default:
                return 0.0f;
        }
    }
    
    void startRamp(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) override {
        // The attack and release parameters are not ramped.
        setParameter(address, value);
    }
    
    void setBuffers(AudioBufferList* outBufferList) {
        outBufferListPtr = outBufferList;
    }
    
    // =========== MIDI
    
    virtual void midiNoteOff() {
        state = NoteStateReleasing;
        gate = false;
    }
    
    void add() {
        if (state == NoteStateUnused) {
            gate = true;
        } else {
            delayed_trigger = true;
        }
        state = NoteStatePlaying;
    }
    
    virtual void midiNoteOn(uint8_t note, uint8_t vel) {
        currentNote = note;
        currentVelocity = ((float) vel) / 127.0;
        add();
    }
    
    virtual void midiAllNotesOff() {
        state = NoteStateUnused;
        gate = false;
        outputBuffer.clear();
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
        
        lfoOutput = ((float) lfo.Process(blockSize)) / INT16_MAX;
        
        modEngine.in[ModInLFO] = lfoOutput;
        modEngine.in[ModInEnvelope] = envelope.value;
        modEngine.in[ModInModwheel] = midiProcessor.modwheelAmount;
        
        modEngine.run();
        
        if (lfoRateIsPatched) {
            updateLfoRate(modEngine.out[ModOutLFORate]);
        }
        
        float lfoAmount = lfoBaseAmount + modEngine.out[ModOutLFOAmount];
    }
    
    void process(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) override {
        float* outL = (float*)outBufferListPtr->mBuffers[0].mData + bufferOffset;
        float* outR = (float*)outBufferListPtr->mBuffers[1].mData + bufferOffset;
        
        int framesRemaining = frameCount;
        
        while (framesRemaining) {
            if (outputBuffer.empty()) {
                
                //voice->Render(kernel->patch, modulations, &frames[0], kAudioBlockSize);
                elements::PerformanceState performance;
                performance.note = currentNote + pitch + detune + 12.0f;
                
                performance.modulation = 0.0f; /*i & 16 ? 60.0f : -60.0f;
                                                if (i > ::kSampleRate * 5) {
                                                performance.modulation = 0;
                                                }*/
                performance.strength = currentVelocity;
                performance.gate = gate;
                
                part.Process(performance, silence, silence, mainSamples, auxSamples, kAudioBlockSize);
                
                rack::Frame<2> outputFrames[16];
                for (int i = 0; i < 16; i++) {
                    outputFrames[i].samples[0] = mainSamples[i];
                    outputFrames[i].samples[1] = auxSamples[i];
                }
                
                int inLen = 16;
                int outLen = (int) outputBuffer.capacity();
                outputSrc.process(outputFrames, &inLen, outputBuffer.endData(), &outLen);
                outputBuffer.endIncr(outLen);
                
                if (delayed_trigger) {
                    gate = true;
                    delayed_trigger = false;
                }
            }
            
            rack::Frame<2> outputFrame = outputBuffer.shift();

            *outL++ += outputFrame.samples[0];
            *outR++ += outputFrame.samples[1];
            
            framesRemaining--;
        }
    }
    
    float randomSignedFloat(float max) {
        int range = ((float) INT_MAX) * max;
        if (range == 0) {
            return 0.0f;
        }
        float result = (float) (rand() % range) / (float) INT_MAX;
        if (rand() % 2 == 1) {
            result *= -1;
        }
        NSLog(@"Result %f", result);
        return result;
    }
    
    // MARK: Member Variables
    
private:
    AudioBufferList* outBufferListPtr = nullptr;
    
    unsigned int activePolyphony = 1;
    
public:
    elements::Part part;
    elements::Patch *patch;
    
    rack::SampleRateConverter<2> outputSrc;
    rack::DoubleRingBuffer<rack::Frame<2>, 256> outputBuffer;
    
    float mainSamples[kAudioBlockSize];
    float auxSamples[kAudioBlockSize];
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
    
    ModulationEngine modEngine;
    ModulationEngineRuleList modulationEngineRules;

    bool lfoRateIsPatched;
    uint16_t envParameters[4];
    peaks::MultistageEnvelope envelope;
    peaks::Lfo lfo;
    float lfoOutput;
    float lfoBaseRate;
    float lfoShape;
    float lfoShapeMod;
    float lfoBaseAmount;
};

#endif /* ElementsDSPKernel_h */
