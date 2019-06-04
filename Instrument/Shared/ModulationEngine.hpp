//
//  ModulationEngine.hpp
//  Spectrum
//
//  Created by tom on 2019-05-31.
//

#ifndef ModulationEngine_h
#define ModulationEngine_h

#include <vector>

/*
 usage:
 C++:
 define enum for inputs.

 obj-c:
 string dict for inputs
 
 */

struct ModulationEngineRule {
    int input1;
    int input2;
    float depth;
    int output;
};

class ModulationEngineRuleList {
public:
    ModulationEngineRuleList(int numRules) {
        rules.resize(numRules);

        for (ModulationEngineRule& rule : rules) {
            rule.depth = 0.0f;
            rule.input1 = 0;
            rule.input2 = 0;
            rule.output = 0;
        }
    }
    
    void setParameter(AUParameterAddress address, AUValue value) {
        unsigned long long index = address / 4;
        int offset = address % 4;
        
        // TODO, know in/out lengths and clamp
        switch(offset) {
            case 0:
                rules[index].input1 = value;
                break;
                
            case 1:
                rules[index].input2 = value;
                break;
                
            case 2:
                rules[index].depth = value;
                break;
                
            case 3:
                rules[index].output = value;
                break;
        }

    }
    
    
    AUValue getParameter(AUParameterAddress address) {
        unsigned long long int index = address / 4;
        int offset = address % 4;
        
        switch(offset) {
            case 0:
                return rules[index].input1;
            case 1:
                return rules[index].input2;
            case 2:
                return rules[index].depth;
            case 3:
                return rules[index].output;
        }
        return 0.0f;
    }
    
    bool isPatched(int outputIndex) {
        for (ModulationEngineRule& rule : rules) {
            if (rule.output == outputIndex) {
                return true;
            }
        }
        return false;
    }
    
    std::vector<ModulationEngineRule> rules;
    int parameterBase;
};

class ModulationEngine {
public:
    ModulationEngine(int numInputs, int numOutputs) {
        in.resize(numInputs);
        out.resize(numOutputs);
    };
    
    ~ModulationEngine() {
        
    };
    
    void run() {
        for (int i = 0; i < out.size(); i++) {
            out[i] = 0.0f;
        }
        for (ModulationEngineRule& rule : rules->rules) {
            if (rule.output != 0) {
                out[rule.output] += in[rule.input1] * in[rule.input2] * rule.depth;
            }
        }
    }
    
    ModulationEngineRuleList *rules;
    int numInputs;
    int numOutputs;
    std::vector<float> in;
    std::vector<float> out;
};
#endif /* ModulationEngine_h */
