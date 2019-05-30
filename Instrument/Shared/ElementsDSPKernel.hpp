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
    ElementsMaxParameters
};

enum {
    NoteStateUnused = 0,
    NoteStatePlaying = 1,
    NoteStateReleasing = 2
};

/*
 InstrumentDSPKernel
 Performs our filter signal processing.
 As a non-ObjC class, this is safe to use from render thread.
 */
class ElementsDSPKernel : public DSPKernel {
public:
    // MARK: Member Functions
    
    ElementsDSPKernel()
    {
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
        
        reset();
    }

    // linked list management
    void release() {
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

    void noteOn(int noteNumber, int velocity)
    {
        if (velocity == 0) {
            if (state == NoteStatePlaying) {
                release();
            }
        } else {
            note = noteNumber;
            add();
        }
    }
    
    void reset() {
        state = NoteStateUnused;
        gate = false;
        elementsFramesIndex = kAudioBlockSize;
    }
    
    void setParameter(AUParameterAddress address, AUValue value) {
        switch (address) {
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
                patch->space = clamp(value, 0.0f, 1.0f);
                break;
        }
    }
    
    AUValue getParameter(AUParameterAddress address) {
        switch (address) {
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
    
    virtual void handleMIDIEvent(AUMIDIEvent const& midiEvent) override {
        if (midiEvent.length != 3) return;
        uint8_t status = midiEvent.data[0] & 0xF0;
        //uint8_t channel = midiEvent.data[0] & 0x0F; // works in omni mode.
        switch (status) {
            case 0x80 : { // note off
                uint8_t note = midiEvent.data[1];
                if (note > 127) break;
                
                if (note == currentNote) {
                    release();
                }
                
                break;
            }
            case 0x90 : { // note on
                uint8_t note = midiEvent.data[1];
                uint8_t veloc = midiEvent.data[2];
                if (note > 127 || veloc > 127) break;
                
                noteOn(note, veloc);
                
                break;
            }
            case 0xE0 : { // pitch bend
                uint8_t coarse = midiEvent.data[2];
                uint8_t fine = midiEvent.data[1];
                int16_t midiPitchBend = (coarse << 7) + fine;
                bendAmount = (((float) (midiPitchBend - 8192)) / 8192.0f) * bendRange;
            }
                
            case 0xB0 : { // control
                uint8_t num = midiEvent.data[1];
                if (num == 123) { // all notes off
                    reset();
                }
                break;
            }
        }
    }
    
    void process(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) override {
        float* outL = (float*)outBufferListPtr->mBuffers[0].mData + bufferOffset;
        float* outR = (float*)outBufferListPtr->mBuffers[1].mData + bufferOffset;
        
        int framesRemaining = frameCount;
        
        while (framesRemaining) {
            if (elementsFramesIndex >= kAudioBlockSize) {
                
                //voice->Render(kernel->patch, modulations, &frames[0], kAudioBlockSize);
                elements::PerformanceState performance;
                performance.note = note;
                performance.modulation = 0.0f; /*i & 16 ? 60.0f : -60.0f;
                                                if (i > ::kSampleRate * 5) {
                                                performance.modulation = 0;
                                                }*/
                performance.strength = 0.5f;
                performance.gate = gate;
                
                part->Process(performance, silence, silence, mainSamples, auxSamples, kAudioBlockSize);
                
                elementsFramesIndex = 0;
                
                if (delayed_trigger) {
                    gate = true;
                    delayed_trigger = false;
                }
            }
            
            *outL++ += mainSamples[elementsFramesIndex];
            *outR++ += auxSamples[elementsFramesIndex];
            
            elementsFramesIndex++;
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
    uint8_t note;
    size_t elementsFramesIndex;
    bool gate;
    int currentNote;
    int state;
    
    bool delayed_trigger = false;
    int pitch = 0;
    float detune = 0;
    int bendRange = 0;
    float bendAmount = 0.0f;
};

#endif /* ElementsDSPKernel_h */
