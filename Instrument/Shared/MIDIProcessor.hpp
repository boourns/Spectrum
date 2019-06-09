//
//  MIDIEngine.h
//  Spectrum
//
//  Created by tom on 2019-05-31.
//

#ifndef MIDIEngine_h
#define MIDIEngine_h

#include "concurrentqueue.h"
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

class MIDIProcessor {
public:
    MIDIProcessor(int maxPolyphony) {
        this->maxPolyphony = maxPolyphony;
        this->activePolyphony = maxPolyphony;
        this->unison = false;
        this->nextVoice = 0;
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
                
                if (unison) {
                    for (int i = 0; i < activePolyphony; i++) {
                        voices[i]->midiNoteOff();
                    }
                } else {
                    MIDIVoice *voice = voiceForNote(note);
                    if (voice) {
                        voice->midiNoteOff();
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
                        voices[i]->midiNoteOn(note, veloc);
                    }
                } else {
                    MIDIVoice *voice = voiceForNote(note);
                    if (voice) {
                        voice->midiNoteOn(note, veloc);
                    } else {
                        voice = freeVoice();
                        if (voice) {
                            voice->midiNoteOn(note, veloc);
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
    
    void setActivePolyphony(int activePolyphony) {
        this->activePolyphony = activePolyphony;
        reset();
    }
    
    int getActivePolyphony() {
        return activePolyphony;
    }
    
    void setUnison(bool unison) {
        if (unison != this->unison) {
            reset();
            this->unison = unison;
        }
    }
    
    bool getUnison() {
        return this->unison;
    }
    
    void reset() {
        for (int i = 0; i < maxPolyphony; i++) {
            voices[i]->midiAllNotesOff();
        }
        nextVoice = 0;
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
    
    std::vector<MIDIVoice *> voices;
    std::vector<uint8_t> activeNotes;
    std::map<uint8_t, std::vector<MIDICCTarget>> ccMap;
    
    int bendRange = 0;
    float bendAmount = 0.0f;
    
    uint8_t modCoarse = 0;
    uint8_t modFine = 0;
    float modwheelAmount = 0.0f;

private:
    
    MIDIVoice *voiceForNote(uint8_t note) {
        for (int i = 0; i < activePolyphony; i++) {
            if (voices[i]->Note() == note) {
                return voices[i];
            }
        }
        return nullptr;
    }
    
    MIDIVoice *freeVoice() {
        // Choose which voice for the new note.
        // Acts like a ring buffer to let latest played voices ring out for the longest.
        
        // first try to find an unused voice.
        int startingPoint = nextVoice;
        do {
            if (voices[nextVoice]->State() == NoteStateUnused) {
                nextVoice = (nextVoice + 1) % activePolyphony;
                return voices[nextVoice];
            }
            nextVoice = (nextVoice + 1) % activePolyphony;
        } while (nextVoice != startingPoint);
        
        // then try to find a voice that is releasing.
        startingPoint = nextVoice;
        do {
            if (voices[nextVoice]->State() == NoteStateReleasing) {
                nextVoice = (nextVoice + 1) % activePolyphony;
                return voices[nextVoice];
            }
            nextVoice = (nextVoice + 1) % activePolyphony;
        } while (nextVoice != startingPoint);
        
        // finally, just use the oldest voice.
        MIDIVoice *stolen = voices[nextVoice];
        nextVoice = (nextVoice + 1) % activePolyphony;
        
        return stolen;
    }
    
    MIDISynthesizer *engine;
    int maxPolyphony;
    int activePolyphony;
    bool unison;
    int nextVoice;
    
    // vector of voices
    // vector of uint8_t playingNotes
};

#endif /* MIDIEngine_h */
