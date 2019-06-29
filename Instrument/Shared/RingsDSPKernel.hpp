//
//  RingsDSPKernel.hpp
//  Spectrum
//
//  Created by tom on 2019-05-28.
//

#ifndef RingsDSPKernel_h
#define RingsDSPKernel_h

#import "peaks/multistage_envelope.h"
#import "DSPKernel.hpp"
#import <vector>

#import "rings/dsp/strummer.h"
#import "rings/dsp/string_synth_part.h"
#import "rings/dsp/part.h"
#import "lfo.hpp"
#import "converter.hpp"

#import "MIDIProcessor.hpp"
#import "ModulationEngine.hpp"

const size_t kAudioBlockSize = 16;
const size_t kPolyphony = 1;
const size_t kNumModulationRules = 10;

enum {
    RingsParamPadX = 0,
    RingsParamPadY = 1,
    RingsParamPadGate = 2,
    RingsParamStructure = 4,
    RingsParamBrightness = 5,
    RingsParamDamping = 6,
    RingsParamPosition = 7,
    RingsParamVolume = 8,
    RingsParamMode = 9,
    RingsParamPolyphony = 10,
    RingsParamPitch = 11,
    RingsParamDetune = 12,
    RingsParamLfoRate = 13,
    RingsParamLfoShape = 14,
    RingsParamLfoShapeMod = 15,
    RingsParamEnvAttack = 16,
    RingsParamEnvDecay = 17,
    RingsParamEnvSustain = 18,
    RingsParamEnvRelease = 19,
    RingsParamInputGain = 20,
    RingsParamStereoSpread = 21,
    RingsParamModMatrixStart = 400,
    RingsParamModMatrixEnd = 400 + (kNumModulationRules * 4), // 26 + 40 = 66
    
    RingsMaxParameters
};

enum {
    ModInDirect = 0,
    ModInPadX,
    ModInPadY,
    ModInPadGate,
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
    ModOutStructure,
    ModOutBrightness,
    ModOutDamping,
    ModOutPosition,
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
class RingsDSPKernel : public DSPKernel, public MIDIVoice {
public:
    // MARK: Member Functions
    
    RingsDSPKernel() : midiProcessor(1), modEngine(NumModulationInputs, NumModulationOutputs), modulationEngineRules(kNumModulationRules, NumModulationInputs, NumModulationOutputs)
    {
        midiProcessor.noteStack.voices.push_back(this);
        
        part.Init(reverb_buffer);
        string_synth.Init(reverb_buffer);

        part.set_polyphony(4);
        
        std::fill(&silence[0], &silence[kAudioBlockSize], 0.0f);
        memset(&basePatch, 0, sizeof(rings::Patch));
        memset(&patch, 0, sizeof(rings::Patch));

        basePatch.structure = 0.4f;
        basePatch.brightness = 0.7f;
        basePatch.damping = 0.8f;
        basePatch.position = 0.3f;
    }
    
    void init(int channelCount, double inSampleRate) {
        if (inputSrc) {
            delete inputSrc;
        }
        if (outputSrc) {
            delete outputSrc;
        }
        inputSrc = new Converter((int) inSampleRate, 48000);
        outputSrc = new Converter(48000, (int) inSampleRate);
        strummer.Init(0.01f, 48000 / kAudioBlockSize);

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
        if (address >= RingsParamModMatrixStart && address <= RingsParamModMatrixEnd) {
            modulationEngineRules.setParameter(address - RingsParamModMatrixStart, value);
            return;
        }
        
        switch (address) {
            case RingsParamPitch:
                pitch = round(clamp(value, -12.0f, 12.0f));
                break;
            case RingsParamStructure:
                basePatch.structure = clamp(value, 0.0f, 1.0f);
                chord = clamp((int) roundf(basePatch.structure * (rings::kNumChords - 1)), 0, rings::kNumChords - 1);

                break;
            case RingsParamBrightness:
                basePatch.brightness = clamp(value, 0.0f, 1.0f);
                break;
            case RingsParamDamping:
                basePatch.damping = clamp(value, 0.0f, 1.0f);
                break;
            case RingsParamPosition:
                basePatch.position = clamp(value, 0.0f, 1.0f);
                break;
            case RingsParamVolume:
                volume = clamp(value, 0.0f, 1.0f);
                break;
            case RingsParamInputGain:
                inputGain = clamp(value, 0.0f, 2.0f);
                break;
            case RingsParamStereoSpread:
                stereo = clamp(value, 0.0f, 1.0f);
                break;
            case RingsParamMode: {
                uint16_t mode = round(clamp(value, 0.0f, 6.0f));
                if (mode == 6) {
                    easterEgg = true;
                } else {
                    easterEgg = false;
                    part.set_model((rings::ResonatorModel) mode);
                }
                break;
            }
            case RingsParamDetune:
                detune = clamp(value, -1.0f, 1.0f);
                break;
                
            case RingsParamPadX: {
                float val = clamp(value, 0.0f, 1.0f);
                modEngine.in[ModInPadX] = val;
                
                break;
            }
                
            case RingsParamPadY: {
                float val = clamp(value, 0.0f, 1.0f);
                modEngine.in[ModInPadY] = val;
                
                break;
            }
                
            case RingsParamPadGate: {
                float val = clamp(value, 0.0f, 1.0f);
                modEngine.in[ModInPadGate] = val;
                
                break;
            }
                
            case RingsParamLfoShape: {
                uint16_t newShape = round(clamp(value, 0.0f, 4.0f));
                if (newShape != lfoShape) {
                    lfoShape = newShape;
                    lfo.set_shape((peaks::LfoShape) lfoShape);
                }
                break;
            }
                
            case RingsParamLfoShapeMod: {
                float newShape = clamp(value, -1.0f, 1.0f);
                if (newShape != lfoShapeMod) {
                    lfoShapeMod = newShape;
                    uint16_t par = (newShape * 32767.0f);
                    lfo.set_parameter(par);
                }
                break;
            }
                
            case RingsParamLfoRate: {
                float newRate = clamp(value, 0.0f, 1.0f);
                
                if (newRate != lfoBaseRate) {
                    lfoBaseRate = newRate;
                    updateLfoRate(0.0f);
                }
                break;
            }
                
            case RingsParamEnvAttack: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != envParameters[0]) {
                    envParameters[0] = newValue;
                    envelope.Configure(envParameters);
                }
                break;
            }
                
            case RingsParamEnvDecay: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != envParameters[1]) {
                    envParameters[1] = newValue;
                    envelope.Configure(envParameters);
                }
                break;
            }
                
            case RingsParamEnvSustain: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != envParameters[2]) {
                    envParameters[2] = newValue;
                    envelope.Configure(envParameters);
                }
                break;
            }
                
            case RingsParamEnvRelease: {
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
        if (address >= RingsParamModMatrixStart && address <= RingsParamModMatrixEnd) {
            return modulationEngineRules.getParameter(address - RingsParamModMatrixStart);
        }
        
        switch (address) {
            case RingsParamPitch:
                return pitch;
                
            case RingsParamStructure:
                return basePatch.structure;
                
            case RingsParamBrightness:
                return basePatch.brightness;
                
            case RingsParamDamping:
                return basePatch.damping;
                
            case RingsParamPosition:
                return basePatch.position;
                
            case RingsParamMode:
                if (easterEgg) {
                    return 6.0f;
                } else {
                    return (float) part.model();
                }
                
            case RingsParamDetune:
                return detune;
                
            case RingsParamPadX:
                return modEngine.in[ModInPadX];
                
            case RingsParamPadY:
                return modEngine.in[ModInPadY];
                
            case RingsParamPadGate:
                return modEngine.in[ModInPadGate];
                
            case RingsParamLfoRate:
                return lfoBaseRate;
                
            case RingsParamLfoShape:
                return lfoShape;
                
            case RingsParamLfoShapeMod:
                return lfoShapeMod;
                
            case RingsParamEnvAttack:
                return ((float) envParameters[0]) / (float) UINT16_MAX;
                
            case RingsParamEnvDecay:
                return ((float) envParameters[1]) / (float) UINT16_MAX;
                
            case RingsParamEnvSustain:
                return ((float) envParameters[2]) / (float) UINT16_MAX;
                
            case RingsParamEnvRelease:
                return ((float) envParameters[3]) / (float) UINT16_MAX;
                
            case RingsParamVolume:
                return volume;
                
            case RingsParamInputGain:
                return inputGain;
                
            case RingsParamStereoSpread:
                return stereo;
                
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
        
        patch.structure = clamp(basePatch.structure + modEngine.out[ModOutStructure], 0.0f, 0.9995f); // LP
        patch.brightness = clamp(basePatch.brightness + modEngine.out[ModOutBrightness], 0.0f, 0.9995f);
        patch.damping = clamp(basePatch.damping + modEngine.out[ModOutDamping], 0.0f, 0.9995f);
        patch.position = clamp(basePatch.position + modEngine.out[ModOutPosition], 0.0f, 0.9995f); // LP
    }
    
    void process(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) override {
        float* outL = (float*)outBufferListPtr->mBuffers[0].mData + bufferOffset;
        float* outR = (float*)outBufferListPtr->mBuffers[1].mData + bufferOffset;
        float *inL = (float *)inBufferListPtr->mBuffers[0].mData + bufferOffset;
        float *inR = (float *)inBufferListPtr->mBuffers[1].mData + bufferOffset;
        
        float mixedInput[kAudioBlockSize];
        
        float *input = &silence[0];
        
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
                    
                    if (easterEgg) {
                        for (int i = 0; i < kAudioBlockSize; ++i) {
                            mixedInput[i] = ((processedL[i] + processedR[i]) / 2.0f) * inputGain;
                        }
                    } else {
                        for (int i = 0; i < kAudioBlockSize; i++) {
                            float in_sample = ((processedL[i] + processedR[i]) / 2.0f) * inputGain;
                            float error, gain;
                            error = in_sample * in_sample - in_level;
                            in_level += error * (error > 0.0f ? 0.1f : 0.0001f);
                            gain = in_level <= kNoiseGateThreshold
                            ? (1.0f / kNoiseGateThreshold) * in_level : 1.0f;
                            mixedInput[i] = gain * in_sample;
                        }
                    }
                    
                    input = &mixedInput[0];
                }
                
                //voice->Render(kernel->patch, modulations, &frames[0], kAudioBlockSize);
                rings::PerformanceState performance;
                
                performance.tonic = pitch + 12.0f;
                performance.note = currentNote;
                performance.fm = detune + modEngine.out[ModOutTune] + (modEngine.out[ModOutFrequency] * 120.0f);
                performance.chord = chord;
                
                // TODO unsure here yet
                performance.strum = gate;
                gate = false;
                performance.internal_exciter = !useAudioInput;
                performance.internal_strum = false;

                float finalVolume = clamp(volume + modEngine.out[ModOutLevel], 0.0f, 1.0f);
                
                if (easterEgg) {
                    strummer.Process(NULL, kAudioBlockSize, &performance);
                    string_synth.Process(performance, patch, input, renderedL, renderedR, kAudioBlockSize);
                } else {
                    strummer.Process(input, kAudioBlockSize, &performance);
                    part.Process(performance, patch, input, renderedL, renderedR, kAudioBlockSize);
                }

                if (delayed_trigger) {
                    gate = true;
                    delayed_trigger = false;
                    envelope.TriggerHigh();
                }
                
                float mix = 1.0f - stereo;
                
                for (int i = 0; i < kAudioBlockSize; i++) {
                    renderedL[i] = (renderedL[i] + (renderedR[i] * mix)) * finalVolume;
                    renderedR[i] = (renderedR[i] + (renderedL[i] * mix)) * finalVolume;;
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
    rings::Part part;
    rings::StringSynthPart string_synth;
    rings::Strummer strummer;
    rings::Patch patch;
    rings::Patch basePatch;
    float chord;
    
    const float kNoiseGateThreshold = 0.00003f;
    float in_level = 0.0f;
    
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
    float stereo;
    
    bool easterEgg = false;
};

#endif /* RingsDSPKernel_h */