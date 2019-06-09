//
//  PlaitsDSPKernel.hpp
//  Instrument
//
//  Created by tom on 2019-05-17.
//

#ifndef PlaitsDSPKernel_h
#define PlaitsDSPKernel_h

#import "resampler.hpp"
#import "MIDIProcessor.hpp"
#import "ModulationEngine.hpp"
#import "peaks/multistage_envelope.h"
#import "DSPKernel.hpp"
#import <vector>
#import "plaits/dsp/voice.h"
#import "lfo.hpp"

const size_t kAudioBlockSize = 24;
const size_t kMaxPolyphony = 8;
const size_t kNumModulationRules = 3;

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
    PlaitsParamModMatrixStart = 39,
    PlaitsParamModMatrixEnd = 39 + (kNumModulationRules * 4), // 39 + 12 = 51
    PlaitsParamQuality = 52,
    PlaitsMaxParameters
};

enum {
    ModInDirect = 0,
    ModInLFO,
    ModInEnvelope,
    ModInNote,
    ModInVelocity,
    ModInModwheel,
    ModInOut,
    ModInAux,
    NumModulationInputs
};

enum {
    ModOutDisabled = 0,
    ModOutTune,
    ModOutFrequency,
    ModOutHarmonics,
    ModOutTimbre,
    ModOutMorph,
    ModOutEngine,
    ModOutLFORate,
    ModOutLFOAmount,
    ModOutLeftSource,
    ModOutRightSource,
    ModOutPan,
    ModOutLevel,
    NumModulationOutputs
};

/*
 InstrumentDSPKernel
 Performs our filter signal processing.
 As a non-ObjC class, this is safe to use from render thread.
 */
class PlaitsDSPKernel : public DSPKernel {
public:
    // MARK: Types
    class VoiceState: public MIDIVoice {
    public:
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
        float out, aux;
        float rightGain, leftGain;
        float leftSource, rightSource;

        plaits::Voice *voice;
        plaits::Modulations modulations;
        ModulationEngine *modEngine;
        
        float panSpread = 0;
        
        bool delayed_trigger = false;
        
        void Init(ModulationEngineRuleList *rules) {
            voice = new plaits::Voice();
            stmlib::BufferAllocator allocator(ram_block, 16384);
            voice->Init(&allocator);
            plaitsFramesIndex = kAudioBlockSize;
            envelope.Init();
            ampEnvelope.Init();
            lfo.Init();
            modEngine = new ModulationEngine(NumModulationInputs, NumModulationOutputs);
            modEngine->rules = rules;
            modEngine->in[ModInDirect] = 1.0f;
        }
        
        virtual void midiAllNotesOff() {
            modulations.trigger = 0.0f;
            envelope.value = 0;
            ampEnvelope.value = 0;
            envelope.TriggerLow();
            ampEnvelope.TriggerLow();
            state = NoteStateUnused;
            plaitsFramesIndex = kAudioBlockSize;
        }
        
        // linked list management
        virtual void midiNoteOff() {
            modulations.trigger = 0.0f;
            envelope.TriggerLow();
            ampEnvelope.TriggerLow();

            state = NoteStateReleasing;
        }
        
        virtual uint8_t Note() {
            return note;
        }
        
        virtual int State() {
            return state;
        }
        
        void add() {
            if (state == NoteStateUnused) {
                modulations.trigger = 1.0f;
                envelope.TriggerHigh();
                ampEnvelope.TriggerHigh();
            } else {
                delayed_trigger = true;
            }
            state = NoteStatePlaying;
        }
        
        virtual void midiNoteOn(uint8_t noteNumber, uint8_t velocity)
        {
            if (velocity == 0) {
                if (state == NoteStatePlaying) {
                    midiNoteOff();
                }
            } else {
                memcpy(&modulations, &kernel->modulations, sizeof(plaits::Modulations));
                
                modulations.note = float(noteNumber) + kernel->randomSignedFloat(kernel->slop) - 48.0f;
                // TODO When stealing don't take new pan spread value
                panSpread = kernel->nextPanSpread();

                note = noteNumber;
                modEngine->in[ModInNote] = ((float) note) / 127.0f;
                modEngine->in[ModInVelocity] = ((float) velocity) / 127.0f;
                
                add();
            }
        }
        
        void updateLfoRate(float modulationAmount) {
            float calculatedRate = clamp(kernel->lfoBaseRate + modulationAmount, 0.0f, 1.0f);
            uint16_t rateParameter = (uint16_t) (calculatedRate * (float) UINT16_MAX);
            lfo.set_rate(rateParameter);
        }
        
        void runModulations(int blockSize) {
            envelope.Process(blockSize);
            ampEnvelope.Process(blockSize);
        
            lfoOutput = ((float) lfo.Process(kAudioBlockSize)) / INT16_MAX;
            
            modEngine->in[ModInLFO] = lfoOutput;
            modEngine->in[ModInEnvelope] = envelope.value;
            modEngine->in[ModInOut] = out;
            modEngine->in[ModInAux] = aux;
            modEngine->in[ModInModwheel] = kernel->midiProcessor->modwheelAmount;
            
            modEngine->run();
            
            if (kernel->lfoRateIsPatched || kernel->envAmountLfoRate > 0.0f) {
                updateLfoRate(modEngine->out[ModOutLFORate] + (envelope.value * kernel->envAmountLfoRate));
            }
            
            float lfoAmount = kernel->lfoAmount + modEngine->out[ModOutLFOAmount] + (envelope.value * kernel->envAmountLfoAmount);
            
            modulations.engine = modEngine->out[ModOutEngine];
            modulations.frequency = kernel->modulations.frequency + modEngine->out[ModOutTune] + (modEngine->out[ModOutFrequency] * 120.0f) + (lfoOutput * kernel->lfoAmountFM * lfoAmount) + (envelope.value * kernel->envAmountFM);
            
            modulations.harmonics = kernel->modulations.harmonics + modEngine->out[ModOutHarmonics] + lfoOutput * kernel->lfoAmountHarmonics * lfoAmount + (envelope.value * kernel->envAmountHarmonics);
            
            modulations.timbre = kernel->modulations.timbre + modEngine->out[ModOutTimbre] + lfoOutput * kernel->lfoAmountTimbre * lfoAmount + (envelope.value * kernel->envAmountTimbre);
            
            modulations.morph = kernel->modulations.morph + modEngine->out[ModOutMorph] + lfoOutput * kernel->lfoAmountMorph * lfoAmount + (envelope.value * kernel->envAmountMorph);
            
            if (kernel->ampSource == 1) {
                modulations.level = ampEnvelope.value;
            } else if (kernel->ampSource == 2){
                modulations.level = 1.0f;
            }
            
            modulations.level += modEngine->out[ModOutLevel];
            
            leftSource = clamp(kernel->leftSource + modEngine->out[ModOutLeftSource], 0.0f, 1.0f);
            rightSource = clamp(kernel->rightSource + modEngine->out[ModOutRightSource], 0.0f, 1.0f);
            
            float pan = clamp(kernel->pan + modEngine->out[ModOutPan] + panSpread, -1.0f, 1.0f);
            if (pan > 0) {
                rightGain = 1.0f;
                leftGain = 1.0f - pan;
            } else {
                leftGain = 1.0f;
                rightGain = 1.0f + pan;
            }
        }
        
        void run(int n, float* outL, float* outR)
        {
            int framesRemaining = n;
            
            while (framesRemaining) {
                if (plaitsFramesIndex >= kAudioBlockSize) {
                    
                    runModulations(kAudioBlockSize);
                    
                    voice->Render(kernel->patch, modulations, &frames[0], kAudioBlockSize);
                    plaitsFramesIndex = 0;
                    
                    if (delayed_trigger) {
                        delayed_trigger = false;
                        modulations.trigger = 1.0f;
                        envelope.TriggerHigh();
                        ampEnvelope.TriggerHigh();
                    }
                    
                    if (state == NoteStateReleasing) {
                        if ((kernel->ampSource == 0 && !voice->lpg_active())
                            || (kernel->ampSource == 1 && ampEnvelope.value_ == 0)) {
                            state = NoteStateUnused;
                        }
                    }
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
        midiProcessor = new MIDIProcessor(kMaxPolyphony);
        voices.resize(kMaxPolyphony);
        modulationEngineRules = new ModulationEngineRuleList(kNumModulationRules);
        for (VoiceState& voice : voices) {
            voice.kernel = this;
            voice.Init(modulationEngineRules);
            midiProcessor->voices.push_back(&voice);
        }
        lfoParameters[2] = lfoParameters[3] = 32768;
        envParameters[2] = UINT16_MAX;
    }
    
    void init(int channelCount, double inSampleRate) {
        outputSrc.setRates(48000, (int) inSampleRate);

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
            state.midiAllNotesOff();
        }
    }
    
    void setParameter(AUParameterAddress address, AUValue value) {
        if (address >= PlaitsParamModMatrixStart && address <= PlaitsParamModMatrixEnd) {
            modulationEngineRules->setParameter(address - PlaitsParamModMatrixStart, value);
            lfoRateIsPatched = modulationEngineRules->isPatched(ModOutLFORate);
            return;
        }
        
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
                if (newPolyphony != midiProcessor->getActivePolyphony()) {
                    midiProcessor->setActivePolyphony(newPolyphony);
                    gainCoefficient = 1.0f / (float) newPolyphony;
                }
                break;
            }
                
            case PlaitsParamUnison: {
                int unison = round(clamp(value, 0.0f, 1.0f)) == 1;
                midiProcessor->setUnison(unison);
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
                    for (int i = 0; i < kMaxPolyphony; i++) {
                        voices[i].lfo.Configure(lfoParameters);
                    }
                }
                break;
            }
                
            case PlaitsParamLfoRate: {
                lfoBaseRate = clamp(value, 0.0f, 1.0f);
                uint16_t newRate = (uint16_t) (lfoBaseRate * (float) UINT16_MAX);

                if (newRate != lfoParameters[0]) {
                    lfoParameters[0] = newRate;
                    for (int i = 0; i < kMaxPolyphony; i++) {
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
                midiProcessor->bendRange = round(clamp(value, 0.0f, 12.0f));
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
                    }
                }
                break;
            }
            
            case PlaitsParamEnvAttack: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != envParameters[0]) {
                    envParameters[0] = newValue;
                    for (int i = 0; i < kMaxPolyphony; i++) {
                        voices[i].envelope.Configure(envParameters);
                    }
                }
                break;
            }
                
            case PlaitsParamEnvDecay: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != envParameters[1]) {
                    envParameters[1] = newValue;
                    for (int i = 0; i < kMaxPolyphony; i++) {
                        voices[i].envelope.Configure(envParameters);
                    }
                }
                break;
            }
                
            case PlaitsParamEnvSustain: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != envParameters[2]) {
                    envParameters[2] = newValue;
                    for (int i = 0; i < kMaxPolyphony; i++) {
                        voices[i].envelope.Configure(envParameters);
                    }
                }
                break;
            }
                
            case PlaitsParamEnvRelease: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != envParameters[3]) {
                    envParameters[3] = newValue;
                    for (int i = 0; i < kMaxPolyphony; i++) {
                        voices[i].envelope.Configure(envParameters);
                    }
                }
                break;
            }
                
            case PlaitsParamAmpEnvAttack: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != ampEnvParameters[0]) {
                    ampEnvParameters[0] = newValue;
                    for (int i = 0; i < kMaxPolyphony; i++) {
                        voices[i].ampEnvelope.Configure(ampEnvParameters);
                    }
                }
                break;
            }
                
            case PlaitsParamAmpEnvDecay: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != ampEnvParameters[1]) {
                    ampEnvParameters[1] = newValue;
                    for (int i = 0; i < kMaxPolyphony; i++) {
                        voices[i].ampEnvelope.Configure(ampEnvParameters);
                    }
                }
                break;
            }
                
            case PlaitsParamAmpEnvSustain: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != ampEnvParameters[2]) {
                    ampEnvParameters[2] = newValue;
                    for (int i = 0; i < kMaxPolyphony; i++) {
                        voices[i].ampEnvelope.Configure(ampEnvParameters);
                    }
                }
                break;
            }
                
            case PlaitsParamAmpEnvRelease: {
                uint16_t newValue = (uint16_t) (clamp(value, 0.0f, 1.0f) * (float) UINT16_MAX);
                if (newValue != ampEnvParameters[3]) {
                    ampEnvParameters[3] = newValue;
                    for (int i = 0; i < kMaxPolyphony; i++) {
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
                
            case PlaitsParamQuality:
                outputSrc.setQuality((int) clamp(value, 0.0f, 10.0f));
                break;
                
        }
    }
    
    AUValue getParameter(AUParameterAddress address) {
        if (address >= PlaitsParamModMatrixStart && address <= PlaitsParamModMatrixEnd) {
            return modulationEngineRules->getParameter(address - PlaitsParamModMatrixStart);
        }
        
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
                return midiProcessor->getUnison() ? 1.0f : 0.0f;
                
            case PlaitsParamPolyphony:
                return (float) midiProcessor->getActivePolyphony() - 1;
                
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
                return (float) midiProcessor->bendRange;
                
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
                
            case PlaitsParamQuality:
                return outputSrc.quality;
                
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
        midiProcessor->handleMIDIEvent(midiEvent);
    }
    
    void process(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) override {
        float* outL = (float*)outBufferListPtr->mBuffers[0].mData + bufferOffset;
        float* outR = (float*)outBufferListPtr->mBuffers[1].mData + bufferOffset;
        
        int playingNotes = 0;
        
        while (frameCount > 0) {
            if (outputBuffer.empty()) {
                float left[kAudioBlockSize] = {};
                float right[kAudioBlockSize] = {};
                
                modulations.frequency = midiProcessor->bendAmount;
                
                for (int i = 0; i < midiProcessor->getActivePolyphony(); i++) {
                    if (voices[i].state != NoteStateUnused) {
                        playingNotes++;
                        
                        voices[i].run(kAudioBlockSize, left, right);
                    }
                }
                
                if (playingNotes > 0) {
                    for (int i = 0; i < kAudioBlockSize; i++) {
                        left[i] *= gainCoefficient * volume;
                        right[i] *= gainCoefficient * volume;
                    }
                }
                
                rack::Frame<2> outputFrames[kAudioBlockSize];
                for (int i = 0; i < kAudioBlockSize; i++) {
                    outputFrames[i].samples[0] = left[i];
                    outputFrames[i].samples[1] = right[i];
                }
                
                int inLen = kAudioBlockSize;
                int outLen = (int) outputBuffer.capacity();
                outputSrc.process(outputFrames, &inLen, outputBuffer.endData(), &outLen);
                outputBuffer.endIncr(outLen);
            }
                
            rack::Frame<2> outputFrame = outputBuffer.shift();
            
            *outL++ += outputFrame.samples[0];
            *outR++ += outputFrame.samples[1];
            
            frameCount--;
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
    
    AudioBufferList* outBufferListPtr = nullptr;
    
public:
    MIDIProcessor *midiProcessor;

    ModulationEngineRuleList *modulationEngineRules;
    bool lfoRateIsPatched = false;
    
    plaits::Modulations modulations;
    plaits::Patch patch;
    
    rack::SampleRateConverter<2> outputSrc;
    rack::DoubleRingBuffer<rack::Frame<2>, 256> outputBuffer;
    
    uint16_t envParameters[4];
    uint16_t ampEnvParameters[4];

    uint16_t lfoParameters[4];
    
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
    
    bool lastPanSpreadWasNegative = 0;
    
    float slop = 0.0f;
    float volume = 1.0f;
    float gainCoefficient = 0.1f;
    float leftSource = 0.0f;
    float rightSource = 1.0f;
    float pan = 0.0f;
    float panSpread = 0.0f;
    
    int pitch = 0;
    float detune = 0;
    
    int ampSource;
};

#endif /* PlaitsDSPKernel_h */
