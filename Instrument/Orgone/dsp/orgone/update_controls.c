

void UPDATECONTROLS_CZ() {

  if (fixedWave == 1) {
    lo_wavesel_index = analogControls[8] >> 9;
    if ((mixLo > 256) && (lo_wavesel_index != lo_wavesel_indexOld)) {
      declick_ready = 1;
      lo_wavesel_indexOld = lo_wavesel_index;
    }
    waveTableLoLink = CZWTselLo[lo_wavesel_index];


    Mid_wavesel_index = analogControls[5] >> 9;
    if ((mixMid > 256) && (Mid_wavesel_index != Mid_wavesel_indexOld)) {
      declick_ready = 1;
      Mid_wavesel_indexOld = Mid_wavesel_index;
    }
    waveTableMidLink = CZWTselMid[Mid_wavesel_index];

    Hi_wavesel_index = analogControls[4] >> 9;
    if ((mixHi > 256) && (Hi_wavesel_index != Hi_wavesel_indexOld)) {
      declick_ready = 1;
      Hi_wavesel_indexOld = Hi_wavesel_index;
    }
    waveTableHiLink = CZWTselHi[Hi_wavesel_index];
  }

      EffectAmountCont = analogControls[2];

      TUNELOCK_TOGGLE();

      if ((analogControls[4] >> 9) == 15) WTShiftHi = 31;
      else WTShiftHi = 23;
    
      mixPos = (analogControls[6] >> 1);

      OSC_MODE_TOGGLES();

      FX_TOGGLES();

      totalratio = totalratio - readingsratio[controlAveragingIndex];
      readingsratio[controlAveragingIndex] = analogControls[0];
      totalratio = totalratio + readingsratio[controlAveragingIndex];
      controlAveragingIndex = controlAveragingIndex + 1;
      if (controlAveragingIndex >= numreadingsratio) controlAveragingIndex = 0;
      averageratio = totalratio / numreadingsratio;

      FMIndexCont = (int)(analogControls[1] >> 2);
      FMTable = CZWTselFM[analogControls[3] >> 9];
}
//--------------------------------------------------------------------CZ-ALT--------------------------------------------------
void UPDATECONTROLS_CZALT() {
  if (fixedWave == 1) {
    lo_wavesel_index = analogControls[8] >> 9;
    if ((mixLo > 256) && (lo_wavesel_index != lo_wavesel_indexOld)) {
      declick_ready = 1;
      lo_wavesel_indexOld = lo_wavesel_index;
    }
    waveTableLoLink = CZAltWTselLo[lo_wavesel_index];

    Mid_wavesel_index = analogControls[5] >> 9;
    if ((mixMid > 256) && (Mid_wavesel_index != Mid_wavesel_indexOld)) {
      declick_ready = 1;
      Mid_wavesel_indexOld = Mid_wavesel_index;
    }
    waveTableMidLink = CZAltWTselMid[Mid_wavesel_index];
  }

      TUNELOCK_TOGGLE();
      EffectAmountCont = analogControls[2];

      if ((analogControls[5] >> 9) == 15) WTShiftMid = 31;
      else WTShiftMid = 23;

      FMX_HiOffsetContCub = (analogControls[4] >> 3) - 512;
      FMX_HiOffsetCont = (float)(FMX_HiOffsetContCub * FMX_HiOffsetContCub * FMX_HiOffsetContCub) / 1073741824.0;


      mixPos = analogControls[6] >> 1;

      OSC_MODE_TOGGLES();

      FX_TOGGLES();

      totalratio = totalratio - readingsratio[controlAveragingIndex];
      readingsratio[controlAveragingIndex] = analogControls[0];
      totalratio = totalratio + readingsratio[controlAveragingIndex];
      controlAveragingIndex = controlAveragingIndex + 1;
      if (controlAveragingIndex >= numreadingsratio) controlAveragingIndex = 0;
      averageratio = totalratio / numreadingsratio;
    
      FMIndexCont = (int)(analogControls[1] >> 2);

      FMTable = CZAltWTselFM[analogControls[3] >> 9];
      FMTableAMX = CZAltWTselFMAMX[analogControls[3] >> 9]; //am mod on hi position

      if ((analogControls[3] >> 9) == 15) WTShiftFM = 31;
      else WTShiftFM = 23;
}


//----------------------------------------------------------------FM--------------------------------------------------------
void UPDATECONTROLS_FM() {
  if (fixedWave == 1) {
    lo_wavesel_index = analogControls[8] >> 9;
    if ((mixLo > 256) && (lo_wavesel_index != lo_wavesel_indexOld)) {
      declick_ready = 1;
      lo_wavesel_indexOld = lo_wavesel_index;
    }
    waveTableLoLink = FMWTselLo[lo_wavesel_index];

    Mid_wavesel_index = analogControls[5] >> 9;
    if ((mixMid > 256) && (Mid_wavesel_index != Mid_wavesel_indexOld)) {
      declick_ready = 1;
      Mid_wavesel_indexOld = Mid_wavesel_index;

    }
    waveTableMidLink = FMWTselMid[Mid_wavesel_index];

    Hi_wavesel_index = analogControls[4] >> 9;
    if ((mixHi > 256) && (Hi_wavesel_index != Hi_wavesel_indexOld)) {
      declick_ready = 1;
      Hi_wavesel_indexOld = Hi_wavesel_index;
    }
    waveTableHiLink = FMWTselHi[Hi_wavesel_index];
  }

      TUNELOCK_TOGGLE();
      EffectAmountCont = analogControls[2];

      if ((analogControls[4] >> 9) == 15) WTShiftHi = 31;
      else WTShiftHi = 23;

      mixPos = (analogControls[6] >> 1);

      OSC_MODE_TOGGLES();

      FX_TOGGLES();

      totalratio = totalratio - readingsratio[controlAveragingIndex];
      readingsratio[controlAveragingIndex] = analogControls[0]; //fm ratio control smoothing in FM
      totalratio = totalratio + readingsratio[controlAveragingIndex];
      controlAveragingIndex = controlAveragingIndex + 1;
      if (controlAveragingIndex >= numreadingsratio) controlAveragingIndex = 0;
      averageratio = totalratio / numreadingsratio;

      FMIndexCont = (int)(analogControls[1] >> 2);

      FMTable = FMWTselFM[analogControls[3] >> 9];
      if ((analogControls[3] >> 9) == 15) WTShiftFM = 31;
      else WTShiftFM = 23;
}


//--------------------------------------------------------------------------FMALT--------------------------------------------------------------

void UPDATECONTROLS_FMALT() {

  if (fixedWave == 1) {
    lo_wavesel_index = analogControls[8] >> 9;
    if ((mixLo > 256) && (lo_wavesel_index != lo_wavesel_indexOld)) {
      declick_ready = 1;
      lo_wavesel_indexOld = lo_wavesel_index;
    }
    waveTableLoLink = FMAltWTselLo[lo_wavesel_index];

    Mid_wavesel_index = analogControls[5] >> 9;
    if ((mixMid > 256) && (Mid_wavesel_index != Mid_wavesel_indexOld)) {
      declick_ready = 1;
      Mid_wavesel_indexOld = Mid_wavesel_index;
    }
    waveTableMidLink = FMAltWTselMid[Mid_wavesel_index];
  }

      TUNELOCK_TOGGLE();
      EffectAmountCont = analogControls[2];

      if ((analogControls[5] >> 9) == 15) WTShiftMid = 31;
      else WTShiftMid = 23;

      FMX_HiOffsetContCub = (analogControls[4] >> 3) - 512;
      FMX_HiOffsetCont = (float)(FMX_HiOffsetContCub * FMX_HiOffsetContCub * FMX_HiOffsetContCub) / 134217728.0;
    
      mixPos = (analogControls[6] >> 1);

      OSC_MODE_TOGGLES();

      FX_TOGGLES();

      totalratio = totalratio - readingsratio[controlAveragingIndex];
      readingsratio[controlAveragingIndex] = analogControls[0]; //fm ratio control smoothing in FM
      totalratio = totalratio + readingsratio[controlAveragingIndex];
      controlAveragingIndex = controlAveragingIndex + 1;
      if (controlAveragingIndex >= numreadingsratio) controlAveragingIndex = 0;
      averageratio = totalratio / numreadingsratio;

      FMIndexCont = (int)(analogControls[1] >> 2);

      FMTable = FMAltWTselFM[analogControls[3] >> 9];
      if ((analogControls[3] >> 9) == 15) WTShiftFM = 31;
      else WTShiftFM = 23;

}

void UPDATECONTROLS_DRUM() {

      EffectAmountCont = analogControls[2];

      TUNELOCK_TOGGLE();


      //((((drum_d * drum_d)>>16)+1)*drum_d)>>2;drum_d
      //drum decay

      //waveTableMidLink = drumWT[analogControls[8] >> 9];

      mixPos = (analogControls[6] >> 1); //this is drum wave mix

      OSC_MODE_TOGGLES();

      FX_TOGGLES();
    
      FMIndexCont = (int)(analogControls[1] >> 2);

      //waveTableHiLink = drumWT2[analogControls[4] >> 9]; //drum uses mid wave from fm
      //drum uses mid wave from fm
      //      if ((analogControls[3] >> 9) == 15) WTShiftMid = 31;
      //      else WTShiftMid = 23;

}


