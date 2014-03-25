
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
// Modified: through March 2014
//
// Note: this class does not care whether you are using V1 or V2 of the OpenBCI
// board because the Arduino itself handles the differences between the two.  The
// command format to the Arduino and the data format from the Arduino are the same.
//
/////////////////////////////////////////////////////////////////////////////

//import processing.serial.*;
import java.io.OutputStream; //for logging raw bytes to an output file

final String command_stop = "s";
final String command_startText = "x";
final String command_startBinary = "b";
final String command_startBinary_4chan = "v";
final String command_activateFilters = "F";
final String command_deactivateFilters = "f";
final String[] command_deactivate_channel = {"1", "2", "3", "4", "5", "6", "7", "8"};
final String[] command_activate_channel = {"q", "w", "e", "r", "t", "y", "u", "i"};
final String[] command_activate_leadoffP_channel = {"!", "@", "#", "$", "%", "^", "&", "*"};  //shift + 1-8
final String[] command_deactivate_leadoffP_channel = {"Q", "W", "E", "R", "T", "Y", "U", "I"};   //letters (plus shift) right below 1-8
final String[] command_activate_leadoffN_channel = {"A", "S", "D", "F", "G", "H", "J", "K"}; //letters (plus shift) below the letters below 1-8
final String[] command_deactivate_leadoffN_channel = {"Z", "X", "C", "V", "B", "N", "M", "<"};   //letters (plus shift) below the letters below the letters below 1-8
 
class OpenBCI_ADS1299 {
 
  //final static int DATAMODE_TXT = 0;
  final static int DATAMODE_BIN = 1;
  //final static int DATAMODE_BIN_4CHAN = 4;
  
  final static int STATE_NOCOM = 0;
  final static int STATE_COMINIT = 1;
  final static int STATE_NORMAL = 2;
  final static int COM_INIT_MSEC = 4000; //you may need to vary this for your computer or your Arduino
  
  int[] measured_packet_length = {0,0,0,0,0};
  int measured_packet_length_ind = 0;
  int known_packet_length_bytes = 0;
  
  final static byte BYTE_START = (byte)0xA0;
  final static byte BYTE_END = (byte)0xC0;
  
  int prefered_datamode = DATAMODE_BIN;

  
  Serial serial_openBCI = null;
  int state = STATE_NOCOM;
  int dataMode = prefered_datamode;
  int prevState_millis = 0;
  //byte[] serialBuff;
  //int curBuffIndex = 0;
  DataPacket_ADS1299 dataPacket;
  boolean isNewDataPacketAvailable = false;
  int num_channels;
  OutputStream output; //for debugging  WEA 2014-01-26
  int prevSampleIndex = 0;
  int serialErrorCounter = 0;
  
  //constructor
  OpenBCI_ADS1299(PApplet applet, String comPort, int baud, int nchan) {
    num_channels = nchan;
    //serialBuff = new byte[LEN_SERIAL_BUFF_CHAR];  //allocate the serial buffer
    dataPacket = new DataPacket_ADS1299(num_channels);
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
        startDataTransfer(prefered_datamode);
      }
    }
    return 0;
  }    

  int closeSerialPort() {
    if (serial_openBCI != null) {
      serial_openBCI.stop();
      serial_openBCI = null;
      state = STATE_NOCOM;
    }
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
        println("OpenBCI_ADS1299: starting binary transfer");
        break;
    }
    return 0;
  }
  
  void stopDataTransfer() {
    if (serial_openBCI != null) {
      serial_openBCI.write(command_stop + "\n");
      serial_openBCI.clear(); // clear anything in the com port's buffer
    }
  }
  
  //read from the serial port
  int read() {  return read(false); }
  int read(boolean echoChar) {
    //get the byte
    byte inByte = byte(serial_openBCI.read());
    if (echoChar) print(char(inByte));
    
    //write raw unprocessed bytes to a binary data dump file
    if (output != null) {
      try {
       output.write(inByte);   //for debugging  WEA 2014-01-26
      } catch (IOException e) {
        System.err.println("OpenBCI_ADS1299: Caught IOException: " + e.getMessage());
        //do nothing
      }
    }
    
    interpretBinaryStream(inByte);  //new 2014-02-02 WEA
    return int(inByte);
  }

  /* **** Borrowed from Chris Viegl from his OpenBCI parser for BrainBay
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
  ********************************************************************* */
  int channelsInPacket = 0;
  int localByteCounter=0;
  int localChannelCounter=0;
  int PACKET_readstate = 0;
  byte[] localByteBuffer = {0,0,0,0};
  void interpretBinaryStream(byte actbyte)
  { 
    //println("OpenBCI_ADS1299: PACKET_readstate " + PACKET_readstate);
    switch (PACKET_readstate) {
      case 0:  
           if (actbyte == byte(0xA0)) {          // look for start indicator
            //println("OpenBCI_ADS1299: found 0xA0");
            PACKET_readstate++;
           } 
           break;
      case 1:  
           channelsInPacket = ((int)actbyte) / 4 - 1;   // get number of channels
           if (channelsInPacket != num_channels) {
            serialErrorCounter++;
            println("OpenBCI_ADS1299: given number of channels (" + channelsInPacket + ") is not acceptable.  Ignoring packet. (" + serialErrorCounter + ")");
            PACKET_readstate=0;
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
            if ((dataPacket.sampleIndex-prevSampleIndex) != 1) {
              serialErrorCounter++;
              println("OpenBCI_ADS1299: apparent sampleIndex jump from Serial data: " + prevSampleIndex + " to  " + dataPacket.sampleIndex + ".  Keeping packet. (" + serialErrorCounter + ")");
            }
            prevSampleIndex = dataPacket.sampleIndex;
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
            //println("OpenBCI_ADS1299: received chan  = " + localChannelCounter);
            localChannelCounter++;
            if (localChannelCounter==channelsInPacket) {  
              // all channels arrived !
              PACKET_readstate++;
              //isNewDataPacketAvailable = true;  //tell the rest of the code that the data packet is complete
            } else { 
              //prepare for next data channel
              localByteCounter=0; //prepare for next usage of localByteCounter
            }
          }
          break;
      case 4:
        if (actbyte == byte(0xC0)) {    // if correct end delimiter found:
          isNewDataPacketAvailable = true; //original place for this.  but why not put it in the previous case block
        } else {
          serialErrorCounter++;
          println("OpenBCI_ADS1299: expecteding end-of-packet byte is missing.  Discarding packet. (" + serialErrorCounter + ")");
        }
        PACKET_readstate=0;  // either way, look for next packet
        break;
      default: 
          println("OpenBCI_ADS1299: Unknown byte: " + actbyte + " ...continuing.");
          PACKET_readstate=0;  // look for next packet
    }
  } // end of interpretBinaryStream


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
  
  public void changeImpedanceState(int Ichan,boolean activate,int code_P_N_Both) {
    //println("OpenBCI_ADS1299: changeImpedanceState: Ichan " + Ichan + ", activate " + activate + ", code_P_N_Both " + code_P_N_Both);
    if (serial_openBCI != null) {
      if ((Ichan >= 0) && (Ichan < command_activate_leadoffP_channel.length)) {
        if (activate) {
          if ((code_P_N_Both == 0) || (code_P_N_Both == 2)) {
            //activate the P channel
            serial_openBCI.write(command_activate_leadoffP_channel[Ichan] + "\n");
          } else if ((code_P_N_Both == 1) || (code_P_N_Both == 2)) {
            //activate the N channel
            serial_openBCI.write(command_activate_leadoffN_channel[Ichan] + "\n");
          }
        } else {
          if ((code_P_N_Both == 0) || (code_P_N_Both == 2)) {
            //deactivate the P channel
            serial_openBCI.write(command_deactivate_leadoffP_channel[Ichan] + "\n");
          } else if ((code_P_N_Both == 1) || (code_P_N_Both == 2)) {
            //deactivate the N channel
            serial_openBCI.write(command_deactivate_leadoffN_channel[Ichan] + "\n");
          }          
        }
      }
    }
  }
  
  
  int interpretAsInt32(byte[] byteArray) {     
    //little endian
    return int(
      ((0xFF & byteArray[3]) << 24) | 
      ((0xFF & byteArray[2]) << 16) |
      ((0xFF & byteArray[1]) << 8) | 
      (0xFF & byteArray[0])
      );
  }
  

  
  int copyDataPacketTo(DataPacket_ADS1299 target) {
    isNewDataPacketAvailable = false;
    dataPacket.copyTo(target);
    return 0;
  }
  
//  int measurePacketLength() {
//    
//    //assume curBuffIndex has already been incremented to the next open spot
//    int startInd = curBuffIndex-1;
//    int endInd = curBuffIndex-1;
//
//    //roll backwards to find the start of the packet
//    while ((startInd >= 0) && (serialBuff[startInd] != BYTE_START)) {
//      startInd--;
//    }
//    if (startInd < 0) {
//      //didn't find the start byte..so ignore this data packet
//      return 0;
//    } else if ((endInd - startInd + 1) < 3) {
//      //data packet isn't long enough to hold any data...so ignore this data packet
//      return 0;
//    } else {
//      //int n_bytes = int(serialBuff[startInd + 1]); //this is the number of bytes in the payload
//      //println("OpenBCI_ADS1299: measurePacketLength = " + (endInd-startInd+1));
//      return endInd-startInd+1;
//    }
//  }
      
    
};


