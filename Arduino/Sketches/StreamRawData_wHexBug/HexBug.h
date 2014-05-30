
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
 I connect these wires to the Arduino. See my write-up at:
 
 http://eeghacker.blogspot.com/2014/05/arduino-control-of-hex-bug.html
 
 Software Approach: Normally, the Arduino pins are set to "INPUT" because that makes
 the pins hae a high input impedance, which means that they do not affect the voltage
 at the pin to the microcontroller.  When I want the Arduino to "push" one of the
 buttons for me, I command the Arduino to change the pin to "OUTPUT" and "LOW",
 which gives a low-resistance path to ground.  As a result, it pulls the remote's
 microcontroller pin low, which makes the remote think that a button was pressed.  
 
 License: MIT License 2014
 
 
 Example Constructor:  HexBug_t hexBug(A1,A2,A3,A4,A5);  //use analog pins to control the Hex Bug
 Example Constructor:  HexBug_t hexBug(4,5,6,7,8);       //use digital pins to control the Hex Bug
 Example Command: hexBug.issueCommand(COMMAND_FIRE);     //issue the FIRE command
 Example Command: hexBug.parseCommandCharacter('P');     //issue the FOREWARD command using a character (as if from the Serial link)
 Example Update (call periodically): hexBug.update();    //stops issuing the current command after set period of time
 
 */


#define NPINS 4
#define COMMAND_FOREWARD 0
#define COMMAND_LEFT 1
#define COMMAND_RIGHT 2
#define COMMAND_FIRE 3
#define NO_COMMAND -1

#define STATE_IDLE 0
#define STATE_ACTIVE 1
#define STATE_READY 2

class HexBug_t {
  public: 

    int pins[NPINS];       //holds which Arduino pins we will be using here for the different commands
    int state;            //state of this object.  Am I transmitting or not?
    int currentCommand;   //here is the command that we last issued
    int bufferedCommand;  //here is a command that I might have received that I haven't issued yet (because I'm already issuing a command
    boolean sequentialCommandsRequireIdle[NPINS];  //when repeating the same command, some commands need an idle and some don't
    
    unsigned long lastStateChange_millis;  //time of the start of the last command (or start of the last idle period
    int durationIdle_millis;       //minimum length of the idle period between commands
    int durationCommand_millis;        //duriation of a command

    HexBug_t(int pinGROUND, int pinFWD, int pinLEFT, int pinRIGHT, int pinFIRE) {
  
      //init variables
      state = STATE_READY;
      currentCommand = NO_COMMAND;
      bufferedCommand = NO_COMMAND;
      lastStateChange_millis = millis();
      durationCommand_millis = 400;
      durationIdle_millis = 400;
    
      //initialize the pins
      pins[COMMAND_FOREWARD] = pinFWD;
      pins[COMMAND_LEFT] = pinLEFT;
      pins[COMMAND_RIGHT] = pinRIGHT;
      pins[COMMAND_FIRE] = pinFIRE;
      pinMode(pinGROUND,OUTPUT); 
      digitalWrite(pinGROUND,LOW);
      stopAllPins();
      
      //define which commands require an idle period if received in sequence
      sequentialCommandsRequireIdle[COMMAND_FOREWARD] = false;
      sequentialCommandsRequireIdle[COMMAND_LEFT] = false;
      sequentialCommandsRequireIdle[COMMAND_RIGHT] = false;
      sequentialCommandsRequireIdle[COMMAND_FIRE] = true;  //only for FIRE do we need an idle period between sequential FIRE commands
    }

    void update(void) {
      unsigned long current_millis = millis();
      
      switch (state) {
        case (STATE_ACTIVE):
          //decide whether to go IDLE
          if (current_millis > (lastStateChange_millis + durationCommand_millis)) {
            //Serial.println(F("Update: Changing from ACTIVE to IDLE"));
            //stop the command
            stopAllPins();
            state = STATE_IDLE;
            lastStateChange_millis = current_millis;
          }
          break;
        case (STATE_IDLE):
          //decide whether to go READY
          if (current_millis > (lastStateChange_millis + durationIdle_millis) ) {
            //Serial.println(F("Update: Changing from IDLE to READY"));
            state = STATE_READY;
            lastStateChange_millis = current_millis;
          }
          break;
      }
      
      //check to see if there is a buffered command waiting...and issue it, if possible
      if (bufferedCommand != NO_COMMAND) {
        //there is a buffered command. Can we issue it?
        if ((state == STATE_READY) || ((state==STATE_IDLE) && (sequentialCommandsRequireIdle[bufferedCommand]==false) && (currentCommand == bufferedCommand))) {
          //yes, issue the command
          if (state==STATE_IDLE) state = STATE_READY;
          currentCommand=bufferedCommand;
          bufferedCommand = NO_COMMAND;
          issueCommand(currentCommand);
        }
      }   
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
      //is it a legal command?
      if ((command_pin_ind < NPINS) && (command_pin_ind > -1)) {
        
        //it is legal.  Can we accept a command right now?
        if (state == STATE_READY) {
          
          //we can accept a command.  act on it.
          stopAllPins();  //first, stop all other actions, if any
          pinMode(pins[command_pin_ind],OUTPUT); //set the Arduino pins to reflect this command
          digitalWrite(pins[command_pin_ind],LOW);  //ensure that the Arduino pin is set LOW to pull it to ground
          lastStateChange_millis = millis();  //time the command was issued
          currentCommand = command_pin_ind;  //record what this command is
          state = STATE_ACTIVE;
        } else {
          
          //we cannot accept a command right now...so try to buffer the command until we're ready for it
          //
          //FIRE always takes precedence
          if ((bufferedCommand != COMMAND_FIRE) bufferedCommand = command_pin_ind;
        }
      }
    }
  
    void parseCommandCharacter(char inChar) {
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
    }
    
  private:
    //nothing priviate
};



