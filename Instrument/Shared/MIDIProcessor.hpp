//
//  MIDIEngine.h
//  Spectrum
//
//  Created by tom on 2019-05-31.
//

#ifndef MIDIEngine_h
#define MIDIEngine_h

#define MIDIPROCESSOR_DEBUG

#import <vector>
#include <map>
#import "DSPKernel.hpp"

enum {
    NoteStateUnused = 0,
    NoteStatePlaying = 1,
    NoteStateReleasing = 2
};

typedef enum {
    Modwheel = 0,
    Pitchbend,
    Aftertouch,
    Sustain
} MIDIControlMessage;

typedef struct {
    AUParameter *parameter;
    float minimum;
    float maximum;
} MIDICCTarget;

class MIDIVoice {
public:
    virtual void midiNoteOn(uint8_t note, uint8_t vel) = 0;
    virtual void midiNoteOff() = 0;
    virtual void midiControlMessage(MIDIControlMessage msg, uint16_t val) = 0;
    virtual void midiAllNotesOff() = 0;
    virtual int State() = 0;
};

class MIDISynthesizer {
public:
    virtual void midiPitchBend(uint16_t value) = 0;
    virtual void midiModWheel(uint16_t value) = 0;
    virtual void setParameter(AUParameterAddress address, AUValue value);
};

typedef struct PlayingNote {
    uint8_t chan;
    uint8_t note;
    uint8_t vel;
    
    bool operator== (const PlayingNote &r) {
        return (r.note == note && r.chan == chan);
    }
} PlayingNote;

typedef struct {
    uint8_t note;
    uint8_t chan;
    MIDIVoice *voice;
} VoiceRecord;

class MIDIProcessor {
    class NoteStack {
    public:
        NoteStack(int maxPolyphony) {
            this->maxPolyphony = maxPolyphony;
            this->activePolyphony = maxPolyphony;
            this->unison = false;
            this->nextVoice = 0;
            VoiceRecord *unisonVoice = new VoiceRecord();
            unisonVoice->note = 0;
            unisonVoice->chan = 0;
            unisonVoice->voice = new UnisonMIDIVoice(this);
            this->unisonVoices.push_back(unisonVoice);
        }
        
        void reset() {
            activeNotes.clear();
            for (int i = 0; i < maxPolyphony; i++) {
                voices[i]->voice->midiAllNotesOff();
            }
            nextVoice = 0;
        }
        
        void noteOn(uint8_t chan, uint8_t note, uint8_t vel) {
            if (vel == 0) {
                noteOff(chan, note);
                return;
            }
            PlayingNote p = {.chan = chan, .note = note, .vel = vel};
            if (std::find(activeNotes.begin(), activeNotes.end(), p) != activeNotes.end()) {
                // note on for note we're already playing.
                return;
            }
            activeNotes.push_back(p);
            std::sort(activeNotes.begin(), activeNotes.end(), MIDIProcessor::noteSort);

            VoiceRecord *vr = voiceForNote(chan, note);
            if (!vr) {
                vr = freeVoice(chan, note);
            }
            
            if (vr) {
                vr->chan = chan;
                vr->note = note;
                vr->voice->midiNoteOn(note, vel);
            }

//            printf("noteOn(%d, %d)\n", note, vel);
            printNoteState();
        }
        
        void noteOff(uint8_t chan, uint8_t note) {
            int poly = polyphony();
            PlayingNote p = {.chan = chan, .note = note, .vel = 0};

            activeNotes.erase(std::remove(activeNotes.begin(), activeNotes.end(), p), activeNotes.end());

            VoiceRecord *vr = voiceForNote(chan, note);
            if (activeNotes.size() < poly) {
                if (vr) {
                    vr->voice->midiNoteOff();
                }
            } else {
                if (vr) {
                    vr->note = activeNotes[poly-1].note;
                    vr->chan = activeNotes[poly-1].chan;
                    vr->voice->midiNoteOn(activeNotes[poly-1].note, activeNotes[poly-1].vel);
                }
            }
           // printf("noteOff(%d)\n", note);
            printNoteState();
        }
        
        void channelMessage(uint8_t chan, MIDIControlMessage msg, int16_t val) {
            std::vector<VoiceRecord *> v = getVoices();
            int poly = polyphony();
            
            for (int i = 0; i < poly; i++) {
                if (v[i]->chan == chan) {
                    v[i]->voice->midiControlMessage(msg, val);
                }
            }
        }
        
        void noteMessage(uint8_t chan, uint8_t note, MIDIControlMessage msg, int16_t val) {
            VoiceRecord *vr = voiceForNote(chan, note);
            
            if (vr) {
                vr->voice->midiControlMessage(msg, val);
            }
        }
        
        std::vector<PlayingNote> activeNotes;

        VoiceRecord *voiceForNote(uint8_t chan, uint8_t note) {
            std::vector<VoiceRecord *> v = getVoices();
            int poly = polyphony();
            
            for (int i = 0; i < poly; i++) {
                if (v[i]->chan == chan && v[i]->note == note) {
                    return v[i];
                }
            }
            return nullptr;
        }
        
        VoiceRecord *freeVoice(uint8_t chan, uint8_t note) {
            // Choose which voice for the new note.
            // Acts like a ring buffer to let latest played voices ring out for the longest.
            
            std::vector<VoiceRecord *> v = getVoices();
            int poly = polyphony();
            
            // first try to find an unused voice.
            int startingPoint = nextVoice;
            do {
                if (v[nextVoice]->voice->State() == NoteStateUnused) {
                    int found = nextVoice;
                    nextVoice = (nextVoice + 1) % poly;
                    return v[found];
                }
                nextVoice = (nextVoice + 1) % poly;
            } while (nextVoice != startingPoint);
            
            // then try to find a voice that is releasing.
            startingPoint = nextVoice;
            do {
                if (v[nextVoice]->voice->State() == NoteStateReleasing) {
                    int found = nextVoice;
                    nextVoice = (nextVoice + 1) % poly;
                    return v[found];
                }
                nextVoice = (nextVoice + 1) % poly;
            } while (nextVoice != startingPoint);
            
            // didn't find a voice.  Check our position in activeNotes to determine if we should replace a note.
            if (activeNotes.size() > poly) {
                for (int i = 0; i < poly; i++) {
                    if (activeNotes[i].chan == chan && activeNotes[i].note == note) {
                        return voiceForNote(activeNotes[poly].chan, activeNotes[poly].note);
                    }
                }
            }
            return 0;
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
        
        void addVoice(MIDIVoice *voice) {
            VoiceRecord *vr = new VoiceRecord();
            vr->note = 0;
            vr->chan = 0;
            vr->voice = voice;
            voices.push_back(vr);
        }
        
        MIDIProcessor *engine;

        std::vector<VoiceRecord *> voices;

    private:
        
        std::vector<VoiceRecord *> unisonVoices;
        
        inline int polyphony() {
            if (unison) {
                return 1;
            } else {
                return activePolyphony;
            }
        }
        
        inline std::vector<VoiceRecord *> getVoices() {
            if (unison) {
                return unisonVoices;
            } else {
                return voices;
            }
        }
        
        inline void printNoteState() {
#ifdef MIDIPROCESSOR_DEBUG
            printf("polyphony() = %d, unison() = %d\n", polyphony(), unison);
            printf("activeNotes.size() = %u\n", activeNotes.size());
            for (int i = 0; i < activeNotes.size(); i++) {
                printf("%d, ", activeNotes[i].note);
            }
            printf("\nVoice states:\n");
            for (int i = 0; i < activePolyphony; i++) {
                printf("chan = %d, note = %d, state = %d\n", voices[i]->chan, voices[i]->note, voices[i]->voice->State());
            }
#endif
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
                noteStack->voices[i]->voice->midiNoteOn(note, vel);
            }
        }
        
        virtual void midiNoteOff() {
            for (int i = 0; i < noteStack->getActivePolyphony(); i++) {
                noteStack->voices[i]->voice->midiNoteOff();
            }
        }
        
        virtual void midiAllNotesOff() {
            for (int i = 0; i < noteStack->getMaxPolyphony(); i++) {
                noteStack->voices[i]->voice->midiAllNotesOff();
            }
        }
        
        virtual void midiControlMessage(MIDIControlMessage msg, uint16_t val) {
            for (int i = 0; i < noteStack->getMaxPolyphony(); i++) {
                noteStack->voices[i]->voice->midiControlMessage(msg, val);
            }
        }
        
        virtual int State() {
            return noteStack->voices[0]->voice->State();
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
        uint8_t channel = midiEvent.data[0] & 0x0F;
        
        if (channelSetting != -1 && channelSetting != channel) {
            return;
        }
        
        switch (status) {
            case 0x80 : { // note off
                uint8_t note = midiEvent.data[1];
                if (note > 127) break;
                noteStack.noteOff(channel, note);
                break;
            }
            case 0x90 : { // note on
                uint8_t note = midiEvent.data[1];
                uint8_t veloc = midiEvent.data[2];
                if (note > 127 || veloc > 127) break;
                noteStack.noteOn(channel, note, veloc);
                break;
            }
            case 0xE0 : { // pitch bend
                uint8_t coarse = midiEvent.data[2];
                uint8_t fine = midiEvent.data[1];
                int16_t midiPitchBend = (coarse << 7) + fine;
                
                noteStack.channelMessage(channel, MIDIControlMessage::Pitchbend, midiPitchBend);
                
                break;
            }
            case 0xA0 : { // poly aftertouch
                uint8_t note = midiEvent.data[1];
                uint8_t pressure = midiEvent.data[2];
                
                noteStack.noteMessage(channel, note, MIDIControlMessage::Aftertouch, pressure);
                break;
            }
            case 0xD0 : { // channel aftertouch
                uint8_t pressure = midiEvent.data[1];

                noteStack.channelMessage(channel, MIDIControlMessage::Aftertouch, pressure);
                break;
            }
            
            case 0xB0 : { // control
                uint8_t num = midiEvent.data[1];
                if (num == 123) { // all notes off
                    reset();
                } else if (num == 1) {
                    modCoarse[channel] = midiEvent.data[2];
                    sendModwheel(channel);
                } else if (num == 32) {
                    modFine[channel] = midiEvent.data[2];
                    sendModwheel(channel);
                }  else if (num == 64) {
                    noteStack.channelMessage(channel, MIDIControlMessage::Sustain, midiEvent.data[2]);
                } else if (num >= 98 && num <= 101) {
                    // TODO: RPN / NRPM for MPE
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
        for (int i = 0; i < 16; i++) {
            modCoarse[i] = 0;
            modFine[i] = 0;
        }
    }
    
    void setCCMap(const std::map<uint8_t, std::vector<MIDICCTarget>> &map) {
        ccMap = map;
        //printCCMap();
    }
    
    void printCCMap() {
        for (int i = 0; i < 128; i++) {
            std::map<uint8_t, std::vector<MIDICCTarget>>::iterator params = ccMap.find(i);
            if (params != ccMap.end()) {
                std::vector<MIDICCTarget>::iterator itr;
                for (itr = params->second.begin(); itr != params->second.end(); ++itr) {
                    printf("<tr><td>%d</td><td>%s</td></tr>\n", i, itr->parameter.displayName.UTF8String);
                }
            }
        }
    }
    
    inline void sendModwheel(int channel) {
        int16_t wheel = (modCoarse[channel] << 7) + modFine[channel];
        noteStack.channelMessage(channel, MIDIControlMessage::Modwheel, wheel);
    }
    
    void setChannel(int chan) {
        if (chan != channelSetting) {
            channelSetting = chan;
            noteStack.reset();
        }
    }
    
    int channelSetting = -1;
    NoteStack noteStack;
    std::map<uint8_t, std::vector<MIDICCTarget>> ccMap;
    
    uint8_t modCoarse[16];
    uint8_t modFine[16];
    
    static bool noteSort (PlayingNote i, PlayingNote j) { return (i.note > j.note); }

private:
    MIDISynthesizer *engine;
};



#endif /* MIDIEngine_h */
