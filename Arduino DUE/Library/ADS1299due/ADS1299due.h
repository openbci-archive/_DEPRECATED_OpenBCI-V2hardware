//
//  ADS1299due.h
//  Part of the Arduino DUE Library
//  Created by Conor Russomanno, Luke Travis, and Joel Murphy. Summer 2013.
//

#ifndef ____ADS1299due__
#define ____ADS1299due__

#include <stdio.h>
#include <Arduino.h>
#include <avr/pgmspace.h>
#include "Definitions.h"


class ADS1299due {
public:
    
    void initialize(int _DRDY, int _RST, int _CS);
    
    //ADS1299 SPI Command Definitions (Datasheet, p35)
    //System Commands
    void WAKEUP();
    void STANDBY();
    void RESET();
    void START();
    void STOP();
    
    //Data Read Commands
    void RDATAC();
    void SDATAC();
    void RDATA();
    
    //Register Read/Write Commands
    byte getDeviceID();
    byte RREG(byte _address);
    void RREGS(byte _address, byte _numRegistersMinusOne);     
    void printRegisterName(byte _address);
    void WREG(byte _address, byte _value); 
    void WREGS(byte _address, byte _numRegistersMinusOne); 
    void printHex(byte _data);
    void updateChannelData();
    
    //SPI Transfer functions
    byte spiRead();
	void spiWrite(byte outByte);

    int DRDY, CS; 		// pin numbers for DRDY and CS 
    long stat;			// used to hold the status register
    byte regData [24];	// array is used to mirror register data
    long channelData [9];	// array used when reading channel data
    boolean verbose;		// turn on/off Serial feedback
    
    
};

#endif