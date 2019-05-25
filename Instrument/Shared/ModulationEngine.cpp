//
//  ModulationEngine.cpp
//  iOSInstrumentDemoFramework
//
//  Created by tom on 2019-05-24.
//

#include "ModulationEngine.hpp"

const unsigned int kNumModulationSlots = 8;

typedef struct {
    int sourceA;
    int sourceB;
    float depth;
    unsigned int dest;
    bool hold;
} modSlot_t;

class ModulationEngine {
    
public:
    ModulationEngine() { }
    ~ModulationEngine() { }
    
    void Init(float *modSources, size_t numSources, float *modDest, size_t numDest);
    
private:
    float *modulationSources;
    size_t numSources;
    
    float *modulationDests;
    size_t numDest;
    
};
