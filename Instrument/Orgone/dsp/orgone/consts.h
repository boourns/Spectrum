#ifndef _CONSTS_H_
#define _CONSTS_H_

#include <stdint.h>

extern const float equalTemprementTable[];
extern const float justTable[];
extern const uint8_t smoothStepTable[];
extern const uint16_t HARM_LEVELS[];

extern const int16_t sinTable[];
extern const int16_t sawTable[];
extern const int16_t pulseTable[];

extern const int16_t triTable[];

extern const int16_t bassTable1[];

extern const int16_t bassTable2[];

extern const int16_t scarabTable1[];

extern const int16_t scarabTable2[];

extern const int16_t pnoTable[];

extern const int16_t celloTable[];

extern const int16_t violTable[];

extern const int16_t distoTable[];

extern const int16_t blipTable[];

extern const int16_t nothingTable[];

extern const int16_t DCTable[];

extern const int16_t AKWF_squ_0011[];

extern const int16_t AKWF_gapsaw_0017[];

extern const int16_t voiceTable[];

extern const int16_t primeTable[];

extern const int16_t FMTableSQ[];

extern const int16_t FMTableSQR[];

extern const int16_t FMTableS180[];

extern const int16_t FMTableFM98[];

extern const int16_t FMTablehvoice26[];

extern const int16_t AKWF_symetric_0010[];

extern const int16_t AKWF_symetric_0013[];

extern const int16_t AKWF_symetric_0001[];

extern const int16_t AKWF_0003[];

extern const int16_t AKWF_1503[];

extern const int16_t AKWF_0312[];

extern const int16_t AKWF_0447[];

extern const int16_t AKWF_1099[];

extern const int16_t AKWF_distorted_0003[];

extern const int16_t AKWF_sinharm_0015[];

//Arrays assign wavetables to wave slots on low, medium and high positions
//CZ

extern const int16_t *CZWTselLo[];

extern const int16_t *CZWTselMid[];

extern const int16_t *CZWTselHi[];

extern const int16_t *CZWTselFM[];

//CZALT
extern const int16_t *CZAltWTselLo[];

extern const int16_t *CZAltWTselMid[];

extern const int16_t *CZAltWTselFM[];

extern const int16_t *CZAltWTselFMAMX[];

//FM

extern const int16_t *FMWTselLo[];

extern const int16_t *FMWTselMid[];

extern const int16_t *FMWTselHi[];

extern const int16_t *FMWTselFM[];
//FMALT

extern const int16_t *FMAltWTselLo[];

extern const int16_t *FMAltWTselMid[];


extern const int16_t *FMAltWTselFM[];

//pulsar envelopes

extern const int16_t *PulsarEnv[];

//extern const int16_t *PulsarEnv[] =  { sinTable, triTable,  distoTable ,AKWF_sinharm_0015, FMTableFM98, AKWF_gapsaw_0017, AKWF_1503, AKWF_symetric_0001 ,
                    //            AKWF_symetric_0010 , scarabTable2 , AKWF_symetric_0013 , voiceTable , FMTableSQR , AKWF_0003 , FMTableS180 ,sawTable
                     //        };

//drum waves
extern const int16_t *drumWT[];

extern const int16_t *drumWT2[];

extern const int potPinTable_DIY[];
extern const int potPinTable_ret[]; //note these are "A**" pins not digital pin numbers

extern const int chordTable[];

extern const int tuneStep;

#endif