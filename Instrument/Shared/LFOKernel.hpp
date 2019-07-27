//
//  LFOKernel.hpp
//  Spectrum
//
//  Created by tom on 2019-07-18.
//

#ifndef LFOKernel_h
#define LFOKernel_h

#import "lfo.hpp"
#import "KernelTransportState.h"

typedef struct {
    const char *name;
    double beatFrequency;
    double beatsPerCycle;
} syncedLfoRate;

const int numLFORates = 8;

const syncedLfoRate lfoRates[numLFORates] = {
    {"1/4", 1.0, 1},
    {"1/4T", 2.0 / 3.0, 2},
    {"1/8", 1.0 / 2.0, 1},
    {"1/8T", 1.0 / 3.0, 1},
    {"1/16", 1.0 / 4.0, 1},
    {"1/16T", 1.0 / 6.0, 1},
    {"1/32", 1.0 / 8.0, 1},
    {"1/32T", 1.0 / 12.0, 1},
};

class LFOKernel {
    
public:
    LFOKernel(AUParameterAddress rate, AUParameterAddress shape, AUParameterAddress shapeMod, AUParameterAddress tempoSync, AUParameterAddress resetPhase, AUParameterAddress keyReset) {
        rateAddress = rate;
        shapeAddress = shape;
        shapeModAddress = shapeMod;
        tempoSyncAddress = tempoSync;
        resetPhaseAddress = resetPhase;
        keyResetAddress = keyReset;
        sync = true;
    }
    
    ~LFOKernel() {
        
    }
    
    void Init(double sampleRate) {
        this->sampleRate = sampleRate;
        
        lfo.Init();
    }
    
    bool ownParameter(AUParameterAddress address) {
        return address == rateAddress || address == shapeAddress || address == shapeModAddress || address == resetPhaseAddress || address == tempoSyncAddress || address == keyResetAddress;
    }
    
    void setParameter(AUParameterAddress address, AUValue value) {
        if (address == shapeAddress) {
            uint16_t newShape = round(clamp(value, 0.0f, 4.0f));
            if (newShape != shape) {
                shape = newShape;
                lfo.set_shape((peaks::LfoShape) shape);
            }
        } else if (address == shapeModAddress) {
            float newShape = clamp(value, -1.0f, 1.0f);
            if (newShape != shapeMod) {
                shapeMod = newShape;
                uint16_t par = (newShape * 32767.0f);
                lfo.set_parameter(par);
            }
        } else if (address == rateAddress) {
            float newRate = clamp(value, 0.0f, 1.0f);
            
            if (newRate != baseRate) {
                baseRate = newRate;
                updateRate(0.0f);
            }
        } else if (address == tempoSyncAddress) {
            sync = (value > 0.9f);
        } else if (address == resetPhaseAddress) {
            resetPhase = clamp(value, 0.0f, 1.0f);
            lfo.reset_phase_ = value * ((float) UINT32_MAX);
        } else if (address == keyResetAddress) {
            keyReset = (value > 0.9f);
        }
    }
    
    AUValue getParameter(AUParameterAddress address) {
        if (address == rateAddress) {
            return baseRate;
        } else if (address == shapeAddress) {
            return shape;
        } else if (address == shapeModAddress) {
            return shapeMod;
        } else if (address == tempoSyncAddress) {
            return sync ? 1.0f : 0.0f;
        } else if (address == resetPhaseAddress) {
            return resetPhase;
        } else if (address == keyResetAddress) {
            return keyReset ? 1.0f : 0.0f;
        }
        return 0.0f;
    }
    
    void updateRate(float modulationAmount) {
        float calculatedRate = clamp(baseRate + modulationAmount, 0.0f, 1.0f);
        
        uint16_t rateParameter = (uint16_t) (calculatedRate * (float) UINT16_MAX);
        lfo.set_rate(rateParameter);
        
        syncRateIndex = (int) (calculatedRate * (numLFORates - 1));
    }
    
    void setTransportState(KernelTransportState *state) {
        transportState = state;
        
        if (sync) {
            int startOfCycle = (transportState->currentBeatPosition / lfoRates[syncRateIndex].beatsPerCycle) * lfoRates[syncRateIndex].beatsPerCycle;
            double position = transportState->currentBeatPosition - (double) startOfCycle;
            
            double lfoPhase = position / lfoRates[syncRateIndex].beatFrequency;
            
            lfo.phase_ = (lfo.reset_phase_ + (uint64_t) (UINT32_MAX * lfoPhase)) & 0xffffffff;
            
        }
        double lfoRate = 60.0 * sampleRate / transportState->currentTempo * lfoRates[syncRateIndex].beatFrequency;
        
        phaseIncrement = UINT32_MAX / lfoRate;
    }
    
    void trigger() {
        if (keyReset && !sync) {
            lfo.phase_ = lfo.reset_phase_;
        }
    }
    
    float process(int blockSize) {
        if (sync) {
            return ((float) lfo.Process(blockSize, phaseIncrement)) / INT16_MAX;
        }
        return ((float) lfo.Process(blockSize)) / INT16_MAX;
    }
    
    AUParameterAddress shapeAddress;
    AUParameterAddress shapeModAddress;
    AUParameterAddress rateAddress;
    AUParameterAddress tempoSyncAddress;
    AUParameterAddress resetPhaseAddress;
    AUParameterAddress keyResetAddress;
    
    KernelTransportState *transportState;
        
    peaks::Lfo lfo;
    float output;
    float baseRate;
    float shape;
    float shapeMod;
    float baseAmount;
    
    bool sync;
    float resetPhase;
    bool keyReset;
    
    double sampleRate;
    int syncRateIndex;
    uint32_t phaseIncrement;
};

#endif /* LFOKernel_h */
