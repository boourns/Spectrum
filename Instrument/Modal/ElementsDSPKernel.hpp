//
//  ElementsDSPKernel.hpp
//  Spectrum
//
//  Created by tom on 2019-05-28.
//

#ifndef ElementsDSPKernel_h
#define ElementsDSPKernel_h

#ifdef DEBUG
#define KERNEL_DEBUG_LOG(...) printf(__VA_ARGS__);
#else
#define KERNEL_DEBUG_LOG(...)
#endif

#import <BurnsAudioUnit/multistage_envelope.h>
#import <BurnsAudioUnit/DSPKernel.hpp>
#import "stmlib/dsp/parameter_interpolator.h"

#import <vector>
#import "elements/dsp/part.h"
#import <BurnsAudioUnit/LFOKernel.hpp>
#import <BurnsAudioUnit/converter.hpp>

#import <BurnsAudioUnit/MIDIProcessor.hpp>
#import <BurnsAudioUnit/ModulationEngine.hpp>

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
    ElementsParamLfoTempoSync = 28,
    ElementsParamLfoResetPhase = 29,
    ElementsParamLfoKeyReset = 30,
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
    ModInAftertouch,
    ModInSustain,
    ModInOut,
    ModInSlide,
    ModInLift,
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
    
    ElementsDSPKernel() : midiProcessor(1), modEngine(NumModulationInputs, NumModulationOutputs), modulationEngineRules(kNumModulationRules, NumModulationInputs, NumModulationOutputs),
        lfo(ElementsParamLfoRate, ElementsParamLfoShape, ElementsParamLfoShapeMod, ElementsParamLfoTempoSync, ElementsParamLfoResetPhase, ElementsParamLfoKeyReset)

    {
        midiProcessor.noteStack.addVoice(this);
        
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
    
    ~ElementsDSPKernel() {
        KERNEL_DEBUG_LOG("kernel voice delete\n")
        
        if (inputSrc) {
            delete inputSrc;
        }
        if (outputSrc) {
            delete outputSrc;
        }
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
        lfo.Init(32000);
        
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
        
        if (lfo.ownParameter(address)) {
            lfo.setParameter(address, value);
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
        
        if (lfo.ownParameter(address)) {
            return lfo.getParameter(address);
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
    
    bool getParameterValueString(AUParameterAddress address, AUValue value, char *dst) {
        if (lfo.ownParameter(address)) {
            return lfo.getParameterValueString(address, value, dst);
        }
        
        return false;
    }
    
    void startRamp(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) override {
        // The attack and release parameters are not ramped.
        setParameter(address, value);
    }
    
    void setBuffers(AudioBufferList* inBufferList, AudioBufferList* outBufferList) {
        inBufferListPtr = inBufferList;
        outBufferListPtr = outBufferList;
    }
    
    void setTransportState(KernelTransportState state) {
        transportState = state;
        lfo.setTransportState(&transportState);
    }
    
    // =========== MIDI
    
    virtual void midiNoteOff(uint8_t vel) override {
        state = NoteStateReleasing;
        gate = false;
        modEngine.in[ModInLift] = ((float) vel )/ 127.0f;
        envelope.TriggerLow();
        delayed_trigger = false;
    }
    
    void add() {
        if (state == NoteStateUnused) {
            gate = true;
            envelope.TriggerHigh();
            lfo.trigger();
        } else {
            delayed_trigger = true;
        }
        state = NoteStatePlaying;
    }
    
    virtual void retrigger() override {
        envelope.TriggerHigh();
        lfo.trigger();
    }
    
    virtual void midiNoteOn(uint8_t note, uint8_t vel) override {
        currentNote = note;
        currentVelocity = ((float) vel) / 127.0;
        modEngine.in[ModInNote] = ((float) currentNote) / 127.0f;
        modEngine.in[ModInVelocity] = currentVelocity;
        modEngine.in[ModInLift] = 0.0f;

        add();
    }
    
    virtual void midiAllNotesOff() override {
        state = NoteStateUnused;
        printf("note state unused");
        delayed_trigger = false;
        gate = false;
        bendAmount = 0.0f;
        modEngine.in[ModInModwheel] = 0.0f;
        modEngine.in[ModInAftertouch] = 0.0f;
        modEngine.in[ModInSustain] = 0.0f;
        
    }
    
    virtual void midiControlMessage(MIDIControlMessage msg, int16_t val) override {
        switch(msg) {
            case MIDIControlMessage::Pitchbend:
                bendAmount = (clamp((float) val, -8192.0f, 8192.0f) / 8192.0f) * bendRange;
                break;
            case MIDIControlMessage::Modwheel:
                modEngine.in[ModInModwheel] = clamp((float) val, 0.0f, 16384.0f) / 16384.0f;
                break;
            case MIDIControlMessage::Aftertouch:
                aftertouchTarget = clamp((float) val, 0.0f, 127.0f) / 127.0f;
                break;
            case MIDIControlMessage::Sustain:
                modEngine.in[ModInSustain] = clamp((float) val, 0.0f, 127.0f) / 127.0f;
                break;
            case MIDIControlMessage::Slide:
                modEngine.in[ModInSlide] = clamp((float) val, 0.0f, 127.0f) / 127.0f;
                break;
        }
    }
    
    virtual int State() override {
        return state;
    }
    
    virtual void handleMIDIEvent(AUMIDIEvent const& midiEvent) override {
        midiProcessor.handleMIDIEvent(midiEvent);
    }
    
    void runModulations(int blockSize) {
        envelope.Process(blockSize);
        
        float lfoAmount = 1.0;
        if (modulationEngineRules.isPatched(ModOutLFOAmount)) {
            lfoAmount = modEngine.out[ModOutLFOAmount];
        }
        
        float lfoOutput = lfoAmount * lfo.process(blockSize);

        modEngine.in[ModInLFO] = lfoOutput;
        modEngine.in[ModInEnvelope] = envelope.value;
        ONE_POLE(modEngine.in[ModInAftertouch], aftertouchTarget, 0.1f);

        modEngine.run();
        
        if (modulationEngineRules.isPatched(ModOutLFORate)) {
            lfo.updateRate(modEngine.out[ModOutLFORate]);
            lfoRatePatched = true;
        } else if (lfoRatePatched) {
            lfoRatePatched = false;
            lfo.updateRate(0.0f);
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
        float *inL = 0;
        float *inR = 0;
        
        if (useAudioInput) {
            inL = (float *)inBufferListPtr->mBuffers[0].mData + bufferOffset;
            inR = (float *)inBufferListPtr->mBuffers[1].mData + bufferOffset;
        }
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
                performance.note = currentNote + pitch + detune + bendAmount + 12.0f + modEngine.out[ModOutTune] + (modEngine.out[ModOutFrequency] * 48.0f);
                
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
                    lfo.trigger();
                }
                
                if (modulationEngineRules.isPatched(ModOutLevel)) {
                    finalVolume *= modEngine.out[ModOutLevel];
                }
                
                stmlib::ParameterInterpolator outputGain(&previousGain, finalVolume, kAudioBlockSize);
                for (int i = 0; i < kAudioBlockSize; i++) {
                    const float amount = outputGain.Next();

                    renderedL[i] *= amount;
                    renderedR[i] *= amount;
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
        
        if (useAudioInput && inputFramesRemaining > 0) {
            ConverterResult result;
            inputSrc->convert(inL, inR, inputFramesRemaining, processedL, processedR, kAudioBlockSize, &result);
            carriedInputFrames = result.outputLength;
        }
    }
    
    void drawLFO(float *points, int count) {
        lfo.draw(points, count);
    }
    
    bool lfoDrawingDirty() {
        return lfo.drawingDirty;
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
    
    KernelTransportState transportState;
    
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
    uint8_t currentNote = 48;
    float currentVelocity;
    int state;
    bool delayed_trigger = false;
    int pitch = 0;
    float detune = 0;
    int bendRange = 12;
    float bendAmount = 0.0f;
    bool useAudioInput = false;
    bool lfoRatePatched = false;
    float aftertouchTarget = 0.0f;

    ModulationEngine modEngine;
    ModulationEngineRuleList modulationEngineRules;

    uint16_t envParameters[4];
    peaks::MultistageEnvelope envelope;
    LFOKernel lfo;
   
    float volume;
    float inputGain;
    bool inputResonator;
    float previousGain = 0.0f;
};

#endif /* ElementsDSPKernel_h */
