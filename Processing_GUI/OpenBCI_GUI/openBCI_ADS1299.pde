
///////////////////////////////////////////////////////////////////////////////
//
// This class configures and manages the connection to the OpenBCI shield for
// the Arduino.  The connection is implemented via a Serial connection.
// The OpenBCI is configured using single letter text commands sent from the
// PC to the Arduino.  The EEG data streams back from the Arduino to the PC
// continuously (once started).  This class defaults to using binary transfer
// for normal operation.
//
// Created: Chip Audette, Oct 2013
//
// Note: this class does not care whether you are using V1 or V2 of the OpenBCI
// board because the Arduino itself handles the differences between the two.  The
// command format to the Arduino and the data format from the Arduino are the same.
//
/////////////////////////////////////////////////////////////////////////////

//import processing.serial.*;

String command_stop = "s";
String command_startText = "x";
String command_startBinary = "b";
String command_startBinary_4chan = "v";
String command_activateFilters = "F";
String command_deactivateFilters = "f";
String[] command_deactivate_channel = {"1", "2", "3", "4", "5", "6", "7", "8"};
String[] command_activate_channel = {"q", "w", "e", "r", "t", "y", "u", "i"};

final int DATAMODE_TXT = 0;
final int DATAMODE_BIN = 1;
final int DATAMODE_BIN_4CHAN = 4;

final int STATE_NOCOM = 0;
final int STATE_COMINIT = 1;
final int STATE_NORMAL = 2;
final int COM_INIT_MSEC = 4000; //you may need to vary this for your computer or your Arduino

final byte BYTE_START = byte(0xA0);
final byte BYTE_END = byte(0xC0);
final byte CHAR_END = byte(0xA0);  //line feed?
final int LEN_SERIAL_BUFF_CHAR = 1000;
final int MIN_PAYLOAD_LEN_INT32 = 1; //8 is the normal number, but there are shorter modes to enable Bluetooth

int preffered_datamode = DATAMODE_BIN;

class openBCI_ADS1299 {
  Serial serial_openBCI = null;
  int state = STATE_NOCOM;
  int dataMode = preffered_datamode;
  int prevState_millis = 0;
  byte[] serialBuff;
  int curBuffIndex = 0;
  dataPacket_ADS1299 dataPacket;
  boolean isNewDataPacketAvailable = false;
  int num_channels;
  
  //constructor
  openBCI_ADS1299(PApplet applet, String comPort, int baud, int num_channels) {
    serialBuff = new byte[LEN_SERIAL_BUFF_CHAR];  //allocate the serial buffer
    dataPacket = new dataPacket_ADS1299(num_channels);
    if (serial_openBCI != null) closeSerialPort();
    openSerialPort(applet, comPort, baud);
  }
  
  //manage the serial port  
  int openSerialPort(PApplet applet, String comPort, int baud) {
    serial_openBCI = new Serial(applet,comPort,baud); //open the com port
    serial_openBCI.clear(); // clear anything in the com port's buffer     
    changeState(STATE_COMINIT);
    return 0;
  }
  int changeState(int newState) {
    state = newState;
    prevState_millis = millis();
    return 0;
  }
  int updateState() {
    if (state == STATE_COMINIT) {
      if ((millis() - prevState_millis) > COM_INIT_MSEC) {
        //serial_openBCI.write(command_activates + "\n"); println("Processing: OpenBCI_ADS1299: activating filters");
        changeState(STATE_NORMAL);
        startDataTransfer(preffered_datamode);
        //startDataTransfer(DATAMODE_BIN_4CHAN);
      }
    }
    return 0;
  }    

  int closeSerialPort() {
    serial_openBCI.stop();
    serial_openBCI = null;
    state = STATE_NOCOM;
    return 0;
  }
  
  //start the data transfer using the current mode
  int startDataTransfer() {
    return startDataTransfer(dataMode);
  }
  
  //start data trasnfer using the given mode
  int startDataTransfer(int mode) {
    dataMode = mode;
    stopDataTransfer();
    switch (mode) {
      case DATAMODE_BIN:
        serial_openBCI.write(command_startBinary + "\n");
        println("Processing: OpenBCI_ADS1299: starting binary");
        break;
      case DATAMODE_BIN_4CHAN:
        serial_openBCI.write(command_startBinary_4chan + "\n");
        println("Processing: OpenBCI_ADS1299: starting binary 4-channel");
        break;      
      case DATAMODE_TXT:
        serial_openBCI.write(command_startText + "\n");
        println("Processing: OpenBCI_ADS1299: starting text");
        break;
    }
    return 0;
  }
  
  void stopDataTransfer() {
    serial_openBCI.write(command_stop + "\n");
    serial_openBCI.clear(); // clear anything in the com port's buffer
  }
  
  //read from the serial port
  int read() {  return read(false); }
  int read(boolean echoChar) {
    //get the byte
    byte inByte = byte(serial_openBCI.read());
    if (echoChar) print(char(inByte));
    
    //accumulate the data in the buffer
    serialBuff[curBuffIndex] = inByte;
    //println("openBCI_ADS1299: curBuffIndex = " + curBuffIndex);
        
    //increment the buffer index for the next time
    curBuffIndex++;     
          
    //is the data packet complete?
    switch (dataMode) {
      case DATAMODE_BIN:
        if (inByte == BYTE_END) interpretBinaryMessage();
        break;
      case DATAMODE_BIN_4CHAN:
        if (inByte == BYTE_END) interpretBinaryMessage();
        break;
      case DATAMODE_TXT:
        if (inByte == CHAR_END) interpretTextMessage();
        break; 
      default:
        //don't accumulate...just reset back to the first place in the buffer
        curBuffIndex=0;
        break;
    }

    //check to make sure that the buffer index hasn't gone too far
    if (curBuffIndex >= serialBuff.length) curBuffIndex = serialBuff.length-1;

    return int(inByte);
  }

  //activate or deactivate an EEG channel...channel counting is zero through nchan-1
  public void changeChannelState(int Ichan,boolean activate) {
    if (serial_openBCI != null) {
      if ((Ichan >= 0) && (Ichan < command_activate_channel.length)) {
        if (activate) {
          serial_openBCI.write(command_activate_channel[Ichan] + "\n");
        } else {
          serial_openBCI.write(command_deactivate_channel[Ichan] + "\n");
        }
      }
    }
  }
  
  //deactivate an EEG channel...channel counting is zero through nchan-1
  public void deactivateChannel(int Ichan) {
    if (serial_openBCI != null) {
      if ((Ichan >= 0) && (Ichan < command_activate_channel.length)) {
        serial_openBCI.write(command_activate_channel[Ichan]);
      }
    }
  }

  //return the state
  boolean isStateNormal() { 
    if (state == STATE_NORMAL) { 
      return true;
    } else {
      return false;
    }
  }
  
  //interpret the data
  int interpretBinaryMessage() {
    //assume curBuffIndex has already been incremented to the next open spot
    int startInd = curBuffIndex-1;
    int endInd = curBuffIndex-1;
    
    //println("openBCI_ADS1299: interpretBinaryMessage: interpretting...");
     
    //roll backwards to find the start of the packet
    while ((startInd >= 0) && (serialBuff[startInd] != BYTE_START)) {
      startInd--;
    }
    if (startInd < 0) {
      //didn't find the start byte..so ignore this data packet
    } else if ((endInd - startInd + 1) < 3) {
      //data packet isn't long enough to hold any data...so ignore this data packet
    } else {
      int n_bytes = int(serialBuff[startInd + 1]); //this is the number of bytes in the payload
      
      
      // check to see if the payload is at least the minimum length
      if (n_bytes < 4*MIN_PAYLOAD_LEN_INT32) {
        //bad data.  ignore this packet;
      } else {
        //check to see if the payload length matches the measured packet size
        if ((startInd + 1 + n_bytes + 1) != endInd) {
          //bad data.  ignore this packet
        } else {
          //println("openBCI_ADS1299: interpretBinaryMessage: good packet!");
          int startIndPayload = startInd+1+1;
          int nInt32 = n_bytes / 4;
          interpretBinaryPayload(startIndPayload,nInt32);
          //dataPacket.printToConsole();
        }
      }      
    }
    
    curBuffIndex=0;  //reset buffer counter back to zero to start refilling the buffer
    return 0;
  }
  int interpretBinaryPayload(int startInd,int nInt32) {
    dataPacket.sampleIndex = interpretAsInt32(subset(serialBuff,startInd,4)); //read the int32 value
    startInd += 4;  //increment the start index
    
    int nValToRead = min(nInt32-1,dataPacket.values.length);
    for (int i=0; i < nValToRead;i++) {
      dataPacket.values[i] = interpretAsInt32(subset(serialBuff,startInd,4)); //read the int32 value
      startInd += 4;  //increment the start index
    }
    
    isNewDataPacketAvailable = true;
    return 0;
  }
  int interpretAsInt32(byte[] byteArray) {
    //big endian
//    return int(
//      ((0xFF & byteArray[0]) << 24) | 
//      ((0xFF & byteArray[1]) << 16) |
//      ((0xFF & byteArray[2]) << 8) | 
//      (0xFF & byteArray[3])
//      );
      
    //little endian
    return int(
      ((0xFF & byteArray[3]) << 24) | 
      ((0xFF & byteArray[2]) << 16) |
      ((0xFF & byteArray[1]) << 8) | 
      (0xFF & byteArray[0])
      );
  }
  
  int interpretTextMessage() {
    //still have to code this!
    curBuffIndex=0;  //reset buffer counter back to zero to start refilling the buffer
    return 0;
  }
  
  int copyDataPacketTo(dataPacket_ADS1299 target) {
    isNewDataPacketAvailable = false;
    dataPacket.copyTo(target);
    return 0;
  }
}
