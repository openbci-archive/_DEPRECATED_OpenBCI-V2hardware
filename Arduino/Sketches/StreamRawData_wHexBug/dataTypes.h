
/*
  TextHexBugController
 
 Created: Chip Audette, May 2014
 http://eeghacker.blogspot.com
 
 Purpose: This code assumes that you've hacked the IR remote control of a hex bug
 to allow the Arduino to "push" the remote control's buttons.  You issue serial commands
 from the PC, which are received by the Arduino, when then interacts with the remote control.
 
 Hex Bug IR Remote: There are four buttons on the Hex Bug IR remote.   The high side of
 each button attached to the remote control's microcontroller, which must use a pull-up
 to hold the pin at 3.3V.  The low side of each button is connected to ground so that,
 when the button is pressed, the pin goes low by conducting through the now-closed button.
 
 Hack: I soldered a wire to the high side of each button and to the remote's "ground".
 I connect these wires to the Arduino. 
 
 Software Approach: Normally, the Arduino pins are set to "INPUT" because that makes
 the pins hae a high input impedance, which means that they do not affect the voltage
 at the pin to the microcontroller.  When I want the Arduino to "push" one of the
 buttons for me, I command the Arduino to change the pin to "OUTPUT" and "LOW",
 which gives a low-resistance path to ground.  As a result, it pulls the remote's
 microcontroller pin low, which makes the remote think that a button was pressed.  
 
 License: MIT License 2014
 
 */

#define PIN_GROUND A1
#define NPINS 4
#define COMMAND_FOREWARD 3
#define COMMAND_LEFT 1
#define COMMAND_RIGHT 2
#define COMMAND_FIRE 0

class HexBug_t {
  public: 

    int pins[NPINS];
    unsigned long lastCommand_millis;
    int commandDuration_millis;

    HexBug_t(void) {
      // initialize serial:
      //Serial.begin(115200); assume already initialized
  
      // print help
      //  Serial.println("TestHexBugController: starting...");
      //  Serial.println("Commands Include: ");
      //  Serial.println("    'P' = Forward");
      //  Serial.println("    '{' = Left");
      //  Serial.println("    '}' = Right");
      //  Serial.println("    '|' = Fire");

    //init variables
    lastCommand_millis = 0;
    commandDuration_millis = 500;
  
    //initialize the pins
    pins[0] = A2;
    pins[1] = A3;
    pins[2] = A4;
    pins[3] = A5;
    pinMode(PIN_GROUND,OUTPUT); 
    digitalWrite(PIN_GROUND,LOW);
    stopAllPins();
  }

  void stopAllPins(void) {
    //stopping all pins means putting them into a high impedance state
    //Serial.println("Stopping All Pins...");
    for (int Ipin=0; Ipin < NPINS; Ipin++) {
      digitalWrite(pins[Ipin],LOW);
      pinMode(pins[Ipin],INPUT);
    }
  }

  void issueCommand(int command_pin_ind) {
    if (command_pin_ind < NPINS) {
      stopAllPins();
      pinMode(pins[command_pin_ind],OUTPUT);
      digitalWrite(pins[command_pin_ind],LOW);
      lastCommand_millis = millis();  //time the command was received
    }
  }

  void parseSerialChar(char inChar) {
    //while (Serial.available()) {
    //  char inChar = (char)Serial.read();
    //  Serial.print("Received "); Serial.println(inChar);
    switch (inChar) {
      case 'P':
        issueCommand(COMMAND_FOREWARD); 
        break;
      case '{':
        issueCommand(COMMAND_LEFT); 
        break;
      case '}':
        issueCommand(COMMAND_RIGHT); 
        break;
      case '|':
        issueCommand(COMMAND_FIRE); 
        break;
      }
    //}
  }
};



