//
//  PlaitsDSPKernel.hpp
//  Instrument
//
//  Created by tom on 2019-05-17.
//

#ifndef PlaitsDSPKernel_h
#define PlaitsDSPKernel_h

#import "multistage_envelope.h"
#import "DSPKernel.hpp"
#import <vector>
#import "plaits/dsp/voice.h"
#import "lfo.hpp"

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
    PlaitsParamLfoShape = 16,
    PlaitsParamLfoRate = 17,
    PlaitsParamLfoAmountFM = 18,
    PlaitsParamLfoAmountHarmonics = 19,
    PlaitsParamLfoAmountTimbre = 20,
    PlaitsParamLfoAmountMorph = 21,
    PlaitsParamPitchBendRange = 22,
    PlaitsParamAmpSource = 23,
    PlaitsParamEnvAttack = 24,
    PlaitsParamEnvDecay = 25,
    PlaitsParamEnvSustain = 26,
    PlaitsParamEnvRelease = 27,
    PlaitsParamAmpEnvAttack = 28,
    PlaitsParamAmpEnvDecay = 29,
    PlaitsParamAmpEnvSustain = 30,
    PlaitsParamAmpEnvRelease = 31,
    PlaitsParamEnvAmountFM = 32,
    PlaitsParamEnvAmountHarmonics = 33,
    PlaitsParamEnvAmountTimbre = 34,
    PlaitsParamEnvAmountMorph = 35,
    PlaitsParamEnvAmountLFORate = 36,
    PlaitsParamEnvAmountLFOAmount = 37,
    PlaitsParamLfoAmount = 38,
    PlaitsMaxParameters
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
        
        peaks::MultistageEnvelope envelope;
        peaks::MultistageEnvelope ampEnvelope;
        peaks::Lfo lfo;
        float lfoOutput;

        plaits::Voice *voice;
        plaits::Modulations modulations;
        float panSpread = 0;
        
        bool delayed_trigger = false;
        
        void Init() {
            voice = new plaits::Voice();
            stmlib::BufferAllocator allocator(ram_block, 16384);
            voice->Init(&allocator);
            plaitsFramesIndex = kAudioBlockSize;
            envelope.Init();
            ampEnvelope.Init();
            lfo.Init();
        }
        
        void clear() {
            modulations.trigger = 0.0f;
            envelope.value = 0;
            ampEnvelope.value = 0;
            envelope.TriggerLow();
            state = NoteStateUnused;
            plaitsFramesIndex = kAudioBlockSize;
        }
        
        // linked list management
        void release() {
            modulations.trigger = 0.0f;
            envelope.TriggerLow();

            state = NoteStateReleasing;
        }
        
        void add() {
            if (state == NoteStateUnused) {
                modulations.trigger = 1.0f;
                envelope.TriggerHigh();
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
                memcpy(&modulations, &kernel->modulations, sizeof(plaits::Modulations));
                
                modulations.note = float(noteNumber) + kernel->randomSignedFloat(kernel->slop) - 48.0f;
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
                    envelope.Process(kAudioBlockSize);

                    // TODO add poly mod
                    lfoOutput = ((float) lfo.Process(kAudioBlockSize)) / INT16_MAX;
                    float lfoAmount = kernel->lfoAmount + (envelope.value * kernel->envAmountLfoAmount);
                    
                    modulations.frequency = kernel->modulations.frequency + (lfoOutput * kernel->lfoAmountFM * lfoAmount) + (envelope.value * kernel->envAmountFM);
                    modulations.harmonics = kernel->modulations.harmonics + lfoOutput * kernel->lfoAmountHarmonics * lfoAmount + (envelope.value * kernel->envAmountHarmonics);
                    modulations.timbre = kernel->modulations.timbre + lfoOutput * kernel->lfoAmountTimbre * lfoAmount + (envelope.value * kernel->envAmountTimbre);
                    modulations.morph = kernel->modulations.morph + lfoOutput * kernel->lfoAmountMorph * lfoAmount + (envelope.value * kernel->envAmountMorph);
                
                    voice->Render(kernel->patch, modulations, &frames[0], kAudioBlockSize);
                    plaitsFramesIndex = 0;
                    
                    if (delayed_trigger) {
                        delayed_trigger = false;
                        modulations.trigger = 1.0f;
                        envelope.TriggerHigh();
                    }
                }
                
                out = ((float) frames[plaitsFramesIndex].out) / ((float) INT16_MAX);
                aux = ((float) frames[plaitsFramesIndex].aux) / ((float) INT16_MAX);
                
                if (kernel->ampSource == 1) {
                    *outL++ += ((out * (1.0f - leftSource)) + (aux * (leftSource))) * leftGain * ampEnvelope.value;
                    *outR++ += ((out * (1.0f - rightSource)) + (aux * (rightSource))) * rightGain * ampEnvelope.value;
                } else {
                    *outL++ += ((out * (1.0f - leftSource)) + (aux * (leftSource))) * leftGain;
                    *outR++ += ((out * (1.0f - rightSource)) + (aux * (rightSource))) * rightGain;
                }
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
        lfoParameters[2] = lfoParameters[3] = 32768;
        envParameters[2] = UINT16_MAX;
    }
    
    void init(int channelCount, double inSampleRate) {
        sampleRate = float(inSampleRate);
        
        patch.engine = 8;
        patch.note = 48.0f;
        patch.harmonics = 0.3f;
        patch.timbre = 0.7f;
        patch.morph = 0.7f;
        patch.frequency_modulation_amount = 1.0f;
        patch.timbre_modulation_amount = 1.0f;
        patch.morph_modulation_amount = 1.0f;
        patch.decay = 0.1f;
        patch.lpg_colour = 0.0f;
        
        modulations.note = 0.0f;
        modulations.engine = 0.0f;
        modulations.frequency = 0.0f;
        modulations.harmonics = 0.0f;
        modulations.morph = 0.0;
        modulations.level = 0.0f;
        modulations.trigger = 0.0f;
        modulations.frequency_patched = true;
        modulations.timbre_patched = true;
        modulations.morph_patched = true;
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
                
            case PlaitsParamPitch:
                pitch = round(clamp(value, 0.0f, 24.0f)) - 12;
                patch.note = 48.0f + pitch + detune;
                break;
                
            case PlaitsParamDetune:
                detune = clamp(value, -1.0f, 1.0f);
                patch.note = 48.0f + pitch + detune;
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
                
            case PlaitsParamLfoShape: {
                uint16_t newShape = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newShape != lfoParameters[1]) {
                    lfoParameters[1] = newShape;
                    for (int i = 0; i < kPolyphony; i++) {
                        voices[i].lfo.Configure(lfoParameters);
                    }
                }
                break;
            }
                
            case PlaitsParamLfoRate: {
                
                uint16_t newRate = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newRate != lfoParameters[0]) {
                    lfoParameters[0] = newRate;
                    for (int i = 0; i < kPolyphony; i++) {
                        voices[i].lfo.Configure(lfoParameters);
                    }
                }
                break;
            }
        
            case PlaitsParamLfoAmountFM:
                lfoAmountFM = clamp(value, 0.0f, 120.0f);
                break;
                
            case PlaitsParamLfoAmount:
                lfoAmount = clamp(value, 0.0f, 1.0f);
                break;
        
            case PlaitsParamLfoAmountHarmonics:
                lfoAmountHarmonics = clamp(value, 0.0f, 1.0f);
                break;
        
            case PlaitsParamLfoAmountTimbre:
                lfoAmountTimbre = clamp(value, 0.0f, 1.0f);
                break;

            case PlaitsParamLfoAmountMorph:
                lfoAmountMorph = clamp(value, 0.0f, 1.0f);
                break;
                
            case PlaitsParamPitchBendRange:
                bendRange = round(clamp(value, 0.0f, 12.0f));
                break;
                
            case PlaitsParamAmpSource: {
                int newAmpSource = round(clamp(value, 0.0f, 3.0f));
                if (ampSource != newAmpSource) {
                    reset();
                    ampSource = newAmpSource;
                    if (ampSource == 0) {
                        modulations.level_patched = false;
                    } else {
                        modulations.level_patched = true;
                        if (ampSource == 2) {
                            modulations.level = 1.0f;
                        }
                    }
                }
                break;
            }
            
            case PlaitsParamEnvAttack: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != envParameters[0]) {
                    envParameters[0] = newValue;
                    for (int i = 0; i < kPolyphony; i++) {
                        voices[i].envelope.Configure(envParameters);
                    }
                }
                break;
            }
                
            case PlaitsParamEnvDecay: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != envParameters[1]) {
                    envParameters[1] = newValue;
                    for (int i = 0; i < kPolyphony; i++) {
                        voices[i].envelope.Configure(envParameters);
                    }
                }
                break;
            }
                
            case PlaitsParamEnvSustain: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != envParameters[2]) {
                    envParameters[2] = newValue;
                    for (int i = 0; i < kPolyphony; i++) {
                        voices[i].envelope.Configure(envParameters);
                    }
                }
                break;
            }
                
            case PlaitsParamEnvRelease: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != envParameters[3]) {
                    envParameters[3] = newValue;
                    for (int i = 0; i < kPolyphony; i++) {
                        voices[i].envelope.Configure(envParameters);
                    }
                }
                break;
            }
                
            case PlaitsParamAmpEnvAttack: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != ampEnvParameters[0]) {
                    ampEnvParameters[0] = newValue;
                    for (int i = 0; i < kPolyphony; i++) {
                        voices[i].ampEnvelope.Configure(ampEnvParameters);
                    }
                }
                break;
            }
                
            case PlaitsParamAmpEnvDecay: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != ampEnvParameters[1]) {
                    ampEnvParameters[1] = newValue;
                    for (int i = 0; i < kPolyphony; i++) {
                        voices[i].ampEnvelope.Configure(ampEnvParameters);
                    }
                }
                break;
            }
                
            case PlaitsParamAmpEnvSustain: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != ampEnvParameters[2]) {
                    ampEnvParameters[2] = newValue;
                    for (int i = 0; i < kPolyphony; i++) {
                        voices[i].ampEnvelope.Configure(ampEnvParameters);
                    }
                }
                break;
            }
                
            case PlaitsParamAmpEnvRelease: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != ampEnvParameters[3]) {
                    ampEnvParameters[3] = newValue;
                    for (int i = 0; i < kPolyphony; i++) {
                        voices[i].ampEnvelope.Configure(ampEnvParameters);
                    }
                }
                break;
            }
                
            case PlaitsParamEnvAmountFM:
                envAmountFM = clamp(value, 0.0f, 120.0f);
                break;
                
            case PlaitsParamEnvAmountHarmonics:
                envAmountHarmonics = clamp(value, 0.0f, 1.0f);
                break;
                
            case PlaitsParamEnvAmountTimbre:
                envAmountTimbre = clamp(value, 0.0f, 1.0f);
                break;
                
            case PlaitsParamEnvAmountMorph:
                envAmountMorph = clamp(value, 0.0f, 1.0f);
                break;
                
            case PlaitsParamEnvAmountLFORate:
                envAmountLfoRate = clamp(value, 0.0f, 1.0f);
                break;
                
            case PlaitsParamEnvAmountLFOAmount:
                envAmountLfoAmount = clamp(value, 0.0f, 1.0f);
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
                
            case PlaitsParamPitch:
                return (float) pitch + 12;
                
            case PlaitsParamDetune:
                return detune;
                
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
                
            case PlaitsParamLfoRate: {
                float result = ((float) lfoParameters[0]) / (float) UINT16_MAX;
                return result;
            }
                
            case PlaitsParamLfoShape:
                return ((float) lfoParameters[1]) / (float) UINT16_MAX;
                
            case PlaitsParamLfoAmountFM:
                return lfoAmountFM;
                
            case PlaitsParamLfoAmount:
                return lfoAmount;
                
            case PlaitsParamLfoAmountHarmonics:
                return lfoAmountHarmonics;
                
            case PlaitsParamLfoAmountTimbre:
                return lfoAmountTimbre;
                
            case PlaitsParamLfoAmountMorph:
                return lfoAmountMorph;
                
            case PlaitsParamPitchBendRange:
                return (float) bendRange;
                
            case PlaitsParamAmpSource:
                return (float) ampSource;
                
            case PlaitsParamEnvAttack:
                return ((float) envParameters[0]) / (float) UINT16_MAX;
           
            case PlaitsParamEnvDecay:
                return ((float) envParameters[1]) / (float) UINT16_MAX;
                
            case PlaitsParamEnvSustain:
                return ((float) envParameters[2]) / (float) UINT16_MAX;
                
            case PlaitsParamEnvRelease:
                return ((float) envParameters[3]) / (float) UINT16_MAX;
                
            case PlaitsParamAmpEnvAttack:
                return ((float) ampEnvParameters[0]) / (float) UINT16_MAX;
                
            case PlaitsParamAmpEnvDecay:
                return ((float) ampEnvParameters[1]) / (float) UINT16_MAX;
                
            case PlaitsParamAmpEnvSustain:
                return ((float) ampEnvParameters[2]) / (float) UINT16_MAX;
                
            case PlaitsParamAmpEnvRelease:
                return ((float) ampEnvParameters[3]) / (float) UINT16_MAX;
                
            case PlaitsParamEnvAmountFM:
                return envAmountFM;
                
            case PlaitsParamEnvAmountHarmonics:
                return envAmountHarmonics;
                
            case PlaitsParamEnvAmountTimbre:
                return envAmountTimbre;
                
            case PlaitsParamEnvAmountMorph:
                return envAmountMorph;
                
            case PlaitsParamEnvAmountLFORate:
                return envAmountLfoRate;
                
            case PlaitsParamEnvAmountLFOAmount:
                return envAmountLfoAmount;
                
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
        // Choose which voice for the new note.
        // Acts like a ring buffer to let latest played voices ring out for the longest.
        
        // first try to find an unused voice.
        int startingPoint = nextVoice;
        do {
            if (voices[nextVoice].state == NoteStateUnused) {
                nextVoice = (nextVoice + 1) % activePolyphony;
                return &voices[nextVoice];
            }
            nextVoice = (nextVoice + 1) % activePolyphony;
        } while (nextVoice != startingPoint);
        
        // then try to find a voice that is releasing.
        startingPoint = nextVoice;
        do {
            if (voices[nextVoice].state == NoteStateReleasing) {
                nextVoice = (nextVoice + 1) % activePolyphony;
                return &voices[nextVoice];
            }
            nextVoice = (nextVoice + 1) % activePolyphony;
        } while (nextVoice != startingPoint);
        
        // finally, just use the oldest voice.
        VoiceState *stolen = &voices[nextVoice];
        nextVoice = (nextVoice + 1) % activePolyphony;
        
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
            case 0xE0 : { // pitch bend
                uint8_t coarse = midiEvent.data[2];
                uint8_t fine = midiEvent.data[1];
                int16_t midiPitchBend = (coarse << 7) + fine;
                bendAmount = (((float) (midiPitchBend - 8192)) / 8192.0f) * bendRange;
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
        while (frameCount > 0) {
            int frames = (frameCount > kAudioBlockSize) ? kAudioBlockSize : frameCount;
            
            modulations.frequency = bendAmount;
            
            for (int i = 0; i < activePolyphony; i++) {
                if (voices[i].state != NoteStateUnused) {
                    playingNotes++;
                    
                    voices[i].run(frames, outL, outR);
                }
            }
            
            if (playingNotes > 0) {
                for (int i = 0; i < frames; i++) {
                    outL[i] *= gainCoefficient * volume;
                    outR[i] *= gainCoefficient * volume;
                }
            }
            outL += frames;
            outR += frames;
            frameCount -= frames;
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
    
    uint16_t lfoParameters[4];
    uint16_t envParameters[4];
    uint16_t ampEnvParameters[4];
    
    float lfoBaseRate;
    float lfoOutput;
    float lfoAmount;
    float lfoAmountFM;
    float lfoAmountHarmonics;
    float lfoAmountTimbre;
    float lfoAmountMorph;
    
    float envAmountFM;
    float envAmountHarmonics;
    float envAmountTimbre;
    float envAmountMorph;
    float envAmountLfoRate;
    float envAmountLfoAmount;
    
    int nextVoice = 0;
    
    bool lastPanSpreadWasNegative = 0;
    
    float slop = 0.0f;
    bool unison = false;
    float volume = 1.0f;
    float gainCoefficient = 0.1f;
    float leftSource = 0.0f;
    float rightSource = 1.0f;
    float pan = 0.0f;
    float panSpread = 0.0f;
    
    int pitch = 0;
    float detune = 0;
    int bendRange = 0;
    float bendAmount = 0.0f;
    
    int ampSource;
};

#endif /* PlaitsDSPKernel_h */
