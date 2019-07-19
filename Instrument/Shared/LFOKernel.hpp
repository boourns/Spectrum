//
//  LFOKernel.hpp
//  Spectrum
//
//  Created by tom on 2019-07-18.
//

#ifndef LFOKernel_h
#define LFOKernel_h

#import "lfo.hpp"

class LFOKernel {
    
public:
    LFOKernel(AUParameterAddress rate, AUParameterAddress shape, AUParameterAddress shapeMod) {
        rateAddress = rate;
        shapeAddress = shape;
        shapeModAddress = shapeMod;
    }
    
    ~LFOKernel() {
        
    }
    
    void Init() {
        lfo.Init();
    }
    
    bool ownParameter(AUParameterAddress address) {
        return address == rateAddress || address == shapeAddress || address == shapeModAddress;
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
        }
    }
    
    AUValue getParameter(AUParameterAddress address) {
        if (address == rateAddress) {
            return baseRate;
        } else if (address == shapeAddress) {
            return shape;
        } else if (address == shapeModAddress) {
            return shapeMod;
        }
        return 0.0f;
    }
    
    void updateRate(float modulationAmount) {
        float calculatedRate = clamp(baseRate + modulationAmount, 0.0f, 1.0f);
        uint16_t rateParameter = (uint16_t) (calculatedRate * (float) UINT16_MAX);
        lfo.set_rate(rateParameter);
    }
    
    float process(int blockSize) {
        return ((float) lfo.Process(blockSize)) / INT16_MAX;
    }
    
    AUParameterAddress shapeAddress;
    AUParameterAddress shapeModAddress;
    AUParameterAddress rateAddress;
        
    peaks::Lfo lfo;
    float output;
    float baseRate;
    float shape;
    float shapeMod;
    float baseAmount;
};

#endif /* LFOKernel_h */
