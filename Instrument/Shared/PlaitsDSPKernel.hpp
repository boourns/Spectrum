//
//  PlaitsDSPKernel.hpp
//  Instrument
//
//  Created by tom on 2019-05-17.
//

#ifndef PlaitsDSPKernel_h
#define PlaitsDSPKernel_h

#import "DSPKernel.hpp"
#import <vector>
#import "plaits/dsp/voice.h"

const double kTwoPi = 2.0 * M_PI;
const size_t kAudioBlockSize = 24;
const size_t kPolyphony = 8;

enum {
    PlaitsParamTimbre = 0,
    PlaitsParamHarmonics = 1,
    PlaitsParamMorph = 2,
    PlaitsParamDecay = 3,
    PlaitsParamAlgorithm = 4,
    PlaitsParamPitch = 5,
    PlaitsParamDetune = 6,
    PlaitsParamLPGColour = 7,
    PlaitsParamUnison = 8,
    PlaitsParamPolyphony = 9,
    PlaitsParamVolume = 10,
    PlaitsParamSlop = 11,
    PlaitsParamLeftSource = 12,
    PlaitsParamRightSource = 13,
    PlaitsParamPan = 14,
    PlaitsParamPanSpread = 15,
    PlaitsMaxParameters
};

enum {
    NoteStateUnused = 0,
    NoteStatePlaying = 1,
    NoteStateReleasing = 2
};

static inline double pow2(double x) {
    return x * x;
}

static inline double pow3(double x) {
    return x * x * x;
}

static inline double noteToHz(int noteNumber)
{
    return 440. * exp2((noteNumber - 69)/12.);
}

static inline double panValue(double x)
{
    x = clamp(x, -1., 1.);
    return cos(M_PI_2 * (.5 * x + .5));
}

/*
 InstrumentDSPKernel
 Performs our filter signal processing.
 As a non-ObjC class, this is safe to use from render thread.
 */
class PlaitsDSPKernel : public DSPKernel {
public:
    // MARK: Types
    struct VoiceState {
        unsigned int state;
        PlaitsDSPKernel *kernel;
        
        char ram_block[16 * 1024];
        uint8_t note;
        plaits::Voice::Frame frames[kAudioBlockSize];
        size_t plaitsFramesIndex;
        
        plaits::Voice *voice;
        plaits::Modulations modulations;
        plaits::Patch patch;
        float panSpread = 0;
        
        void Init() {
            voice = new plaits::Voice();
            stmlib::BufferAllocator allocator(ram_block, 16384);
            voice->Init(&allocator);
            plaitsFramesIndex = kAudioBlockSize;
        }
        
        void clear() {
            modulations.trigger = 0.0f;
            state = NoteStateUnused;
        }
        
        // linked list management
        void release() {
            modulations.trigger = 0.0f;
            state = NoteStateReleasing;
        }
        
        void add() {
            modulations.trigger = 1.0f;
            state = NoteStatePlaying;
        }
        
        void noteOn(int noteNumber, int velocity)
        {
            if (velocity == 0) {
                if (state == NoteStatePlaying) {
                    release();
                }
            } else {
                memcpy(&patch, &kernel->patch, sizeof(plaits::Patch));
                memcpy(&modulations, &kernel->modulations, sizeof(plaits::Modulations));
                
                patch.note = float(noteNumber) + kernel->randomSignedFloat(kernel->slop);
                // TODO When stealing don't take new pan spread value
                panSpread = kernel->nextPanSpread();

                note = noteNumber;
                add();
            }
        }
        
        void run(int n, float* outL, float* outR)
        {
            int framesRemaining = n;
            float leftSource = kernel->leftSource;
            float rightSource = kernel->rightSource;
            
            float out, aux, rightGain, leftGain;
            
            float pan = clamp(kernel->pan + panSpread, -1.0f, 1.0f);
            if (pan > 0) {
                rightGain = 1.0f;
                leftGain = 1.0f - pan;
            } else {
                leftGain = 1.0f;
                rightGain = 1.0f + pan;
            }
            
            while (framesRemaining) {
                if (plaitsFramesIndex >= kAudioBlockSize) {
                    voice->Render(patch, modulations, &frames[0], kAudioBlockSize);
                    plaitsFramesIndex = 0;
                }
                
                out = ((float) frames[plaitsFramesIndex].out) / ((float) INT16_MAX);
                aux = ((float) frames[plaitsFramesIndex].aux) / ((float) INT16_MAX);
                
                *outL++ += ((out * (1.0f - leftSource)) + (aux * (leftSource))) * leftGain;
                *outR++ += ((out * (1.0f - rightSource)) + (aux * (rightSource))) * rightGain;
                
                plaitsFramesIndex++;
                framesRemaining--;
            }
        }
    };
    
    
    // MARK: Member Functions
    
    PlaitsDSPKernel()
    {
        voices.resize(kPolyphony);
        for (VoiceState& voice : voices) {
            voice.kernel = this;
            voice.Init();
        }
    }
    
    void init(int channelCount, double inSampleRate) {
        sampleRate = float(inSampleRate);
        
        patch.engine = 8;
        patch.note = 48.0f;
        patch.harmonics = 0.3f;
        patch.timbre = 0.7f;
        patch.morph = 0.7f;
        patch.frequency_modulation_amount = 0.0f;
        patch.timbre_modulation_amount = 0.0f;
        patch.morph_modulation_amount = 0.0f;
        patch.decay = 0.1f;
        patch.lpg_colour = 0.0f;
        
        modulations.note = 0.0f;
        modulations.engine = 0.0f;
        modulations.frequency = 0.0f;
        modulations.harmonics = 0.0f;
        modulations.morph = 0.0;
        modulations.level = 0.0f;
        modulations.trigger = 0.0f;
        modulations.frequency_patched = false;
        modulations.timbre_patched = false;
        modulations.morph_patched = false;
        modulations.trigger_patched = true;
        modulations.level_patched = false;
    }
    
    void reset() {
        for (VoiceState& state : voices) {
            state.clear();
        }
    }
    
    void setParameter(AUParameterAddress address, AUValue value) {
        switch (address) {
            case PlaitsParamTimbre:
                patch.timbre = clamp(value, 0.0f, 1.0f);
                break;
                
            case PlaitsParamHarmonics:
                patch.harmonics = clamp(value, 0.0f, 1.0f);
                break;
                
            case PlaitsParamMorph:
                patch.morph = clamp(value, 0.0f, 1.0f);
                break;
                
            case PlaitsParamAlgorithm:
                patch.engine = round(clamp(value, 0.0f, 15.0f));
                break;
                
            case PlaitsParamDecay:
                patch.decay = clamp(value, 0.0f, 1.0f);
                break;
                
            case PlaitsParamLPGColour:
                patch.lpg_colour = clamp(value, 0.0f, 1.0f);
                break;
                
            case PlaitsParamPolyphony: {
                int newPolyphony = 1 + round(clamp(value, 0.0f, 7.0f));
                if (newPolyphony != activePolyphony) {
                    gainCoefficient = 1.0f / (float) activePolyphony;
                    reset();
                    activePolyphony = newPolyphony;
                }
                break;
            }
                
            case PlaitsParamUnison: {
                int newUnison = round(clamp(value, 0.0f, 1.0f)) == 1;
                if (newUnison != unison) {
                    reset();
                    unison = newUnison;
                }
                
                break;
            }
                
            case PlaitsParamVolume:
                volume = clamp(value, 0.0f, 2.0f);
                break;
                
            case PlaitsParamSlop:
                slop = clamp(value, 0.0f, 1.0f);
                break;
                
            case PlaitsParamLeftSource:
                leftSource = clamp(value, 0.0f, 1.0f);
                break;
            
            case PlaitsParamRightSource:
                rightSource = clamp(value, 0.0f, 1.0f);
                break;
                
            case PlaitsParamPan:
                pan = clamp(value, -1.0f, 1.0f);
                break;
                
            case PlaitsParamPanSpread:
                panSpread = clamp(value, 0.0f, 1.0f);
                break;
        }
    }
    
    AUValue getParameter(AUParameterAddress address) {
        switch (address) {
            case PlaitsParamTimbre:
                return patch.timbre;
                
            case PlaitsParamHarmonics:
                return patch.harmonics;
                
            case PlaitsParamMorph:
                return patch.morph;
                
            case PlaitsParamAlgorithm:
                return (float) patch.engine;
                
            case PlaitsParamDecay:
                return patch.decay;
                
            case PlaitsParamLPGColour:
                return patch.lpg_colour;
                
            case PlaitsParamUnison:
                return unison ? 1.0f : 0.0f;
                
            case PlaitsParamPolyphony:
                return (float) activePolyphony - 1;
                
            case PlaitsParamVolume:
                return volume;
                
            case PlaitsParamSlop:
                return slop;
                
            case PlaitsParamLeftSource:
                return leftSource;
                
            case PlaitsParamRightSource:
                return rightSource;
                
            case PlaitsParamPan:
                return pan;
                
            case PlaitsParamPanSpread:
                return panSpread;
                
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
    
    VoiceState *voiceForNote(uint8_t note) {
        for (int i = 0; i < activePolyphony; i++) {
            if (voices[i].note == note) {
                return &voices[i];
            }
        }
        return nullptr;
    }
    
    VoiceState *freeVoice() {
        for (int i = 0; i < activePolyphony; i++) {
            if (voices[i].state == NoteStateUnused) {
                return &voices[i];
            }
        }
        for (int i = 0; i < activePolyphony; i++) {
            if (voices[i].state == NoteStateReleasing) {
                return &voices[i];
            }
        }
        VoiceState *stolen = &voices[stolenVoice];
        stolenVoice = (stolenVoice + 1) % activePolyphony;
        return stolen;
    }
    
    virtual void handleMIDIEvent(AUMIDIEvent const& midiEvent) override {
        if (midiEvent.length != 3) return;
        uint8_t status = midiEvent.data[0] & 0xF0;
        //uint8_t channel = midiEvent.data[0] & 0x0F; // works in omni mode.
        switch (status) {
            case 0x80 : { // note off
                uint8_t note = midiEvent.data[1];
                if (note > 127) break;
                
                if (unison) {
                    for (int i = 0; i < activePolyphony; i++) {
                        voices[i].release();
                    }
                } else {
                    VoiceState *voice = voiceForNote(note);
                    if (voice) {
                        voice->release();
                    }
                }
                    
                break;
            }
            case 0x90 : { // note on
                uint8_t note = midiEvent.data[1];
                uint8_t veloc = midiEvent.data[2];
                if (note > 127 || veloc > 127) break;
                if (unison) {
                    for (int i = 0; i < activePolyphony; i++) {
                        voices[i].noteOn(note, veloc);
                    }
                } else {
                    VoiceState *voice = voiceForNote(note);
                    if (voice) {
                        voice->noteOn(note, veloc);
                    } else {
                        voice = freeVoice();
                        if (voice) {
                            voice->noteOn(note, veloc);
                        }
                    }
                }
                break;
            }
            case 0xB0 : { // control
                uint8_t num = midiEvent.data[1];
                if (num == 123) { // all notes off
                    for (int i = 0; i < kPolyphony; i++) {
                        voices[i].clear();
                    }
                }
                break;
            }
        }
    }
    
    void process(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) override {
        float* outL = (float*)outBufferListPtr->mBuffers[0].mData + bufferOffset;
        float* outR = (float*)outBufferListPtr->mBuffers[1].mData + bufferOffset;
        
        int playingNotes = 0;
        for (int i = 0; i < activePolyphony; i++) {
            if (voices[i].state != NoteStateUnused) {
                playingNotes++;
                voices[i].run(frameCount, outL, outR);
            }
        }
        
        if (playingNotes > 0) {
            for (int i = 0; i < frameCount; i++) {
                outL[i] *= gainCoefficient * volume;
                outR[i] *= gainCoefficient * volume;
            }
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
    
    float nextPanSpread() {
        float result = panSpread;
        if (!lastPanSpreadWasNegative) {
            result *= -1;
        }
        lastPanSpreadWasNegative = !lastPanSpreadWasNegative;
        return result;
    }
    
    // MARK: Member Variables
    
private:
    std::vector<VoiceState> voices;
    
    float sampleRate = 44100.0;
    
    AudioBufferList* outBufferListPtr = nullptr;
    
    unsigned int activePolyphony = 8;
    
public:
    plaits::Modulations modulations;
    plaits::Patch patch;
    int stolenVoice = 0;
    bool lastPanSpreadWasNegative = 0;
    float slop = 0.0f;
    bool unison = false;
    float volume = 1.0f;
    float gainCoefficient = 0.1f;
    float leftSource = 0.0f;
    float rightSource = 1.0f;
    float pan = 0.0f;
    float panSpread = 0.0f;
};

#endif /* PlaitsDSPKernel_h */
