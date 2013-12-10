/*Developed by Joel Murphy and Conor Russomanno (Summer 2013)
  This example uses the ADS1299 Arduino Library, a software bridge between the ADS1299 TI chip and 
  Arduino. See http://www.ti.com/product/ads1299 for more information about the device and the README
  folder in the ADS1299 directory for more information about the library.
  
  This program does the following
  It reads in all registers in verbose mode, then alters the CONFIG3 register,
  then asks for a prompt to take 500 samples at the default rate of 250sps.
  At the prompt, the START command is sent, and a mS timestamp is saved.
  A function called ADStest() proceeds to poll the DRDY pin, and call
  the updateChanelData() member funcion until all samples are counted.
  Then another timestamp is taken, duration of event is calculated and 
  printed to terminal. Then the prompt re-appears.
  The library outputs verbose feedback when verbose is true.
  
  Arduino Uno - Pin Assignments
  SCK = 13
  MISO [DOUT] = 12
  MOSI [DIN] = 11
  CS = 10; 
  RESET = 9;
  DRDY = 8;
  
*/

#include <ADS1299.h>

ADS1299 ADS;                           // create an instance of ADS1299

unsigned long thisTime;                
unsigned long thatTime;
unsigned long elapsedTime;
int resetPin = 9;                      // pin 9 used to start conversion in Read Data Continuous mode
int sampleCounter = 0;                 // used to time the tesing loop
boolean testing = false;               // this flag is set in serialEvent on reciept of prompt

void setup() {
  // don't put anything before the initialization routine for recommended POR  
  ADS.initialize(8,9,10,4); // (DRDY pin, RST pin, CS pin, SCK frequency in MHz);

  Serial.begin(115200);
  Serial.println("ADS1299-Arduino UNO Example 2"); 
  delay(2000);             

  ADS.verbose = true;      // when verbose is true, there will be Serial feedback 
  ADS.RESET();             // send RESET command to default all registers
  ADS.SDATAC();            // exit Read Data Continuous mode to communicate with ADS
  ADS.RREGS(0x00,0x17);     // read all registers starting at ID and ending at CONFIG4
  ADS.WREG(CONFIG3,0xE0);  // enable internal reference buffer, for fun
  ADS.RREG(CONFIG3);       // verify write
  ADS.RDATAC();            // enter Read Data Continuous mode
  
  Serial.println("Press 'x' to begin test");    // ask for prompt
} // end of setup

void loop(){
  
  if (testing){
    Serial.println("entering test loop");
    ADS.START();                    // start sampling at the default rate
    thatTime = millis();            // timestamp
    ADStest(500);                   // go to testing routine and specify the number of samples to take
    thisTime = millis();            // timestamp
    ADS.STOP();                     // stop the sampling
    elapsedTime = thisTime - thatTime;
    Serial.print("Elapsed Time ");Serial.println(elapsedTime);  // benchmark
      Serial.print("Samples ");Serial.println(sampleCounter);   // 
    testing = false;                // reset testing flag
    sampleCounter = 0;              // reset counter
    Serial.println("Press 'x' to begin test");  // ask for prompt
  }// end of testing
  
} // end of loop


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
    while(digitalRead(8)){            // watch the DRDY pin
      }
    ADS.updateChannelData();          // update the channelData array 
    sampleCounter++;                  // increment sample counter for next time
  }
    return;
}




