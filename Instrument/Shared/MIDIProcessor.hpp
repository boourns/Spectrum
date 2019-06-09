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
#import "DSPKernel.hpp"

enum {
    NoteStateUnused = 0,
    NoteStatePlaying = 1,
    NoteStateReleasing = 2
};

typedef struct {
    uint8_t controller;
    int parameter;
} MIDICCMap;

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
    virtual void midiControllerChange(uint8_t number, uint8_t value) = 0;
};

class MIDIProcessor {
public:
    MIDIProcessor(int maxPolyphony): updatedParams(64) {
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
    }
    
    void setCCMap(std::vector<MIDICCMap> &map) {
        ccMap = map;
    }
    
    std::vector<MIDIVoice *> voices;
    std::vector<uint8_t> activeNotes;
    
    std::vector<MIDICCMap> ccMap;
    int bendRange = 0;
    float bendAmount = 0.0f;

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
    
    moodycamel::ConcurrentQueue<int> updatedParams;

    // vector of voices
    // vector of uint8_t playingNotes
};

#endif /* MIDIEngine_h */
