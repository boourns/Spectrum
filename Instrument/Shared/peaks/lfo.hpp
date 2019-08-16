// Copyright 2013 Emilie Gillet.
//
// Author: Emilie Gillet (emilie.o.gillet@gmail.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
// See http://creativecommons.org/licenses/MIT/ for more information.
//
// -----------------------------------------------------------------------------
//
// LFO.

#ifndef PEAKS_MODULATIONS_LFO_H_
#define PEAKS_MODULATIONS_LFO_H_

#include "stmlib/stmlib.h"
#include "stmlib/utils/ring_buffer.h"

namespace peaks {
    
    enum ControlMode {
        CONTROL_MODE_FULL,
        CONTROL_MODE_HALF
    };
    
    enum GateFlagsBits {
        GATE_FLAG_LOW = 0,
        GATE_FLAG_HIGH = 1,
        GATE_FLAG_RISING = 2,
        GATE_FLAG_FALLING = 4,
        GATE_FLAG_FROM_BUTTON = 8,
        
        GATE_FLAG_AUXILIARY_LOW = 0,
        GATE_FLAG_AUXILIARY_HIGH = 16,
        GATE_FLAG_AUXILIARY_RISING = 32,
        GATE_FLAG_AUXILIARY_FALLING = 64,
    };
    
    typedef uint8_t GateFlags;
    
    inline GateFlags ExtractGateFlags(GateFlags previous, bool current) {
        previous &= GATE_FLAG_HIGH;
        if (current) {
            return previous ? GATE_FLAG_HIGH : (GATE_FLAG_RISING | GATE_FLAG_HIGH);
        } else {
            return previous ? GATE_FLAG_FALLING : GATE_FLAG_LOW;
        }
    }
    
}  // namespace peaks

namespace peaks {
    
    enum LfoShape {
        LFO_SHAPE_SINE,
        LFO_SHAPE_TRIANGLE,
        LFO_SHAPE_SQUARE,
        LFO_SHAPE_STEPS,
        LFO_SHAPE_NOISE,
        LFO_SHAPE_LAST
    };
    
    class Lfo {
        
    public:
        typedef int16_t (Lfo::*ComputeSampleFn)();
        
    private:
        int16_t ComputeSampleSine();
        int16_t ComputeSampleTriangle();
        int16_t ComputeSampleSquare();
        int16_t ComputeSampleSteps();
        int16_t ComputeSampleNoise();
        
        uint16_t rate_;
        int16_t parameter_;
        int32_t level_;
        
        bool sync_;
        uint32_t sync_counter_;
        
        uint32_t phase_increment_;
        
        uint32_t period_;
        uint32_t end_of_attack_;
        uint32_t attack_factor_;
        uint32_t decay_factor_;
        int16_t previous_parameter_;
        
        int32_t value_;
        int32_t next_value_;
        
        static ComputeSampleFn compute_sample_fn_table_[];
        
    public:
        LfoShape shape_;
        uint32_t phase_;
        uint32_t reset_phase_;
        uint32_t last_phase_;
        
        Lfo() { }
        ~Lfo() { }
        
        void Init();
        int16_t Process(size_t size);
        int16_t Process(size_t size, uint32_t phase_increment);

        void Trigger();
        
        inline void set_rate(uint16_t rate) {
            rate_ = rate;
        }
        
        inline void set_shape(LfoShape shape) {
            shape_ = shape;
        }
        
        inline void set_shape_integer(uint16_t value) {
            shape_ = static_cast<LfoShape>(value * LFO_SHAPE_LAST >> 16);
        }
        
        void set_shape_parameter_preset(uint16_t value);
        
        inline void set_parameter(int16_t parameter) {
            parameter_ = parameter;
        }
        
        inline void set_reset_phase(int16_t reset_phase) {
            reset_phase_ = static_cast<int32_t>(reset_phase) << 16;
        }
        
//        inline void set_sync(bool sync) {
//            if (!sync_ && sync) {
//                pattern_predictor_.Init();
//            }
//            sync_ = sync;
//        }
//
        inline void set_level(uint16_t level) {
            level_ = level >> 1;
        }
        
        void Configure(uint16_t* parameter) {
            if (sync_) {
                set_level(parameter[0]);
                set_shape_integer(parameter[1]);
                set_parameter(parameter[2] - 32768);
                set_reset_phase(parameter[3] - 32768);
            } else {
                set_level(40960);
                set_rate(parameter[0]);
                set_shape_integer(parameter[1]);
                set_parameter(parameter[2] - 32768);
                set_reset_phase(parameter[3] - 32768);
            }
        }
    };
    
}  // namespace peaks

#endif  // PEAKS_MODULATIONS_LFO_H_
