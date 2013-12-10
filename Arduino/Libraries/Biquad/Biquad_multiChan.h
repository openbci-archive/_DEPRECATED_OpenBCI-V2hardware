//
//  Biquad_multiChan.h
//
//  Created by Nigel Redmon on 11/24/12
//  EarLevel Engineering: earlevel.com
//  Copyright 2012 Nigel Redmon
//
//  For a complete explanation of the Biquad code:
//  http://www.earlevel.com/main/2012/11/25/biquad-c-source-code/
//
//  License:
//
//  This source code is provided as is, without warranty.
//  You may copy and distribute verbatim copies of this document.
//  You may modify and use this source code to create binary code
//  for your own purposes, free or commercial.
//
//  Extended by Chip Audette (Nov 2013) to handle multiple channels of data
//  that are being filtered by the same coefficients
//

#ifndef Biquad_multiChan_h
#define Biquad_multiChan_h

enum {
    bq_type_lowpass = 0,
    bq_type_highpass,
    bq_type_bandpass,
    bq_type_notch,
    bq_type_peak,
    bq_type_lowshelf,
    bq_type_highshelf
};

class Biquad_multiChan {
public:
    //Biquad_multiChan();
    Biquad_multiChan(int Nchan, int type, double Fc, double Q, double peakGainDB);
    ~Biquad_multiChan();
    void setType(int type);
    void setQ(double Q);
    void setFc(double Fc);
    void setPeakGain(double peakGainDB);
    void setBiquad(int type, double Fc, double Q, double peakGain);
    float process(float in,int Ichan);
    
protected:
    void calcBiquad(void);

    int Nchan;
    int type;
    double a0, a1, a2, b1, b2;
    double Fc, Q, peakGain;
    double *z1, *z2;
};

inline float Biquad_multiChan::process(float in,int Ichan) {
    double out = in * a0 + z1[Ichan];
    z1[Ichan] = in * a1 + z2[Ichan] - b1 * out;
    z2[Ichan] = in * a2 - b2 * out;
    return out;
}

#endif // Biquad_multiChan_h
