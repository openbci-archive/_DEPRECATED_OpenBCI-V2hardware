
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
// Modified: through Jan 2014
//
// Note: this class does not care whether you are using V1 or V2 of the OpenBCI
// board because the Arduino itself handles the differences between the two.  The
// command format to the Arduino and the data format from the Arduino are the same.
//
/////////////////////////////////////////////////////////////////////////////

//import processing.serial.*;
import java.io.OutputStream; //for logging raw bytes to an output file

String command_stop = "s";
String command_startText = "x";
String command_startBinary = "b";
String command_startBinary_4chan = "v";
String command_activateFilters = "F";
String command_deactivateFilters = "f";
String[] command_deactivate_channel = {"1", "2", "3", "4", "5", "6", "7", "8"};
String[] command_activate_channel = {"q", "w", "e", "r", "t", "y", "u", "i"};

//final int DATAMODE_TXT = 0;
final int DATAMODE_BIN = 1;
//final int DATAMODE_BIN_4CHAN = 4;

final int STATE_NOCOM = 0;
final int STATE_COMINIT = 1;
final int STATE_NORMAL = 2;
final int COM_INIT_MSEC = 4000; //you may need to vary this for your computer or your Arduino

int[] measured_packet_length = {0,0,0,0,0};
int measured_packet_length_ind = 0;
int known_packet_length_bytes = 0;

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
  OutputStream output; //for debugging  WEA 2014-01-26
  
  //constructor
  openBCI_ADS1299(PApplet applet, String comPort, int baud, int num_channels) {
    serialBuff = new byte[LEN_SERIAL_BUFF_CHAR];  //allocate the serial buffer
    dataPacket = new dataPacket_ADS1299(num_channels);
    if (serial_openBCI != null) closeSerialPort();
    openSerialPort(applet, comPort, baud);
    
    //open file for raw bytes
    //output = createOutput("rawByteDumpFromProcessing.bin");  //for debugging  WEA 2014-01-26
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
//      case DATAMODE_BIN_4CHAN:
//        serial_openBCI.write(command_startBinary_4chan + "\n");
//        println("Processing: OpenBCI_ADS1299: starting binary 4-channel");
//        break;      
//      case DATAMODE_TXT:
//        serial_openBCI.write(command_startText + "\n");
//        println("Processing: OpenBCI_ADS1299: starting text");
//        break;
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
    
    //write raw unprocessed bytes to a binary data dump file
//    if (output != null) {
//      try {
//       output.write(inByte);   //for debugging  WEA 2014-01-26
//      } catch (IOException e) {
//        //System.err.println("Caught IOException: " + e.getMessage());
//        //do nothing
//      }
//    }
    
    //try to interpret the bytes
//    if (dataMode == DATAMODE_BIN) {
      readBinaryStream(inByte);  //new 2014-02-02 WEA
//    } else { 
//      //non binary stream
//    }

    return int(inByte);
  }

  /***** Borrowed from Chris Viegl from his OpenBCI parser for BrainBay
  Packet Parser for OpenBCI (1-N channel binary format):

  4-byte (long) integers are stored in 'little endian' formant in AVRs
  so this protocol parser expects the lower bytes first.

  Start Indicator: 0xA0
  Packet_length  : 1 byte  (length = 4 bytes per active channel + 4 bytes framenumber)
  Framenumber    : 4 bytes (currently not used - will be a sequential counter ?)
  Channel 1 data  : 4 bytes 
  ...
  Channel N data  : 4 bytes
  End Indcator:    0xC0
  **********************************************************************/
  int channelsInPacket = 0;
  int localByteCounter=0;
  int localChannelCounter=0;
  int PACKET_readstate = 0;
  byte[] localByteBuffer = {0,0,0,0};
  void readBinaryStream(byte actbyte)
  { 
    //println("openBCI_ADS1299: PACKET_readstate " + PACKET_readstate);
    switch (PACKET_readstate) {
      case 0:  
           if (actbyte == byte(0xA0)) {          // look for start indicator
            //println("openBCI_ADS1299: found 0xA0");
            PACKET_readstate++;
           } 
           break;
      case 1:  
           channelsInPacket = ((int)actbyte) / 4 - 1;   // get number of channels
           //println("openBCI_ADS1299: channelsInPacket = " + channelsInPacket);
           if ((channelsInPacket<1) || (channelsInPacket>16)) {
            PACKET_readstate=0;
            println("openBCI_ADS1299: given number of channels (" + channelsInPacket + ") is not acceptable.  Ignoring packet.");
           } else { 
            localByteCounter=0; //prepare for next usage of localByteCounter
            PACKET_readstate++;
           }
           break;
      case 2: 
          //don't know if this branch is correct.  Untested as of 2014-02-02
          localByteBuffer[localByteCounter] = actbyte;
          localByteCounter++;
          if (localByteCounter==4) {
            dataPacket.sampleIndex = interpretAsInt32(localByteBuffer); //added WEA
            //println("openBCI_ADS1299: sampleIndex  = " + dataPacket.sampleIndex);
            localByteCounter=0;//prepare for next usage of localByteCounter
            localChannelCounter=0; //prepare for next usage of localChannelCounter
            PACKET_readstate++;
          } 
          break;
      case 3: // get channel values 
          localByteBuffer[localByteCounter] = actbyte;
          localByteCounter++;
          if (localByteCounter==4) {
            dataPacket.values[localChannelCounter] = interpretAsInt32(localByteBuffer);
            //println("openBCI_ADS1299: received chan  = " + localChannelCounter);
            localChannelCounter++;
            if (localChannelCounter==channelsInPacket) {  
              // all channels arrived !
              PACKET_readstate++;
              isNewDataPacketAvailable = true;  //tell the rest of the code that the data packet is complete
            } else { 
              //prepare for next data channel
              localByteCounter=0; //prepare for next usage of localByteCounter
            }
          }
          break;
      case 4:
        if (actbyte == byte(0xC0)) {    // if correct end delimiter found:
          PACKET_readstate=0;  // look for next packet
          //println("openBCI_ADS1299: found 0xC0");
          //isNewDataPacketAvailable = true; //original place for this.  but why not put it in the previous case block
        }
        break;
      default: 
          println("openBCI_ADS1299: Unknown byte: " + actbyte + " ...continuing");
          PACKET_readstate=0;  // look for next packet
    }
  } // end of readBinaryStream


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
    int endInd = curBuffIndex-1;
    int startInd = curBuffIndex-known_packet_length_bytes;

    
    //println("openBCI_ADS1299: interpretBinaryMessage: interpretting...");
     
    //check to see whether the data is valid to interpret
    while ((startInd >= 0) && (serialBuff[startInd] != BYTE_START)) {
      startInd--;
    }
    if (startInd < 0) {
      //didn't find the start byte..so ignore this data packet
      println("openBCI_ADS1299: interpretBinaryMessage: badly formatted packet. Dropping.");
    } else if ((endInd - startInd + 1) < 3) {
      //data packet isn't long enough to hold any data...so ignore this data packet
      println("openBCI_ADS1299: interpretBinaryMessage: badly formatted packet. Dropping.");
    } else {
      //so the data is valid to interpret.  Let's do so.
      
      //the first field after the header is the number of bytes in the payload
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
  
  int measurePacketLength() {
    
    //assume curBuffIndex has already been incremented to the next open spot
    int startInd = curBuffIndex-1;
    int endInd = curBuffIndex-1;

    //roll backwards to find the start of the packet
    while ((startInd >= 0) && (serialBuff[startInd] != BYTE_START)) {
      startInd--;
    }
    if (startInd < 0) {
      //didn't find the start byte..so ignore this data packet
      return 0;
    } else if ((endInd - startInd + 1) < 3) {
      //data packet isn't long enough to hold any data...so ignore this data packet
      return 0;
    } else {
      //int n_bytes = int(serialBuff[startInd + 1]); //this is the number of bytes in the payload
      //println("openBCI_ADS1299: measurePacketLength = " + (endInd-startInd+1));
      return endInd-startInd+1;
    }
  }
      
    
}
