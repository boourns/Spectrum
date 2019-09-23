//
//  OrgoneDSPKernel.hpp
//  Orgone
//
//  Created by tom on 2019-09-07.
//

#ifndef OrgoneDSPKernel_h
#define OrgoneDSPKernel_h

#define INPUT_FACTOR 8191.0f

#import <vector>
#import "orgone.hpp"
#import "peaks/multistage_envelope.h"
#import "stmlib/dsp/parameter_interpolator.h"
#import "stmlib/dsp/dsp.h"
#import "converter.hpp"
#import "DSPKernel.hpp"

#import "MIDIProcessor.hpp"
#import "ModulationEngine.hpp"
#import "LFOKernel.hpp"

#ifdef DEBUG
#define KERNEL_DEBUG_LOG(...) printf(__VA_ARGS__);
#else
#define KERNEL_DEBUG_LOG(...)
#endif

//#define DEADVOICE

const size_t kAudioBlockSize = 24;
const size_t kMaxPolyphony = 8;
const size_t kNumModulationRules = 12;

enum {
    OrgoneParamPadX = 0,
    OrgoneParamPadY = 1,
    OrgoneParamPadGate = 2,
    OrgoneParamPosition = 3,
    OrgoneParamEffect = 4,
    OrgoneParamPitch = 5,
    OrgoneParamDetune = 6,
    OrgoneParamWaveLow = 7,
    OrgoneParamWaveMid = 8,
    OrgoneParamWaveHigh = 9,
    OrgoneParamFreq = 10,
    OrgoneParamVolume = 11,
    OrgoneParamModulation = 12,
    OrgoneParamIndex = 13,
    OrgoneParamPan = 14,
    OrgoneParamPanSpread = 15,
    OrgoneParamLfoRate = 16,
    OrgoneParamLfoShape = 17,
    OrgoneParamLfoShapeMod = 18,
    OrgoneParamEnvAttack = 20,
    OrgoneParamEnvDecay = 21,
    OrgoneParamEnvSustain = 22,
    OrgoneParamEnvRelease = 23,
    OrgoneParamPitchBendRange = 24,
    OrgoneParamAmpEnvAttack = 28,
    OrgoneParamAmpEnvDecay = 29,
    OrgoneParamAmpEnvSustain = 30,
    OrgoneParamAmpEnvRelease = 31,
    OrgoneParamPortamento = 32,
    OrgoneParamUnison = 33,
    OrgoneParamPolyphony = 34,
    OrgoneParamSlop = 35,
    OrgoneParamLfoTempoSync = 36,
    OrgoneParamLfoResetPhase = 37,
    OrgoneParamLfoKeyReset = 38,
    OrgoneParamFXAlgorithm = 39,
    
    OrgoneParamModMatrixStart = 400,
    OrgoneParamModMatrixEnd = 400 + (kNumModulationRules * 4), // 39 + 48 = 87
    OrgoneMaxParameters
};

enum {
    ModInDirect = 0,
    ModInLFO,
    ModInEnvelope,
    ModInNote,
    ModInVelocity,
    ModInGate,
    ModInModwheel,
    ModInOut,
    ModInPadX,
    ModInPadY,
    ModInPadGate,
    ModInAftertouch,
    ModInSustain,
    ModInSlide,
    ModInLift,
    NumModulationInputs
};

enum {
    ModOutDisabled = 0,
    ModOutTune,
    ModOutFrequency,
    ModOutPosition,
    ModOutEffect,
    ModOutModulation,
    ModOutIndex,
    ModOutFreq,
    ModOutLFORate,
    ModOutLFOAmount,
    ModOutPan,
    ModOutLevel,
    ModOutPortamento,
    NumModulationOutputs
};

/*
 InstrumentDSPKernel
 Performs our filter signal processing.
 As a non-ObjC class, this is safe to use from render thread.
 */
class OrgoneDSPKernel : public DSPKernel {
public:
    // MARK: Types
    class VoiceState: public MIDIVoice {
    public:
        unsigned int state = 0;
        OrgoneDSPKernel *kernel = 0;
        
        uint8_t note = 0;
        float noteTarget = 0.0f;
        
        size_t orgoneFramesIndex = 0;
        float frames[kAudioBlockSize];

        peaks::MultistageEnvelope envelope;
        peaks::MultistageEnvelope ampEnvelope;
        LFOKernel lfo;
        float lfoOutput;
        float out;
        float rightGain, leftGain, rightGainTarget, leftGainTarget;
        
        Orgone orgone;
        ModulationEngine modEngine;
        
        double portamento = 0.0;
        float bendAmount;
        float panSpread = 0;
        
        float aftertouchTarget = 0.0f;
        
        bool lfoRatePatched = false;
        bool portamentoPatched = false;
        
        bool delayed_trigger = false;
        
        VoiceState() : modEngine(NumModulationInputs, NumModulationOutputs),
        lfo(OrgoneParamLfoRate, OrgoneParamLfoShape, OrgoneParamLfoShapeMod, OrgoneParamLfoTempoSync, OrgoneParamLfoResetPhase, OrgoneParamLfoKeyReset) {
            
        }
        
        void Init(ModulationEngineRuleList *rules) {
            KERNEL_DEBUG_LOG("kernel voice Init")
            
            orgone.patch.freq = 512;
            orgone.patch.index = 100;
            orgone.patch.effect = 0;
            orgone.patch.mod = 100;
            orgone.patch.waveHi = 200;
            orgone.patch.waveMid = 100;
            orgone.patch.waveLo = 400;
            orgone.patch.pos = 500;
            orgone.patch.tuneFine = 512;
            orgone.patch.tune = 512;
            orgone.patch.fx = 4;
            orgone.patch.fixedFM = false;
            orgone.patch.fmMode = false;
            orgone.patch.effectA = true;
            orgone.patch.effectB = true;
            orgone.patch.effectC = true;
            orgone.patch.trigger = false;

            orgone.setup();
            for (int i = 0; i < 20; i++) {
                orgone.loop();
            }
            
            orgoneFramesIndex = kAudioBlockSize;
            envelope.Init();
            ampEnvelope.Init();
            lfo.Init(48000);
            modEngine.rules = rules;
            modEngine.in[ModInDirect] = 1.0f;
        }
        
        // ================ MIDIProcessor
        
        virtual void midiAllNotesOff() override {
            orgone.patch.trigger = false;
            modEngine.in[ModInGate] = 0.0f;
            envelope.TriggerLow();
            ampEnvelope.TriggerLow();
            state = NoteStateReleasing;
            bendAmount = 0.0f;
            modEngine.in[ModInModwheel] = 0.0f;
            modEngine.in[ModInAftertouch] = 0.0f;
            modEngine.in[ModInSustain] = 0.0f;
            delayed_trigger = false;
        }
        
        // linked list management
        virtual void midiNoteOff(uint8_t vel) override {
            orgone.patch.trigger = false;
            envelope.TriggerLow();
            ampEnvelope.TriggerLow();
            modEngine.in[ModInGate] = 0.0f;
            modEngine.in[ModInLift] = ((float) vel )/ 127.0f;
            if (delayed_trigger) {
                printf("delayed trigger while note off\n");
            }
            delayed_trigger = false;
            state = NoteStateReleasing;
#ifdef DEADVOICE
            deadCount = 20000;
#endif
        }
        
        virtual void midiControlMessage(MIDIControlMessage msg, int16_t val) override {
            switch(msg) {
                case MIDIControlMessage::Pitchbend:
                    bendAmount = (clamp((float) val, -8192.0f, 8192.0f) / 8192.0f) * kernel->bendRange;
                    break;
                case MIDIControlMessage::Modwheel:
                    modEngine.in[ModInModwheel] = clamp((float) val, 0.0f, 16384.0f) / 16384.0f;
                    break;
                case MIDIControlMessage::Aftertouch:
                    aftertouchTarget = clamp((float) val, 0.0f, 127.0f) / 127.0f;
                    break;
                case MIDIControlMessage::Sustain:
                    modEngine.in[ModInSustain] = clamp((float) val, 0.0f, 127.0f) / 127.0f;
                    break;
                case MIDIControlMessage::Slide:
                    modEngine.in[ModInSlide] = clamp((float) val, 0.0f, 127.0f) / 127.0f;
                    break;
            }
        }
        
        virtual int State() override {
            return state;
        }
        
        void add() {
            if (state == NoteStateUnused) {
                orgone.patch.trigger = true;
                envelope.TriggerHigh();
                ampEnvelope.TriggerHigh();
                lfo.trigger();
                modEngine.in[ModInGate] = 1.0f;
            } else if (state == NoteStateReleasing) {
                delayed_trigger = true;
            }
            state = NoteStatePlaying;
        }
        
        virtual void retrigger() override {
            envelope.TriggerHigh();
            ampEnvelope.TriggerHigh();
            lfo.trigger();
        }
        
        virtual void midiNoteOn(uint8_t noteNumber, uint8_t velocity) override
        {
            if (state == NoteStateUnused) {
                //memcpy(&modulations, &kernel->modulations, sizeof(plaits::Modulations));
            }
            
            panSpread = kernel->nextPanSpread();
            
            noteTarget = float(noteNumber) + kernel->randomSignedFloat(kernel->slop) - 48.0f;
            
            note = noteNumber;
            modEngine.in[ModInNote] = ((float) note) / 127.0f;
            modEngine.in[ModInVelocity] = ((float) velocity) / 127.0f;
            modEngine.in[ModInLift] = 0.0f;
            
            
            add();
        }
        
        // === MODULATIONS
        
        void updatePortamento(float modulationAmount) {
            portamento = clamp(kernel->portamento + modulationAmount, 0.0, 0.9995);
            portamento = pow(portamento, 0.05f);
        }
        
        void runModulations(int blockSize) {
            envelope.Process(blockSize);
            ampEnvelope.Process(blockSize);
            
            float lfoAmount = 1.0;
            if (kernel->modulationEngineRules.isPatched(ModOutLFOAmount)) {
                lfoAmount = modEngine.out[ModOutLFOAmount];
            }
            
            lfoOutput = lfoAmount * lfo.process(blockSize);
            
            modEngine.in[ModInLFO] = lfoOutput;
            modEngine.in[ModInEnvelope] = envelope.value;
            modEngine.in[ModInOut] = out;
            
            if (kernel->modulationEngineRules.isPatched(ModOutPortamento)) {
                updatePortamento(modEngine.out[ModOutPortamento]);
                portamentoPatched = true;
            } else if (portamentoPatched) {
                portamentoPatched = false;
                updatePortamento(0.0f);
            }
            
            ONE_POLE(orgone.patch.note, noteTarget, 1.0f - portamento);
            ONE_POLE(modEngine.in[ModInAftertouch], aftertouchTarget, 0.1f);
            
            modEngine.run();
            
            if (kernel->modulationEngineRules.isPatched(ModOutLFORate)) {
                lfo.updateRate(modEngine.out[ModOutLFORate]);
                lfoRatePatched = true;
            } else if (lfoRatePatched) {
                lfoRatePatched = false;
                lfo.updateRate(0.0f);
            }
            
            orgone.patch.note += bendAmount + modEngine.out[ModOutTune] + (modEngine.out[ModOutFrequency] * 120.0f);
            
            orgone.patch.pos = clamp(kernel->patch.pos + (modEngine.out[ModOutPosition] * 4095.0f), 0.0f, 4095.0f);
            orgone.patch.effect = clamp(kernel->patch.effect + (modEngine.out[ModOutEffect] * 4095.0f), 0.0f, 4095.0f);
            orgone.patch.waveHi = kernel->patch.waveHi;
            orgone.patch.waveMid = kernel->patch.waveMid;
            orgone.patch.waveLo = kernel->patch.waveLo;
            orgone.patch.mod = clamp(kernel->patch.mod + (modEngine.out[ModOutModulation] * INPUT_FACTOR), 0.0f, INPUT_FACTOR);
            orgone.patch.index = clamp(kernel->patch.index + (modEngine.out[ModOutIndex] * INPUT_FACTOR), 0.0f, INPUT_FACTOR);
            orgone.patch.freq = clamp(kernel->patch.freq + (modEngine.out[ModOutFreq] * INPUT_FACTOR), 0.0f, INPUT_FACTOR);
            orgone.patch.fx = kernel->patch.fx;
            
            /*
            modulations.engine = modEngine.out[ModOutEngine];
            modulations.frequency = kernel->modulations.frequency + bendAmount + modEngine.out[ModOutTune] + (modEngine.out[ModOutFrequency] * 120.0f);
            
            modulations.harmonics = kernel->modulations.harmonics + modEngine.out[ModOutHarmonics];
            
            modulations.timbre = kernel->modulations.timbre + modEngine.out[ModOutTimbre];
            
            modulations.morph = kernel->modulations.morph + modEngine.out[ModOutMorph];
            
             */
            
            float gain = clamp(ampEnvelope.value + modEngine.out[ModOutLevel], 0.0f, 1.0f);
            float pan = clamp(kernel->pan + modEngine.out[ModOutPan] + panSpread, -1.0f, 1.0f);
            
            if (pan > 0) {
                rightGainTarget = 1.0f * gain;
                leftGainTarget = (1.0f - pan) * gain;
            } else {
                leftGainTarget = 1.0f * gain;
                rightGainTarget = (1.0f + pan) * gain;
            }
        }
        
        void run(int n, float* outL, float* outR)
        {
            int framesRemaining = n;
            
            while (framesRemaining) {
                if (orgoneFramesIndex >= kAudioBlockSize) {
                    
                    if (state == NoteStateReleasing && ampEnvelope.done) {
                        state = NoteStateUnused;
                    }
                    
                    runModulations(kAudioBlockSize);
                    
                    orgone.gateISR();
                    orgone.loop();
                    for (int i = 0; i < kAudioBlockSize; i++) {
                        orgone.interrupt();
                        frames[i] = orgone.written;
                    }
                    
                    //voice->Render(kernel->patch, modulations, &frames[0], kAudioBlockSize);
                    orgoneFramesIndex = 0;
                    
                    if (delayed_trigger) {
                        delayed_trigger = false;
                        //modulations.trigger = 1.0f;
                        envelope.TriggerHigh();
                        ampEnvelope.TriggerHigh();
                        lfo.trigger();
                        modEngine.in[ModInGate] = 1.0f;
                        assert(state == NoteStatePlaying);
                    }
                }
                
                out = ((float) frames[orgoneFramesIndex] - 32000)/ 32000.0;
                
                ONE_POLE(leftGain, leftGainTarget, 0.01);
                ONE_POLE(rightGain, rightGainTarget, 0.01);
         
                *outL++ += out * leftGain;
                *outR++ += out * rightGain;
                
                orgoneFramesIndex++;
                framesRemaining--;
            }
        }
    };
    
    // MARK: Member Functions
    
    OrgoneDSPKernel() : midiProcessor(kMaxPolyphony), modulationEngineRules(kNumModulationRules, NumModulationInputs, NumModulationOutputs)
    {
        KERNEL_DEBUG_LOG("Kernel constructor")
        
        voices.resize(kMaxPolyphony);
        for (VoiceState& voice : voices) {
            voice.kernel = this;
            voice.Init(&modulationEngineRules);
            midiProcessor.noteStack.addVoice(&voice);
        }
        envParameters[2] = UINT16_MAX;
        
    }
    
    void init(int channelCount, double inSampleRate) {
        KERNEL_DEBUG_LOG("Kernel init")
        if (outputSrc) {
            delete outputSrc;
        }
        outputSrc = new Converter(48000, (int) inSampleRate);
    }
    
    void setupModulationRules() {
        KERNEL_DEBUG_LOG("setupModulationRules")
        
        modulationEngineRules.rules[0].input1 = ModInLFO;
        modulationEngineRules.rules[1].input1 = ModInLFO;
        modulationEngineRules.rules[2].input1 = ModInEnvelope;
        modulationEngineRules.rules[3].input1 = ModInEnvelope;
    }
    
    void reset() {
        for (VoiceState& state : voices) {
            state.midiAllNotesOff();
        }
    }
    
    void setParameter(AUParameterAddress address, AUValue value) {
        if (address >= OrgoneParamModMatrixStart && address <= OrgoneParamModMatrixEnd) {
            modulationEngineRules.setParameter(address - OrgoneParamModMatrixStart, value);
            
            return;
        }
        
        if (voices[0].lfo.ownParameter(address)) {
            for (int i = 0; i < kMaxPolyphony; i++) {
                voices[i].lfo.setParameter(address, value);
            }
            return;
        }
        
        switch (address) {
            case OrgoneParamPosition:
                patch.pos = clamp(value, 0.0f, 1.0f) * 4095;
                break;
            case OrgoneParamEffect:
                patch.effect = clamp(value, 0.0f, 1.0f) * 2047;
                break;
            case OrgoneParamWaveLow:
                patch.waveLo = clamp(value, 0.0f, 1.0f) * INPUT_FACTOR;
                break;
            case OrgoneParamWaveMid:
                patch.waveMid = clamp(value, 0.0f, 1.0f) * INPUT_FACTOR;
                break;
            case OrgoneParamWaveHigh:
                patch.waveHi = clamp(value, 0.0f, 1.0f) * INPUT_FACTOR;
                break;
            case OrgoneParamModulation:
                patch.mod = clamp(value, 0.0f, 1.0f) * INPUT_FACTOR;
                break;
            case OrgoneParamIndex:
                patch.index = clamp(value, 0.0f, 1.0f) * INPUT_FACTOR;
                break;
            case OrgoneParamFreq:
                patch.freq = clamp(value, 0.0f, 1.0f) * INPUT_FACTOR;
                break;
            case OrgoneParamFXAlgorithm:
                patch.fx = round(clamp(value, 0.0f, 9.0f));
                break;
                
            case OrgoneParamPolyphony: {
                int newPolyphony = 1 + round(clamp(value, 0.0f, 7.0f));
                if (newPolyphony != midiProcessor.noteStack.getActivePolyphony()) {
                    midiProcessor.noteStack.setActivePolyphony(newPolyphony);
                }
                gainCoefficient = 1.0f / std::pow((float) newPolyphony, 0.35f);
                break;
            }
                
            case OrgoneParamUnison: {
                int unison = round(clamp(value, 0.0f, 1.0f)) == 1;
                midiProcessor.noteStack.setUnison(unison);
                break;
            }
                
            case OrgoneParamVolume:
                volume = clamp(value, 0.0f, 1.5f);
                break;
                
            case OrgoneParamSlop:
                slop = clamp(value, 0.0f, 1.0f);
                break;
                
            case OrgoneParamPan:
                pan = clamp(value, -1.0f, 1.0f);
                break;
                
            case OrgoneParamPanSpread:
                panSpread = clamp(value, 0.0f, 1.0f);
                break;
                
            case OrgoneParamPitchBendRange:
                bendRange = round(clamp(value, 0.0f, 12.0f));
                break;
                
            case OrgoneParamEnvAttack: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != envParameters[0]) {
                    envParameters[0] = newValue;
                    for (int i = 0; i < kMaxPolyphony; i++) {
                        voices[i].envelope.Configure(envParameters);
                    }
                }
                break;
            }
                
            case OrgoneParamEnvDecay: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != envParameters[1]) {
                    envParameters[1] = newValue;
                    for (int i = 0; i < kMaxPolyphony; i++) {
                        voices[i].envelope.Configure(envParameters);
                    }
                }
                break;
            }
                
            case OrgoneParamEnvSustain: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != envParameters[2]) {
                    envParameters[2] = newValue;
                    for (int i = 0; i < kMaxPolyphony; i++) {
                        voices[i].envelope.Configure(envParameters);
                    }
                }
                break;
            }
                
            case OrgoneParamEnvRelease: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != envParameters[3]) {
                    envParameters[3] = newValue;
                    for (int i = 0; i < kMaxPolyphony; i++) {
                        voices[i].envelope.Configure(envParameters);
                    }
                }
                break;
            }
                
            case OrgoneParamAmpEnvAttack: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != ampEnvParameters[0]) {
                    ampEnvParameters[0] = newValue;
                    for (int i = 0; i < kMaxPolyphony; i++) {
                        voices[i].ampEnvelope.Configure(ampEnvParameters);
                    }
                }
                break;
            }
                
            case OrgoneParamAmpEnvDecay: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != ampEnvParameters[1]) {
                    ampEnvParameters[1] = newValue;
                    for (int i = 0; i < kMaxPolyphony; i++) {
                        voices[i].ampEnvelope.Configure(ampEnvParameters);
                    }
                }
                break;
            }
                
            case OrgoneParamAmpEnvSustain: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != ampEnvParameters[2]) {
                    ampEnvParameters[2] = newValue;
                    for (int i = 0; i < kMaxPolyphony; i++) {
                        voices[i].ampEnvelope.Configure(ampEnvParameters);
                    }
                }
                break;
            }
                
            case OrgoneParamAmpEnvRelease: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != ampEnvParameters[3]) {
                    ampEnvParameters[3] = newValue;
                    for (int i = 0; i < kMaxPolyphony; i++) {
                        voices[i].ampEnvelope.Configure(ampEnvParameters);
                    }
                }
                break;
            }
                
            case OrgoneParamPortamento:
                portamento = clamp(value, 0.0f, 0.99999f);
                for (int i = 0; i < kMaxPolyphony; i++) {
                    voices[i].updatePortamento(0.0f);
                }
                break;
                
            case OrgoneParamPadX: {
                float padX = clamp(value, 0.0f, 1.0f);
                for (int i = 0; i < kMaxPolyphony; i++) {
                    voices[i].modEngine.in[ModInPadX] = padX;
                }
                break;
            }
                
            case OrgoneParamPadY:{
                float padY = clamp(value, 0.0f, 1.0f);
                for (int i = 0; i < kMaxPolyphony; i++) {
                    voices[i].modEngine.in[ModInPadY] = padY;
                }
                break;
            }
                
            case OrgoneParamPadGate:{
                float padGate = clamp(value, 0.0f, 1.0f);
                for (int i = 0; i < kMaxPolyphony; i++) {
                    voices[i].modEngine.in[ModInPadGate] = padGate;
                }
                break;
            }
        }
    }
    
    AUValue getParameter(AUParameterAddress address) {
        if (address >= OrgoneParamModMatrixStart && address <= OrgoneParamModMatrixEnd) {
            return modulationEngineRules.getParameter(address - OrgoneParamModMatrixStart);
        }
        
        if (voices[0].lfo.ownParameter(address)) {
            return voices[0].lfo.getParameter(address);
        }
        
        switch (address) {
            case OrgoneParamPosition:
                return ((float) patch.pos / 4095.0);

            case OrgoneParamEffect:
                return ((float) patch.effect / 2047.0);

            case OrgoneParamWaveLow:
                return ((float) patch.waveLo / INPUT_FACTOR);

            case OrgoneParamWaveMid:
                return ((float) patch.waveMid / INPUT_FACTOR);

            case OrgoneParamWaveHigh:
                return ((float) patch.waveHi / INPUT_FACTOR);

            case OrgoneParamModulation:
                return ((float) patch.mod / INPUT_FACTOR);

            case OrgoneParamIndex:
                return ((float) patch.index / INPUT_FACTOR);

            case OrgoneParamFreq:
                return ((float) patch.freq / INPUT_FACTOR);

            case OrgoneParamFXAlgorithm:
                return patch.fx;
                
            case OrgoneParamPitch:
                return (float) pitch;
                
            case OrgoneParamDetune:
                return detune;
                
            case OrgoneParamUnison:
                return midiProcessor.noteStack.getUnison() ? 1.0f : 0.0f;
                
            case OrgoneParamPolyphony:
                return (float) midiProcessor.noteStack.getActivePolyphony() - 1;
                
            case OrgoneParamVolume:
                return volume;
                
            case OrgoneParamSlop:
                return slop;
                
            case OrgoneParamPan:
                return pan;
                
            case OrgoneParamPanSpread:
                return panSpread;
                
            case OrgoneParamPitchBendRange:
                return (float) bendRange;
                
            case OrgoneParamEnvAttack:
                return ((float) envParameters[0]) / (float) UINT16_MAX;
                
            case OrgoneParamEnvDecay:
                return ((float) envParameters[1]) / (float) UINT16_MAX;
                
            case OrgoneParamEnvSustain:
                return ((float) envParameters[2]) / (float) UINT16_MAX;
                
            case OrgoneParamEnvRelease:
                return ((float) envParameters[3]) / (float) UINT16_MAX;
                
            case OrgoneParamAmpEnvAttack:
                return ((float) ampEnvParameters[0]) / (float) UINT16_MAX;
                
            case OrgoneParamAmpEnvDecay:
                return ((float) ampEnvParameters[1]) / (float) UINT16_MAX;
                
            case OrgoneParamAmpEnvSustain:
                return ((float) ampEnvParameters[2]) / (float) UINT16_MAX;
                
            case OrgoneParamAmpEnvRelease:
                return ((float) ampEnvParameters[3]) / (float) UINT16_MAX;

            case OrgoneParamPortamento:
                return portamento;
                
            case OrgoneParamPadX:
                return voices[0].modEngine.in[ModInPadX];
                
            case OrgoneParamPadY:
                return voices[0].modEngine.in[ModInPadY];
                
            case OrgoneParamPadGate:
                return voices[0].modEngine.in[ModInPadGate];
                
            default:
                return 0.0f;
        }
    }
    
    bool getParameterValueString(AUParameterAddress address, AUValue value, char *dst) {
        if (voices[0].lfo.ownParameter(address)) {
            return voices[0].lfo.getParameterValueString(address, value, dst);
        }
        
        return false;
    }
    
    void startRamp(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) override {
        // The attack and release parameters are not ramped.
        setParameter(address, value);
    }
    
    void setBuffers(AudioBufferList* outBufferList) {
        outBufferListPtr = outBufferList;
    }
    
    virtual void handleMIDIEvent(AUMIDIEvent const& midiEvent) override {
        midiProcessor.handleMIDIEvent(midiEvent);
    }
    
    void setTransportState(KernelTransportState state) {
        transportState = state;
        for (int i = 0; i < kMaxPolyphony; i++) {
            voices[i].lfo.setTransportState(&transportState);
        }
    }
    
    void process(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) override {
        float* outL = (float*)outBufferListPtr->mBuffers[0].mData + bufferOffset;
        float* outR = (float*)outBufferListPtr->mBuffers[1].mData + bufferOffset;
        
        int playingNotes = 0;
        
        while (frameCount > 0) {
            
            if (renderedFramesPos == kAudioBlockSize) {
                memset(renderedL, 0, sizeof(float) * kAudioBlockSize);
                memset(renderedR, 0, sizeof(float) * kAudioBlockSize);
                
                for (int i = 0; i < midiProcessor.noteStack.getActivePolyphony(); i++) {
                    if (voices[i].state != NoteStateUnused) {
                        playingNotes++;
                        
                        voices[i].run(kAudioBlockSize, renderedL, renderedR);
                    }
                }
                
                if (playingNotes > 0) {
                    for (int i = 0; i < kAudioBlockSize; i++) {
                        renderedL[i] *= gainCoefficient * volume;
                        renderedR[i] *= gainCoefficient * volume;
                    }
                }
                
                renderedFramesPos = 0;
            }
            
            ConverterResult result;
            
            outputSrc->convert(renderedL + renderedFramesPos, renderedR + renderedFramesPos, kAudioBlockSize - renderedFramesPos, outL, outR, frameCount, &result);
            
            outL += result.outputLength;
            outR += result.outputLength;
            
            renderedFramesPos += result.inputConsumed;
            frameCount -= result.outputLength;
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
    
    void drawLFO(float *points, int count) {
        voices[0].lfo.draw(points, count);
    }
    
    bool lfoDrawingDirty() {
        return voices[0].lfo.drawingDirty;
    }
    
    // MARK: Member Variables
    
private:
    std::vector<VoiceState> voices;
    
    AudioBufferList* outBufferListPtr = nullptr;
    
public:
    MIDIProcessor midiProcessor;
    orgone_patch_t patch;
    
    ModulationEngineRuleList modulationEngineRules;
    KernelTransportState transportState;
    
    Converter *outputSrc = 0;
    float renderedL[kAudioBlockSize] = {};
    float renderedR[kAudioBlockSize] = {};
    int renderedFramesPos = 0;
    
    uint16_t envParameters[4];
    uint16_t ampEnvParameters[4];
    
    bool lastPanSpreadWasNegative = 0;
    
    float bendRange = 0.0f;
    float slop = 0.0f;
    float volume = 1.0f;
    float gainCoefficient = 0.1f;
    float source = 0.0f;
    float sourceSpread = 1.0f;
    
    float pan = 0.0f;
    float panSpread = 0.0f;
    double portamento = 0.0f;
    
    int pitch = 0;
    float detune = 0;
};

#endif /* OrgoneDSPKernel_h */
