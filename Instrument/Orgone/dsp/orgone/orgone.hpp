/*
Copyright (c) <2016> <James L Matheson>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software
and associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, 
and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, 
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Neutron-sound.com
Orgone Accumulator 2.0
*/


//pre 2.0 firmware orgones
//use config.h tab to change FX function button to momentary if you changed it.
//tune lock is now pulsar mode. you can change it back in config, but you get no pulsar mode.

//detune = FX
//detune prime = FX select
//detune enable = FX enable
//lock = pulsar

#ifndef ORGONE_H_
#define ORGONE_H_

#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "Bounce.hpp"
#include "config.h"
//#include <Arduino.h>
#include "shim.h"

#include "consts.h"

#define FASTRUN

#define ARRAY_ASSIGN(x, type, vals) { \
  type tmp[] = vals; \
  memcpy(x, tmp, sizeof(tmp)); \
}

enum OrgoneISR {
MAIN,
WAVE_TWIN,
DISTS,
SPECTRUM,
WAVE_DELAY,
DRUM,
PULSAR_TWIN,
PULSAR_DISTS,
PULSAR_CHORD,//under isr detune
PULSAR_DELAY,
};

class Orgone {
public:
  Orgone():
  pulsarButton(5, 20),
  FXCycleButton(3, 20),
  FMmodeButton(13, 20),
  FMFixedButton(16, 20),
  effectEnButton_A(2, 20),
  effectEnButton_B(7, 20),
  effectEnButton_C(8, 20),
  tuneLockButton(1, 20),
  xModeButton( 10 , 20) {

    //memset(&marker1, 0, &marker2 - &marker1);

    histCount = 0;
    //const uint8_t histMax = 4;
    //uint32_t Lo_wave_hist[4],Mid_wave_hist[4],Hi_wave_hist[4];
    //uint32_t Lo_accumulator,Mid_accumulator,Hi_accumulator;
    smooth_declick_threshold = 200;

    lo_wavesel_indexOld = 0;
    Mid_wavesel_indexOld = 0;
    Hi_wavesel_indexOld = 0;

    lo_wavesel_index = 1;
    Mid_wavesel_index = 1;
    Hi_wavesel_index =1;

    delayCounter = 0;
    delayFB = 0;
    delayCounterShift = 0;
    delayTime = 512;
    delayTimeShift = 0;
    delayTimeShift2 = 0;
    delayTimeShift3 = 0;
    delayTimeShift4 = 0;
    delayFeedback = 0;

    float osc_mult[] = {
      4, 4, 4
    };
    memcpy(this->osc_mult, osc_mult, sizeof(osc_mult));

    nextstep = 8388609;
    clipping = 0;
    clippingTest = 0;

    //drum envelopes

    int32_t drum_envVal[] = {0, 0, 0, 0};
    memcpy(this->drum_envVal, drum_envVal, sizeof(drum_envVal));

    int32_t drum_envTemp[] = {0, 0, 0};
    memcpy(this->drum_envTemp, drum_envTemp, sizeof(drum_envTemp));

    drum_a = 0;
    drum_st = 0;
    drum_st2 = 0;
    drum_d = 0;
    drum_d2 = 0;
    drum_dB = 0;
    temph = 0;
    tempr = 0;
    drum_d2B = 0;
    uint8_t drum_envStep[] = {0, 0, 0};
    memcpy(this->drum_envStep, drum_envStep, sizeof(drum_envStep));

    bipolarFX = 0;
    monopoleFX = 0;

    declick = 8;
    declick_ready = 0;

    tuneLockSwitch = 1;


    #define oSQout 11 //square wave out
    #define gateIn 12

    LED_TuneLock = 0;
    LED_Lo = 0;
    LED_Mid = 0;
    LED_Hi = 0;
    //#define LED_PWM 32

    #define LED_LoSel 3
    #define LED_pulsarON 32
    #define LED_MidSel 24
    #define LED_FXSelUp 33
    #define LED_HiSel 31
    #define LED_xSel 30
    #define LED_CZSel 29
    #define LED_FixSel 15

    //from config file
    conf_LED_comp = 0;//LED_COMP; //see config.h for explanations
    conf_TuneMult = TUNEMULT;
    
    WTShiftHi = 23;
    WTShiftLo = 23;
    WTShiftMid = 23;
    FXSelArmed[0] = FXSelArmed[1] = 0;

    QUIET_MCD = 0;

    aout2 = 0;// A14; //dac out
    gateState = 0;
    
    int32_t detune[] = {0, 0, 0, 0}; //array holds detune amounts
    memcpy(this->detune, detune, sizeof(detune));

    float chord[] = {0.0, 0.0, 0.0, 0.0,};
    memcpy(this->chord, chord, sizeof(chord));

    outsq = 0;

    indexaInRAv = 0;
    indexInCV = 0;
    
    tuneLockOn = 0;
    bitCrushOn = 0;
    //float updn;
    inCV = 1200;
    
    CRUSHBITS = 0;
    CRUSH_Remain = 0;

    ISRrate = 12;
    uint8_t SEL_LED_ARRAY[] = {3, 32, 24, 33, 31, 30, 29, 15};
    memcpy(this->SEL_LED_ARRAY, SEL_LED_ARRAY, sizeof(SEL_LED_ARRAY));

    float primes[] = {199.1221, 621.6538, 1074.5242, 1343.189,};
    memcpy(this->primes, primes, sizeof(primes));

    float fibi[] = {2.0, 3.0, 5.0, 8.0, 13.0};
    memcpy(this->fibi, fibi, sizeof(fibi));

    numreadingsaInRAv = 16;
    numreadingsCV = 3;
    memset(readingsaInRAv, 0, sizeof(readingsaInRAv));
    memset(readingsaInIAv, 0, sizeof(readingsaInIAv));
    memset(readingsaInCV, 0, sizeof(readingsaInCV));
    aInModIndex = 0;

    enBreak = 130000000;
    Temporal_Shift_CZ = 9;
    Temporal_Shift_P = 18;
    conf_NoteSize = NOTESIZE;

    FXSw = FX_SWITCH;
    PWM_Div = PWM_SUB;
    PWM_Min = PWM_MINIMUM << 5;
    FX_Count = 7;
    LED_MST = LED_MODESWITCH_TIME;
    QUIET_MST = 10000;

    numreadingsratio = 16;
    numreadingsaInRAv = 16;
    numreadingsCV = 3;
    memset(readingsratio, 0, sizeof(readingsratio));
    controlAveragingIndex = 0;
    totalratio = 0;

    inputConverterF = 30000.0;
    inputConverterA = 180000.0;
    pulsarOn = 0;
    oscMode = 0;
    FinalOut = 0;

    //Arrays assign wavetables to wave slots on low[0], & medium and high positions
    //CZ

    const int16_t *CZWTselLo[] = {&sinTable[0], & triTable[0], & sawTable [0], & scarabTable1 [0], & scarabTable2 [0], & pulseTable [0], & pnoTable [0], & bassTable1
                                  [0], & bassTable2 [0], & celloTable [0], & violTable [0], & distoTable [0], &AKWF_distorted_0003[0], &  AKWF_0447 [0], & primeTable[0], & nothingTable[0], &  nothingTable //extra nothingtables dont do anything. needed to stop out of bounds crash
                                 [0]};
    memcpy(this->CZWTselLo, CZWTselLo, sizeof(this->CZWTselLo));


    const int16_t *CZWTselMid[] = {&sinTable[0], & triTable[0], & sawTable [0], & scarabTable1 [0], & scarabTable2 [0], & pulseTable [0], & pnoTable [0], & bassTable1
                                   [0], & bassTable2 [0], & celloTable [0], & violTable [0], & distoTable [0], & AKWF_distorted_0003[0], &  AKWF_0447 [0], & noiseTable2 [0], & noiseTable [0], &nothingTable
                                  [0]};
    memcpy(this->CZWTselMid, CZWTselMid, sizeof(this->CZWTselMid));

    const int16_t *CZWTselHi[] = {&sinTable[0], & triTable[0], & sawTable [0], & scarabTable1 [0], & scarabTable2 [0], & pulseTable [0], & pnoTable [0], & bassTable1
                                  [0], & bassTable2 [0], & celloTable [0], & violTable [0], & distoTable [0], & AKWF_distorted_0003 [0], &  AKWF_0447 [0], & noiseTable2 [0], & noiseLive0 [0], &nothingTable
                                 [0]};
    memcpy(this->CZWTselHi, CZWTselHi, sizeof(this->CZWTselHi));

    const int16_t *CZWTselFM[] = {&sinTable[0], & triTable[0], & FMTableS180 [0], & FMTableSQ [0], & FMTableSQR [0], & AKWF_0003 [0], & pnoTable [0], & bassTable1
                                  [0], & bassTable2 [0], & celloTable [0], & violTable [0], & FMTableFM98 [0], & FMTablehvoice26 [0], & AKWF_squ_0011 [0], & noiseTable2 [0], & noiseLive1
                                 [0]};
    memcpy(this->CZWTselFM, CZWTselFM, sizeof(this->CZWTselFM));

    //CZALT
    const int16_t *CZAltWTselLo[] = {& sinTable[0], & triTable[0], & sawTable [0], & scarabTable1 [0], &  pulseTable [0], & pnoTable [0], & bassTable1
                                      [0], & bassTable2 [0], & celloTable [0], & violTable [0], & distoTable [0], & AKWF_distorted_0003 [0], & blipTable [0], & voiceTable [0], & primeTable [0], &nothingTable  [0], &nothingTable
                                    [0]};
    memcpy(this->CZAltWTselLo, CZAltWTselLo, sizeof(this->CZAltWTselLo));

    const int16_t *CZAltWTselMid[] = {&sinTable[0], & triTable[0], & sawTable [0], & scarabTable1 [0], & scarabTable2 [0], & pulseTable [0], &  bassTable1
                                      [0], & bassTable2 [0], & celloTable [0], & violTable [0], & distoTable [0], & AKWF_distorted_0003 [0], & blipTable [0], & voiceTable [0], & noiseTable2 [0], & noiseLive0 [0], &nothingTable
                                     [0]};
    memcpy(this->CZAltWTselMid, CZAltWTselMid, sizeof(this->CZAltWTselMid));

    const int16_t *CZAltWTselFM[] = {&sinTable[0], & sinTable[0], & triTable [0], & FMTableSQ [0], & FMTableSQR [0], & AKWF_0003 [0], & pnoTable [0], & bassTable1
                                     [0], & bassTable2 [0], & celloTable [0], & violTable [0], & FMTableFM98 [0], & FMTablehvoice26 [0], & AKWF_squ_0011 [0], & noiseTable2 [0], & noiseLive1
                                    [0]};
    memcpy(this->CZAltWTselFM, CZAltWTselFM, sizeof(this->CZAltWTselFM));

    const int16_t *CZAltWTselFMAMX[] = {&DCTable[0], & sinTable[0], & FMTableSQ [0], & FMTableSQ [0], & FMTableSQR [0], & AKWF_0003 [0], & pnoTable [0], & bassTable1
                                        [0], & bassTable2 [0], & celloTable [0], & violTable [0], & FMTableFM98 [0], & FMTablehvoice26 [0], & sinTable [0], & noiseTable2 [0], & noiseTable
                                       [0]};
    memcpy(this->CZAltWTselFMAMX, CZAltWTselFMAMX, sizeof(this->CZAltWTselFMAMX));

    //FM

    const int16_t *FMWTselLo[] = {& sinTable[0], & triTable[0], & AKWF_symetric_0001 [0], & AKWF_symetric_0010 [0], & scarabTable2 [0], & AKWF_symetric_0013 [0], & pnoTable [0], & FMTableS180
                                   [0], & AKWF_gapsaw_0017 [0], & FMTableSQR [0], & distoTable [0], & AKWF_distorted_0003 [0], & AKWF_0003 [0], &  FMTableFM98 [0], & noiseTable2[0], & nothingTable[0], & nothingTable[0],
                                 };
    memcpy(this->FMWTselLo, FMWTselLo, sizeof(this->FMWTselLo));

    const int16_t *FMWTselMid[] = {&sinTable[0], & triTable[0], & AKWF_symetric_0001 [0], & AKWF_symetric_0010 [0], &  AKWF_symetric_0013 [0], & pnoTable [0], & FMTableS180
                                   [0], & AKWF_gapsaw_0017 [0], & FMTableSQR [0], & distoTable  [0], & AKWF_distorted_0003[0], & AKWF_0003 [0], & voiceTable [0], & FMTableFM98 [0], & noiseTable2 [0], & AKWF_squ_0011 [0], &nothingTable[0],
                                  };
    memcpy(this->FMWTselMid, FMWTselMid, sizeof(this->FMWTselMid));

    const int16_t *FMWTselHi[] = {&sinTable[0], & triTable[0], & AKWF_symetric_0001 [0], & AKWF_symetric_0010 [0], & scarabTable2 [0], & AKWF_symetric_0013 [0], & bassTable1
                                  [0], & AKWF_gapsaw_0017 [0], & FMTableSQR [0], & distoTable [0], & AKWF_distorted_0003 [0], & AKWF_0003 [0], & voiceTable [0], & FMTableFM98 [0], & noiseTable2 [0], & noiseLive1[0], & nothingTable[0],
                                 };
    memcpy(this->FMWTselHi, FMWTselHi, sizeof(this->FMWTselHi));

    const int16_t *FMWTselFM[] = {&sinTable[0], & triTable[0], & AKWF_symetric_0001 [0], & FMTableSQ [0], & FMTableSQR [0], & AKWF_symetric_0013 [0], & AKWF_symetric_0010 [0], & bassTable1
                                  [0], & FMTableS180 [0], & celloTable [0], & violTable [0], & distoTable [0], & blipTable [0], & FMTableFM98 [0], & noiseTable2 [0], & noiseLive0
                                 [0]};
    memcpy(this->FMWTselFM, FMWTselFM, sizeof(this->FMWTselFM));

    //FMALT

    const int16_t *FMAltWTselLo[] = {& sinTable[0], & triTable[0], & AKWF_symetric_0001 [0], & AKWF_symetric_0010 [0], & scarabTable2 [0], & AKWF_symetric_0013 [0], & pnoTable [0], & FMTableS180  
                                      [0], & AKWF_gapsaw_0017 [0], & FMTableSQR [0], & distoTable [0], &  AKWF_0003 [0], & AKWF_0447 [0], & FMTableFM98 [0], & noiseTable2 [0], &nothingTable [0], &nothingTable
                                    [0]};
    memcpy(this->FMAltWTselLo, FMAltWTselLo, sizeof(this->FMAltWTselLo));

    const int16_t *FMAltWTselMid[] = {&sinTable[0], & triTable[0], & AKWF_symetric_0001 [0], & AKWF_symetric_0010 [0], & scarabTable2 [0], & AKWF_symetric_0013 [0], & FMTableS180
                                      [0], & AKWF_gapsaw_0017 [0], & FMTableSQR [0], & distoTable [0], & AKWF_distorted_0003 [0], & AKWF_0003 [0], & AKWF_0447 [0], & FMTableFM98 [0], & noiseTable2 [0], & noiseLive1 [0], &nothingTable
                                     [0]};
    memcpy(this->FMAltWTselMid, FMAltWTselMid, sizeof(this->FMAltWTselMid));


    const int16_t *FMAltWTselFM[] = {&sinTable[0], & triTable[0], & AKWF_symetric_0001 [0], & FMTableSQ [0], & FMTableSQR [0], & AKWF_symetric_0013 [0], & AKWF_symetric_0010 [0], & bassTable1
                                     [0], & FMTableS180 [0], & celloTable [0], & violTable [0], & distoTable [0], & blipTable [0], & FMTableFM98 [0], & noiseTable2 [0], & noiseLive0
                                    [0]};
    memcpy(this->FMAltWTselFM, FMAltWTselFM, sizeof(this->FMAltWTselFM));

    //pulsar envelopes

    const int16_t *PulsarEnv[] =  {& sinTable[0], & triTable[0], &  distoTable [0], & AKWF_0312[0], & AKWF_symetric_0013 [0], & FMTableSQR [0], & celloTable [0], & violTable
                                    [0], & pnoTable [0], & bassTable1 [0], & blipTable [0], & bassTable2 [0], & scarabTable2 [0], &AKWF_0447[0], & sinTable[0], & AKWF_1099
                                  [0]};
    memcpy(this->PulsarEnv, PulsarEnv, sizeof(this->PulsarEnv));

    //const int16_t *PulsarEnv[] =  {& sinTable[0], & triTable[0], &  distoTable [0], &AKWF_sinharm_0015[0], & FMTableFM98[0], & AKWF_gapsaw_0017[0], & AKWF_1503[0], & AKWF_symetric_0001 [0], &
                        //            AKWF_symetric_0010 [0], & scarabTable2 [0], & AKWF_symetric_0013 [0], & voiceTable [0], & FMTableSQR [0], & AKWF_0003 [0], & FMTableS180 [0], &sawTable
                         //        [0]};

    //drum waves
    const int16_t *drumWT[] = {&sinTable[0], & triTable[0], & distoTable [0], & AKWF_distorted_0003[0], & FMTableSQR [0], & FMTableS180 [0], & AKWF_sinharm_0015[0], & AKWF_gapsaw_0017 [0], & AKWF_symetric_0001 [0], &
                                AKWF_symetric_0010 [0], & AKWF_symetric_0013 [0], & FMTableFM98 [0], & AKWF_0003 [0], & voiceTable [0], &sawTable [0], &  noiseTable2 [0], &noiseTable 
                               [0]};
    memcpy(this->drumWT, drumWT, sizeof(this->drumWT));

    const int16_t *drumWT2[] = {&sinTable[0], & triTable[0], & distoTable [0], & AKWF_distorted_0003[0], & FMTableSQR [0], & FMTableS180 [0], & AKWF_sinharm_0015[0], & AKWF_gapsaw_0017 [0], & AKWF_symetric_0001 [0], &
                                AKWF_symetric_0010 [0], & AKWF_symetric_0013 [0], & FMTableFM98 [0], & AKWF_0003 [0], &  voiceTable [0], &sawTable [0], & noiseTable2 [0], &noiseTable 
                               [0]};
    memcpy(this->drumWT2, drumWT2, sizeof(this->drumWT2));
    

    TUNELOCK_SWITCH = 1;

    memset(analogControls, 0, sizeof(analogControls));
    declickValue = 0;
    declickRampOut = 0;
    declickRampIn = 0;
    declickValue = 0;
    declickHold = 0;
    declick = 8;
    declick_ready = 0;

    memset(&oSQ, 0, sizeof(oSQ));
    memset(&o1, 0, sizeof(o1));
    memset(&o2, 0, sizeof(o2));
    memset(&o3, 0, sizeof(o3));
    memset(&o4, 0, sizeof(o4));
    memset(&o5, 0, sizeof(o5));
    memset(&o6, 0, sizeof(o6));
    memset(&o7, 0, sizeof(o7));
    memset(&o8, 0, sizeof(o8));
    memset(&o9, 0, sizeof(o9));
    memset(&o10, 0, sizeof(o10));
    memset(&o11, 0, sizeof(o11));
    memset(&o12, 0, sizeof(o12));

    memset(&lfo, 0, sizeof(lfo));
    memset(&nosc0, 0, sizeof(nosc0));
    memset(&nosc1, 0, sizeof(nosc1));


  }

  ~Orgone() {

  }

  char marker1;

  int16_t noiseTable[512]; //generated in program, uses SRAM
  int16_t noiseTable2[512]; //generated in program, uses SRAM
  int16_t noiseTable3[2]; //array of 2, for program generated LF noise
  int16_t noiseLive1[2];
  int16_t plickety[2];
  int32_t plicketycalc;
  int16_t noiseLive0[2];
  int16_t noiseLive1Val;
  int16_t noiseLive1ValOld;


  uint8_t histCount;
  //const uint8_t histMax;
  //uint32_t Lo_wave_hist[4],Mid_wave_hist[4],Hi_wave_hist[4];
  //uint32_t Lo_accumulator,Mid_accumulator,Hi_accumulator;
  uint32_t smooth_declick_threshold;
  uint32_t LoOld,MidOld,HiOld;

  int IsHW2;
  uint16_t lo_wavesel_indexOld;
  uint16_t Mid_wavesel_indexOld;
  uint16_t Hi_wavesel_indexOld;

  uint16_t lo_wavesel_index;
  uint16_t Mid_wavesel_index;
  uint16_t Hi_wavesel_index;

  int16_t NT3Rate; //the rate noisetable 3 changes.

  int16_t delayTable[4096];
  uint16_t delayCounter;
  uint16_t delayFB;
  uint16_t delayCounterShift;
  uint16_t delayTime;
  uint16_t delayTimeShift;
  uint16_t delayTimeShift2;
  uint16_t delayTimeShift3;
  uint16_t delayTimeShift4;
  int32_t delayFeedback;

  int32_t ADT1;
  int32_t ADT2;

  uint32_t pcounter;
  uint32_t pcounterOld;
  uint8_t fixedWave;

  float osc_mult[3];

  int32_t nextstep;
  int32_t clipping;
  int32_t clippingTest;

  //drum envelopes

  int32_t drum_envVal[4];
  int32_t drum_envTemp[3];
  int32_t enBreak;
  int32_t drum_a;
  uint8_t drum_st;
  uint8_t drum_st2;
  int32_t drum_d;
  int32_t drum_d2;
  int32_t drum_dB;
  int32_t temph;
  int32_t tempr;
  int32_t drum_d2B;
  uint8_t drum_envStep[3];
  int32_t bipolarFX;
  uint32_t monopoleFX;

  int32_t declickRampOut;
  int32_t declickRampIn;
  int32_t declickValue;
  int32_t declickHold;
  int declick;
  int declick_ready;

  int Temporal_Shift_CZ;
  int Temporal_Shift_P;

  struct oscillatorSQUARE //PWM osc
  {
    uint32_t phase;
    int32_t phaseRemain;
    int32_t wave;
    int32_t nextwave;
    int32_t PW;
    int32_t phase_increment;
  }
  oSQ;

  struct oscillator1
  {
    uint32_t phase;
    uint32_t phase_SUB;
    double freq;
    int32_t phaseRemain;
    int32_t phaseOffset;
    int32_t pulseAdd;
    uint32_t CRUSHwave;
    uint32_t maxlev;
    int32_t amp;
    uint32_t phaseOld;
    int32_t wave;
    int32_t nextwave;
    int32_t index;
    int32_t phase_increment;

  }
  o1;

  struct oscillator2
  {
    uint32_t phase;
    int32_t phaseRemain;
    uint32_t phaseOld;
    int32_t index;
    int32_t wave;
    int32_t nextwave;
    int32_t phase_increment;
    uint32_t phase_mult;
  }
  o2;

  struct oscillator3
  {
    uint32_t phase;
    uint32_t phaseAdd;
    int32_t phaseRemain;
    uint32_t phaseTest;
    int32_t nextwave;
    int32_t phaseOffset;
    uint32_t phaseOld;
    int32_t index;
    int32_t wave;
    int32_t phase_increment;
  }
  o3;

  struct oscillator4
  {
    uint32_t phase;
    uint32_t phaseOld;
    uint32_t phaseAdd;
    int32_t phaseRemain;
    int32_t nextwave;
    int32_t wave;
    int32_t index;
    int32_t phase_increment;
  }
  o4;

  struct oscillator5
  {
    uint32_t phase;  
    int32_t phaseRemain;
    int32_t nextwave;
    int32_t phaseOffset;
    uint32_t phaseOld;
    int32_t index;
    int32_t wave;
    int32_t phase_increment;
  }
  o5;

  struct oscillator6
  {
    uint32_t phase;
    uint32_t phaseTest;
    int32_t phaseRemain;
    int32_t nextwave;
    int32_t wave;
    int32_t index;
    int32_t phase_increment;
  }
  o6;

  struct oscillator7
  {
    uint32_t phase;
    int32_t phaseRemain;
    int32_t nextwave;
    int32_t phaseOffset;
    uint32_t phaseOld;
    int32_t index;
    int32_t wave;
    int32_t phase_increment;
    int32_t phase_increment2;
  }
  o7;

  struct oscillator8
  {
    uint32_t phase;
    int32_t phaseRemain;
    int32_t nextwave;
    int32_t wave;
    int32_t index;
    int32_t phase_increment;
  }
  o8;

  struct oscillator9
  {
    uint32_t phase;
    int32_t phaseRemain;
    int32_t nextwave;
    int32_t phaseOffset;
    uint32_t phaseOld;
    uint32_t phaseTest;
    int32_t index;
    int32_t wave;
    int32_t phase_increment;
    int32_t phase_increment2;
  }
  o9;

  struct oscillator10
  {
    uint32_t phase;
    int32_t phaseRemain;
    uint32_t phaseOld;
    int32_t nextwave;
    int32_t wave;
    int32_t index;
    int32_t phase_increment;
  }
  o10;

  struct oscillator11
  {
    uint32_t phase;
    int32_t phaseRemain;
    int32_t nextwave;
    int32_t phaseOffset;
    uint32_t phaseOld;
    int32_t index;
    int32_t wave;
    int32_t phase_increment;
  }
  o11;

  struct oscillator12
  {
    uint32_t phase;
    int32_t phaseRemain;
    int32_t nextwave;
    int32_t phaseOffset;
    uint32_t phaseOld;
    uint32_t phaseTest;
    int32_t index;
    int32_t wave;
    int32_t phase_increment;

  }
  o12;

  struct lfo
  {
    uint32_t phase;
    int32_t wave;
    int32_t nextwave;
    int32_t phaseRemain;
    int32_t phase_increment;
  }
  lfo;

  struct noiseosc0 //live BW noise oscs. o1.increment
  {
    uint32_t phase;
    uint32_t phaseOld;
    int32_t wave;
    int32_t nextwave;
    int32_t envBreak;
    int32_t phase_increment;
    int32_t envVal;
    int32_t decay;
    uint8_t trig;

  }
  nosc0;

  struct noiseosc1 // BW noise osc o2.increment
  {
    uint32_t phase;
    uint32_t phaseOld;
    int32_t wave;
    int32_t nextwave;
    int32_t envBreak;
    int32_t phase_increment;
    int32_t envVal;
    int32_t decay;
    uint8_t trig;

  }
  nosc1;

  int noscReadings[4];

  #ifdef __cplusplus
  #define cast_uint32_t static_cast<uint32_t>
  #else
  #define cast_uint32_t (uint32_t)
  #endif

  int effectSwitch_A;//there are pre configured for HW2 because the debounce of momentary switches is initiated before setup
  int FXButtonDn;
  int effectSwitch_B;
  int FXButton; //3 DIY  HW2 gets changed to 25 later
  int effectSwitch_C;
  int xModeSwitch;
  int FMmodeSwitch;
  int FMFixedSwitch;

  int tuneLockSwitch;


  #define oSQout 11 //square wave out
  #define gateIn 12

  int LED_TuneLock;
  int LED_Lo;
  int LED_Mid;
  int LED_Hi;
  //#define LED_PWM 32

  #define LED_LoSel 3
  #define LED_pulsarON 32
  #define LED_MidSel 24
  #define LED_FXSelUp 33
  #define LED_HiSel 31
  #define LED_xSel 30
  #define LED_CZSel 29
  #define LED_FixSel 15

  //from config file
  uint16_t conf_LED_comp; //see config.h for explanations
  uint32_t conf_TuneMult;

  //uint32_t conf_LFOBase;
  float conf_NoteSize;
  int FXSw;
  int PWM_Div;
  int PWM_Min;
  int FX_Count;
  int LED_MST;
  uint8_t SEL_LED_ARRAY[8];
  float primes[4];
  float fibi[5];
  uint8_t WTShiftFM;
  uint8_t WTShiftHi;
  uint8_t WTShiftLo;
  uint8_t WTShiftMid;
  uint8_t FXSelArmed[2];
  uint8_t FXchangedSAVE;

  int LED_MCD;
  int QUIET_MCD;
  int QUIET_MST;//cowntdown to save button states after pressing.

  int aout2; //dac out
  int gateState;
  int ARC;
  int SWC; //slow wave counter
  uint8_t FX; //effect mode.
  int Lbuh ;
  int Mbuh ;
  int Hbuh;

  int32_t aInMod;
  float aInModRatio;
  float ModRatioCubing;
  int32_t aInModIndex;

  //detuning
  float aInModEffect;
  uint16_t aInEffectReading;
  float aInModEffectCubing;
  float effectScaler;
  float EffectAmountCont;
  //float EffectAmountContCubing;
  //int32_t mixEffectUpTMp ;
  //int32_t mixEffectDnTMp;
  int32_t detune[4]; //array holds detune amounts
  float chord[4];

  int outsq;


  int32_t analogControls[10];

  const int16_t *waveTableHiLink;
  const int16_t *waveTableLoLink;
  const int16_t *waveTableMidLink;
  const int16_t *FMTable;
  const int16_t *FMTableMM;
  const int16_t *FMTableAMX; //in CZ alt mode the modulator for the hi position
  const int16_t *GWTlo1; //gwt are virtual wavetables for modes with gradual wavetable change.
  const int16_t *GWTlo2;
  const int16_t *GWTmid1;
  const int16_t *GWTmid2;
  const int16_t *GWThi1;
  const int16_t *GWThi2;
  const int16_t *PENV;
  int32_t GremLo; //gradual wavetable change remainders
  int32_t GremMid;
  int32_t GremHi;
  uint32_t uGremLo; //gradual wavetable change remainders
  uint32_t uGremMid;
  uint32_t uGremHi;


  //running average for sensetive controls
  int numreadingsratio;
  int readingsratio[16];
  int controlAveragingIndex;
  int totalratio;
  int averageratio;
  int loopReset;

  int numreadingsaInRAv; 
  int numreadingsCV;

  float readingsaInRAv[16];
  float readingsaInIAv[16];
  float readingsaInCV[3];
  int indexaInRAv;
  int indexInCV;
  float totalaInRAv;
  float totalaInIAv;
  float totalInCV;
  float averageaInRAv;
  float averageaInCV;
  float averageaInIAvCubing;
  float averageaInIAv;
  float avgcubing;
  int32_t AInRawFilter;
  float octaveSize;


  //mixing
  int32_t mixPos;
  uint16_t mixHi;
  //float mixHi_fl;
  uint16_t mixLo;
  //float mixLo_fl;
  uint16_t mixMid;
  //float mixMid_fl;
  uint32_t mixEffect;
  uint32_t mixEffectUp;
  uint32_t mixEffectDn;
  uint32_t FXMixer[4];
  float floats[4];
  int32_t FXMixOut;
  int32_t CZMix;
  int32_t CZMixDn;

  int32_t envVal;
  int chordArrayOffset;
  float tuner;
  float dtuner;

  int32_t AGCtest;
  int32_t AGCtestPeriod;
  int32_t AGCtestSmooth;
  int32_t FinalOut;
  float FMX_HiOffset;
  float FMX_HiOffsetCont;
  int32_t FMX_HiOffsetContCub;

  int fuh;
  uint8_t tuneLockOn;
  uint8_t bitCrushOn;
  //float updn;
  float inputScaler;
  float inputVOct;
  float inputConverter; //exponential output from V/oct
  float inputConverterF;// fixed freq FM.
  float inputConverterA;//fixed AM
  float FMMult; //FM multiplier
  float chaosMult1;
  float chaosMult2;
  float chaosMult3;
  int32_t FMIndexCont; //FM index control
  float FMIndexContCubing;
  int32_t FMModCont;
  uint16_t FMIndex; //FM index (not scaled like a real fm synth)
  uint32_t AMIndex;
  uint8_t oscMode;
  uint8_t pulsarOn;
  uint8_t FMFixedOnToggle;
  uint8_t oscSync;
  uint8_t oscSyncTest;
  uint8_t buh;
  float inCV;
  float inCVraw;
  int cycleCounter;
  uint8_t CRUSHBITS;
  int32_t CRUSH_Remain;

  int ISRrate;

  Bounce pulsarButton;
  Bounce FXCycleButton;
  Bounce FMmodeButton;
  Bounce FMFixedButton;
  Bounce effectEnButton_A;
  Bounce effectEnButton_B;
  Bounce effectEnButton_C;
  Bounce tuneLockButton;
  Bounce xModeButton;

  int16_t *CZWTselLo[17];

  int16_t *CZWTselMid[17];

  int16_t *CZWTselHi[17];

  int16_t *CZWTselFM[17];

  //CZALT
  int16_t *CZAltWTselLo[17];

  int16_t *CZAltWTselMid[17];

  int16_t *CZAltWTselFM[17];

  int16_t *CZAltWTselFMAMX[17];

  //FM

  int16_t *FMWTselLo[17];

  int16_t *FMWTselMid[17];

  int16_t *FMWTselHi[17];

  int16_t *FMWTselFM[17];

  //FMALT

  int16_t *FMAltWTselLo[17];

  int16_t *FMAltWTselMid[17];


  int16_t *FMAltWTselFM[17];

  //pulsar envelopes

  int16_t *PulsarEnv[17];

  //int16_t *PulsarEnv[] =  { sinTable, triTable,  distoTable ,AKWF_sinharm_0015, FMTableFM98, AKWF_gapsaw_0017, AKWF_1503, AKWF_symetric_0001 ,
                      //            AKWF_symetric_0010 , scarabTable2 , AKWF_symetric_0013 , voiceTable , FMTableSQR , AKWF_0003 , FMTableS180 ,sawTable
                       //        };

  //drum waves
  int16_t *drumWT[17];

  int16_t *drumWT2[17];



  int TUNELOCK_SWITCH;



  enum OrgoneISR isr;

  #include "assign_increments.c"
  #include "bistromath.c"
  #include "common.c"
  //#include "consts.c"
  #include "detuning.c"
  #include "gate_isr.c"
  #include "main_loop.c"
  #include "osc_irs_del.c"
  #include "osc_irs_detune.c"
  #include "osc_isr_dists.c"
  #include "osc_isr_drum.c"
  #include "osc_isr_spectrum.c"
  #include "osc_isrs_twin.c"
  #include "shim.c"
  #include "update_controls.c"
  #include "util.c"

  char marker2;

  void setup() {
      IsHW2 = 1;
      FXButton = 25;

      LED_TuneLock = 0;
      LED_Lo = 4;
      LED_Mid = 6;
      LED_Hi = 9;

    tuneLockOn = 0;

    isr = MAIN;

    for (int i = 0; i <= 511; i++) {
      noiseTable[i] = (random() % 65536) - 32768;
    }//add noise to noise array l

    octaveSize = conf_NoteSize * 12.0;

    o1.phase =
      o2.phase =
        o3.phase =
          o4.phase =
            o5.phase =
              o6.phase =
                o7.phase =
                  o8.phase =
                    o9.phase =
                      o10.phase = 0;

    // ---------------------------
    // ---------------------------
    }

    void interrupt() {
      switch(isr) {
        case MAIN:
          outUpdateISR_MAIN();
          break;
        case WAVE_TWIN:
          outUpdateISR_WAVE_TWIN();
          break;
        case DISTS:
          outUpdateISR_DISTS();
          break;
        case SPECTRUM:
          outUpdateISR_SPECTRUM();
          break;
        case WAVE_DELAY:
          outUpdateISR_WAVE_DELAY();
          break;
        case DRUM:
          outUpdateISR_DRUM();
          break;
        case PULSAR_CHORD:
          outUpdateISR_PULSAR_CHORD();
          break;
        case PULSAR_TWIN:
          outUpdateISR_PULSAR_TWIN();
          break;
        case PULSAR_DISTS:
          outUpdateISR_PULSAR_DISTS();
          break;
        
        case PULSAR_DELAY:
          outUpdateISR_PULSAR_DELAY();
          break;
      }
    }
};

#endif








