//
//  MIDIEngine.h
//  Spectrum
//
//  Created by tom on 2019-05-31.
//

#ifndef MIDIEngine_h
#define MIDIEngine_h

#ifdef DEBUG
//#define MIDIPROCESSOR_DEBUG
#endif

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
    Sustain,
    Slide,
} MIDIControlMessage;

typedef struct {
    AUParameter *parameter;
    float minimum;
    float maximum;
} MIDICCTarget;

class MIDIVoice {
public:
    virtual void midiNoteOn(uint8_t note, uint8_t vel) = 0;
    virtual void midiNoteOff(uint8_t vel) = 0;
    virtual void midiControlMessage(MIDIControlMessage msg, int16_t val) = 0;
    virtual void retrigger() = 0;
    virtual void midiAllNotesOff() = 0;
    virtual int State() = 0;
};

typedef struct MIDINote {
    uint8_t channel;
    uint8_t note;
    uint8_t velocity;
    
    bool operator== (const MIDINote &r) {
        return (r.note == note && r.channel == channel);
    }
} MIDINote;

typedef struct {
    uint8_t note;
    uint8_t chan;
    MIDIVoice *voice;
} VoiceRecord;

class MIDIProcessor {
    
    class MPE {
    public:
        MPE() { }
        ~MPE() { }
        
        bool channelInZone(uint8_t ch) {
            return (masterChannel == 0 && ch <= lowChannels) || (masterChannel == 15 && ch >= 15-highChannels);
        }
        
        bool enabled = false;
        uint8_t masterChannel = 0;
        uint8_t lowChannels = 15;
        uint8_t highChannels = 0;
    };
    
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
            activeNotes.reserve(128);
        }
        
        void reset() {
            activeNotes.clear();
            for (int i = 0; i < maxPolyphony; i++) {
                voices[i]->voice->midiAllNotesOff();
            }
            nextVoice = 0;
            resetModulations();
        }
        
        void noteOn(uint8_t chan, uint8_t note, uint8_t vel) {
            MIDINote p = {.channel = chan, .note = note, .velocity = vel};
            if (std::find(activeNotes.begin(), activeNotes.end(), p) != activeNotes.end()) {
                // note on for note we're already playing.
                VoiceRecord *vr = voiceForNote(chan, note);
                if (vr) {
                    vr->voice->retrigger();
                }
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
                for (int i = 0; i < 5; i++) {
                    if (mpe->enabled) {
                        vr->voice->midiControlMessage((MIDIControlMessage) i, modulations[chan][i] + modulations[mpe->masterChannel][i]);
                    } else {
                        vr->voice->midiControlMessage((MIDIControlMessage) i, modulations[chan][i]);
                    }
                }
                vr->voice->midiNoteOn(note, vel);
            }

//            printf("noteOn(%d, %d)\n", note, vel);
            printNoteState();
        }
        
        void noteOff(uint8_t chan, uint8_t note, uint8_t vel) {
            int poly = polyphony();
            MIDINote p = {.channel = chan, .note = note, .velocity = 0};

            activeNotes.erase(std::remove(activeNotes.begin(), activeNotes.end(), p), activeNotes.end());

            VoiceRecord *vr = voiceForNote(chan, note);
            if (activeNotes.size() < poly) {
                if (vr) {
                    vr->voice->midiNoteOff(vel);
                }
            } else {
                if (vr) {
                    vr->note = activeNotes[poly-1].note;
                    vr->chan = activeNotes[poly-1].channel;
                    vr->voice->midiNoteOn(activeNotes[poly-1].note, activeNotes[poly-1].velocity);
                }
            }
           // printf("noteOff(%d)\n", note);
            printNoteState();
        }
        
        void channelMessage(uint8_t chan, MIDIControlMessage msg, int16_t val) {
            std::vector<VoiceRecord *> v = getVoices();
            int poly = polyphony();
            modulations[chan][msg] = val;
            
            for (int i = 0; i < poly; i++) {
                if (v[i]->chan == chan) {
                    if (mpe->enabled) {
                        v[i]->voice->midiControlMessage(msg, val + modulations[mpe->masterChannel][msg]);
                    } else {
                        v[i]->voice->midiControlMessage(msg, val);
                    }
                }
            }
        }
        
        void zoneMessage(MIDIControlMessage msg, int16_t val) {
            std::vector<VoiceRecord *> v = getVoices();
            int poly = polyphony();
            assert(mpe->enabled);
            
            modulations[mpe->masterChannel][msg] = val;
            
            for (int i = 0; i < poly; i++) {
                v[i]->voice->midiControlMessage(msg, val + modulations[v[i]->chan][msg]);
            }
        }
        
        void noteMessage(uint8_t chan, uint8_t note, MIDIControlMessage msg, int16_t val) {
            VoiceRecord *vr = voiceForNote(chan, note);
            
            if (vr) {
                vr->voice->midiControlMessage(msg, val);
            }
        }
        
        std::vector<MIDINote> activeNotes;

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
                    if (activeNotes[i].channel == chan && activeNotes[i].note == note) {
                        return voiceForNote(activeNotes[poly].channel, activeNotes[poly].note);
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
        MPE *mpe;

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
        
        int16_t modulations[16][5];
        
        void resetModulations() {
            for (int ch = 0; ch < 16; ch++) {
                for (int i = 0; i < 5; i++) {
                    modulations[ch][i] = 0;
                }
                modulations[ch][1] = 8192;
            }
        }
        
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
        
        virtual void retrigger() {
            for (int i = 0; i < noteStack->getActivePolyphony(); i++) {
                noteStack->voices[i]->voice->retrigger();
            }
        }
        
        virtual void midiNoteOff(uint8_t vel) {
            for (int i = 0; i < noteStack->getActivePolyphony(); i++) {
                noteStack->voices[i]->voice->midiNoteOff(vel);
            }
        }
        
        virtual void midiAllNotesOff() {
            for (int i = 0; i < noteStack->getMaxPolyphony(); i++) {
                noteStack->voices[i]->voice->midiAllNotesOff();
            }
        }
        
        virtual void midiControlMessage(MIDIControlMessage msg, int16_t val) {
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
        sustainedNotes.reserve(128);
        noteStack.mpe = &mpe;
    }
    
    ~MIDIProcessor() {
        
    }
    
    void noteOff(uint8_t channel, uint8_t note, uint8_t vel) {
        if (sustainSetting && sustainPressed) {
            MIDINote p = {.channel = channel, .note = note, .velocity = vel};
            if (std::find(sustainedNotes.begin(), sustainedNotes.end(), p) == sustainedNotes.end()) {
                sustainedNotes.push_back(p);
            }
        } else {
            noteStack.noteOff(channel, note, vel);
        }
    }
    
    virtual void handleMIDIEvent(AUMIDIEvent const& midiEvent) {
        //if (midiEvent.length > 3) return;
        uint8_t status = midiEvent.data[0] & 0xF0;
        uint8_t channel = midiEvent.data[0] & 0x0F;
        
        if ((mpe.enabled && mpe.channelInZone(channel)) ||
             (!mpe.enabled && channelSetting != -1 && channelSetting != channel)) {
            return;
        }
        
        bool isMasterChannel = mpe.enabled && channel == mpe.masterChannel;
        
#ifdef MIDIPROCESSOR_DEBUG
        printf("------------------\nMIDI event: status %d(0x%02x), channel %d, length %d\nRaw: ", status, status, channel, midiEvent.length);
        
        for (int i = 0; i < midiEvent.length; i++) {
            printf("%02x ", midiEvent.data[i]);
        }
        printf("\n");
#endif
        
        switch (status) {
            case 0x80 : { // note off
                uint8_t note = midiEvent.data[1];
                uint8_t veloc = midiEvent.data[2];

                if (note > 127 || veloc > 127) break;
                noteOff(channel, note, veloc);
                break;
            }
            case 0x90 : { // note on
                uint8_t note = midiEvent.data[1];
                uint8_t veloc = midiEvent.data[2];
                if (note > 127 || veloc > 127) break;
                if (veloc == 0) {
                    noteOff(channel, note, veloc);
                } else {
                    noteStack.noteOn(channel, note, veloc);
                }
                break;
            }
            case 0xE0 : { // pitch bend
                uint8_t coarse = midiEvent.data[2];
                uint8_t fine = midiEvent.data[1];
                int16_t midiPitchBend = (coarse << 7) + fine;
                
                if (isMasterChannel) {
                    noteStack.zoneMessage(MIDIControlMessage::Pitchbend, midiPitchBend - 8192);
                } else {
                    noteStack.channelMessage(channel, MIDIControlMessage::Pitchbend, midiPitchBend - 8192);
                }
                
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

                if (isMasterChannel) {
                    noteStack.zoneMessage(MIDIControlMessage::Aftertouch, pressure);
                } else {
                    noteStack.channelMessage(channel, MIDIControlMessage::Aftertouch, pressure);
                }
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
                } else if (num == 64) {
                    if (!mpe.enabled || isMasterChannel) {
                        // TODO: all message
                        if (mpe.enabled) {
                            noteStack.zoneMessage(MIDIControlMessage::Sustain, midiEvent.data[2]);
                        } else {
                            noteStack.channelMessage(channel, MIDIControlMessage::Sustain, midiEvent.data[2]);
                        }
                        if (sustainSetting) {
                            if (midiEvent.data[2] >= 64) {
                                sustainPress();
                            } else {
                                sustainRelease();
                            }
                        }
                    }
                } else if (num == 74) {
                    if (mpe.enabled) {
                        noteStack.zoneMessage(MIDIControlMessage::Slide, midiEvent.data[2]);
                    } else {
                        noteStack.channelMessage(channel, MIDIControlMessage::Slide, midiEvent.data[2]);
                    }
                } else if (num >= 98 && num <= 101) {
                    // TODO: RPN / NRPM for MPE
                } else {
                    if (automation) {
                        std::map<uint8_t, std::vector<MIDICCTarget>>::iterator params = ccMap.find(num);
                        if (params != ccMap.end()) {
                            std::vector<MIDICCTarget>::iterator itr;
                            for (itr = params->second.begin(); itr != params->second.end(); ++itr) {
                                float value = itr->minimum + (itr->maximum - itr->minimum) * (((float) midiEvent.data[2]) / 127.0f);
                                itr->parameter.value = value;
                            }
                        }
                    }
                }
                break;
            }
        }
    }
    
    void reset() {
        noteStack.reset();
        sustainPressed = false;
        for (int i = 0; i < 16; i++) {
            modCoarse[i] = 0;
            modFine[i] = 0;
        }
    }
    
    void sustainPress() {
        sustainPressed = true;
    }
    
    void sustainRelease() {
        sustainPressed = false;
        std::vector<MIDINote>::iterator itr;
        for (itr = sustainedNotes.begin(); itr != sustainedNotes.end(); ++itr) {
            noteOff((*itr).channel, (*itr).note, (*itr).velocity);
        }
        sustainedNotes.clear();
    }
    
    void setCCMap(const std::map<uint8_t, std::vector<MIDICCTarget>> &map) {
        ccMap = map;
        printCCMap();
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
    
    void setSustainSetting(bool sustain) {
        if (sustainSetting != sustain) {
            sustainSetting = sustain;
            noteStack.reset();
        }
    }
    
    void setAutomation(bool automation) {
        this->automation = automation;
    }
    
    void setMPEEnabled(bool mpe) {
        this->mpe.enabled = mpe;
    }
    
    int channelSetting = -1;
    bool automation = true;
    bool sustainSetting = true;
    bool sustainPressed = false;
    MPE mpe;
    
    NoteStack noteStack;
    std::map<uint8_t, std::vector<MIDICCTarget>> ccMap;
    std::vector<MIDINote> sustainedNotes;
    
    uint8_t modCoarse[16];
    uint8_t modFine[16];
    
    static bool noteSort (MIDINote i, MIDINote j) { return (i.note > j.note); }
};



#endif /* MIDIEngine_h */
