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
#import "resampler.hpp"

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
    CloudsParamPitch = 16,
    CloudsParamDetune = 17,
    CloudsParamLfoRate = 18,
    CloudsParamLfoShape = 19,
    CloudsParamLfoShapeMod = 20,
    CloudsParamEnvAttack = 22,
    CloudsParamEnvDecay = 23,
    CloudsParamEnvSustain = 24,
    CloudsParamEnvRelease = 25,
    CloudsParamModMatrixStart = 26,
    CloudsParamModMatrixEnd = 26 + (kNumModulationRules * 4), // 26 + 40 = 66
    
    CloudsMaxParameters
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
    ModOutPosition,
    ModOutSize,
    ModOutDensity,
    ModOutTexture,
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
    
    CloudsDSPKernel() : midiProcessor(1), modEngine(NumModulationInputs, NumModulationOutputs), modulationEngineRules(kNumModulationRules)
    {
        midiProcessor.noteStack.voices.push_back(this);
        
        modulationEngineRules.rules[0].input1 = ModInLFO;
        modulationEngineRules.rules[1].input1 = ModInLFO;
        modulationEngineRules.rules[2].input1 = ModInEnvelope;
        modulationEngineRules.rules[3].input1 = ModInEnvelope;
    }
    
    void init(int channelCount, double inSampleRate) {
        outputSrc.setRates(32000, (int) inSampleRate);
        inputSrc.setRates((int) inSampleRate, 32000);

        processor.Init(
                       &large_buffer[0], sizeof(large_buffer),
                       &small_buffer[0],sizeof(small_buffer));
        
        processor.set_num_channels(2);
        processor.set_low_fidelity(false);
        processor.set_quality(0);
        processor.set_playback_mode(clouds::PLAYBACK_MODE_GRANULAR);
        processor.Prepare();
        
        midiAllNotesOff();
        envelope.Init();
        lfo.Init();
        
        modEngine.rules = &modulationEngineRules;
        modEngine.in[ModInDirect] = 1.0f;
    }
    
    void setParameter(AUParameterAddress address, AUValue value) {
        if (address >= CloudsParamModMatrixStart && address <= CloudsParamModMatrixEnd) {
            modulationEngineRules.setParameter(address - CloudsParamModMatrixStart, value);
            lfoRateIsPatched = modulationEngineRules.isPatched(ModOutLFORate);
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
                baseParameters.density = clamp(value, 0.0f, 1.0f);
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
                pitch = round(clamp(value, 0.0f, 24.0f)) - 12;
                break;
            
            case CloudsParamDetune:
                detune = clamp(value, -1.0f, 1.0f);
                break;
                
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
                return baseParameters.density;
                
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
                
            case CloudsParamPitch:
                return pitch + 12;
                
            case CloudsParamDetune:
                return detune;
                
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
        modEngine.in[ModInNote] = ((float) currentNote) / 127.0f;
        modEngine.in[ModInVelocity] = currentVelocity;
        
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
        lfoOutput *= clamp(lfoBaseAmount + modEngine.out[ModOutLFOAmount], 0.0f, 1.0f);
        
        modEngine.in[ModInLFO] = lfoOutput;
        modEngine.in[ModInEnvelope] = envelope.value;
        modEngine.in[ModInModwheel] = midiProcessor.modwheelAmount;
        
        modEngine.run();
        
        if (lfoRateIsPatched) {
            updateLfoRate(modEngine.out[ModOutLFORate]);
        }
        
        clouds::Parameters* p = processor.mutable_parameters();

        p->trigger = false;
        p->freeze = false;
        p->position = clamp(baseParameters.position + modEngine.out[ModOutPosition], 0.0f, 1.0f);
        p->size = clamp(baseParameters.size + modEngine.out[ModOutSize], 0.0f, 1.0f);
        p->pitch = (float) currentNote + pitch + detune + modEngine.out[ModOutTune] + (modEngine.out[ModOutFrequency] * 24.0f);
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
            if (outputBuffer.empty()) {
                runModulations(kAudioBlockSize);
                
                rack::Frame<2> inputFrame = {};
                while (!inputBuffer.full() && inputFramesRemaining > 0) {
                    inputFrame.samples[0] = *inL++;
                    inputFrame.samples[1] = *inR++;
                    inputBuffer.push(inputFrame);
                    inputFramesRemaining--;
                }
                
                // convert inputBuffer into clouds Input
                clouds::ShortFrame input[kAudioBlockSize] = {};
                // Convert input buffer
                {
                    rack::Frame<2> inputFrames[kAudioBlockSize];
                    int inLen = (int) inputBuffer.size();
                    int outLen = kAudioBlockSize;
                    
                    inputSrc.process(inputBuffer.startData(), &inLen, inputFrames, &outLen);
                    inputBuffer.startIncr(inLen);
                    
                    // We might not fill all of the input buffer if there is a deficiency, but this cannot be avoided due to imprecisions between the input and output SRC.
                    for (int i = 0; i < outLen; i++) {
                        input[i].l = clamp(inputFrames[i].samples[0] * 32767.0f, -32768.0f, 32767.0f);
                        input[i].r = clamp(inputFrames[i].samples[1] * 32767.0f, -32768.0f, 32767.0f);
                    }
                    
                }
                
                // process
                clouds::ShortFrame output[kAudioBlockSize];
                processor.Process(input, output, kAudioBlockSize);
                
                rack::Frame<2> outputFrames[kAudioBlockSize];
                for (int i = 0; i < kAudioBlockSize; i++) {
                    outputFrames[i].samples[0] = output[i].l / 32768.0;
                    outputFrames[i].samples[1] = output[i].r / 32768.0;
                }
                
                int inLen = kAudioBlockSize;
                int outLen = (int) outputBuffer.capacity();
                outputSrc.process(outputFrames, &inLen, outputBuffer.endData(), &outLen);
                outputBuffer.endIncr(outLen);
                
                if (delayed_trigger) {
                    gate = true;
                    delayed_trigger = false;
                }
                
                //modEngine.in[ModInOut] = mainSamples[kAudioBlockSize-1];
            }
            
            rack::Frame<2> outputFrame = outputBuffer.shift();
            
            *outL++ = outputFrame.samples[0];
            *outR++ = outputFrame.samples[1];
            
            outputFramesRemaining--;
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
    
    rack::SampleRateConverter<2> inputSrc;
    rack::DoubleRingBuffer<rack::Frame<2>, 256> inputBuffer;
    rack::SampleRateConverter<2> outputSrc;
    rack::DoubleRingBuffer<rack::Frame<2>, 256> outputBuffer;
    
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
    float inputGain;
    float trigger;
    float freeze;
};

#endif /* CloudsDSPKernel_h */
