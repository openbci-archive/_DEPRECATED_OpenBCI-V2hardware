
//
//  ADS1299Manager.h
//  Part of the Arduino Library for the ADS1299 Shield
//  Created by Chip Audette, Fall 2013
//


#ifndef ____ADS1299Manager__
#define ____ADS1299Manager__

#include <ADS1299.h>

//Pick which version of OpenBCI you have
#define OPENBCI_V1 (1)    //Sept 2013
#define OPENBCI_V2 (2)    //Oct 24, 2013
#define OPENBCI_NCHAN (8)  // number of EEG channels

/*   Arduino Uno - Pin Assignments
  SCK = 13
  MISO [DOUT] = 12
  MOSI [DIN] = 11
  CS = 10; 
  RESET = 9;
  DRDY = 8;
*/
#define PIN_DRDY (8)
#define PIN_RST (9)
#define PIN_CS (10)
#define SCK_MHZ (4)

//gainCode choices
#define ADS_GAIN01 (0b00000000)
#define ADS_GAIN02 (0b00010000)
#define ADS_GAIN04 (0b00100000)
#define ADS_GAIN06 (0b00110000)
#define ADS_GAIN08 (0b01000000)
#define ADS_GAIN12 (0b01010000)
#define ADS_GAIN24 (0b01100000)

//inputCode choices
#define ADSINPUT_NORMAL (0b00000000)
#define ADSINPUT_SHORTED (0b00000001)
#define ADSINPUT_TESTSIG (0b00000101)

//test signal choices...ADS1299 datasheet page 41
#define ADSTESTSIG_AMP_1X (0b00000000)
#define ADSTESTSIG_AMP_2X (0b00000100)
#define ADSTESTSIG_PULSE_SLOW (0b00000000)
#define ADSTESTSIG_PULSE_FAST (0b00000001)
#define ADSTESTSIG_DCSIG (0b00000011)
#define ADSTESTSIG_NOCHANGE (0b11111111)

//binary communication codes for each packet
#define PCKT_START 0xA0
#define PCKT_END 0xC0

class ADS1299Manager : public ADS1299 {
  public:
    void initialize(void);                                     //initialize the ADS1299 controller.  Call once.  Assumes OpenBCI_V2
    void initialize(int version);                              //initialize the ADS1299 controller.  Call once.  Set which version of OpenBCI you're using.
    void setVersionOpenBCI(int version);			//Set which version of OpenBCI you're using.
    void reset(void);                                          //reset all the ADS1299's settings.  Call however you'd like
    void activateChannel(int N, byte gainCode,byte inputCode); //setup the channel 1-8
    void deactivateChannel(int N);                            //disable given channel 1-8
    void configureInternalTestSignal(byte amplitudeCode, byte freqCode);  
    void start(void);
    void stop(void);
    int isDataAvailable(void);
    void printChannelDataAsText(int N, long int sampleNumber);
    void writeChannelDataAsBinary(int N, long int sampleNumber);
    void writeChannelDataAsOpenEEG_P2(long int sampleNumber);
    void writeChannelDataAsOpenEEG_P2(long int sampleNumber, boolean useSyntheticData);
    void printAllRegisters(void);
    void setSRB1(boolean desired_state);
    
  private:
    boolean use_neg_inputs;
    boolean use_SRB2[OPENBCI_NCHAN];
    boolean use_SRB1(void);
};

#endif