
///////////////////////////////////////////////
//
// GUI for controlling the ADS1299-based OpenBCI Shield
// This is the simpler-looking version of our GUI.
//
// Created: Chip Audette, Oct-Nov 2013
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
//import processing.core.PApplet;

boolean useSyntheticData = false; //flip this to false when using OpenBCI, flip to true to develop this GUI without the OpenBCI board

//Serial communications constants
openBCI_ADS1299 openBCI;
String openBCI_portName = "COM8";   /************** CHANGE THIS TO MATCH THE COM PORT REPORTED ON *YOUR* COMPUTER *****************/

//these settings are for a single OpenBCI board
int openBCI_baud = 115200; //baud rate from the Arduino
int OpenBCI_Nchannels = 8; //normal OpenBCI has 8 channels

//which channels active and which not?
int nchan = 2;  //total number of channels to make available to the user
int nchan_active_at_startup = 1;  //just have one active at startup, though

//data constants
float fs_Hz = 250f; //sample rate
float dataBuffX[];
float dataBuffY_uV[][]; //2D array to handle multiple data channels, each row is a new channel so that dataBuffY[3][] is channel 4
float dataBuffY_filtY_uV[][];
float scale_fac_uVolts_per_count = (4.5f / 24.0f / pow(2, 24)) * 1000000.f * 2.0f; //factor of 2 added 2013-11-10 to match empirical tests in my office on Friday
int prev_time_millis = 0;
final int nPointsPerUpdate = 30;
float yLittleBuff[] = new float[nPointsPerUpdate];

//filter variables
float yLittleBuff_uV[][] = new float[nchan][nPointsPerUpdate];
float filtState[] = new float[nchan];
filterConstants[] filtCoeff = new filterConstants[2]; //how many filters?...filters are defined in defineFilters();


//fft constants
int Nfft = 256; //set resolution of the FFT.  Use N=256 for normal, N=512 for MU waves
float fft_smooth_fac = 0.75f; //use value between [0 and 1].  Bigger is more smoothing.  Use 0.9 for MU waves, 0.75 for Alpha, 0.0 for no smoothing
FFT fftBuff[] = new FFT[nchan];   //from the minim library

//plotting constants
gui_Manager gui;
float vertScale_uV = 100.0f;  //here's the Y-axis limits on the time-domain plot
float displayTime_sec = 5f;   //here's the X-axis limit on the time-domain plot
float dataBuff_len_sec = displayTime_sec+2f;

//program constants
boolean isRunning=false;
int openBCI_byteCount = 0;
int inByte = -1;    // Incoming serial data

//file writing variables
//PrintWriter fileoutput;
OutputFile_rawtxt fileoutput;
String output_fname;

//openBCI data packet
final int nDataBackBuff = (int)fs_Hz; //how many samples might get stuck in our serial buffer that we need to get at once?
dataPacket_ADS1299 dataPacketBuff[] = new dataPacket_ADS1299[nDataBackBuff]; //allocate a big array, but doesn't call constructor.  Still need to call the constructor!
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
    for (int Ichan = 0; Ichan < dataBuffY_uV.length; Ichan++) { 
      dataBuffY_uV[Ichan][i] = 0f;  //make the y data all zeros
    }
  }
}

void initializeFFTObjects(FFT[] fftBuff, float[][] dataBuffY_uV) {

  float[] fooData;
  for (int Ichan=0; Ichan < fftBuff.length; Ichan++) {
    //make the FFT objects...Following "SoundSpectrum" example that came with the Minim library
    //fftBuff[Ichan] = new FFT(Nfft, fs_Hz);  //I can't have this here...it must be in setup
    fftBuff[Ichan].window(FFT.HAMMING);

    //do the FFT on the initial data
    fooData = dataBuffY_uV[Ichan];
    fooData = Arrays.copyOfRange(fooData, fooData.length-Nfft, fooData.length); 
    fftBuff[Ichan].forward(fooData); //compute FFT on this channel of data
  }
}


void defineFilters(filterConstants[] filtCoeff) {
  //define notch filter
  double[] b = new double[]{ 9.650809863447347e-001, -2.424683201757643e-001, 1.945391494128786e+000, -2.424683201757643e-001, 9.650809863447347e-001};
  double[] a = new double[]{ 1.000000000000000e+000,   -2.467782611297853e-001,    1.944171784691352e+000,   -2.381583792217435e-001,    9.313816821269039e-001}; 
  filtCoeff[0] =  new filterConstants(b,a,"Notch 1-50Hz");
  
  //define bandpass filter
  double[] b2 = new double[]{ 2.001387256580675e-001, 0.0f, -4.002774513161350e-001, 0.0f, 2.001387256580675e-001 };
  double[] a2 = new double[]{ 1.0f, -2.355934631131582e+000, 1.941257088655214e+000, -7.847063755334187e-001, 1.999076052968340e-001 };
  filtCoeff[1] =  new filterConstants(b2,a2,"Bandpass 1-50Hz"); //Matlab....butter(2,[1 50]/(250/2));  %bandpass filter
}

void setup() {

  println("Starting setup...");

  //open window
  int win_x = 1200; //window height
  int win_y = 450;  //window width
  size(win_x, win_y, P2D);
  //if (frame != null) frame.setResizable(true);  //make window resizable

  //prepare data variables
  dataBuffX = new float[(int)(dataBuff_len_sec * fs_Hz)];
  dataBuffY_uV = new float[nchan][dataBuffX.length];
  dataBuffY_filtY_uV = new float[nchan][dataBuffX.length];
  for (int i=0; i<nDataBackBuff;i++) { 
    dataPacketBuff[i] = new dataPacket_ADS1299(OpenBCI_Nchannels); //tell it how many data fields will be coming from the Arduino
  }

  //initialize the data
  prepareData(dataBuffX, dataBuffY_uV, fs_Hz);

  //initialize the FFT objects
  for (int Ichan=0; Ichan < fftBuff.length; Ichan++) { 
    fftBuff[Ichan] = new FFT(Nfft, fs_Hz);
  };  //make the FFT objects
  initializeFFTObjects(fftBuff, dataBuffY_uV);

  //define the time-domain filters to use
  defineFilters(filtCoeff);

  //initilize the GUI
  gui = new gui_Manager(this, win_x, win_y, nchan, displayTime_sec,vertScale_uV);

  //associate the data to the GUI traces
  gui.initDataTraces(dataBuffX, dataBuffY_filtY_uV, fftBuff);

  // Open the serial port to the Arduino that has the OpenBCI
  if (useSyntheticData == false) {
    if (true) {
      println(Serial.list());  //print out all the serial ports on your system
      //openBCI_portName = Serial.list()[0]; //choose the serial port that you want
    }
    println("Opening Serial " + openBCI_portName);
    //open the serial link, this also starts the data transfer after XX seconds
    openBCI = new openBCI_ADS1299(this, openBCI_portName, openBCI_baud, OpenBCI_Nchannels); //this likely restarts the arduino
  
    //wait for the Arduino and OpenBCI board to start
    int foo_millis=millis();
    int openBCI_serial_timeout_msec = 6000;
    println("Waiting for OpenBCI...");
    while (((millis()-foo_millis) < openBCI_serial_timeout_msec) && 
      (openBCI.updateState() != STATE_NORMAL) && 
      (openBCI_byteCount < 200) ) {};  //wait for Arduino to startup and send some data
    //note, this could exit in both a good state (Arduino is going) or a bad state (nothing from Arduino
  }
    
  //initialize the on/off state of the different channels
  for (int Ichan=0; Ichan<OpenBCI_Nchannels;Ichan++) {
    if (Ichan < nchan_active_at_startup) { activateChannel(Ichan); } else { deactivateChannel(Ichan);  }
  }
  
  //open the data file for writing
  fileoutput = new OutputFile_rawtxt(fs_Hz);
  output_fname = fileoutput.fname;
  println("openBCI: opened output file: " + output_fname);

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
  //newData = false;
  if (isRunning) {
    if (useSyntheticData) {  //use synthetic data (for GUI debugging) or use real data from the Serial stream
      lastReadDataPacketInd = 0;
      for (int i = 0; i < nPointsPerUpdate; i++) {
        //synthesize data
        dataPacketBuff[lastReadDataPacketInd].sampleIndex++;
        synthesizeData(nchan, fs_Hz, scale_fac_uVolts_per_count, dataPacketBuff[lastReadDataPacketInd]); //make one data point per channel

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

      //is data waiting in the buffer from the serial port?
      if (curDataPacketInd != lastReadDataPacketInd) { //curDataPacketInd is incremented by serialEvent, so look down there
        //gather the data into the "little buffer"
        while ( (curDataPacketInd != lastReadDataPacketInd) && (pointCounter < nPointsPerUpdate)) {
          //increment the counter that points us to the next data packet that we will copy from.
          //We're using it as a circular buffer, hence the mod operation to wrap us around if we try to go off the end
          lastReadDataPacketInd = (lastReadDataPacketInd+1) % dataPacketBuff.length; 
          
          //copy just the number of channels that we want into our local buffer in preparation for plotting
          for (int Ichan=0; Ichan < nchan; Ichan++) {  
            //scale the data into engineering units..."microvolts"
            yLittleBuff_uV[Ichan][pointCounter] = dataPacketBuff[lastReadDataPacketInd].values[Ichan]* scale_fac_uVolts_per_count;
          } 
          pointCounter++;
        }
      }
    }

    //has enough data arrived to process it and update the GUI?
    if (pointCounter >= nPointsPerUpdate) {
      pointCounter = 0;  //reset for next time
      byteRate_perSec = (int)(1000.f * ((float)(openBCI_byteCount - prevBytes)) / ((float)(millis() - prevMillis)));
      prevBytes = openBCI_byteCount; 
      prevMillis=millis();
      float foo_val;
      float prevFFTdata[] = new float[fftBuff[0].specSize()];

      //loop over each channel that we want to display
      for (int Ichan=0;Ichan < nchan; Ichan++) {
        //append data to larger buffer
        appendAndShift(dataBuffY_uV[Ichan], yLittleBuff_uV[Ichan]);

        //process the time domain data
        dataBuffY_filtY_uV[Ichan] = dataBuffY_uV[Ichan].clone();
        for (int Ifilt=0; Ifilt < filtCoeff.length; Ifilt++) { filterIIR(filtCoeff[Ifilt].b, filtCoeff[Ifilt].a, dataBuffY_filtY_uV[Ichan]); }//apply all of the filters 

        //update the FFT stuff
        for (int I=0; I < fftBuff[Ichan].specSize(); I++) prevFFTdata[I] = fftBuff[Ichan].getBand(I); //copy the old spectrum values
        float[] fooData_raw = dataBuffY_uV[Ichan];  //use the raw data
        fooData_raw = Arrays.copyOfRange(fooData_raw, fooData_raw.length-Nfft, fooData_raw.length);   //just grab the most recent block of data
        fftBuff[Ichan].forward(fooData_raw); //compute FFT on this channel of data
        
        //average the FFT with previous FFT data
        double min_val = 0.01d;
        double foo;
        for (int I=0; I < fftBuff[Ichan].specSize(); I++) {  //loop over each FFT bin
          if (prevFFTdata[I] < min_val) prevFFTdata[I] = (float)min_val; //make sure we're not too small for the log calls
          foo = fftBuff[Ichan].getBand(I); if (foo < min_val) foo = min_val; //make sure this value isn't too small
          foo =   (1.0d-fft_smooth_fac) * java.lang.Math.log(java.lang.Math.pow(foo,2));
          foo += fft_smooth_fac * java.lang.Math.log(java.lang.Math.pow((double)prevFFTdata[I],2)); 
          foo_val = (float)java.lang.Math.sqrt(java.lang.Math.exp(foo)); //average in dB space
          fftBuff[Ichan].setBand(I,foo_val);
        }
      }

      //tell the GUI that it has received new data via dumping new data into arrays that the GUI has pointers to
      gui.update();
      
      //write data to file
      if (output_fname != null) fileoutput.writeRawData_txt(yLittleBuff_uV,dataPacketBuff[lastReadDataPacketInd].sampleIndex);
    } 
    else {
      //not enough data has arrived yet.  do nothing more
    }
  }

  //redraw the screen...not every time, get paced by when data is being plotted
  background(0);
  gui.draw();
  frame.setTitle(int(frameRate) + " fps, Byte Count = " + openBCI_byteCount + ", bit rate = " + byteRate_perSec*8 + " bps" + ", Writing to " + output_fname);
}

//here is the routine that listens to the serial port.
//if any data is waiting, get it, parse it, and stuff it into our vector of pre-allocated dataPacketBuff
void serialEvent(Serial port) {
  //check to see which serial port it is
  if (port == openBCI.serial_openBCI) {
    boolean echoBytes = !openBCI.isStateNormal(); 
    openBCI.read(echoBytes);
    openBCI_byteCount++;
    if (openBCI.isNewDataPacketAvailable) {
      curDataPacketInd = (curDataPacketInd+1) % dataPacketBuff.length;
      openBCI.copyDataPacketTo(dataPacketBuff[curDataPacketInd]);
    }
  } 
  else {
    inByte = port.read();
    print(char(inByte));
  }
}

//interpret a keypress...the key pressed comes in as "key"
void keyPressed() {
  switch (key) {
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
    case 'm':
     println("'m' was pressed...taking screenshot...");
     saveFrame("OpenBCI-####.jpg");    // take a shot of that!
     break;
    default: 
      println("OpenBCI_GUI: '" + key + "' Pressed...sending to OpenBCI...");
      if (openBCI != null) openBCI.serial_openBCI.write(key + "\n"); //send the value as ascii with a newline character
  }
}

//swtich yard if a click is detected
void mousePressed() {

  //was the stopButton pressed?
  if (gui.stopButton.updateIsMouseHere()) { 
    stopButtonWasPressed(); 
    gui.stopButton.setIsActive(true);
  }

  //check the channel buttons
  for (int Ibut = 0; Ibut < gui.chanButtons.length; Ibut++) {
    if (gui.chanButtons[Ibut].updateIsMouseHere()) { 
      toggleChannelState(Ibut);
    }
  }
}

void mouseReleased() {
  //gui.stopButton.updateMouseIsReleased();
  gui.stopButton.setIsActive(false);
}

//execute this function whenver the stop button is pressed
void stopButtonWasPressed() {
  //toggle the data transfer state of the ADS1299...stop it or start it...
  if (isRunning) {
    println("openBCI_GUI: stopButton was pressed...stopping data transfer...");
    if (openBCI != null) openBCI.stopDataTransfer();
  } 
  else {
    println("openBCI_GUI: startButton was pressed...starting data transfer...");
    if (openBCI != null) openBCI.startDataTransfer(); //use whatever was the previous data transfer mode (TXT vs BINARY)
  }

  isRunning = !isRunning;  //toggle the variable holding the current state of running

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
  if (Ichan < gui.chanButtons.length) gui.chanButtons[Ichan].setIsActive(false); //an active channel is a light-colored NOT-ACTIVE button
}  
void deactivateChannel(int Ichan) {
  println("OpenBCI_GUI: deactivating chnnel " + (Ichan+1));
  if (openBCI != null) openBCI.changeChannelState(Ichan, false); //de-activate
  if (Ichan < gui.chanButtons.length) gui.chanButtons[Ichan].setIsActive(true); //a deactivated channel is a dark-colored ACTIVE button
}

