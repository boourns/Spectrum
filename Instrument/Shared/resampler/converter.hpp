//
//  converter.h
//  Spectrum
//
//  Created by tom on 2019-06-23.
//

#ifndef converter_h
#define converter_h

#include "speex_resampler.h"

struct ConverterResult {
    int inputConsumed;
    int outputLength;
};

class Converter {
private:
    SpeexResamplerState *speex;
    
public:
    Converter(int inputRate, int outputRate, int quality = SPEEX_RESAMPLER_QUALITY_DEFAULT) {
        int err;
        if (inputRate != outputRate) {
            speex = speex_resampler_init(2, inputRate, outputRate, quality, &err);
            if (err) {
                printf("Speex error: %d\n", err);
            }
        }
    }
    
    ~Converter() {
        if (speex) {
            speex_resampler_destroy(speex);
        }
    }
    
    void convert(const float *inL, const float *inR, int inputLen, float *outL, float *outR, int outputLen, ConverterResult *result) {
        if (speex) {
            spx_uint32_t i = inputLen;
            spx_uint32_t o = outputLen;
            speex_resampler_process_float(speex, 0, inL, &i, outL, &o);
            i = inputLen;
            o = outputLen;
            speex_resampler_process_float(speex, 1, inR, &i, outR, &o);
            result->inputConsumed = i;
            result->outputLength = o;
        } else {
            int samples = (inputLen < outputLen) ? inputLen : outputLen;
            memcpy(outL, inL, samples * sizeof(float));
            memcpy(outR, inR, samples * sizeof(float));

            result->inputConsumed = samples;
            result->outputLength = samples;
        }
    }
    


};

#endif /* converter_h */
