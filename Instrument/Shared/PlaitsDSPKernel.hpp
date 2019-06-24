//
//  PlaitsDSPKernel.hpp
//  Instrument
//
//  Created by tom on 2019-05-17.
//

#ifndef PlaitsDSPKernel_h
#define PlaitsDSPKernel_h

#import <vector>

#import "plaits/dsp/voice.h"
#import "peaks/multistage_envelope.h"
#import "stmlib/dsp/parameter_interpolator.h"
#import "lfo.hpp"

#import "converter.hpp"
#import "DSPKernel.hpp"

#import "MIDIProcessor.hpp"
#import "ModulationEngine.hpp"

const size_t kAudioBlockSize = 24;
const size_t kMaxPolyphony = 8;
const size_t kNumModulationRules = 12;

enum {
    PlaitsParamTimbre = 0,
    PlaitsParamHarmonics = 1,
    PlaitsParamMorph = 2,
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
    PlaitsParamLfoRate = 16,
    PlaitsParamLfoShape = 17,
    PlaitsParamLfoShapeMod = 18,
    PlaitsParamEnvAttack = 20,
    PlaitsParamEnvDecay = 21,
    PlaitsParamEnvSustain = 22,
    PlaitsParamEnvRelease = 23,
    PlaitsParamPitchBendRange = 24,
    PlaitsParamAmpEnvAttack = 28,
    PlaitsParamAmpEnvDecay = 29,
    PlaitsParamAmpEnvSustain = 30,
    PlaitsParamAmpEnvRelease = 31,
    PlaitsParamModMatrixStart = 39,
    PlaitsParamModMatrixEnd = 39 + (kNumModulationRules * 4), // 39 + 48 = 87
    PlaitsParamPortamento = 88,
    PlaitsParamPadX = 89,
    PlaitsParamPadY = 90,
    PlaitsParamPadGate = 91,
    PlaitsMaxParameters
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
    ModInAux,
    ModInPadX,
    ModInPadY,
    ModInPadGate,
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
    ModOutPortamento,
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
        float noteTarget;
        plaits::Voice::Frame frames[kAudioBlockSize];
        size_t plaitsFramesIndex;
        
        peaks::MultistageEnvelope envelope;
        peaks::MultistageEnvelope ampEnvelope;
        peaks::Lfo lfo;
        float lfoOutput;
        float out, aux;
        float rightGain, leftGain, rightGainTarget, leftGainTarget;
        float leftSource, rightSource, leftSourceTarget, rightSourceTarget;

        plaits::Voice *voice;
        plaits::Modulations modulations;
        ModulationEngine modEngine;
        
        float panSpread = 0;
        
        bool delayed_trigger = false;
        
        VoiceState() : modEngine(NumModulationInputs, NumModulationOutputs) { }
        
        void Init(ModulationEngineRuleList *rules) {
            voice = new plaits::Voice();
            stmlib::BufferAllocator allocator(ram_block, 16384);
            voice->Init(&allocator);
            plaitsFramesIndex = kAudioBlockSize;
            envelope.Init();
            ampEnvelope.Init();
            lfo.Init();
            modEngine.rules = rules;
            modEngine.in[ModInDirect] = 1.0f;
        }
        
        // ================ MIDIProcessor
        
        virtual void midiAllNotesOff() {
            modulations.trigger = 0.0f;
            modEngine.in[ModInGate] = 0.0f;
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
            modEngine.in[ModInGate] = 0.0f;

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
                modEngine.in[ModInGate] = 1.0f;
            } else if (state == NoteStateReleasing) {
                delayed_trigger = true;
            }
            state = NoteStatePlaying;
        }
        
        virtual void midiNoteOn(uint8_t noteNumber, uint8_t velocity)
        {
            if (state == NoteStateUnused) {
                memcpy(&modulations, &kernel->modulations, sizeof(plaits::Modulations));

                // TODO When stealing don't take new pan spread value
                panSpread = kernel->nextPanSpread();
            }
            
            noteTarget = float(noteNumber) + kernel->randomSignedFloat(kernel->slop) - 48.0f;

            note = noteNumber;
            modEngine.in[ModInNote] = ((float) note) / 127.0f;
            modEngine.in[ModInVelocity] = ((float) velocity) / 127.0f;
            
            add();
        }
        
        // === MODULATIONS
        
        void updateLfoRate(float modulationAmount) {
            float calculatedRate = clamp(kernel->lfoBaseRate + modulationAmount, 0.0f, 1.0f);
            uint16_t rateParameter = (uint16_t) (calculatedRate * (float) UINT16_MAX);
            lfo.set_rate(rateParameter);
        }
        
        void runModulations(int blockSize) {
            envelope.Process(blockSize);
            ampEnvelope.Process(blockSize);
        
            float lfoAmount = 1.0;
            if (kernel->lfoAmountIsPatched) {
                lfoAmount = modEngine.out[ModOutLFOAmount];
            }
            
            lfoOutput = lfoAmount * ((float) lfo.Process(blockSize)) / INT16_MAX;
            
            modEngine.in[ModInLFO] = lfoOutput;
            modEngine.in[ModInEnvelope] = envelope.value;
            modEngine.in[ModInOut] = out;
            modEngine.in[ModInAux] = aux;
            modEngine.in[ModInModwheel] = kernel->midiProcessor.modwheelAmount;
            
            ONE_POLE(modulations.note, noteTarget, 1.0f - clamp(kernel->portamento + modEngine.out[ModOutPortamento], 0.0f, 0.995f));

            modEngine.run();
            
            if (kernel->lfoRateIsPatched) {
                updateLfoRate(modEngine.out[ModOutLFORate]);
            }
            
            modulations.engine = modEngine.out[ModOutEngine];
            modulations.frequency = kernel->modulations.frequency + modEngine.out[ModOutTune] + (modEngine.out[ModOutFrequency] * 120.0f);
            
            modulations.harmonics = kernel->modulations.harmonics + modEngine.out[ModOutHarmonics];
            
            modulations.timbre = kernel->modulations.timbre + modEngine.out[ModOutTimbre];
            
            modulations.morph = kernel->modulations.morph + modEngine.out[ModOutMorph];
            
            modulations.level = ampEnvelope.value + modEngine.out[ModOutLevel];
            
            leftSourceTarget = (1.0f + clamp(kernel->leftSource + modEngine.out[ModOutLeftSource], -1.0f, 1.0f)) / 2.0f;
            rightSourceTarget = (1.0f + clamp(kernel->rightSource + modEngine.out[ModOutRightSource], -1.0f, 1.0f)) / 2.0f;
            
            float pan = clamp(kernel->pan + modEngine.out[ModOutPan] + panSpread, -1.0f, 1.0f);
            if (pan > 0) {
                rightGainTarget = 1.0f;
                leftGainTarget = 1.0f - pan;
            } else {
                leftGainTarget = 1.0f;
                rightGainTarget = 1.0f + pan;
            }
        }
        
        void run(int n, float* outL, float* outR)
        {
            int framesRemaining = n;
            
            while (framesRemaining) {
                if (plaitsFramesIndex >= kAudioBlockSize) {
                    
                    if (state == NoteStateReleasing && !voice->lpg_active()) {
                        state = NoteStateUnused;
                    }
                    
                    runModulations(kAudioBlockSize);
                    
                    voice->Render(kernel->patch, modulations, &frames[0], kAudioBlockSize);
                    plaitsFramesIndex = 0;
                    
                    if (delayed_trigger) {
                        delayed_trigger = false;
                        modulations.trigger = 1.0f;
                        envelope.TriggerHigh();
                        ampEnvelope.TriggerHigh();
                        modEngine.in[ModInGate] = 1.0f;

                    }
                }
                
                out = ((float) frames[plaitsFramesIndex].out) / ((float) INT16_MAX);
                aux = ((float) frames[plaitsFramesIndex].aux) / ((float) INT16_MAX);
                ONE_POLE(leftSource, leftSourceTarget, 0.01);
                ONE_POLE(rightSource, rightSourceTarget, 0.01);
                ONE_POLE(leftGain, leftGainTarget, 0.01);
                ONE_POLE(rightGain, rightGainTarget, 0.01);
                
                *outL++ += ((out * (1.0f - leftSource)) + (aux * (leftSource))) * leftGain;
                *outR++ += ((out * (1.0f - rightSource)) + (aux * (rightSource))) * rightGain;
                
                plaitsFramesIndex++;
                framesRemaining--;
            }
        }
    };
    
    // MARK: Member Functions
    
    PlaitsDSPKernel() : midiProcessor(kMaxPolyphony), modulationEngineRules(kNumModulationRules)
    {
        voices.resize(kMaxPolyphony);
        for (VoiceState& voice : voices) {
            voice.kernel = this;
            voice.Init(&modulationEngineRules);
            midiProcessor.noteStack.voices.push_back(&voice);
        }
        envParameters[2] = UINT16_MAX;
        
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
        modulations.level_patched = true;
    }
    
    void init(int channelCount, double inSampleRate) {
        if (outputSrc) {
            delete outputSrc;
        }
        outputSrc = new Converter(48000, (int) inSampleRate);
        
        modulationEngineRules.rules[0].input1 = ModInLFO;
        modulationEngineRules.rules[1].input1 = ModInLFO;
        modulationEngineRules.rules[2].input1 = ModInEnvelope;
        modulationEngineRules.rules[3].input1 = ModInEnvelope;
        modulationEngineRules.rules[4].input1 = ModInPadX;
        modulationEngineRules.rules[4].input2 = ModInPadGate;
        modulationEngineRules.rules[5].input1 = ModInPadY;
        modulationEngineRules.rules[5].input2 = ModInPadGate;
    }
    
    void reset() {
        for (VoiceState& state : voices) {
            state.midiAllNotesOff();
        }
    }
    
    void setParameter(AUParameterAddress address, AUValue value) {
        if (address >= PlaitsParamModMatrixStart && address <= PlaitsParamModMatrixEnd) {
            modulationEngineRules.setParameter(address - PlaitsParamModMatrixStart, value);
            lfoRateIsPatched = modulationEngineRules.isPatched(ModOutLFORate);
            lfoAmountIsPatched = modulationEngineRules.isPatched(ModOutLFOAmount);
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
                pitch = round(clamp(value, -12.0f, 12.0f));
                patch.note = 48.0f + pitch + detune;
                break;
                
            case PlaitsParamDetune:
                detune = clamp(value, -1.0f, 1.0f);
                patch.note = 48.0f + pitch + detune;
                break;
                
            case PlaitsParamLPGColour:
                patch.lpg_colour = clamp(value, 0.0f, 1.0f);
                break;
                
            case PlaitsParamPolyphony: {
                int newPolyphony = 1 + round(clamp(value, 0.0f, 7.0f));
                if (newPolyphony != midiProcessor.noteStack.getActivePolyphony()) {
                    midiProcessor.noteStack.setActivePolyphony(newPolyphony);
                    gainCoefficient = 1.0f / (float) newPolyphony;
                }
                break;
            }
                
            case PlaitsParamUnison: {
                int unison = round(clamp(value, 0.0f, 1.0f)) == 1;
                midiProcessor.noteStack.setUnison(unison);
                break;
            }
                
            case PlaitsParamVolume:
                volume = clamp(value, 0.0f, 2.0f);
                break;
                
            case PlaitsParamSlop:
                slop = clamp(value, 0.0f, 1.0f);
                break;
                
            case PlaitsParamLeftSource:
                leftSource = clamp(value, -1.0f, 1.0f);
                break;
            
            case PlaitsParamRightSource:
                rightSource = clamp(value, -1.0f, 1.0f);
                break;
                
            case PlaitsParamPan:
                pan = clamp(value, -1.0f, 1.0f);
                break;
                
            case PlaitsParamPanSpread:
                panSpread = clamp(value, 0.0f, 1.0f);
                break;
                
            case PlaitsParamLfoShape: {
                uint16_t newShape = round(clamp(value, 0.0f, 4.0f));
                if (newShape != lfoShape) {
                    lfoShape = newShape;
                    for (int i = 0; i < kMaxPolyphony; i++) {
                        voices[i].lfo.set_shape((peaks::LfoShape) lfoShape);
                    }
                }
                break;
            }
                
            case PlaitsParamLfoShapeMod: {
                float newShape = clamp(value, -1.0f, 1.0f);
                if (newShape != lfoShapeMod) {
                    lfoShapeMod = newShape;
                    uint16_t par = (newShape * 32767.0f);
                    for (int i = 0; i < kMaxPolyphony; i++) {
                        voices[i].lfo.set_parameter(par);
                    }
                }
                break;
            }
                
            case PlaitsParamLfoRate: {
                float newRate = clamp(value, 0.0f, 1.0f);

                if (newRate != lfoBaseRate) {
                    lfoBaseRate = newRate;
                    for (int i = 0; i < kMaxPolyphony; i++) {
                        voices[i].updateLfoRate(0.0f);
                    }
                }
                break;
            }
                
            case PlaitsParamPitchBendRange:
                midiProcessor.bendRange = round(clamp(value, 0.0f, 12.0f));
                break;
            
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
                patch.decay = clamp(value, 0.0f, 1.0f);
                break;
            }
                
            case PlaitsParamPortamento:
                portamento = clamp(value, 0.0f, 0.995f);
                break;
                
            case PlaitsParamPadX: {
                float padX = clamp(value, 0.0f, 1.0f);
                for (int i = 0; i < kMaxPolyphony; i++) {
                    voices[i].modEngine.in[ModInPadX] = padX;
                }
                break;
            }
                
            case PlaitsParamPadY:{
                float padY = clamp(value, 0.0f, 1.0f);
                for (int i = 0; i < kMaxPolyphony; i++) {
                    voices[i].modEngine.in[ModInPadY] = padY;
                }
                break;
            }
                
            case PlaitsParamPadGate:{
                float padGate = clamp(value, 0.0f, 1.0f);
                for (int i = 0; i < kMaxPolyphony; i++) {
                    voices[i].modEngine.in[ModInPadGate] = padGate;
                }
                break;
            }
        }
    }
    
    AUValue getParameter(AUParameterAddress address) {
        if (address >= PlaitsParamModMatrixStart && address <= PlaitsParamModMatrixEnd) {
            return modulationEngineRules.getParameter(address - PlaitsParamModMatrixStart);
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
                return (float) pitch;
                
            case PlaitsParamDetune:
                return detune;
                
            case PlaitsParamLPGColour:
                return patch.lpg_colour;
                
            case PlaitsParamUnison:
                return midiProcessor.noteStack.getUnison() ? 1.0f : 0.0f;
                
            case PlaitsParamPolyphony:
                return (float) midiProcessor.noteStack.getActivePolyphony() - 1;
                
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
                
            case PlaitsParamLfoRate:
                return lfoBaseRate;
                
            case PlaitsParamLfoShape:
                return lfoShape;
                
            case PlaitsParamLfoShapeMod:
                return lfoShapeMod;
                
            case PlaitsParamPitchBendRange:
                return (float) midiProcessor.bendRange;
                
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
                return patch.decay;
                
            case PlaitsParamPortamento:
                return portamento;
                
            case PlaitsParamPadX:
                return voices[0].modEngine.in[ModInPadX];
                
            case PlaitsParamPadY:
                return voices[0].modEngine.in[ModInPadY];

            case PlaitsParamPadGate:
                return voices[0].modEngine.in[ModInPadGate];
                
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
        midiProcessor.handleMIDIEvent(midiEvent);
    }
    
    void process(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) override {
        float* outL = (float*)outBufferListPtr->mBuffers[0].mData + bufferOffset;
        float* outR = (float*)outBufferListPtr->mBuffers[1].mData + bufferOffset;
        
        int playingNotes = 0;
        
        while (frameCount > 0) {
            
            if (renderedFramesPos == kAudioBlockSize) {
                modulations.frequency = midiProcessor.bendAmount;
                
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
    MIDIProcessor midiProcessor;

    ModulationEngineRuleList modulationEngineRules;
    bool lfoRateIsPatched = false;
    bool lfoAmountIsPatched = false;
    
    plaits::Modulations modulations;
    plaits::Patch patch;
    
    Converter *outputSrc = 0;
    float renderedL[kAudioBlockSize] = {};
    float renderedR[kAudioBlockSize] = {};
    int renderedFramesPos = 0;
    
    uint16_t envParameters[4];
    uint16_t ampEnvParameters[4];
    
    float lfoBaseRate;
    float lfoShape;
    float lfoShapeMod;
    
    bool lastPanSpreadWasNegative = 0;
    
    float slop = 0.0f;
    float volume = 1.0f;
    float gainCoefficient = 0.1f;
    float leftSource = 0.0f;
    float rightSource = 1.0f;
    
    float pan = 0.0f;
    float panSpread = 0.0f;
    float portamento = 0.0f;
    
    int pitch = 0;
    float detune = 0;
};

#endif /* PlaitsDSPKernel_h */
