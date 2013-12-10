//
//  ADS1299due.cpp   ARDUINO DUE LIBRARY FOR COMMUNICATING WITH ADS1299
//  
//  Created by Conor Russomanno, Luke Travis, and Joel Murphy. Summer, 2013
//


#include "pins_arduino.h"
#include "ADS1299due.h"

void ADS1299due::initialize(int _DRDY, int _RST, int _CS){
    DRDY = _DRDY;
    CS = _CS;
//	int FREQ = _FREQ;
	int RST = _RST;
	
		delay(50);				// recommended power up sequence requiers Tpor (~32mS)	
		pinMode(RST,OUTPUT);
		pinMode(RST,LOW);
		delayMicroseconds(4);	// toggle reset pin
		pinMode(RST,HIGH);
		delayMicroseconds(20);	// recommended to wait 18 Tclk before using device (~8uS);
	

    // **** ----- SPI Setup ----- **** //
    
    // Set direction register for SCK and MOSI pin.
    // MISO pin automatically overrides to INPUT.
    // When the SS pin is set as OUTPUT, it can be used as
    // a general purpose output port (it doesn't influence
    // SPI operations).
    
//    pinMode(SCK, OUTPUT);
//    pinMode(MOSI, OUTPUT);
//    pinMode(SS, OUTPUT);
	
    
//    digitalWrite(SCK, LOW);
//    digitalWrite(MOSI, LOW);
//    digitalWrite(SS, HIGH);
    
    // set as master and enable SPI
//    SPCR |= _BV(MSTR);
//    SPCR |= _BV(SPE);
//    //set bit order
//    SPCR &= ~(_BV(DORD)); ////SPI data format is MSB (pg. 25)
//	// set data mode
//    SPCR = (SPCR & ~SPI_MODE_MASK) | SPI_DATA_MODE; //clock polarity = 0; clock phase = 1 (pg. 8)
//    // set clock divider
//	switch (FREQ){
//		case 8:
//			DIVIDER = SPI_CLOCK_DIV_2;
//			break;
//		case 4:
//			DIVIDER = SPI_CLOCK_DIV_4;
//			break;
//		case 1:
//			DIVIDER = SPI_CLOCK_DIV_16;
//			break;
//		default:
//			break;
//	}
//    SPCR = (SPCR & ~SPI_CLOCK_MASK) | (DIVIDER);  // set SCK frequency  
//    SPSR = (SPSR & ~SPI_2XCLOCK_MASK) | (DIVIDER); // by dividing 16MHz system clock
    
    
    
    
    
    // **** ----- End of SPI Setup ----- **** //
    
    // initalize the  data ready chip select and reset pins:
	pinMode(13,OUTPUT);  // SCK
	pinMode(12, INPUT);  // MISO
	pinMode(11,OUTPUT);  // MOSI
	pinMode(CS, OUTPUT);
    pinMode(DRDY, INPUT);
    
	digitalWrite(13,LOW);
	digitalWrite(CS,HIGH); 	
//	digitalWrite(RST,HIGH);
}

//System Commands
void ADS1299due::WAKEUP() {
    digitalWrite(CS, LOW); 
    spiWrite(_WAKEUP);
    digitalWrite(CS, HIGH); 
    delayMicroseconds(3);  		//must wait 4 tCLK cycles before sending another command (Datasheet, pg. 35)
}

void ADS1299due::STANDBY() {		// only allowed to send WAKEUP after sending STANDBY
    digitalWrite(CS, LOW);
    spiWrite(_STANDBY);
    digitalWrite(CS, HIGH);
}

void ADS1299due::RESET() {			// reset all the registers to default settings
    digitalWrite(CS, LOW);
    spiWrite(_RESET);
    delayMicroseconds(12);   	//must wait 18 tCLK cycles to execute this command (Datasheet, pg. 35)
    digitalWrite(CS, HIGH);
}

void ADS1299due::START() {			//start data conversion 
    digitalWrite(CS, LOW);
    spiWrite(_START);
    digitalWrite(CS, HIGH);
}

void ADS1299due::STOP() {			//stop data conversion
    digitalWrite(CS, LOW);
    spiWrite(_STOP);
    digitalWrite(CS, HIGH);
}

void ADS1299due::RDATAC() {
    digitalWrite(CS, LOW);
    spiWrite(_RDATAC);
    digitalWrite(CS, HIGH);
	delayMicroseconds(3);   
}
void ADS1299due::SDATAC() {
    digitalWrite(CS, LOW);
    spiWrite(_SDATAC);
    digitalWrite(CS, HIGH);
	delayMicroseconds(3);   //must wait 4 tCLK cycles after executing this command (Datasheet, pg. 37)
}


// Register Read/Write Commands
byte ADS1299due::getDeviceID() {			// simple hello world com check
	byte data = RREG(0x00);
	if(verbose){						// verbose otuput
		Serial.print(F("Device ID "));
		printHex(data);	
	}
	return data;
}

byte ADS1299due::RREG(byte _address) {		//  reads ONE register at _address
    byte opcode1 = _address + 0x20; 	//  RREG expects 001rrrrr where rrrrr = _address
    digitalWrite(CS, LOW); 				//  open SPI
    spiWrite(opcode1); 					//  opcode1
    spiWrite(0x00); 					//  opcode2
    regData[_address] = spiRead();//  update mirror location with returned byte
    digitalWrite(CS, HIGH); 			//  close SPI	
	if (verbose){						//  verbose output
		printRegisterName(_address);
		printHex(_address);
		Serial.print(", ");
		printHex(regData[_address]);
		Serial.print(", ");
		for(byte j = 0; j<8; j++){
			Serial.print(bitRead(regData[_address], 7-j));
			if(j!=7) Serial.print(", ");
		}
		
		Serial.println();
	}
	return regData[_address];			// return requested register value
}

// Read more than one register starting at _address
void ADS1299due::RREGS(byte _address, byte _numRegistersMinusOne) {
//	for(byte i = 0; i < 0x17; i++){
//		regData[i] = 0;					//  reset the regData array
//	}
    byte opcode1 = _address + 0x20; 	//  RREG expects 001rrrrr where rrrrr = _address
    digitalWrite(CS, LOW); 				//  open SPI
    spiWrite(opcode1); 					//  opcode1
    spiWrite(_numRegistersMinusOne);	//  opcode2
    for(int i = 0; i <= _numRegistersMinusOne; i++){
        regData[_address + i] = spiRead(); 	//  add register byte to mirror array
		}
    digitalWrite(CS, HIGH); 			//  close SPI
	if(verbose){						//  verbose output
		for(int i = 0; i<= _numRegistersMinusOne; i++){
			printRegisterName(_address + i);
			printHex(_address + i);
			Serial.print(", ");
			printHex(regData[_address + i]);
			Serial.print(", ");
			for(int j = 0; j<8; j++){
				Serial.print(bitRead(regData[_address + i], 7-j));
				if(j!=7) Serial.print(", ");
			}
			Serial.println();
		}
    }
    
}

void ADS1299due::WREG(byte _address, byte _value) {	//  Write ONE register at _address
    byte opcode1 = _address + 0x40; 	//  WREG expects 010rrrrr where rrrrr = _address
    digitalWrite(CS, LOW); 				//  open SPI
    spiWrite(opcode1);					//  Send WREG command & address
    spiWrite(0x00);						//	Send number of registers to read -1
    spiWrite(_value);					//  Write the value to the register
    digitalWrite(CS, HIGH); 			//  close SPI
	regData[_address] = _value;			//  update the mirror array
	if(verbose){						//  verbose output
		Serial.print(F("Register "));
		printHex(_address);
		Serial.println(F(" modified."));
	}
}

void ADS1299due::WREGS(byte _address, byte _numRegistersMinusOne) {
    byte opcode1 = _address + 0x40;		//  WREG expects 010rrrrr where rrrrr = _address
    digitalWrite(CS, LOW); 				//  open SPI
    spiWrite(opcode1);					//  Send WREG command & address
    spiWrite(_numRegistersMinusOne);	//	Send number of registers to read -1	
	for (int i=_address; i <=(_address + _numRegistersMinusOne); i++){
		spiWrite(regData[i]);			//  Write to the registers
	}	
	digitalWrite(CS,HIGH);				//  close SPI
	if(verbose){
		Serial.print(F("Registers "));
		printHex(_address); Serial.print(F(" to "));
		printHex(_address + _numRegistersMinusOne);
		Serial.println(F(" modified"));
	}
}


void ADS1299due::updateChannelData(){
	byte inByte;
	stat = 0;
	digitalWrite(CS, LOW);				//  open SPI
	for(int i=0; i<3; i++){
		inByte = spiRead();				
		stat = (stat<<8) | inByte;		//  read status register (1100 + LOFF_STATP + LOFF_STATN + GPIO[7:4])
	}
	
	for(int i = 0; i<8; i++){
		for(int j=0; j<3; j++){			//  read 24 bits of channel data in 8 3 byte chunks
			inByte = spiRead();
			channelData[i] = (channelData[i]<<8) | inByte;
		}
	}
	digitalWrite(CS, HIGH);				//  close SPI
	
	for(int i=0; i<8; i++){			// convert 3 byte 2's compliment to 4 byte 2's compliment
		if(bitRead(channelData[i],23) == 1){	
			channelData[i] |= 0xFF000000;
		}else{
			channelData[i] &= 0x00FFFFFF;
		}
	}
//	if(verbose){
//		Serial.print(stat); Serial.print(", ");
//		for(int i=0; i<8; i++){
//			Serial.print(channelData[i]);
//			if(i<7){Serial.print(", ");}
//		}
//		Serial.println();
//	}
}
	



void ADS1299due::RDATA() {					//  use in Stop Read Continuous mode when DRDY goes low
	byte inByte;						//  to read in one sample of the channels
    digitalWrite(CS, LOW);				//  open SPI
    spiWrite(_RDATA);					//  send the RDATA command
	stat = spiRead();				//  read status register (1100 + LOFF_STATP + LOFF_STATN + GPIO[7:4])
	for(int i = 0; i<8; i++){
		for(int j=0; j<3; j++){		//  read in the status register and new channel data
			inByte = spiRead();
			channelData[i] = (channelData[i]<<8) | inByte;
		}
	}
	digitalWrite(CS, HIGH);				//  close SPI
	
	for(int i=0; i<8; i++){
		if(bitRead(channelData[i],23) == 1){	// convert 3 byte 2's compliment to 4 byte 2's compliment
			channelData[i] |= 0xFF000000;
		}else{
			channelData[i] &= 0x00FFFFFF;
		}
	}
    
}


// String-Byte converters for RREG and WREG
void ADS1299due::printRegisterName(byte _address) {
    if(_address == ID){
        Serial.print(F("ID, ")); //the "F" macro loads the string directly from Flash memory, thereby saving RAM
    }
    else if(_address == CONFIG1){
        Serial.print(F("CONFIG1, "));
    }
    else if(_address == CONFIG2){
        Serial.print(F("CONFIG2, "));
    }
    else if(_address == CONFIG3){
        Serial.print(F("CONFIG3, "));
    }
    else if(_address == LOFF){
        Serial.print(F("LOFF, "));
    }
    else if(_address == CH1SET){
        Serial.print(F("CH1SET, "));
    }
    else if(_address == CH2SET){
        Serial.print(F("CH2SET, "));
    }
    else if(_address == CH3SET){
        Serial.print(F("CH3SET, "));
    }
    else if(_address == CH4SET){
        Serial.print(F("CH4SET, "));
    }
    else if(_address == CH5SET){
        Serial.print(F("CH5SET, "));
    }
    else if(_address == CH6SET){
        Serial.print(F("CH6SET, "));
    }
    else if(_address == CH7SET){
        Serial.print(F("CH7SET, "));
    }
    else if(_address == CH8SET){
        Serial.print(F("CH8SET, "));
    }
    else if(_address == BIAS_SENSP){
        Serial.print(F("BIAS_SENSP, "));
    }
    else if(_address == BIAS_SENSN){
        Serial.print(F("BIAS_SENSN, "));
    }
    else if(_address == LOFF_SENSP){
        Serial.print(F("LOFF_SENSP, "));
    }
    else if(_address == LOFF_SENSN){
        Serial.print(F("LOFF_SENSN, "));
    }
    else if(_address == LOFF_FLIP){
        Serial.print(F("LOFF_FLIP, "));
    }
    else if(_address == LOFF_STATP){
        Serial.print(F("LOFF_STATP, "));
    }
    else if(_address == LOFF_STATN){
        Serial.print(F("LOFF_STATN, "));
    }
    else if(_address == GPIO){
        Serial.print(F("GPIO, "));
    }
    else if(_address == MISC1){
        Serial.print(F("MISC1, "));
    }
    else if(_address == MISC2){
        Serial.print(F("MISC2, "));
    }
    else if(_address == CONFIG4){
        Serial.print(F("CONFIG4, "));
    }
}

////SPI communication methods
//byte ADS1299::transfer(byte _data) {
//	cli();
//    SPDR = _data;
//    while (!(SPSR & _BV(SPIF)))
//        ;
//	sei();
//    return SPDR;
//}

// Used for printing HEX in verbose feedback mode
void ADS1299due::printHex(byte _data){
	Serial.print("0x");
    if(_data < 0x10) Serial.print("0");
    Serial.print(_data, HEX);
}

void ADS1299due::spiWrite(byte outByte){
		REG_PIOB_SODR |= 0x08000000;     // set SCK
	    if(outByte & 0x80){          // bang out a bit
	      REG_PIOD_SODR |= 0x80;        // fastest way to set pin 11
	    }else{ 
	      REG_PIOD_CODR |= 0x80;        // fastet way to clear pin 11
	    }
	    REG_PIOB_CODR |= 0x08000000;    // clear SCK
	    
	    REG_PIOB_SODR |= 0x08000000;     // set SCK
	    if(outByte & 0x40){          // bang out a bit
	      REG_PIOD_SODR |= 0x80;        // fastest way to set pin 11
	    }else{ 
	      REG_PIOD_CODR |= 0x80;        // fastet way to clear pin 11
	    }
	    REG_PIOB_CODR |= 0x08000000;    // clear SCK
	    
	    REG_PIOB_SODR |= 0x08000000;     // set SCK
	    if(outByte & 0x20){          // bang out a bit
	      REG_PIOD_SODR |= 0x80;        // fastest way to set pin 11
	    }else{ 
	      REG_PIOD_CODR |= 0x80;        // fastet way to clear pin 11
	    }
	    REG_PIOB_CODR |= 0x08000000;    // clear SCK
	    
	    REG_PIOB_SODR |= 0x08000000;     // set SCK
	    if(outByte & 0x10){          // bang out a bit
	      REG_PIOD_SODR |= 0x80;        // fastest way to set pin 11
	    }else{ 
	      REG_PIOD_CODR |= 0x80;        // fastet way to clear pin 11
	    }
	    REG_PIOB_CODR |= 0x08000000;    // clear SCK
	    
	    REG_PIOB_SODR |= 0x08000000;     // set SCK
	    if(outByte & 0x08){          // bang out a bit
	      REG_PIOD_SODR |= 0x80;        // fastest way to set pin 11
	    }else{ 
	      REG_PIOD_CODR |= 0x80;        // fastet way to clear pin 11
	      }
	      REG_PIOB_CODR |= 0x08000000;    // clear SCK
	    
	    REG_PIOB_SODR |= 0x08000000;     // set SCK
	    if(outByte & 0x04){          // bang out a bit
	      REG_PIOD_SODR |= 0x80;        // fastest way to set pin 11
	    }else{ 
	      REG_PIOD_CODR |= 0x80;        // fastet way to clear pin 11
	    }
	    REG_PIOB_CODR |= 0x08000000;    // clear SCK
	    
	    REG_PIOB_SODR |= 0x08000000;     // set SCK
	    if(outByte & 0x02){          // bang out a bit
	      REG_PIOD_SODR |= 0x80;        // fastest way to set pin 11
	    }else{ 
	      REG_PIOD_CODR |= 0x80;        // fastet way to clear pin 11
	    }
	    REG_PIOB_CODR |= 0x08000000;    // clear SCK
	    
	    REG_PIOB_SODR |= 0x08000000;     // set SCK
	    if(outByte & 0x01){          // bang out a bit
	      REG_PIOD_SODR |= 0x80;        // fastest way to set pin 11
	    }else{ 
	      REG_PIOD_CODR |= 0x80;        // fastet way to clear pin 11
	    }
	    REG_PIOB_CODR |= 0x08000000;    // clear SCK
}


byte ADS1299due::spiRead(){
	 	REG_PIOD_CODR |= 0x80;                 // fastet way to clear pin 11 to send only zeros
	  	byte inByte = 0;                       // the byte to be returned
	  
	    REG_PIOB_SODR |= 0x08000000;     // set SCK    
	    REG_PIOB_CODR |= 0x08000000;    // clear SCK
	    inByte |= (REG_PIOD_PDSR & 0x100) >> 1;    // bang in a bit
	    
	    REG_PIOB_SODR |= 0x08000000;     // set SCK    
	    REG_PIOB_CODR |= 0x08000000;    // clear SCK
	    inByte |= (REG_PIOD_PDSR & 0x100) >> 2;    // bang in a bit
	    
	    REG_PIOB_SODR |= 0x08000000;     // set SCK    
	    REG_PIOB_CODR |= 0x08000000;    // clear SCK
	    inByte |= (REG_PIOD_PDSR & 0x100) >> 3;    // bang in a bit
	    
	    REG_PIOB_SODR |= 0x08000000;     // set SCK    
	    REG_PIOB_CODR |= 0x08000000;    // clear SCK
	    inByte |= (REG_PIOD_PDSR & 0x100) >> 4;    // bang in a bit
	    
	    REG_PIOB_SODR |= 0x08000000;     // set SCK    
	    REG_PIOB_CODR |= 0x08000000;    // clear SCK
	    inByte |= (REG_PIOD_PDSR & 0x100) >> 5;    // bang in a bit
	    
	    REG_PIOB_SODR |= 0x08000000;     // set SCK    
	    REG_PIOB_CODR |= 0x08000000;    // clear SCK
	    inByte |= (REG_PIOD_PDSR & 0x100) >> 6;    // bang in a bit
	    
	    REG_PIOB_SODR |= 0x08000000;     // set SCK    
	    REG_PIOB_CODR |= 0x08000000;    // clear SCK
	    inByte |= (REG_PIOD_PDSR & 0x100) >> 7;    // bang in a bit
	    
	    REG_PIOB_SODR |= 0x08000000;     // set SCK    
	    REG_PIOB_CODR |= 0x08000000;    // clear SCK
	    inByte |= (REG_PIOD_PDSR & 0x100) >> 8;    // bang in a bit
	     
	    return inByte;                   // give up your byte!
}

//-------------------------------------------------------------------//
//-------------------------------------------------------------------//
//-------------------------------------------------------------------//



