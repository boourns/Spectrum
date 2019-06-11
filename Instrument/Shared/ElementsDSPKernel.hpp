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

const size_t kAudioBlockSize = 16;
const size_t kPolyphony = 1;

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
    ElementsMaxParameters
};

/*
 InstrumentDSPKernel
 Performs our filter signal processing.
 As a non-ObjC class, this is safe to use from render thread.
 */
class ElementsDSPKernel : public DSPKernel, public MIDIVoice {
public:
    // MARK: Member Functions
    
    ElementsDSPKernel() : midiProcessor(1)
    {
        midiProcessor.noteStack.voices.push_back(this);
    }
    
    void init(int channelCount, double inSampleRate) {
        sampleRate = float(inSampleRate);
        outputSrc.setRates(32000, (int) inSampleRate);
        
        part = new elements::Part();
        part->Init(reverb_buffer);
        
        patch = part->mutable_patch();
        
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
        
        midiAllNotesOff();
    }
    
    void setParameter(AUParameterAddress address, AUValue value) {
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
                part->set_resonator_model((elements::ResonatorModel) clamp(value, 0.0f, 3.0f));
                break;
        }
    }
    
    AUValue getParameter(AUParameterAddress address) {
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
                if (part->easter_egg_) {
                    return 3.0f;
                } else {
                    return (float) part->resonator_model();
                }
                
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
    
    // linked list management
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
    
    void process(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) override {
        float* outL = (float*)outBufferListPtr->mBuffers[0].mData + bufferOffset;
        float* outR = (float*)outBufferListPtr->mBuffers[1].mData + bufferOffset;
        
        int framesRemaining = frameCount;
        
        while (framesRemaining) {
            if (outputBuffer.empty()) {
                
                //voice->Render(kernel->patch, modulations, &frames[0], kAudioBlockSize);
                elements::PerformanceState performance;
                performance.note = currentNote + pitch + 12.0f;
                
                performance.modulation = 0.0f; /*i & 16 ? 60.0f : -60.0f;
                                                if (i > ::kSampleRate * 5) {
                                                performance.modulation = 0;
                                                }*/
                performance.strength = currentVelocity;
                performance.gate = gate;
                
                part->Process(performance, silence, silence, mainSamples, auxSamples, kAudioBlockSize);
                
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
    float sampleRate = 32000.0;
    
    AudioBufferList* outBufferListPtr = nullptr;
    
    unsigned int activePolyphony = 1;
    
public:
    elements::Part *part;
    elements::Patch *patch;
    
    rack::SampleRateConverter<2> outputSrc;
    rack::DoubleRingBuffer<rack::Frame<2>, 256> outputBuffer;
    
    float mainSamples[kAudioBlockSize];
    float auxSamples[kAudioBlockSize];
    float silence[kAudioBlockSize];
    uint16_t reverb_buffer[32768];

    bool gate;
    uint8_t currentNote;
    float currentVelocity;
    
    MIDIProcessor midiProcessor;

    peaks::MultistageEnvelope envelope;
    peaks::Lfo lfo;
    float lfoOutput;
    
    int state;
    
    bool delayed_trigger = false;
    int pitch = 0;
    float detune = 0;
    int bendRange = 0;
    float bendAmount = 0.0f;
};

#endif /* ElementsDSPKernel_h */
