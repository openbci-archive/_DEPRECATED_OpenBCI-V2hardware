//System Commands
void ADS_POR(){                 
  delay(50);		        // recommended power up sequence requiers Tpor (~32mS)	
//  pinMode(RESET_PIN,OUTPUT);
  digitalWrite(RESET_PIN,LOW);
  delayMicroseconds(4);	        // toggle reset pin
  digitalWrite(RESET_PIN,HIGH);
  delayMicroseconds(20);	// recommended to wait 18 Tclk before using device (~8uS); 
}

void WAKEUP() {
    ADS.setSelect(LOW);                     // open spi
    ADS.transfer(_WAKEUP);         // only allowed to send WAKEUP after sending STANDBY
    ADS.setSelect(HIGH);                     // close spi 
    delayMicroseconds(3);       //must wait 4 tCLK cycles before sending another command (Datasheet, pg. 35)
}

void STANDBY() {       
    ADS.setSelect(LOW);                     // open spi
    ADS.transfer(_STANDBY);
    ADS.setSelect(HIGH);                     // close spi
}

void RESET() {                  
    ADS.setSelect(LOW);                     // open spi
    ADS.transfer(_RESET);          // reset all the registers to default settings
    delayMicroseconds(12);      // must wait 18 tCLK cycles to execute this command (Datasheet, pg. 35)
    ADS.setSelect(HIGH);                     // close spi
}

void START() {         
    ADS.setSelect(LOW);                     // open spi
    ADS.transfer(_START);          // start data conversion
    ADS.setSelect(HIGH);                     // close spi
}

void STOP() {          
    ADS.setSelect(LOW);                     // open spi
    ADS.transfer(_STOP);           // stop data conversion
    ADS.setSelect(HIGH);                     // close spi
}

void RDATAC() {
    ADS.setSelect(LOW);                     // open spi
    ADS.transfer(_RDATAC);         // enter Read Data Continuous mode
    ADS.setSelect(HIGH);                     // close spi
    delayMicroseconds(3);   
}
void SDATAC() {
    ADS.setSelect(LOW);                     // open spi
    ADS.transfer(_SDATAC);         // exit Read Data Continuous mode
    ADS.setSelect(HIGH);                     // close spi
    delayMicroseconds(3);       // must wait 4 tCLK cycles after executing this command (Datasheet, pg. 37)
}


// Register Read/Write Commands
byte getDeviceID() {            // simple hello world com verification
    byte data = RREG(0x00);     // this will return the Device ID (0x3E on my developer module)
    if(verbose){                // verbose otuput
        Serial.print("Device ID ");
        printHex(data); 
    }
    return data;
}

byte RREG(byte _address) {     //  reads ONE register at _address
    byte opcode1 = _address + 0x20;     //  RREG expects 001rrrrr where rrrrr = _address
    ADS.setSelect(LOW);                     // open spi              //  open SPI
    ADS.transfer(opcode1);                  //  opcode1
    ADS.transfer(0x00);                     //  opcode2
    byte data = ADS.transfer(0x00);         //  returned byte
    ADS.setSelect(HIGH);             //  close SPI   
    if (verbose){                       //  verbose output
        printRegisterName(_address);
        printHex(_address);
        Serial.print(", ");
        printHex(data);
        Serial.print(", ");
        for(byte j = 0x80; j>0; j>>=1){
            if((data & j) > 0){
                Serial.print("1");
            }else{
                Serial.print("0");
            }
            
        }
        
        Serial.println();
    }
    return data;
}

// Read more than one register starting at _address
void RREGS(byte _address, byte _numRegistersMinusOne) {
    byte opcode1 = _address + 0x20;     //  RREG expects 001rrrrr where rrrrr = _address
    ADS.setSelect(LOW);              // open spi           
    ADS.transfer(opcode1);                 //  opcode1
    ADS.transfer(_numRegistersMinusOne);   //  opcode2
    for(int i = _address; i <= _address+_numRegistersMinusOne; i++){
        regData[i] = ADS.transfer(0x00);       //  add returned byte to array
    }
    ADS.setSelect(HIGH);                             //  close SPI
    if(verbose){                        //  verbose output
        for(int i = 0; i<= _numRegistersMinusOne; i++){
            printRegisterName(_address + i);
            printHex(_address + i);
            Serial.print(", ");
            printHex(regData[_address + i]);
            Serial.print(", ");
            for(byte j = 0x80; j>0; j>>=1){
                if((regData[_address + i] & j) > 0){
                    Serial.print("1");
                }else{
                    Serial.print("0");
                }
            }
            Serial.println();
        }
    }  
}

void WREG(byte _address, byte _value) {    //  Write ONE register at _address
    char opcode1 = _address + 0x40;     //  WREG expects 010rrrrr where rrrrr = _address
    ADS.setSelect(LOW);                     // open spi            
    ADS.transfer(opcode1);                  //  Send WREG command & address
    ADS.transfer(0x00);                     //  Send number of registers to read -1
    ADS.transfer(_value);                   //  Write the value to the register
    ADS.setSelect(HIGH);             //  close SPI
    if(verbose){                        //  verbose output
        Serial.print("Register ");
        printHex(_address);
        Serial.print(" modified.\n");
    }
}

void WREGS(byte _address, byte _numRegistersMinusOne) {
    byte opcode1 = _address + 0x40;     //  WREG expects 010rrrrr where rrrrr = _address
    ADS.setSelect(LOW);                             // open spi             
    ADS.transfer(opcode1);                 //  Send WREG command & address
    ADS.transfer(_numRegistersMinusOne);   //  Send number of registers to read -1 
    for (int i=_address; i <= _address +_numRegistersMinusOne; i++){
        ADS.transfer(regData[i]);           //  Write to the registers
    }   
    ADS.setSelect(HIGH);                             //  close SPI
    if(verbose){
        Serial.print("Registers ");
        printHex(_address); Serial.print(" to ");
        printHex(_address + _numRegistersMinusOne);
        Serial.print(" modified.\n");
    }
}


void updateChannelData(){
    byte inByte;
    ADS.setSelect(LOW);                             // open spi
    for(int i=0; i<3; i++){    
      inByte = ADS.transfer(0x00);           //  read status register (1100 + LOFF_STATP + LOFF_STATN + GPIO[4:7]).
      stats = (stats<<8) | inByte;
    }
    for(int i=0; i<8; i++){
        for(int j=0; j<3; j++){         //  read channel data
            inByte = ADS.transfer(0x00);
            channelData[i] = (channelData[i]<<8) | inByte;
        }
    }
    ADS.setSelect(HIGH);         //  close SPI
    
    for(int i=0; i<8; i++){         // convert 3 byte 2's compliment to 4 byte 2's compliment   
        if((channelData[i] & 0x00800000) > 0){   
            channelData[i] |= 0xFF000000;       // when MSB is set, the number is negative
        }else{
            channelData[i] &= 0x00FFFFFF;       // when MSB is clear, the number is positive
        }
    }

}
    



void RDATA() {                      //  use in Stop Read Continuous mode when DRDY goes low
    byte inByte;
    ADS.setSelect(LOW);                         // open spi           
    ADS.transfer(_RDATA);               // send the RDATA command
    for(int i=0; i<3; i++){    
      inByte = ADS.transfer(0x00);           //  read status register (1100 + LOFF_STATP + LOFF_STATN + GPIO[4:7]).
      stats = stats<<8 | inByte;
    }
    for(int i=0; i<8; i++){
        for(int j=0; j<3; j++){     //  read the new channel data
            inByte = ADS.transfer(0x00);
            channelData[i] = (channelData[i]<<8) | inByte;
        }
    }
    ADS.setSelect(HIGH);                         //  close SPI
    for(int i=0; i<8; i++){         // convert 3 byte 2's compliment to 4 byte 2's compliment   
        if((channelData[i] & 0x00800000) > 0){   
            channelData[i] |= 0xFF000000;       // when MSB is set, the number is negative
        }else{
            channelData[i] &= 0x00FFFFFF;       // when MSB is clear, it's a positive number
        }
    }
	if(verbose){
		Serial.print(stats); Serial.print(", ");
		for(int i=0; i<8; i++){
			Serial.print(channelData[i]);
			if(i<7){Serial.print(", ");}
		}
		Serial.println();
	}
}


// String-Byte converters for RREG and WREG used in verbose mode
void printRegisterName(char _address) {
    switch(_address){
        case ID:
            Serial.print("ID, ");
            break;
        case CONFIG1:
            Serial.print("CONFIG1, ");
            break;
        case CONFIG2:
            Serial.print("CONFIG2, ");
            break;
        case CONFIG3:
            Serial.print("CONFIG3, ");
            break;
        case LOFF:
            Serial.print("LOFF, ");
            break;
        case CH1SET:
            Serial.print("CH1SET, ");
            break;
        case CH2SET:
            Serial.print("CH2SET, ");
            break;
        case CH3SET:
            Serial.print("CH3SET, ");
            break;
        case CH4SET:
            Serial.print("CH4SET, ");
            break;
        case CH5SET:
            Serial.print("CH5SET, ");
            break;
        case CH6SET:
            Serial.print("CH6SET, ");
            break;
        case CH7SET:
            Serial.print("CH7SET, ");
            break;
        case CH8SET:
            Serial.print("CH8SET, ");
            break;
        case BIAS_SENSP:
            Serial.print("BIAS_SENSP, ");
            break;
        case BIAS_SENSN:
            Serial.print("BIAS_SENSN, ");
            break;
        case LOFF_SENSP:
            Serial.print("LOFF_SENSP, ");
            break;
        case LOFF_SENSN:
            Serial.print("LOFF_SENSN, ");
            break;
        case LOFF_FLIP:
            Serial.print("LOFF_FLIP, ");
            break;
        case LOFF_STATP:
            Serial.print("LOFF_STATP, ");
            break;
        case LOFF_STATN:
            Serial.print("LOFF_STATN, ");
            break;
        case GPIO:
            Serial.print("GPIO, ");
            break;
        case MISC1:
            Serial.print("MISC1, ");
            break;
        case MISC2:
            Serial.print("MISC2, ");
            break;
        case CONFIG4:
            Serial.print("CONFIG4, ");
            break;
        default:
            break;
    }
}


// Used for printing HEX in verbose mode
void printHex(byte _data){  
    Serial.print("0x");
    if(_data < 0x10){
        Serial.print("0");
    }
    Serial.print(_data,HEX);
}
