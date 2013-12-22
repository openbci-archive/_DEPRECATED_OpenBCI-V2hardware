
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

boolean useSyntheticData = false; //flip this to false when using OpenBCI, flip to true to develop this GUI without the OpenBCI board

//Serial communications constants
openBCI_ADS1299 openBCI;
String openBCI_portName = "COM13";   /************** CHANGE THIS TO MATCH THE COM PORT REPORTED ON *YOUR* COMPUTER *****************/

//these settings are for a single OpenBCI board
int openBCI_baud = 115200; //baud rate from the Arduino
int OpenBCI_Nchannels = 8; //normal OpenBCI has 8 channels

//which channels active and which not?
int nchan = 2;  //total number of channels to make available to the user
int nchan_active_at_startup = 1;  //just have one active at startup, though

//data constants
float fs_Hz = 250.f; //sample rate
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

//signal detection constants
boolean showFFTFilteringData = false;
String signalDetectName = "Alpha";
float inband_Hz[] = {9.0f, 12.0f};  //look at energy within these frequencies
float guard_Hz[] = {13.5f, 23.5f};  //and compare to energy within these frequencies
float fft_det_thresh_dB = 10.0;      //how much higher does the in-band signal have to be above the guard band?
DetectionData_FreqDomain[] detData_freqDomain = new DetectionData_FreqDomain[nchan]; //holds data describing any detections performed in the frequency domain

//fft constants
int Nfft = 256*2; //set resolution of the FFT.  Use N=256 for normal, N=512 for MU waves
float fft_smooth_fac = 0.9f; //use value between [0 and 1].  Bigger is more smoothing.  Use 0.9 for MU waves, 0.75 for Alpha, 0.0 for no smoothing
FFT fftBuff[] = new FFT[nchan];   //from the minim library

//plotting constants
gui_Manager gui;
float vertScale_uV = 200.0f;  //here's the Y-axis limits on the time-domain plot
float displayTime_sec = 10.0f;   //here's the X-axis limit on the time-domain plot
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
  filtCoeff[0] =  new filterConstants(b,a,"Notch 60Hz");
  
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

  //define the filters and signal processing stuff
  defineFilters(filtCoeff);
  for (int Ichan=0; Ichan < nchan; Ichan++) { detData_freqDomain[Ichan] = new DetectionData_FreqDomain(); }

  //initilize the GUI
  String filterText = ""; for (int i=0; i<filtCoeff.length; i++) { if (i>0) {filterText+= '\n';} filterText += filtCoeff[i].name; };
  gui = new gui_Manager(this, win_x, win_y, nchan, displayTime_sec,vertScale_uV,fs_Hz,filterText,signalDetectName);
 
  //associate the data to the GUI traces
  gui.initDataTraces(dataBuffX, dataBuffY_filtY_uV, fftBuff);
  
  //show the FFT-based signal detection
  gui.setGoodFFTBand(inband_Hz); gui.setBadFFTBand(guard_Hz);
  gui.showFFTFilteringData(showFFTFilteringData);

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
int millis_lastSynthDatapoint=0;
void draw() {
  //newData = false;
  if (isRunning) {
    
    //get the new data...use synthetic data (for GUI debugging) or use real data from the Serial stream
    if (useSyntheticData) {  
      if ((millis() - millis_lastSynthDatapoint) >= nPointsPerUpdate/fs_Hz*1000) {
        millis_lastSynthDatapoint = millis();
                  
        //in this branch, we'll generate synthetic data
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
    } else {
      //in this branch we'll get EEG data from OpenBCI
      openBCI.updateState();

      //is data waiting in the buffer from the serial port?
      if (curDataPacketInd != lastReadDataPacketInd) { //curDataPacketInd is incremented by serialEvent, so look down there
        //gather the data into the "little buffer"
        while ( (curDataPacketInd != lastReadDataPacketInd) && (pointCounter < nPointsPerUpdate)) {
          //increment the counter that points us to the next data packet that we will copy from.
          lastReadDataPacketInd = (lastReadDataPacketInd+1) % dataPacketBuff.length;   //We're using it as a circular buffer, hence the mod operation to wrap us around if we try to go off the end
          
          //copy just the number of channels that we want into our local buffer in preparation for plotting (and for saving to disk)
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
  
      //loop over each channel that we want to display and process
      boolean sendToSpectrogram = true;  //initialize to send the first channel that we can
      for (int Ichan=0;Ichan < nchan; Ichan++) {
        
        //add raw data to spectrogram...if the correct channel...
        //...look for the first channel that is active (meaning button is not active) or, if it
       //     hasn't yet sent any data, send the last channel even if the channel is off
        if (sendToSpectrogram & (!(gui.chanButtons[Ichan].isActive()) | (Ichan == (nchan-1)))) { //send data to spectrogram
          sendToSpectrogram = false;  //prevent us from sending more data after this time through
          for (int Idata=0;Idata < nPointsPerUpdate;Idata++) {
            gui.spectrogram.addDataPoint(yLittleBuff_uV[Ichan][Idata]);
            gui.tellGUIWhichChannelForSpectrogram(Ichan);
            //gui.spectrogram.addDataPoint(100.0f+(float)Idata);
          }
        }
        
        //append data to larger buffer
        appendAndShift(dataBuffY_uV[Ichan], yLittleBuff_uV[Ichan]);
  

        //process the time domain data
        dataBuffY_filtY_uV[Ichan] = dataBuffY_uV[Ichan].clone();
        for (int Ifilt=0; Ifilt < filtCoeff.length; Ifilt++) { filterIIR(filtCoeff[Ifilt].b, filtCoeff[Ifilt].a, dataBuffY_filtY_uV[Ichan]); }//apply all of the filters 
      }
      
      //process in the time domain (for the frequency-domain plot and any subsequent processing
      processFreqDomain(dataBuffY_uV,fftBuff,fs_Hz,fft_smooth_fac);  //use rawData, not filtered data
    
      //try to detect the desired signals, do it in frequency space
      detectInFreqDomain(fftBuff,inband_Hz,guard_Hz,detData_freqDomain);
      gui.setDetectionData_freqDomain(detData_freqDomain);
      
      //tell the GUI that it has received new data via dumping new data into arrays that the GUI has pointers to
      gui.update();
      
      //write data to file
      if (output_fname != null) fileoutput.writeRawData_txt(yLittleBuff_uV,dataPacketBuff[lastReadDataPacketInd].sampleIndex);
    } else {
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
  
  //check the detection button
  if (gui.detectButton.updateIsMouseHere()) toggleDetectionState();
  
  //check spectrogram button
  if (gui.spectrogramButton.updateIsMouseHere()) toggleSpectrogramState();

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

final float sine_freq_Hz = 10.0f;
float sine_phase_rad = 0.0;
void synthesizeData(int nchan, float fs_Hz, float scale_fac_uVolts_per_count, dataPacket_ADS1299 curDataPacket) {
  float val_uV;
  for (int Ichan=0; Ichan < nchan; Ichan++) {
    if (gui.chanButtons[Ichan].isActive()==false) { //an INACTIVE button has not been pressed, which means that the channel itself is ACTIVE
      val_uV = randomGaussian()*sqrt(fs_Hz/2.0f); // ensures that it has amplitude of one unit per sqrt(Hz) of signal bandwidth
      //val_uV = random(1)*sqrt(fs_Hz/2.0f); // ensures that it has amplitude of one unit per sqrt(Hz) of signal bandwidth
      if (Ichan==0) val_uV*= 10f;  //scale one channel higher
      
      if (Ichan==1) {
        //add sine wave at 10 Hz at 10 uVrms
        sine_phase_rad += 2.0f*PI * sine_freq_Hz / fs_Hz;
        if (sine_phase_rad > 2.0f*PI) sine_phase_rad -= 2.0f*PI;
        val_uV += 10.0f * sqrt(2.0)*sin(sine_phase_rad);
      }
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

void toggleDetectionState() {
  gui.detectButton.setIsActive(!gui.detectButton.isActive());
  showFFTFilteringData = gui.detectButton.isActive();
  gui.showFFTFilteringData(showFFTFilteringData);
}

void toggleSpectrogramState() {
  gui.spectrogramButton.setIsActive(!gui.spectrogramButton.isActive());
  gui.setShowSpectrogram(gui.spectrogramButton.isActive());
}

//process in the time domain (for the frequency-domain plot and any subsequent processing
void processFreqDomain(float[][] dataBuffY_uV,FFT[] fftBuff, float fs_Hz,float fft_smooth_fac) {
  int Nfft = (fftBuff[0].specSize()-1)*2;
  float prevFFTdata[] = new float[fftBuff[0].specSize()];
  
  //loop over each channel
  for (int Ichan = 0; Ichan < dataBuffY_uV.length; Ichan++) {
    
    //update the FFT stuff
    for (int I=0; I < fftBuff[Ichan].specSize(); I++) prevFFTdata[I] = fftBuff[Ichan].getBand(I); //copy the old spectrum values
    float[] fooData_raw = dataBuffY_uV[Ichan];  //use the raw data
    fooData_raw = Arrays.copyOfRange(fooData_raw, fooData_raw.length-Nfft, fooData_raw.length);   //just grab the most recent block of data
    fftBuff[Ichan].forward(fooData_raw); //compute FFT on this channel of data
    
    //convert fft data to uV_per_sqrtHz
    //final float mean_winpow_sqr = 0.3966;  //account for power lost when windowing...mean(hamming(N).^2) = 0.3966
    final float mean_winpow = 1.0f/sqrt(2.0f);  //account for power lost when windowing...mean(hamming(N).^2) = 0.3966
    final float scale_raw_to_rtHz = pow((float)fftBuff[0].specSize(),1)*fs_Hz*mean_winpow; //normalize the amplitude by the number of bins to get the correct scaling to uV/sqrt(Hz)???
    double foo;
    for (int I=0; I < fftBuff[Ichan].specSize(); I++) {  //loop over each FFT bin
      foo = sqrt(pow(fftBuff[Ichan].getBand(I),2)/scale_raw_to_rtHz);
      fftBuff[Ichan].setBand(I,(float)foo);
      //if ((Ichan==0) & (I > 5) & (I < 15)) println("processFreqDomain: uV/rtHz = " + I + " " + foo);
    }
    
    //smooth the FFT values using the previous FFT values
    double min_val = 0.01d;
    for (int I=0; I < fftBuff[Ichan].specSize(); I++) {  //loop over each FFT bin
      if (prevFFTdata[I] < min_val) prevFFTdata[I] = (float)min_val; //make sure we're not too small for the log calls
      foo = fftBuff[Ichan].getBand(I); if (foo < min_val) foo = min_val; //make sure this value isn't too small
      if (false) {
        //smooth in dB power space
        foo =   (1.0d-fft_smooth_fac) * java.lang.Math.log(java.lang.Math.pow(foo,2));
        foo += fft_smooth_fac * java.lang.Math.log(java.lang.Math.pow((double)prevFFTdata[I],2)); 
        foo = java.lang.Math.sqrt(java.lang.Math.exp(foo)); //average in dB space
      } else { 
        //smooth (average) in linear power space
        foo =   (1.0d-fft_smooth_fac) * java.lang.Math.pow(foo,2) + fft_smooth_fac * java.lang.Math.pow((double)prevFFTdata[I],2); 
        // take sqrt to be back into uV_rtHz
        foo = java.lang.Math.sqrt(foo);
      }
      fftBuff[Ichan].setBand(I,(float)foo); //put the smoothed data back into the fftBuff data holder for use by everyone else
    }
  }
}

void detectInFreqDomain(FFT[] fftBuff,float[] inband_Hz, float[] guard_Hz, DetectionData_FreqDomain[] results) {
  boolean isDetected = false;
  int nchan = fftBuff.length;
  
  //process each channel independently
  for (int Ichan = 0; Ichan < nchan; Ichan++) {
    //process the FFT data to look for certain types of waves
    float sum_inband_uV2 = 0; //a PSD value
    float sum_guard_uV2 = 0; //a PSD value
    final float Hz_per_bin = fs_Hz / ((float)fftBuff[Ichan].specSize());
    float fft_PSDperBin[] = new float[fftBuff[Ichan].specSize()];
    float freq_Hz=0;
    float max_inband_PSD = 0.0f;
    float max_inband_freq_Hz = 0.0f;
    
    for (int i=0;i < fft_PSDperBin.length;i++) { 
      fft_PSDperBin[i] = (float)java.lang.Math.pow(fftBuff[Ichan].getBand(i),2) * Hz_per_bin;   //convert from uV/sqrt(Hz) to PSD per bin
      freq_Hz = fftBuff[Ichan].indexToFreq(i);
      if ((freq_Hz >= inband_Hz[0]) & (freq_Hz <= inband_Hz[1])) { 
        sum_inband_uV2 += fft_PSDperBin[i]; 
        if (fft_PSDperBin[i] > max_inband_PSD) {
          max_inband_PSD = fft_PSDperBin[i];
          max_inband_freq_Hz = freq_Hz;
        }
      }
      if ((freq_Hz >= guard_Hz[0]) & (freq_Hz <= guard_Hz[1])) { sum_guard_uV2 += fft_PSDperBin[i]; }
    }
    float max_inband_uV_rtHz = (float)java.lang.Math.sqrt(max_inband_PSD / Hz_per_bin);
    
    //float inband_uV_rtHz = (float)java.lang.Math.sqrt(sum_inband_uV2 / (inband_Hz[1]-inband_Hz[0]));= 
    float guard_uV_rtHz = (float)java.lang.Math.sqrt(sum_guard_uV2 / (guard_Hz[1]-guard_Hz[0]));
    //float inband_vs_guard_dB = 20.f*log10(inband_uV_rtHz / guard_uV_rtHz);
    float inband_vs_guard_dB = 20.f*log10(max_inband_uV_rtHz / guard_uV_rtHz);
    if (showFFTFilteringData) {
      if (!gui.chanButtons[Ichan].isActive())  {
        println("Chan [" + Ichan + "] Max Inband, Mean Guard (uV/sqrtHz) " + max_inband_uV_rtHz + " " + guard_uV_rtHz + ",  Inband / Guard (dB) " + inband_vs_guard_dB);
      }
    } 
    isDetected = false;
    if (inband_vs_guard_dB > fft_det_thresh_dB) isDetected = true;
    results[Ichan].inband_uV = max_inband_uV_rtHz;
    results[Ichan].inband_freq_Hz = max_inband_freq_Hz;
    results[Ichan].guard_uV = guard_uV_rtHz;
    results[Ichan].thresh_uV = (float)(guard_uV_rtHz * java.lang.Math.pow(10.0,fft_det_thresh_dB / 20.0f));
    results[Ichan].isDetected = isDetected;
  }
}
