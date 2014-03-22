///////////////////////////////////////////////
//
// GUI for controlling the ADS1299-based OpenBCI Shield
//
// Created: Chip Audette, Oct 2013 - Mar 2014
//
// Requires gwoptics graphing library for processing.  Built on V0.5.0
// http://www.gwoptics.org/processing/gwoptics_p5lib/
//
// No warranty.  Use at your own risk.  Use for whatever you'd like.
// 
///////////////////////////////////////////////


import processing.serial.*;
import ddf.minim.analysis.*; //for FFT
import java.util.*; //for Array.copyOfRange()
import java.lang.Math; //for exp, log, sqrt...they seem better than Processing's built-in

boolean useSyntheticData = false; //flip this to false when using OpenBCI

//Serial communications constants
openBCI_ADS1299 openBCI;
String openBCI_portName = "COM21";   /************** CHANGE THIS TO MATCH THE COM PORT REPORTED ON *YOUR* COMPUTER *****************/

//these settings are for a single OpenBCI board
int openBCI_baud = 115200; //baud rate from the Arduino
int OpenBCI_Nchannels = 8; //normal OpenBCI has 8 channels
//use this for when daisy-chaining two OpenBCI boards
//int openBCI_baud = 2*115200; //baud rate from the Arduino
//int OpenBCI_Nchannels = 16; //daisy chain has 16 channels


//data
float fs_Hz = 250.0f;  //sample rate used by OpenBCI board
float dataBuffX[];
float dataBuffY_uV[][]; //2D array to handle multiple data channels, each row is a new channel so that dataBuffY[3][] is channel 4
float dataBuffY_filtY_uV[][];
float data_std_uV[];
int nchan = OpenBCI_Nchannels;
final float ADS1299_Vref = 4.5f;  //reference voltage for ADC in ADS1299
final float ADS1299_gain = 24;  //assumed gain setting for ADS1299
final float scale_fac_uVolts_per_count = ADS1299_Vref / (pow(2,23)-1) / ADS1299_gain  * 1000000.f; //ADS1299 datasheet Table 7, confirmed through experiment
int prev_time_millis = 0;
final int nPointsPerUpdate = 50; //update screen after this many data points.  
float yLittleBuff[] = new float[nPointsPerUpdate];
boolean is_railed[];
final int threshold_railed = int(pow(2,23)-1000);

//filter constants
float yLittleBuff_uV[][] = new float[nchan][nPointsPerUpdate];
float filtState[] = new float[nchan];

//define filter...Matlab....butter(2,[1 50]/(250/2));  %bandpass filter
double[] b = new double[]{ 2.001387256580675e-001, 0.0f, -4.002774513161350e-001, 0.0f, 2.001387256580675e-001 };
double[] a = new double[]{ 1.0f, -2.355934631131582e+000, 1.941257088655214e+000, -7.847063755334187e-001, 1.999076052968340e-001 };
filterConstants filtCoeff_bp =  new filterConstants(b,a,"Bandpass 1-50Hz");
double[] b2 = new double[]{ 9.650809863447347e-001, -2.424683201757643e-001, 1.945391494128786e+000, -2.424683201757643e-001, 9.650809863447347e-001};
double[] a2 = new double[]{    1.000000000000000e+000,   -2.467782611297853e-001,    1.944171784691352e+000,   -2.381583792217435e-001,    9.313816821269039e-001}; 
filterConstants filtCoeff_notch =  new filterConstants(b2,a2,"Notch 60Hz");

////The code below causes no filtering of the data
//double[] b = new double[] {1.0};
//double[] a = new double[] {1.0};
//filterConstants filtCoeff_bp =  new filterConstants(b,a,"No Filter");
//double[] b2 = new double[] {1.0};
//double[] a2 = new double[] {1.0};
//filterConstants filtCoeff_notch =  new filterConstants(b2,a2,"No Filter");


//fft constants
int Nfft = 256; //set resolution of the FFT.  Use N=256 for normal, N=512 for MU waves
float fft_smooth_fac = 0.75f; //use value between [0 and 1].  Bigger is more smoothing.  Use 0.9 for MU waves, 0.75 for Alpha, 0.0 for no smoothing
FFT fftBuff[] = new FFT[nchan];   //from the minim library

//plotting constants
gui_Manager gui;
float vertScale_uV = 200.0f;
float displayTime_sec = 5f;
float dataBuff_len_sec = displayTime_sec+3f; //needs to be wider than actual display so that filter startup is hidden

//program constants
boolean isRunning=false;
boolean redrawScreenNow = true;
int openBCI_byteCount = 0;
int inByte = -1;    // Incoming serial data

//file writing variables
//PrintWriter fileoutput;
OutputFile_rawtxt fileoutput;
String output_fname;

//openBCI data packet
final int nDataBackBuff = 3*(int)fs_Hz;
dataPacket_ADS1299 dataPacketBuff[] = new dataPacket_ADS1299[nDataBackBuff]; //allocate the array, but doesn't call constructor.  Still need to call the constructor!
int curDataPacketInd = -1;
int lastReadDataPacketInd = -1;

void appendAndShift(float[] data, float[] newData) {
  int nshift = newData.length;
  int end = data.length-nshift;
  for (int i=0; i < end; i++) {
    data[i]=data[i+nshift];  //shift data points down by 1
  }
  for (int i=0; i<nshift;i++) {
    data[end+i] = newData[i];  //append new data
  }
}

void prepareData(float[] dataBuffX, float[][] dataBuffY_uV, float fs_Hz) {
  //initialize the x and y data
  int xoffset = dataBuffX.length - 1;
  for (int i=0; i < dataBuffX.length; i++) {
    dataBuffX[i] = ((float)(i-xoffset)) / fs_Hz; //x data goes from minus time up to zero
    for (int Ichan = 0; Ichan < nchan; Ichan++) { 
      dataBuffY_uV[Ichan][i] = 0f;  //make the y data all zeros
    }
  }
}

void initializeFFTObjects(FFT[] fftBuff, float[][] dataBuffY_uV, int N, float fs_Hz) {

  float[] fooData;
  for (int Ichan=0; Ichan < nchan; Ichan++) {
    //make the FFT objects...Following "SoundSpectrum" example that came with the Minim library
    //fftBuff[Ichan] = new FFT(Nfft, fs_Hz);  //I can't have this here...it must be in setup
    fftBuff[Ichan].window(FFT.HAMMING);

    //do the FFT on the initial data
    fooData = dataBuffY_uV[Ichan];
    fooData = Arrays.copyOfRange(fooData, fooData.length-Nfft, fooData.length); 
    fftBuff[Ichan].forward(fooData); //compute FFT on this channel of data
  }
}


void setup() {

  println("Starting setup...");
  //open window
  int win_x = 1200;  
  int win_y = 768;  //desktop PC
  size(win_x, win_y, P2D);
  //if (frame != null) frame.setResizable(true);  //make window resizable
  //attach exit handler
  //prepareExitHandler();

  //prepare data variables
  dataBuffX = new float[(int)(dataBuff_len_sec * fs_Hz)];
  dataBuffY_uV = new float[nchan][dataBuffX.length];
  dataBuffY_filtY_uV = new float[nchan][dataBuffX.length];
  data_std_uV = new float[nchan];
  is_railed = new boolean[nchan]; 
  for (int i=0; i<nDataBackBuff;i++) { 
    dataPacketBuff[i] = new dataPacket_ADS1299(nchan);
  }

  //initialize the data
  prepareData(dataBuffX, dataBuffY_uV, fs_Hz);
  
  //initialize the FFT objects
  for (int Ichan=0; Ichan < nchan; Ichan++) { 
    fftBuff[Ichan] = new FFT(Nfft, fs_Hz);
  };  //make the FFT objects
  initializeFFTObjects(fftBuff, dataBuffY_uV, Nfft, fs_Hz);

  //initilize the GUI
  String filterDescription = filtCoeff_bp.name + ", " + filtCoeff_notch.name; 
  gui = new gui_Manager(this, win_x, win_y, nchan, displayTime_sec,vertScale_uV,filterDescription);
  
  //associate the data to the GUI traces
  gui.initDataTraces(dataBuffX, dataBuffY_filtY_uV, fftBuff, data_std_uV, is_railed);

  //open the data file for writing
  openNewLogFile();

  // Open the serial port to the Arduino that has the OpenBCI
  if (useSyntheticData == false) {
    if (true) {
      println(Serial.list());
      //openBCI_portName = Serial.list()[0]; //change this for your computer!
    }
    println("Opening Serial " + openBCI_portName);
    openBCI = new openBCI_ADS1299(this, openBCI_portName, openBCI_baud, nchan); //this also starts the data transfer after XX seconds
  }

  //start
  isRunning=true;

  println("setup: Setup complete...");
}

int pointCounter = 0;
//boolean newData = true;
int prevBytes = 0; 
int prevMillis=millis();
int byteRate_perSec = 0;
void draw() {
  if (isRunning) {
    if (useSyntheticData) {  //use synthetic data (for GUI debugging) or use real data from the Serial stream
      lastReadDataPacketInd = 0;
      for (int i = 0; i < nPointsPerUpdate; i++) {
        //synthesize data
        dataPacketBuff[lastReadDataPacketInd].sampleIndex++;
        synthesizeData(nchan, fs_Hz, scale_fac_uVolts_per_count, dataPacketBuff[lastReadDataPacketInd]);

        //gather the data into the "little buffer"
        for (int Ichan=0; Ichan < nchan; Ichan++) {
          //scale the data into engineering units..."microvolts"
          yLittleBuff_uV[Ichan][pointCounter] = dataPacketBuff[lastReadDataPacketInd].values[Ichan]* scale_fac_uVolts_per_count;
        }
        pointCounter++;
      }
    } 
    else {
      openBCI.updateState();

      //gather any new data into the "little buffer"
      while ( (curDataPacketInd != lastReadDataPacketInd) && (pointCounter < nPointsPerUpdate)) {
        lastReadDataPacketInd = (lastReadDataPacketInd+1) % dataPacketBuff.length;  //increment to read the next packet
        for (int Ichan=0; Ichan < nchan; Ichan++) {   //loop over each cahnnel
          //scale the data into engineering units ("microvolts") and save to the "little buffer"
          yLittleBuff_uV[Ichan][pointCounter] = dataPacketBuff[lastReadDataPacketInd].values[Ichan] * scale_fac_uVolts_per_count;
        } 
        pointCounter++; //increment counter for "little buffer"
      }
    }

    //has enough data arrived to process it and update the GUI?
    //println("pointCounter " + pointCounter + ", nPointsPerUpdate " + nPointsPerUpdate);
    if (pointCounter >= nPointsPerUpdate) {
      pointCounter = 0;  //reset for next time
      byteRate_perSec = (int)(1000.f * ((float)(openBCI_byteCount - prevBytes)) / ((float)(millis() - prevMillis)));
      prevBytes = openBCI_byteCount; 
      prevMillis=millis();
      float foo_val;
      float prevFFTdata[] = new float[fftBuff[0].specSize()];

      for (int Ichan=0;Ichan < nchan; Ichan++) {
        //append data to larger buffer
        appendAndShift(dataBuffY_uV[Ichan], yLittleBuff_uV[Ichan]);
        
        //look to see if the signal is railed
        is_railed[Ichan]=false;
        if (abs(dataPacketBuff[lastReadDataPacketInd].values[Ichan]) > threshold_railed) {
          //println("OpenBCI_GUI: channel " + Ichan + " may be railed at " + dataPacketBuff[lastReadDataPacketInd].values[Ichan]);
          is_railed[Ichan]=true;
        }

        //process the time domain data
        dataBuffY_filtY_uV[Ichan] = dataBuffY_uV[Ichan].clone();
        filterIIR(filtCoeff_notch.b, filtCoeff_notch.a, dataBuffY_filtY_uV[Ichan]); //notch
        filterIIR(filtCoeff_bp.b, filtCoeff_bp.a, dataBuffY_filtY_uV[Ichan]); //bandpass

        //update the FFT stuff
        for (int I=0; I < fftBuff[Ichan].specSize(); I++) prevFFTdata[I] = fftBuff[Ichan].getBand(I); //copy the old spectrum values
        float[] fooData_raw = dataBuffY_uV[Ichan];  //use the raw data
        fooData_raw = Arrays.copyOfRange(fooData_raw, fooData_raw.length-Nfft, fooData_raw.length);   //just grab the most recent block of data
        fftBuff[Ichan].forward(fooData_raw); //compute FFT on this channel of data
        
        //average the FFT with previous FFT data...log average
        double min_val = 0.01d;
        double foo;
        for (int I=0; I < fftBuff[Ichan].specSize(); I++) {   //loop over each fft bin
          if (prevFFTdata[I] < min_val) prevFFTdata[I] = (float)min_val; //make sure we're not too small for the log calls
          foo = fftBuff[Ichan].getBand(I); if (foo < min_val) foo = min_val; //make sure this value isn't too small
          foo =   (1.0d-fft_smooth_fac) * java.lang.Math.log(java.lang.Math.pow(foo,2));
          foo += fft_smooth_fac * java.lang.Math.log(java.lang.Math.pow((double)prevFFTdata[I],2)); 
          foo_val = (float)java.lang.Math.sqrt(java.lang.Math.exp(foo)); //average in dB space
          fftBuff[Ichan].setBand(I,foo_val);
        }
    
        //compute the stddev of the signal...for the head plot
        float[] fooData_filt = dataBuffY_filtY_uV[Ichan];  //use the filtered data
        fooData_filt = Arrays.copyOfRange(fooData_filt, fooData_filt.length-Nfft, fooData_filt.length);   //just grab the most recent block of data
        data_std_uV[Ichan]=std(fooData_filt);
      }

      //tell the GUI that it has received new data via dumping new data into arrays that the GUI has pointers to
      gui.update(data_std_uV);
      redrawScreenNow=true;
    } 
    else {
      //not enough data has arrived yet.  do nothing more
    }
    
    //either way, update the title of the figure;
    frame.setTitle(int(frameRate) + " fps, Byte Count = " + openBCI_byteCount + ", bit rate = " + byteRate_perSec*8 + " bps" + ", Writing to " + output_fname);
  }
  
  if (redrawScreenNow) {
    //redraw the screen...not every time, get paced by when data is being plotted
    redrawScreenNow = false;  //reset for next time
    background(0);
    gui.draw();
  }


}

void serialEvent(Serial port) {
  //check to see which serial port it is
  if (port == openBCI.serial_openBCI) {
    boolean echoBytes = !openBCI.isStateNormal(); 
    openBCI.read(echoBytes);
    openBCI_byteCount++;
    if (openBCI.isNewDataPacketAvailable) {
      //copy packet into buffer of data packets
      curDataPacketInd = (curDataPacketInd+1) % dataPacketBuff.length; //this is also used to let the rest of the code that it may be time to do something
      openBCI.copyDataPacketTo(dataPacketBuff[curDataPacketInd]);  //resets isNewDataPacketAvailable to false
      
      //write this chunk of data to file
      fileoutput.writeRawData_dataPacket(dataPacketBuff[curDataPacketInd],scale_fac_uVolts_per_count);
    }
  } 
  else {
    inByte = port.read();
    print(char(inByte));
  }
}

//interpret a keypress...the key pressed comes in as "key"
void keyPressed() {
  //note that the Processing variable "key" is the keypress as an ASCII character
  //note that the Processing variable "keyCode" is the keypress as a JAVA keycode.  This differs from ASCII  
  //println("OpenBCI_GUI: keyPressed: key = " + key + ", int(key) = " + int(key) + ", keyCode = " + keyCode);
  
  if ((int(key) >=32) && (int(key) <= 126)) {  //32 through 126 represent all the usual printable ASCII characters
    parseKey(key);
  } else {
    parseKeycode(keyCode);
  }
}
void parseKey(char val) {
  int Ichan; boolean activate; int code_P_N_Both;
  
  //assumes that val is a usual printable ASCII character (ASCII 32 through 126)
  switch (val) {
    case '1':
      deactivateChannel(1-1); 
      break;
    case '2':
      deactivateChannel(2-1); 
      break;
    case '3':
      deactivateChannel(3-1); 
      break;
    case '4':
      deactivateChannel(4-1); 
      break;
    case '5':
      deactivateChannel(5-1); 
      break;
    case '6':
      deactivateChannel(6-1); 
      break;
    case '7':
      deactivateChannel(7-1); 
      break;
    case '8':
      deactivateChannel(8-1); 
      break;
    case 'q':
      activateChannel(1-1); 
      break;
    case 'w':
      activateChannel(2-1); 
      break;
    case 'e':
      activateChannel(3-1); 
      break;
    case 'r':
      activateChannel(4-1); 
      break;
    case 't':
      activateChannel(5-1); 
      break;
    case 'y':
      activateChannel(6-1); 
      break;
    case 'u':
      activateChannel(7-1); 
      break;
    case 'i':
      activateChannel(8-1); 
      break;
    case 's':
      stopButtonWasPressed();
      break;
      
    //change the state of the impedance measurements...activate the P-channels
    case '!':
      Ichan = 1; activate = true; code_P_N_Both = 0;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case '@':
      Ichan = 2; activate = true; code_P_N_Both = 0;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case '#':
      Ichan = 3; activate = true; code_P_N_Both = 0;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case '$':
      Ichan = 4; activate = true; code_P_N_Both = 0;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case '%':
      Ichan = 5; activate = true; code_P_N_Both = 0;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case '^':
      Ichan = 6; activate = true; code_P_N_Both = 0;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case '&':
      Ichan = 7; activate = true; code_P_N_Both = 0;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case '*':
      Ichan = 8; activate = true; code_P_N_Both = 0;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
      
    //change the state of the impedance measurements...deactivate the P-channels
    case 'Q':
      Ichan = 1; activate = false; code_P_N_Both = 0;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case 'W':
      Ichan = 2; activate = false; code_P_N_Both = 0;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case 'E':
      Ichan = 3; activate = false; code_P_N_Both = 0;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case 'R':
      Ichan = 4; activate = false; code_P_N_Both = 0;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case 'T':
      Ichan = 5; activate = false; code_P_N_Both = 0;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case 'Y':
      Ichan = 6; activate = false; code_P_N_Both = 0;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case 'U':
      Ichan = 7; activate = false; code_P_N_Both = 0;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case 'I':
      Ichan = 8; activate = false; code_P_N_Both = 0;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
      
      
    //change the state of the impedance measurements...activate the N-channels
    case 'A':
      Ichan = 1; activate = true; code_P_N_Both = 1;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case 'S':
      Ichan = 2; activate = true; code_P_N_Both = 1;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case 'D':
      Ichan = 3; activate = true; code_P_N_Both = 1;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case 'F':
      Ichan = 4; activate = true; code_P_N_Both = 1;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case 'G':
      Ichan = 5; activate = true; code_P_N_Both = 1;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case 'H':
      Ichan = 6; activate = true; code_P_N_Both = 1;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case 'J':
      Ichan = 7; activate = true; code_P_N_Both = 1;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case 'K':
      Ichan = 8; activate = true; code_P_N_Both = 1;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
      
    //change the state of the impedance measurements...deactivate the N-channels
    case 'Z':
      Ichan = 1; activate = false; code_P_N_Both = 1;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case 'X':
      Ichan = 2; activate = false; code_P_N_Both = 1;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case 'C':
      Ichan = 3; activate = false; code_P_N_Both = 1;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case 'V':
      Ichan = 4; activate = false; code_P_N_Both = 1;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case 'B':
      Ichan = 5; activate = false; code_P_N_Both = 1;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case 'N':
      Ichan = 6; activate = false; code_P_N_Both = 1;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case 'M':
      Ichan = 7; activate = false; code_P_N_Both = 1;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;
    case '<':
      Ichan = 8; activate = false; code_P_N_Both = 1;  setChannelImpedanceState(Ichan-1,activate,code_P_N_Both);
      break;

      
    case 'm':
     println("OpenBCI_GUI: 'm' was pressed...taking screenshot...");
     saveFrame("OpenBCI-####.jpg");    // take a shot of that!
     break;
    default:
     println("OpenBCI_GUI: '" + key + "' Pressed...sending to OpenBCI...");
     if (openBCI != null) openBCI.serial_openBCI.write(key + "\n"); //send the value as ascii with a newline character
     break;
  }
}
void parseKeycode(int val) { 
  //assumes that val is Java keyCode
  switch (val) {
    case 8:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received BACKSPACE keypress.  Ignoring...");
      break;   
    case 9:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received TAB keypress.  Toggling Impedance Control...");
      gui.showImpedanceButtons = !gui.showImpedanceButtons;
      break;    
    case 10:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received ENTER keypress.  Ignoring...");
      break;
    case 16:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received SHIFT keypress.  Ignoring...");
      break;
    case 17:
      //println("OpenBCI_GUI: parseKeycode(" + val + "): received CTRL keypress.  Ignoring...");
      break;
    case 18:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received ALT keypress.  Ignoring...");
      break;
    case 20:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received CAPS LOCK keypress.  Ignoring...");
      break;
    case 27:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received ESC keypress.  Stopping OpenBCI...");
      stopRunning();
      break; 
    case 33:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received PAGE UP keypress.  Ignoring...");
      break;    
    case 34:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received PAGE DOWN keypress.  Ignoring...");
      break;
    case 35:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received END keypress.  Ignoring...");
      break; 
    case 36:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received HOME keypress.  Ignoring...");
      break; 
    case 37:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received LEFT ARROW keypress.  Ignoring...");
      break;  
    case 38:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received UP ARROW keypress.  Ignoring...");
      break;  
    case 39:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received RIGHT ARROW keypress.  Ignoring...");
      break;  
    case 40:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received DOWN ARROW keypress.  Ignoring...");
      break;
    case 112:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received F1 keypress.  Ignoring...");
      break;
    case 113:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received F2 keypress.  Ignoring...");
      break;  
    case 114:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received F3 keypress.  Ignoring...");
      break;  
    case 115:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received F4 keypress.  Ignoring...");
      break;  
    case 116:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received F5 keypress.  Ignoring...");
      break;  
    case 117:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received F6 keypress.  Ignoring...");
      break;  
    case 118:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received F7 keypress.  Ignoring...");
      break;  
    case 119:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received F8 keypress.  Ignoring...");
      break;  
    case 120:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received F9 keypress.  Ignoring...");
      break;  
    case 121:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received F10 keypress.  Ignoring...");
      break;  
    case 122:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received F11 keypress.  Ignoring...");
      break;  
    case 123:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received F12 keypress.  Ignoring...");
      break;     
    case 127:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received DELETE keypress.  Ignoring...");
      break;
    case 155:
      println("OpenBCI_GUI: parseKeycode(" + val + "): received INSERT keypress.  Ignoring...");
      break; 
    default:
      println("OpenBCI_GUI: parseKeycode(" + val + "): value is not known.  Ignoring...");
      break;
  }
}

//swtich yard if a click is detected
void mousePressed() {

  //was the stopButton pressed?
  if (gui.stopButton.updateIsMouseHere()) { 
    stopButtonWasPressed(); 
    gui.stopButton.setIsActive(true);
    redrawScreenNow = true;
  }
  
  if (gui.chanModeButton.updateIsMouseHere()) {
    //toggle whether to show channel on/off or channel impedance on/off
    gui.showImpedanceButtons = !gui.showImpedanceButtons;
    redrawScreenNow = true;
  }

  //check the buttons
  if (gui.showImpedanceButtons == false) {
    //check the channel buttons
    for (int Ibut = 0; Ibut < gui.chanButtons.length; Ibut++) {
      if (gui.chanButtons[Ibut].updateIsMouseHere()) { 
        toggleChannelState(Ibut);
        redrawScreenNow = true;
      }
    }
  } else {
    for (int Ibut = 0; Ibut < gui.impedanceButtonsP.length; Ibut++) {
      if (gui.impedanceButtonsP[Ibut].updateIsMouseHere()) { 
        toggleChannelImpedanceState(gui.impedanceButtonsP[Ibut],Ibut,0);
        redrawScreenNow = true;
      }
      if (gui.impedanceButtonsN[Ibut].updateIsMouseHere()) { 
        toggleChannelImpedanceState(gui.impedanceButtonsN[Ibut],Ibut,1);
        redrawScreenNow = true;
      }
    }
  }
  
  
  //check the graphs
  if (gui.isMouseOnFFT(mouseX,mouseY)) {
    graphDataPoint dataPoint = new graphDataPoint();
    gui.getFFTdataPoint(mouseX,mouseY,dataPoint);
    println("OpenBCI_GUI: FFT data point: " + String.format("%4.2f",dataPoint.x) + " " + dataPoint.x_units + ", " + String.format("%4.2f",dataPoint.y) + " " + dataPoint.y_units);
  }
}

void mouseReleased() {
  //gui.stopButton.updateMouseIsReleased();
  gui.stopButton.setIsActive(false);
  redrawScreenNow = true;
}

void stopRunning() {
    if (openBCI != null) openBCI.stopDataTransfer();
    closeLogFile();
    isRunning = false;
}
void startRunning() {
    openNewLogFile();  //open a new log file
    if (openBCI != null) openBCI.startDataTransfer(); //use whatever was the previous data transfer mode (TXT vs BINARY)
    isRunning = true;
}

//execute this function whenver the stop button is pressed
void stopButtonWasPressed() {
  //toggle the data transfer state of the ADS1299...stop it or start it...
  if (isRunning) {
    println("openBCI_GUI: stopButton was pressed...stopping data transfer...");
    stopRunning();
  } 
  else { //not running
    println("openBCI_GUI: startButton was pressed...starting data transfer...");
    startRunning();
  }

  //update the push button with new text based on the current running state
  //gui.stopButton.setActive(isRunning);
  if (isRunning) {
    gui.stopButton.setString(stopButton_pressToStop_txt);
  } 
  else {
    gui.stopButton.setString(stopButton_pressToStart_txt);
  }
}

void synthesizeData(int nchan, float fs_Hz, float scale_fac_uVolts_per_count, dataPacket_ADS1299 curDataPacket) {
  float val_uV;
  for (int Ichan=0; Ichan < nchan; Ichan++) {
    if (gui.chanButtons[Ichan].isActive()==false) { //an INACTIVE button has not been pressed, which means that the channel itself is ACTIVE
      val_uV = randomGaussian()*sqrt(fs_Hz/2.0f); // ensures that it has amplitude of one unit per sqrt(Hz) of signal bandwidth
      //val_uV = random(1)*sqrt(fs_Hz/2.0f); // ensures that it has amplitude of one unit per sqrt(Hz) of signal bandwidth
      if (Ichan==0) val_uV*= 10f;  //scale one channel higher
    } 
    else {
      val_uV = 0.0f;
    }
    curDataPacket.values[Ichan] = (int) (0.5f+ val_uV / scale_fac_uVolts_per_count); //convert to counts, the 0.5 is to ensure rounding
  }
}

//toggleChannelState: : Ichan is [0 nchan-1]
void toggleChannelState(int Ichan) {
  if ((Ichan >= 0) && (Ichan < gui.chanButtons.length)) {
    if (gui.chanButtons[Ichan].isActive()) { //button is pressed, which means the channel was NOT active
      //change to activate
      activateChannel(Ichan);
    } 
    else {  //button is not pressed, which means the channel is active
      //change to activate
      deactivateChannel(Ichan);
    }
  }
}

//activateChannel: Ichan is [0 nchan-1]
void activateChannel(int Ichan) {
  println("OpenBCI_GUI: activating channel " + (Ichan+1));
  if (openBCI != null) openBCI.changeChannelState(Ichan, true); //activate
  gui.chanButtons[Ichan].setIsActive(false); //an active channel is a light-colored NOT-ACTIVE button
}  
void deactivateChannel(int Ichan) {
  println("OpenBCI_GUI: deactivating channel " + (Ichan+1));
  if (openBCI != null) openBCI.changeChannelState(Ichan, false); //de-activate
  gui.chanButtons[Ichan].setIsActive(true); //a deactivated channel is a dark-colored ACTIVE button
}

void toggleChannelImpedanceState(Button but, int Ichan, int code_P_N_Both) {
  boolean newstate = false;
  println("OpenBCI_GUI: toggleChannelImpedanceState: Ichan " + Ichan + ", code_P_N_Both " + code_P_N_Both);
  if ((Ichan >= 0) && (Ichan < gui.impedanceButtonsP.length)) {

    //find what state we were, because that sets what state we need
    newstate = !(but.isActive()); //toggle the state

    //set the desired impedance state
    setChannelImpedanceState(Ichan,newstate,code_P_N_Both);
  }
}
void setChannelImpedanceState(int Ichan,boolean newstate,int code_P_N_Both) {
  if ((Ichan >= 0) && (Ichan < gui.impedanceButtonsP.length)) {
    //change the state of the OpenBCI channel itself
    openBCI.changeImpedanceState(Ichan,newstate,code_P_N_Both);
    
    //now update the button state
    if ((code_P_N_Both == 0) || (code_P_N_Both == 2)) {
      //set the P channel
      gui.impedanceButtonsP[Ichan].setIsActive(newstate);
    } else if ((code_P_N_Both == 1) || (code_P_N_Both == 2)) {
      //set the N channel
      gui.impedanceButtonsN[Ichan].setIsActive(newstate);
    }
  }
}

void openNewLogFile() {
  //close the file if it's open
  println("OpenBCI_GUI: closing log file");
  if (fileoutput != null) closeLogFile();
  
  //open the new file
  fileoutput = new OutputFile_rawtxt(fs_Hz);
  output_fname = fileoutput.fname;
  println("openBCI: openNewLogFile: opened output file: " + output_fname);
}

void closeLogFile() {
  fileoutput.closeFile();
}


// here's a function to catch whenever the window is being closed, so that
// it stops OpenBCI
// from: http://forum.processing.org/one/topic/run-code-on-exit.html
//
// must add "prepareExitHandler();" in setup() for Processing sketches 
//private void prepareExitHandler () {
//  Runtime.getRuntime().addShutdownHook(
//    new Thread(new Runnable() {
//        public void run () {
//          //System.out.println("SHUTDOWN HOOK");
//          println("OpenBCI_GUI: executing shutdown code...");
//          try {
//            stopRunning();
//            if (openBCI != null) {
//              openBCI.closeSerialPort();
//            }
//            stop();
//          } catch (Exception ex) {
//            ex.printStackTrace(); // not much else to do at this point
//          }
//        }
//      }
//    )
//  );
//}  

