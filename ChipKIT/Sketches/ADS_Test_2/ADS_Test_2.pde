/*
    ChipKit interface to the ADS1299 OpenBCI Breakout
*/


#include <ADSdefinitions.h>

#include <DSPI.h>


long stats;             // used to hold the statsus register
byte regData [24];      // array used when reading ADS register data
long channelData [8];   // array used when reading ADS channel data
boolean verbose;        // turn on/off Serial feedback
boolean testing;
unsigned long thisTime;
unsigned long thatTime;
long elapsedTime;
int sampleCounter = 0;

byte inByte;
// instantiate the dspiZero
DSPI0  ADS;  // DSPI0 is connected to 13,12,11 on UNO32 board


void setup(){
  
  ADS.begin(10);      // do this in the ads library?
  ADS.setMode(DSPI_MODE1);  //  do this in the ads library?
  ADS.setSpeed(4000000);
  
  pinMode(RESET_PIN,OUTPUT);
  digitalWrite(RESET_PIN,HIGH);
  pinMode(DRDY_PIN,INPUT);
  
  ADS_POR();            // try not to do anything before this, for proper POR sequence
  Serial.begin(115200);
  Serial.println("ChipKIT ADS1299 Test 2");
  verbose = true;       // set up for serial feedback
  testing = false;
    RESET();             // send RESET command as part of the power up routine
    SDATAC();            // stop Read Data Continuous mode to communicate with ADS
    RREGS(0x00,0x17);     // read ADS registers starting at 0x00 and ending at 0x17
    WREG(CONFIG3,0xE0);  // enable internal reference buffer
    RREG(CONFIG3);       // verify write
    for(int i=CH1SET; i<=CH8SET; i++){
        regData[i] = 0x60;              // regData is our copy of the ADS register settings
    }
    WREGS(0x05,7);      // (reg to start writing at, number of regs-1)
    RREGS(0x05,7);      // read ADS registers starting at 0x00 and ending at 0x17
    RDATAC();           // start Read Data Continuous mode

    Serial.println("Press 'x' to initiate test");
  // this is just a blinky thing for fun
//  pinMode(PIN_LED1, OUTPUT);     
//  pinMode(PIN_LED2, OUTPUT); 

}

void loop() {
  
   if (testing){
    Serial.println("entering test loop");
    START();                    // start sampling at the default rate
    thatTime = millis();            // timestamp
//    Serial.println(thatTime);
    ADStest(500);                   // go to testing routine and specify the number of samples to take
    thisTime = millis();            // timestamp
    STOP();                     // stop the sampling
//    elapsedTime = thisTime - thatTime;
    Serial.print("Elapsed Time ");Serial.println(thisTime - thatTime);  // benchmark
    Serial.print("Samples ");Serial.println(sampleCounter);   // 
    testing = false;                // reset testing flag
    sampleCounter = 0;              // reset counter
    Serial.println("Press 'x' to begin test");  // ask for prompt
  }// end of testing

  
  
////  digitalWrite(PIN_LED1, HIGH);  
//  digitalWrite(PIN_LED2, LOW); 
//  delay(500);              
////  digitalWrite(PIN_LED1, LOW);    
//  digitalWrite(PIN_LED2, HIGH);
//  delay(200);              
  
  serialEvent();
}


void serialEvent(){            // send an 'x' on the serial line to trigger ADStest()
  while(Serial.available()){      
    char inChar = (char)Serial.read();
    if (inChar  == 'x'){   
      testing = true;
    }
  }
}

void ADStest(int numSamples){
  while(sampleCounter < numSamples){  // take only as many samples as you need
//  Serial.print("numSamples = ");
//  Serial.println(numSamples);
//  int dummy = digitalRead(DRDY);
    while(digitalRead(DRDY_PIN)){            // watch the DRDY pin
//      dummy = digitalRead(DRDY);
      }
//      Serial.println("hi");
    updateChannelData();          // update the channelData array 
    sampleCounter++;                  // increment sample counter for next time
  }
    return;
}



