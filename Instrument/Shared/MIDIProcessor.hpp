//
//  MIDIEngine.h
//  Spectrum
//
//  Created by tom on 2019-05-31.
//

#ifndef MIDIEngine_h
#define MIDIEngine_h

#include <vector>
#include <map>
#import "DSPKernel.hpp"

enum {
    NoteStateUnused = 0,
    NoteStatePlaying = 1,
    NoteStateReleasing = 2
};

typedef struct {
    AUParameter *parameter;
    float minimum;
    float maximum;
} MIDICCTarget;

class MIDIVoice {
public:
    virtual void midiNoteOn(uint8_t note, uint8_t vel) = 0;
    virtual void midiNoteOff() = 0;
    virtual void midiAllNotesOff() = 0;
    virtual uint8_t Note() = 0;
    virtual int State() = 0;
};

class MIDISynthesizer {
public:
    virtual void midiPitchBend(uint16_t value) = 0;
    virtual void midiModWheel(uint16_t value) = 0;
    virtual void setParameter(AUParameterAddress address, AUValue value);
};

bool noteSort (int i,int j) { return (i>j); }

class MIDIProcessor {
    class NoteStack {
    public:
        NoteStack(int maxPolyphony) {
            this->maxPolyphony = maxPolyphony;
            this->activePolyphony = maxPolyphony;
            this->unison = false;
            this->nextVoice = 0;
            this->unisonVoices.push_back(new UnisonMIDIVoice(this));
        }
        
        void reset() {
            activeNotes.clear();
            for (int i = 0; i < maxPolyphony; i++) {
                voices[i]->midiAllNotesOff();
            }
            nextVoice = 0;
        }
        
        void noteOn(uint8_t note, uint8_t vel) {
            activeNotes.push_back(note);
            std::sort(activeNotes.begin(), activeNotes.end(), noteSort);

            MIDIVoice *voice = voiceForNote(note);
            if (voice) {
                voice->midiNoteOn(note, vel);
            } else {
                voice = freeVoice();
                if (voice) {
                    voice->midiNoteOn(note, vel);
                }
            }
        }
        
        void noteOff(uint8_t note) {
            MIDIVoice *voice = voiceForNote(note);
            if (voice) {
                voice->midiNoteOff();
            }
        }
        
        std::vector<uint8_t> activeNotes;

        MIDIVoice *voiceForNote(uint8_t note) {
            std::vector<MIDIVoice *> v = getVoices();
            int poly = polyphony();
            
            for (int i = 0; i < poly; i++) {
                if (v[i]->Note() == note) {
                    return v[i];
                }
            }
            return nullptr;
        }
        
        MIDIVoice *freeVoice() {
            // Choose which voice for the new note.
            // Acts like a ring buffer to let latest played voices ring out for the longest.
            
            std::vector<MIDIVoice *> v = getVoices();
            int poly = polyphony();
            
            // first try to find an unused voice.
            int startingPoint = nextVoice;
            do {
                if (v[nextVoice]->State() == NoteStateUnused) {
                    nextVoice = (nextVoice + 1) % poly;
                    return v[nextVoice];
                }
                nextVoice = (nextVoice + 1) % poly;
            } while (nextVoice != startingPoint);
            
            // then try to find a voice that is releasing.
            startingPoint = nextVoice;
            do {
                if (v[nextVoice]->State() == NoteStateReleasing) {
                    nextVoice = (nextVoice + 1) % poly;
                    return v[nextVoice];
                }
                nextVoice = (nextVoice + 1) % poly;
            } while (nextVoice != startingPoint);
            
            // finally, just use the oldest voice.
            MIDIVoice *stolen = v[nextVoice];
            nextVoice = (nextVoice + 1) % poly;
            
            return stolen;
        }
        
        void setActivePolyphony(int activePolyphony) {
            this->activePolyphony = activePolyphony;
            engine->reset();
        }
        
        int getActivePolyphony() {
            return activePolyphony;
        }
        
        int getMaxPolyphony() {
            return maxPolyphony;
        }
        
        void setUnison(bool unison) {
            if (unison != this->unison) {
                engine->reset();
                this->unison = unison;
            }
        }
        
        bool getUnison() {
            return this->unison;
        }
        
        MIDIProcessor *engine;
        std::vector<MIDIVoice *> voices;
        std::vector<MIDIVoice *> unisonVoices;
        
    private:
        
        inline int polyphony() {
            if (unison) {
                return 1;
            } else {
                return activePolyphony;
            }
        }
        
        inline std::vector<MIDIVoice *> getVoices() {
            if (unison) {
                return unisonVoices;
            } else {
                return voices;
            }
        }
        
        int maxPolyphony;
        int activePolyphony;
        bool unison;
        int nextVoice;
    };
    
    class UnisonMIDIVoice: public MIDIVoice {
    public:
        UnisonMIDIVoice(NoteStack *noteStack) {
            this->noteStack = noteStack;
        }
        
        virtual void midiNoteOn(uint8_t note, uint8_t vel) {
            for (int i = 0; i < noteStack->getActivePolyphony(); i++) {
                noteStack->voices[i]->midiNoteOn(note, vel);
            }
        }
        
        virtual void midiNoteOff() {
            for (int i = 0; i < noteStack->getActivePolyphony(); i++) {
                noteStack->voices[i]->midiNoteOff();
            }
        }
        
        virtual void midiAllNotesOff() {
            for (int i = 0; i < noteStack->getMaxPolyphony(); i++) {
                noteStack->voices[i]->midiAllNotesOff();
            }
        }
        
        virtual uint8_t Note() {
            return noteStack->voices[0]->Note();
        }
        
        virtual int State() {
            return noteStack->voices[0]->State();
        }
        
        NoteStack *noteStack;
    };
    
public:
    MIDIProcessor(int maxPolyphony): noteStack(maxPolyphony) {
        noteStack.engine = this;
    }
    
    ~MIDIProcessor() {
        
    }
    
    virtual void handleMIDIEvent(AUMIDIEvent const& midiEvent) {
        if (midiEvent.length != 3) return;
        uint8_t status = midiEvent.data[0] & 0xF0;
        //uint8_t channel = midiEvent.data[0] & 0x0F; // works in omni mode.
        switch (status) {
            case 0x80 : { // note off
                uint8_t note = midiEvent.data[1];
                if (note > 127) break;
                noteStack.noteOff(note);
                break;
            }
            case 0x90 : { // note on
                uint8_t note = midiEvent.data[1];
                uint8_t veloc = midiEvent.data[2];
                if (note > 127 || veloc > 127) break;
                noteStack.noteOn(note, veloc);
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
                } else if (num == 1) {
                    modCoarse = midiEvent.data[2];
                    calculateModwheel();
                } else if (num == 32) {
                    modFine = midiEvent.data[2];
                    calculateModwheel();
                } else {
                    std::map<uint8_t, std::vector<MIDICCTarget>>::iterator params = ccMap.find(num);
                    if (params != ccMap.end()) {
                        std::vector<MIDICCTarget>::iterator itr;
                        for (itr = params->second.begin(); itr != params->second.end(); ++itr) {
                            float value = itr->minimum + (itr->maximum - itr->minimum) * (((float) midiEvent.data[2]) / 127.0f);
                            itr->parameter.value = value;
                        }
                    }
                }
                break;
            }
        }
    }
    
    void reset() {
        noteStack.reset();
        bendAmount = 0.0f;
        modwheelAmount = 0.0f;
        modCoarse = 0;
        modFine = 0;
    }
    
    void setCCMap(std::map<uint8_t, std::vector<MIDICCTarget>> &map) {
        ccMap = map;
    }
    
    inline void calculateModwheel() {
        int16_t wheel = (modCoarse << 7) + modFine;

        modwheelAmount = (((float) wheel) / 16384.0f);
    }
    
    NoteStack noteStack;
    std::map<uint8_t, std::vector<MIDICCTarget>> ccMap;
    
    int bendRange = 0;
    float bendAmount = 0.0f;
    
    uint8_t modCoarse = 0;
    uint8_t modFine = 0;
    float modwheelAmount = 0.0f;

private:
    MIDISynthesizer *engine;
    
    // vector of voices
    // vector of uint8_t playingNotes

};



#endif /* MIDIEngine_h */
