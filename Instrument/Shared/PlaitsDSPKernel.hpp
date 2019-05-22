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
        
        void Init() {
            voice = new plaits::Voice();
            stmlib::BufferAllocator allocator(ram_block, 16384);
            voice->Init(&allocator);
            plaitsFramesIndex = kAudioBlockSize;
        }
        
        void clear() {
            modulations.trigger = 0.0f;
            state = NoteStateUnused;
            NSLog(@"Clear");
        }
        
        // linked list management
        void release() {
            modulations.trigger = 0.0f;
            state = NoteStateReleasing;
            NSLog(@"Release");
        }
        
        void add() {
            modulations.trigger = 1.0f;
            state = NoteStatePlaying;
            NSLog(@"Add");
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
                
                NSLog(@"Here");
                patch.note = float(noteNumber);
                note = noteNumber;
                add();
            }
        }
        
        void run(int n, float* outL, float* outR)
        {
            int framesRemaining = n;
            while (framesRemaining) {
                if (plaitsFramesIndex >= kAudioBlockSize) {
                    voice->Render(patch, modulations, &frames[0], kAudioBlockSize);
                    plaitsFramesIndex = 0;
                }
                
                *outL++ += ((float) frames[plaitsFramesIndex].out) / ((float) INT16_MAX);
                *outR++ += ((float) frames[plaitsFramesIndex].aux) / ((float) INT16_MAX);
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
                patch.engine = round(clamp(value, 0.0f, 16.0f));
            NSLog(@"Engine %d value %f", patch.engine, value);
                break;
                
            case PlaitsParamDecay:
                patch.decay = clamp(value, 0.0f, 1.0f);
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
        for (int i = 0; i < kPolyphony; i++) {
            if (voices[i].note == note) {
                return &voices[i];
            }
        }
        return nullptr;
    }
    
    VoiceState *freeVoice() {
        for (int i = 0; i < kPolyphony; i++) {
            if (voices[i].state == NoteStateUnused) {
                return &voices[i];
            }
        }
        for (int i = 0; i < kPolyphony; i++) {
            if (voices[i].state == NoteStateReleasing) {
                return &voices[i];
            }
        }
        VoiceState *stolen = &voices[stolenVoice];
        stolenVoice = (stolenVoice + 1) % kPolyphony;
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
                VoiceState *voice = voiceForNote(note);
                if (voice) {
                    voice->release();
                }
                
                modulations.trigger = 0.0f;
                break;
            }
            case 0x90 : { // note on
                uint8_t note = midiEvent.data[1];
                uint8_t veloc = midiEvent.data[2];
                if (note > 127 || veloc > 127) break;
                VoiceState *voice = voiceForNote(note);
                if (voice) {
                    voice->noteOn(note, veloc);
                } else {
                    voice = freeVoice();
                    if (voice) {
                        voice->noteOn(note, veloc);
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
        for (int i = 0; i < kPolyphony; i++) {
            if (voices[i].state != NoteStateUnused) {
                playingNotes++;
                voices[i].run(frameCount, outL, outR);
            }
        }
        
        if (playingNotes > 0) {
            for (int i = 0; i < frameCount; i++) {
                outL[i] *= 0.1f;
                outR[i] *= 0.1f;
            }
        }
    }
    
    // MARK: Member Variables
    
private:
    std::vector<VoiceState> voices;
    
    float sampleRate = 44100.0;
    
    AudioBufferList* outBufferListPtr = nullptr;
    
public:
    plaits::Modulations modulations;
    plaits::Patch patch;
    int stolenVoice = 0;
};

#endif /* PlaitsDSPKernel_h */
