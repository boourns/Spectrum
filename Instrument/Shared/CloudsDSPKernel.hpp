//
//  CloudsDSPKernel.h
//  Spectrum
//
//  Created by tom on 2019-06-12.
//

#ifndef CloudsDSPKernel_h
#define CloudsDSPKernel_h

#import "clouds/dsp/granular_processor.h"
#import "peaks/multistage_envelope.h"
#import "DSPKernel.hpp"
#import <vector>
#import "lfo.hpp"
#import "converter.hpp"

#import "MIDIProcessor.hpp"
#import "ModulationEngine.hpp"

const size_t kAudioBlockSize = 32;
const size_t kPolyphony = 1;
const size_t kNumModulationRules = 10;

enum {
    CloudsParamPosition = 0,
    CloudsParamSize = 1,
    CloudsParamDensity = 2,
    CloudsParamTexture = 3,
    CloudsParamFeedback = 4,
    CloudsParamWet = 5,
    CloudsParamReverb = 6,
    CloudsParamStereo = 7,
    CloudsParamInputGain = 8,
    CloudsParamTrigger = 9,
    CloudsParamFreeze = 10,
    CloudsParamMode = 11,
    CloudsParamPadX = 12,
    CloudsParamPadY = 13,
    CloudsParamPadGate = 14,
    CloudsParamPitch = 16,
    CloudsParamDetune = 17,
    CloudsParamLfoRate = 18,
    CloudsParamLfoShape = 19,
    CloudsParamLfoShapeMod = 20,
    CloudsParamEnvAttack = 22,
    CloudsParamEnvDecay = 23,
    CloudsParamEnvSustain = 24,
    CloudsParamEnvRelease = 25,
    CloudsParamVolume = 26,
    CloudsParamModMatrixStart = 400,
    CloudsParamModMatrixEnd = 400 + (kNumModulationRules * 4), // 26 + 40 = 66
    
    CloudsMaxParameters
};

enum {
    ModInDirect = 0,
    ModInLFO,
    ModInEnvelope,
    ModInNote,
    ModInVelocity,
    ModInModwheel,
    ModInPadX,
    ModInPadY,
    ModInPadGate,
    ModInOut,
    NumModulationInputs
};

enum {
    ModOutDisabled = 0,
    ModOutTune,
    ModOutFrequency,
    ModOutPosition,
    ModOutSize,
    ModOutDensity,
    ModOutTexture,
    ModOutTrigger,
    ModOutFreeze,
    ModOutFeedback,
    ModOutWet,
    ModOutReverb,
    ModOutStereo,
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
class CloudsDSPKernel : public DSPKernel, public MIDIVoice {
public:
    // MARK: Member Functions
    
    CloudsDSPKernel() : midiProcessor(1), modEngine(NumModulationInputs, NumModulationOutputs), modulationEngineRules(kNumModulationRules, NumModulationInputs, NumModulationOutputs)
    {
        midiProcessor.noteStack.voices.push_back(this);
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

        processor.Init(
                       &large_buffer[0], sizeof(large_buffer),
                       &small_buffer[0],sizeof(small_buffer));
        
        processor.set_num_channels(2);
        processor.set_low_fidelity(false);
        processor.set_playback_mode(clouds::PLAYBACK_MODE_GRANULAR);
        processor.Prepare();
        
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
        if (address >= CloudsParamModMatrixStart && address <= CloudsParamModMatrixEnd) {
            modulationEngineRules.setParameter(address - CloudsParamModMatrixStart, value);
            return;
        }
        
        switch (address) {
            case CloudsParamPosition:
                baseParameters.position = clamp(value, 0.0f, 1.0f);
                break;
                
            case CloudsParamSize:
                baseParameters.size = clamp(value, 0.0f, 1.0f);
                break;
                
            case CloudsParamDensity:
                baseParameters.density = (1.0 + clamp(value, -1.0f, 1.0f)) / 2.0;
                break;
                
            case CloudsParamTexture:
                baseParameters.texture = clamp(value, 0.0f, 1.0f);
                break;
                
            case CloudsParamInputGain:
                inputGain = clamp(value, 0.0f, 1.0f);
                break;
                
            case CloudsParamTrigger:
                trigger = clamp(value, 0.0f, 1.0f);
                break;
                
            case CloudsParamFreeze:
                freeze = clamp(value, 0.0f, 1.0f);
                break;
                
            case CloudsParamFeedback:
                baseParameters.feedback = clamp(value, 0.0f, 1.0f);
                break;
                
            case CloudsParamWet:
                baseParameters.dry_wet = clamp(value, 0.0f, 1.0f);
                break;
                
            case CloudsParamReverb:
                baseParameters.reverb = clamp(value, 0.0f, 1.0f);
                break;
                
            case CloudsParamStereo:
                baseParameters.stereo_spread = clamp(value, 0.0f, 1.0f);
                break;
                
            case CloudsParamPitch:
                pitch = clamp(value, -12.0f, 12.0f);
                break;
            
            case CloudsParamDetune:
                detune = clamp(value, -1.0f, 1.0f);
                break;
                
            case CloudsParamVolume:
                volume = clamp(value, 0.0f, 1.5f);
                gainCoefficient = volume / 0.6f; // make up for SoftConvert in GranularProcessor
                printf("gain %f\n", gainCoefficient);
                break;
                
            case CloudsParamMode: {
                clouds::PlaybackMode newMode = (clouds::PlaybackMode) round(clamp(value, 0.0f, 3.0f));
                if (newMode != processor.playback_mode()) {
                    processor.set_playback_mode(newMode);
                    processor.Prepare();
                }
                break;
            }
                
            case CloudsParamPadX: {
                float val = clamp(value, 0.0f, 1.0f);
                modEngine.in[ModInPadX] = val;
                
                break;
            }
                
            case CloudsParamPadY: {
                float val = clamp(value, 0.0f, 1.0f);
                modEngine.in[ModInPadY] = val;
                
                break;
            }
                
            case CloudsParamPadGate: {
                float val = clamp(value, 0.0f, 1.0f);
                modEngine.in[ModInPadGate] = val;
                
                break;
            }
                
            case CloudsParamLfoShape: {
                uint16_t newShape = round(clamp(value, 0.0f, 4.0f));
                if (newShape != lfoShape) {
                    lfoShape = newShape;
                    lfo.set_shape((peaks::LfoShape) lfoShape);
                }
                break;
            }
                
            case CloudsParamLfoShapeMod: {
                float newShape = clamp(value, -1.0f, 1.0f);
                if (newShape != lfoShapeMod) {
                    lfoShapeMod = newShape;
                    uint16_t par = (newShape * 32767.0f);
                    lfo.set_parameter(par);
                }
                break;
            }
                
            case CloudsParamLfoRate: {
                float newRate = clamp(value, 0.0f, 1.0f);
                
                if (newRate != lfoBaseRate) {
                    lfoBaseRate = newRate;
                    updateLfoRate(0.0f);
                }
                break;
            }
                
            case CloudsParamEnvAttack: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != envParameters[0]) {
                    envParameters[0] = newValue;
                    envelope.Configure(envParameters);
                }
                break;
            }
                
            case CloudsParamEnvDecay: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != envParameters[1]) {
                    envParameters[1] = newValue;
                    envelope.Configure(envParameters);
                }
                break;
            }
                
            case CloudsParamEnvSustain: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != envParameters[2]) {
                    envParameters[2] = newValue;
                    envelope.Configure(envParameters);
                }
                break;
            }
                
            case CloudsParamEnvRelease: {
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
        if (address >= CloudsParamModMatrixStart && address <= CloudsParamModMatrixEnd) {
            return modulationEngineRules.getParameter(address - CloudsParamModMatrixStart);
        }
        
        switch (address) {
            case CloudsParamPosition:
                return baseParameters.position;
                
            case CloudsParamSize:
                return baseParameters.size;
                
            case CloudsParamDensity:
                return (baseParameters.density * 2.0f) - 1.0f;
                
            case CloudsParamTexture:
                return baseParameters.texture;
                
            case CloudsParamInputGain:
                return inputGain;
                
            case CloudsParamTrigger:
                return trigger;
                
            case CloudsParamFreeze:
                return freeze;
                
            case CloudsParamFeedback:
                return baseParameters.feedback;
                
            case CloudsParamWet:
                return baseParameters.dry_wet;
                
            case CloudsParamReverb:
                return baseParameters.reverb;
                
            case CloudsParamStereo:
                return baseParameters.stereo_spread;
                
            case CloudsParamMode:
                return (float) processor.playback_mode();
                
            case CloudsParamPadX:
                return modEngine.in[ModInPadX];
                
            case CloudsParamPadY:
                return modEngine.in[ModInPadY];
                
            case CloudsParamPadGate:
                return modEngine.in[ModInPadGate];
                
            case CloudsParamPitch:
                return pitch;
                
            case CloudsParamDetune:
                return detune;
                
            case CloudsParamVolume:
                return volume;
                
            case CloudsParamLfoRate:
                return lfoBaseRate;
                
            case CloudsParamLfoShape:
                return lfoShape;
                
            case CloudsParamLfoShapeMod:
                return lfoShapeMod;
                
            case CloudsParamEnvAttack:
                return ((float) envParameters[0]) / (float) UINT16_MAX;
                
            case CloudsParamEnvDecay:
                return ((float) envParameters[1]) / (float) UINT16_MAX;
                
            case CloudsParamEnvSustain:
                return ((float) envParameters[2]) / (float) UINT16_MAX;
                
            case CloudsParamEnvRelease:
                return ((float) envParameters[3]) / (float) UINT16_MAX;
                
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
        
        lfoOutput = ((float) lfo.Process(blockSize)) / INT16_MAX;
        if (modulationEngineRules.isPatched(ModOutLFOAmount)) {
            lfoOutput *= modEngine.out[ModOutLFOAmount];
        }
        
        modEngine.in[ModInLFO] = lfoOutput;
        modEngine.in[ModInEnvelope] = envelope.value;
        modEngine.in[ModInModwheel] = midiProcessor.modwheelAmount;
        
        modEngine.run();
        
        if (modulationEngineRules.isPatched(ModOutLFORate)) {
            updateLfoRate(modEngine.out[ModOutLFORate]);
        }
        
        clouds::Parameters* p = processor.mutable_parameters();

        p->trigger = trigger + modEngine.out[ModOutTrigger] > 0.9;
        p->freeze = freeze + modEngine.out[ModOutFreeze] > 0.9;
        p->position = clamp(baseParameters.position + modEngine.out[ModOutPosition], 0.0f, 1.0f);
        p->size = clamp(baseParameters.size + modEngine.out[ModOutSize], 0.0f, 1.0f);
        p->pitch = (float) (currentNote - 48.0f) + pitch + detune + modEngine.out[ModOutTune] + (modEngine.out[ModOutFrequency] * 24.0f);
        p->density = clamp(baseParameters.density + modEngine.out[ModOutDensity], 0.0f, 1.0f);
        p->texture = clamp(baseParameters.texture + modEngine.out[ModOutTexture], 0.0f, 1.0f);
        p->feedback = clamp(baseParameters.feedback + modEngine.out[ModOutFeedback], 0.0f, 1.0f);
        p->dry_wet = clamp(baseParameters.dry_wet + modEngine.out[ModOutWet], 0.0f, 1.0f);
        p->reverb = clamp(baseParameters.reverb + modEngine.out[ModOutReverb], 0.0f, 1.0f);
        p->stereo_spread = clamp(baseParameters.stereo_spread + modEngine.out[ModOutStereo], 0.0f, 1.0f);
    }
    
    void process(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) override {
        float* outL = (float*)outBufferListPtr->mBuffers[0].mData + bufferOffset;
        float* outR = (float*)outBufferListPtr->mBuffers[1].mData + bufferOffset;
        float *inL = (float *)inBufferListPtr->mBuffers[0].mData + bufferOffset;
        float *inR = (float *)inBufferListPtr->mBuffers[1].mData + bufferOffset;
        
        int outputFramesRemaining = frameCount;
        int inputFramesRemaining = frameCount;
        
        while (outputFramesRemaining) {
            
            if (renderedFramesPos == kAudioBlockSize) {
                runModulations(kAudioBlockSize);
                
                ConverterResult result;
                inputSrc->convert(inL, inR, inputFramesRemaining, processedL + carriedInputFrames, processedR + carriedInputFrames, kAudioBlockSize - carriedInputFrames, &result);
                inL += result.inputConsumed;
                inR += result.inputConsumed;
                inputFramesRemaining -= result.inputConsumed;
                
                // convert inputBuffer into clouds Input
                clouds::ShortFrame input[kAudioBlockSize] = {};
                    
                // We might not fill all of the input buffer if there is a deficiency, but this cannot be avoided due to imprecisions between the input and output SRC.
                float gain = inputGain * 32767.0f;
                
                for (int i = 0; i < carriedInputFrames + result.outputLength; i++) {
                    input[i].l = clamp(processedL[i] * gain, -32768.0f, 32767.0f);
                    input[i].r = clamp(processedR[i] * gain, -32768.0f, 32767.0f);
                }
                
                carriedInputFrames = 0;
                
                // process
                clouds::ShortFrame output[kAudioBlockSize];
                processor.Process(input, output, kAudioBlockSize);
                
                gain = gainCoefficient / 32768.0f;
                for (int i = 0; i < kAudioBlockSize; i++) {
                    renderedL[i] = output[i].l * gain;
                    renderedR[i] = output[i].r * gain;
                }
                
                renderedFramesPos = 0;
                
                modEngine.in[ModInOut] = renderedL[kAudioBlockSize-1];
                
                if (delayed_trigger) {
                    gate = true;
                    delayed_trigger = false;
                    envelope.TriggerHigh();
                }
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
    clouds::Parameters baseParameters;
    clouds::GranularProcessor processor;
    uint8_t large_buffer[118784];
    uint8_t small_buffer[65536 - 128];
    
    Converter *inputSrc = 0;
    float processedL[kAudioBlockSize] = {};
    float processedR[kAudioBlockSize] = {};
    int carriedInputFrames = 0;
    
    Converter *outputSrc = 0;
    float renderedL[kAudioBlockSize] = {};
    float renderedR[kAudioBlockSize] = {};
    int renderedFramesPos = 0;
    
    MIDIProcessor midiProcessor;
    bool gate;
    uint8_t currentNote = 48;
    float currentVelocity;
    int state;
    bool delayed_trigger = false;
    int pitch = 0;
    float detune = 0;
    int bendRange = 0;
    float bendAmount = 0.0f;
    
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
    float inputGain;
    float volume;
    float gainCoefficient;
    float trigger;
    float freeze;
};

#endif /* CloudsDSPKernel_h */
