/*Developed by Joel Murphy and Conor Russomanno (Summer 2013)
  This example uses the ADS1299 Arduino Library, a software bridge between the ADS1299 chip and 
  Arduino. See http://www.ti.com/product/ads1299 for more information about the device and the README
  folder in the ADS1299 directory for more information about the library.
  
  This program reads all the ADS1299 registers, modifies CONFIG3, then modifies all 8 channel registers.
  Yup, it's a simple SPI link hello world functional test. When verbose is true, there will be Serial feedback.
  NOTE: the datasheet will tell you that the Channel Set Registers (0x05 to 0x0C) default to 0x60. Don't believe it.
  The default value for these locations is 0x61. 
  
  
  Arduino Uno - Pin Assignments
  SCK = 13
  MISO [DOUT] = 12
  MOSI [DIN] = 11
  CS = 10; 
  RESET = 9;
  DRDY = 8;
  
*/

#include <ADS1299.h>

ADS1299 ADS;

void setup() {
  // don't put anything before the initialization routine for recommended POR  
  ADS.initialize(8,9,10,4); // (DRDY pin, RST pin, CS pin, SCK frequency in MHz);

  Serial.begin(115200);
  Serial.println("ADS1299-Arduion UNO Example 1"); 
  delay(1000);             

  ADS.verbose = true;      // when verbose is true, there will be Serial feedback 
  ADS.RESET();             // all registers set to default
  ADS.SDATAC();            // stop Read Data Continuous mode to communicate with ADS
  ADS.RREGS(0x00,0x17);    // read ADS registers starting at 0x00 and ending at 0x17
  ADS.WREG(CONFIG3,0xE0);  // enable internal reference buffer
  ADS.RREG(CONFIG3);       // verify write
  for(byte i=CH1SET; i<=CH8SET; i++){   // set up to modify the 8 channel setting registers
    ADS.regData[i] = 0x60;           // the regData array mirrors the ADS1299 register addresses
  }                                  
  ADS.WREGS(CH1SET,7);               // write new channel settings
  ADS.RREGS(CH1SET,7);               // read out what we just did to verify the write
  ADS.RDATAC();                      // enter Read Data Continuous mode
  
} // end of setup

void loop(){
} // end of loop
