
///////////////////////////////////////////////
//
// GUI for controlling the ADS1299-based OpenBCI Shield
// This is the simpler-looking version of our GUI.
//
// Created: Chip Audette, Oct 2013 - May 2014
//
// Requires gwoptics graphing library for processing.  Built on V0.5.0
// http://www.gwoptics.org/processing/gwoptics_p5lib/
//
// No warranty.  Use at your own risk.  Use for whatever you'd like.
// 
///////////////////////////////////////////////


import processing.serial.*;  //for serial communication to Arduino/OpenBCI
import ddf.minim.analysis.*; //for FFT
import java.util.*; //for Array.copyOfRange()
import java.lang.Math; //for exp, log, sqrt...they seem better than Processing's built-in
import ddf.minim.*;  // To make sound.  Following minim example "frequencyModulation"
import ddf.minim.ugens.*;  // To make sound.  Following minim example "frequencyModulation"

//choose where to get the EEG data
final int DATASOURCE_NORMAL =  0;        //Receive LIVE data from OpenBCI
final int DATASOURCE_NORMAL_W_AUX =  1;  //Receive LIVE data from OpenBCI plus the Aux data recorded by the Arduino  
final int DATASOURCE_SYNTHETIC = 2;    //Generate synthetic signals (steady noise)
final int DATASOURCE_PLAYBACKFILE = 3; //Playback previously recorded data...see "playbackData_fname" down below
final int eegDataSource = DATASOURCE_PLAYBACKFILE;

//Serial communications constants
OpenBCI_ADS1299 openBCI;
String openBCI_portName = "COM12";   /************** CHANGE THIS TO MATCH THE COM PORT REPORTED ON *YOUR* COMPUTER *****************/

//these settings are for a single OpenBCI board
int openBCI_baud = 115200; //baud rate from the rArduino
int OpenBCI_Nchannels = 8; //normal OpenBCI has 8 channels

//here are variables that are used if loading input data from a CSV text file...double slash ("\\") is necessary to make a single slash
//final String playbackData_fname = "EEG_Data\\openBCI_2013-12-24_meditation.txt"; //only used if loading input data from a file
final String playbackData_fname = "EEG_Data\\openBCI_2013-12-24_relaxation.txt"; //only used if loading input data from a file
int currentTableRowIndex = 0;
Table_CSV playbackData_table;
int nextPlayback_millis = -100; //any negative number

//properties of the openBCI board
float fs_Hz = 250.0f;  //sample rate used by OpenBCI board
final float ADS1299_Vref = 4.5f;  //reference voltage for ADC in ADS1299
final float ADS1299_gain = 24;  //assumed gain setting for ADS1299
final float scale_fac_uVolts_per_count = ADS1299_Vref / (pow(2,23)-1) / ADS1299_gain  * 1000000.f; //ADS1299 datasheet Table 7, confirmed through experiment
final float openBCI_impedanceDrive_amps = 6.0e-9;  //6 nA
boolean isBiasAuto = true;

//other data fields
float dataBuffX[];
float dataBuffY_uV[][]; //2D array to handle multiple data channels, each row is a new channel so that dataBuffY[3][] is channel 4
float dataBuffY_filtY_uV[][];
float data_std_uV[];
float data_elec_imp_ohm[];
int nchan = OpenBCI_Nchannels;
int n_aux_ifEnabled = 1;  //if DATASOURCE_NORMAL_W_AUX then this is how many aux channels there will be
int prev_time_millis = 0;
final int nPointsPerUpdate = 50; //update screen after this many data points.  
float yLittleBuff[] = new float[nPointsPerUpdate];
DataStatus is_railed[];
final int threshold_railed = int(pow(2,23)-1000);
final int threshold_railed_warn = int(pow(2,23)*0.75);
float yLittleBuff_uV[][] = new float[nchan][nPointsPerUpdate]; //small buffer used to send data to the filters

//allocate space for filters
final int N_FILT_CONFIGS = 5;
FilterConstants[] filtCoeff_bp = new FilterConstants[N_FILT_CONFIGS];
FilterConstants[] filtCoeff_notch = new FilterConstants[N_FILT_CONFIGS];
int currentFilt_ind = 0;

//fft constants
int Nfft = 256; //set resolution of the FFT.  Use N=256 for normal, N=512 for MU waves
//float fft_smooth_fac = 0.75f; //use value between [0 and 1].  Bigger is more smoothing.  Use 0.9 for MU waves, 0.75 for Alpha, 0.0 for no smoothing
FFT fftBuff[] = new FFT[nchan];   //from the minim library
float[] smoothFac = new float[]{0.75, 0.9, 0.95, 0.98, 0.0, 0.5};
final int N_SMOOTHEFAC = 6;
int smoothFac_ind = 0;


//plotting constants
Gui_Manager gui;
float default_vertScale_uV = 200.0f;
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
DataPacket_ADS1299 dataPacketBuff[] = new DataPacket_ADS1299[nDataBackBuff]; //allocate the array, but doesn't call constructor.  Still need to call the constructor!
int curDataPacketInd = -1;
int lastReadDataPacketInd = -1;

///////////// Specific to OpenBCI_GUI_Simpler

//which channels active and which not?
int nchan = 2;  //total number of channels to make available to the user
int nchan_active_at_startup = 1;  //just have one active at startup, though

//signal detection constants
boolean showFFTFilteringData = false;
String signalDetectName = "Alpha";
float inband_Hz[] = {9.0f, 12.0f};  //look at energy within these frequencies
float guard_Hz[] = {13.5f, 23.5f};  //and compare to energy within these frequencies
float fft_det_thresh_dB = 10.0;      //how much higher does the in-band signal have to be above the guard band?
DetectionData_FreqDomain[] detData_freqDomain = new DetectionData_FreqDomain[nchan]; //holds data describing any detections performed in the frequency domain

//constants for sound generation for alpha detection
Minim minim;
AudioOutput audioOut;  //was just "out" in the Minim example
Oscil wave;


/////////////////////////////////////////////////////////////////////// functions

//define filters...assumes fs = 250 Hz !!!!!
void defineFilters(FilterConstants[] filtCoeff_bp,FilterConstants[] filtCoeff_notch) {
  int n_filt = filtCoeff_bp.length;
  double[] b, a, b2, a2;
  String filt_txt, filt_txt2;
  String short_txt, short_txt2; 
    
  //loop over all of the pre-defined filter types
  for (int Ifilt=0;Ifilt<n_filt;Ifilt++) {
    
    //define common notch filter
    b2 = new double[]{ 9.650809863447347e-001, -2.424683201757643e-001, 1.945391494128786e+000, -2.424683201757643e-001, 9.650809863447347e-001};
    a2 = new double[]{    1.000000000000000e+000,   -2.467782611297853e-001,    1.944171784691352e+000,   -2.381583792217435e-001,    9.313816821269039e-001}; 
    filtCoeff_notch[Ifilt] =  new FilterConstants(b2,a2,"Notch 60Hz","60Hz");
    
    //define bandpass filter
    switch (Ifilt) {
      case 0:
        //butter(2,[1 50]/(250/2));  %bandpass filter
        b = new double[]{ 2.001387256580675e-001, 0.0f, -4.002774513161350e-001, 0.0f, 2.001387256580675e-001 };
        a = new double[]{ 1.0f, -2.355934631131582e+000, 1.941257088655214e+000, -7.847063755334187e-001, 1.999076052968340e-001 };
        filt_txt = "Bandpass 1-50Hz";
        short_txt = "1-50 Hz";
        break;
      case 1:
        //butter(2,[7 13]/(250/2));
        b = new double[]{  5.129268366104263e-003, 0.0f,  -1.025853673220853e-002, 0.0f, 5.129268366104263e-003 };
        a = new double[]{ 1.0f,  -3.678895469764040e+000,  5.179700413522124e+000, -3.305801890016702e+000,8.079495914209149e-001 };
        filt_txt = "Bandpass 7-13Hz";
        short_txt = "7-13 Hz";
        break;      
      case 2:
        //[b,a]=butter(2,[15 50]/(250/2)); %matlab command
        b = new double[]{ 1.173510367246093e-001,  0.0f, -2.347020734492186e-001,  0.0f, 1.173510367246093e-001};
        a = new double[]{ 1.0f, -2.137430180172061e+000, 2.038578008108517e+000,-1.070144399200925e+000, 2.946365275879138e-001};
        filt_txt = "Bandpass 15-50Hz";
        short_txt = "15-50 Hz";  
        break;    
      case 3:
        //[b,a]=butter(2,[5 50]/(250/2)); %matlab command
        b = new double[]{  1.750876436721012e-001,  0.0f, -3.501752873442023e-001,  0.0f, 1.750876436721012e-001};       
        a = new double[]{ 1.0f,  -2.299055356038497e+000,   1.967497759984450e+000,  -8.748055564494800e-001,   2.196539839136946e-001};
        filt_txt = "Bandpass 5-50Hz";
        short_txt = "5-50 Hz";
        break;      
      default:
        //no filtering
        b = new double[] {1.0};
        a = new double[] {1.0};
        filt_txt = "No BP Filter";
        short_txt = "No Filter";
        b2 = new double[] {1.0};
        a2 = new double[] {1.0};
        filtCoeff_notch[Ifilt] =  new FilterConstants(b2,a2,"No Notch","No Notch");
    }  //end switch block  

    //create the bandpass filter    
    filtCoeff_bp[Ifilt] =  new FilterConstants(b,a,filt_txt,short_txt);  
  } //end loop over filters
  
} //end defineFilters method 
 


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

//set window size
int win_x = 1200;  //window width
//int win_y = 768; //window height
int win_y = 450;   //window height
void setup() {

  //open window
  size(win_x, win_y, P2D);
  //if (frame != null) frame.setResizable(true);  //make window resizable
  //attach exit handler
  //prepareExitHandler();

  println("Starting setup...");

  //prepare data variables
  dataBuffX = new float[(int)(dataBuff_len_sec * fs_Hz)];
  dataBuffY_uV = new float[nchan][dataBuffX.length];
  dataBuffY_filtY_uV = new float[nchan][dataBuffX.length];
  data_std_uV = new float[nchan];
  data_elec_imp_ohm = new float[nchan];
  is_railed = new DataStatus[nchan];
  for (int i=0; i<nchan;i++) is_railed[i] = new DataStatus(threshold_railed,threshold_railed_warn);
  for (int i=0; i<nDataBackBuff;i++) { 
    dataPacketBuff[i] = new DataPacket_ADS1299(nchan+n_aux_ifEnabled);
  }

  //initialize the data
  prepareData(dataBuffX, dataBuffY_uV, fs_Hz);

  //initialize the FFT objects
  for (int Ichan=0; Ichan < nchan; Ichan++) { 
    fftBuff[Ichan] = new FFT(Nfft, fs_Hz);
  };  //make the FFT objects
  initializeFFTObjects(fftBuff, dataBuffY_uV, Nfft, fs_Hz);

  //prepare the filters...must be anytime before the GUI
  defineFilters(filtCoeff_bp,filtCoeff_notch);
  
  //prepare some signal processing stuff
  for (int Ichan=0; Ichan < nchan; Ichan++) { detData_freqDomain[Ichan] = new DetectionData_FreqDomain(); }

  //initilize the GUI
//  String filterText = ""; for (int i=0; i<filtCoeff.length; i++) { if (i>0) {filterText+= '\n';} filterText += filtCoeff[i].name; };
//  gui = new gui_Manager(this, win_x, win_y, nchan, displayTime_sec,vertScale_uV,fs_Hz,filterText,signalDetectName);
  String filterDescription = filtCoeff_bp[currentFilt_ind].name + ", " + filtCoeff_notch[currentFilt_ind].name; 
  gui = new Gui_Manager(this, win_x, win_y, nchan, displayTime_sec,default_vertScale_uV,filterDescription, smoothFac[smoothFac_ind],signalDetectName);
  
  //associate the data to the GUI traces
  gui.initDataTraces(dataBuffX, dataBuffY_filtY_uV, fftBuff, data_std_uV, is_railed);
  
  //limit how much data is plotted...hopefully to speed things up a little
  gui.setDoNotPlotOutsideXlim(true);
  gui.setDecimateFactor(2);
  
  //show the FFT-based signal detection
  gui.setGoodFFTBand(inband_Hz); gui.setBadFFTBand(guard_Hz);
  gui.showFFTFilteringData(showFFTFilteringData);

  //prepare the source of the input data
  switch (eegDataSource) {
    case DATASOURCE_NORMAL: case DATASOURCE_NORMAL_W_AUX:
      //list all the serial ports available...useful for debugging
      println(Serial.list());
      //openBCI_portName = Serial.list()[0];
      
      // Open the serial port to the Arduino that has the OpenBCI
      println("OpenBCI_GUI: Opening Serial " + openBCI_portName);
      int nDataValuesPerPacket = nchan;
      if (eegDataSource == DATASOURCE_NORMAL_W_AUX) nDataValuesPerPacket += n_aux_ifEnabled;
      openBCI = new OpenBCI_ADS1299(this, openBCI_portName, openBCI_baud,nDataValuesPerPacket); //this also starts the data transfer after XX seconds
      break;
    case DATASOURCE_SYNTHETIC:
      //do nothing
      break;
    case DATASOURCE_PLAYBACKFILE:
      //open and load the data file
      println("OpenBCI_GUI: loading playback data from " + playbackData_fname);
      //playbackData_table = loadTable(playbackData_fname, "header,csv");
      try {
        playbackData_table = new Table_CSV(playbackData_fname);
      } catch (Exception e) {
        println("setup: could not open file for playback: " + playbackData_fname);
        println("   : quitting...");
        exit();
      }
      println("OpenBCI_GUI: loading complete.  " + playbackData_table.getRowCount() + " rows of data, which is " + round(float(playbackData_table.getRowCount())/fs_Hz) + " seconds of EEG data");
      
      //removing first column of data from data file...the first column is a time index and not eeg data
      playbackData_table.removeColumn(0);
      break;
    default: 
  }
    
  //initialize the on/off state of the different channels...specific to OpenBCI_GUI_Simpler
  for (int Ichan=0; Ichan<OpenBCI_Nchannels;Ichan++) {
    if (Ichan < nchan_active_at_startup) { activateChannel(Ichan); } else { deactivateChannel(Ichan);  }
  }
  
  // initialize the minim and audioOut objects...specific to OpenBCI_GUI_Simpler
  minim = new Minim( this );
  audioOut   = minim.getLineOut(); 
  wave = new Oscil( 200, 0.0, Waves.TRIANGLE );  // make the Oscil we will hear.  Arguments are frequency, amplitude, and waveform
  wave.patch( audioOut );
  gui.setAudioOscillator(wave);
  
  //final config
  setBiasState(isBiasAuto);

  //start
  startRunning();

  println("setup: Setup complete...");
}

int pointCounter = 0;
//boolean newData = true;
int prevBytes = 0; 
int prevMillis=millis();
int byteRate_perSec = 0;
int drawLoop_counter = 0;
void draw() {
  drawLoop_counter++;
  if (isRunning) {
    //get the data, if it is available
    pointCounter = getDataIfAvailable(pointCounter);
    
    //has enough data arrived to process it and update the GUI?
    if (pointCounter >= nPointsPerUpdate) {
      pointCounter = 0;  //reset for next time
      
      //process the data
      processNewData();

      //try to detect the desired signals, do it in frequency space...for OpenBCI_GUI_Simpler
      detectInFreqDomain(fftBuff,inband_Hz,guard_Hz,detData_freqDomain);
      gui.setDetectionData_freqDomain(detData_freqDomain);

      //tell the GUI that it has received new data via dumping new data into arrays that the GUI has pointers to
      gui.update(data_std_uV,data_elec_imp_ohm);
      
      ///add raw data to spectrogram...if the correct channel...
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
        
      redrawScreenNow=true;
    } 
    else {
      //not enough data has arrived yet.  do nothing more
    }
  }
    
  int drawLoopCounter_thresh = 100;
  if ((redrawScreenNow) || (drawLoop_counter >= drawLoopCounter_thresh)) {
    //if (drawLoop_counter >= drawLoopCounter_thresh) println("OpenBCI_GUI: redrawing based on loop counter...");
    drawLoop_counter=0; //reset for next time
    redrawScreenNow = false;  //reset for next time
    
    //update the title of the figure;
    switch (eegDataSource) {
      case DATASOURCE_NORMAL: case DATASOURCE_NORMAL_W_AUX:
        frame.setTitle(int(frameRate) + " fps, Byte Count = " + openBCI_byteCount + ", bit rate = " + byteRate_perSec*8 + " bps" + ", " + int(float(fileoutput.getRowsWritten())/fs_Hz) + " secs Saved, Writing to " + output_fname);
        break;
      case DATASOURCE_SYNTHETIC:
        frame.setTitle(int(frameRate) + " fps, Using Synthetic EEG Data");
        break;
      case DATASOURCE_PLAYBACKFILE:
        frame.setTitle(int(frameRate) + " fps, Playing " + int(float(currentTableRowIndex)/fs_Hz) + " of " + int(float(playbackData_table.getRowCount())/fs_Hz) + " secs, Reading from: " + playbackData_fname);
        break;
    } 
    
    //redraw the screen...not every time, get paced by when data is being plotted    
    background(0);  //clear the screen
    gui.draw(); //draw the GUI
  }
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
    redrawScreenNow = true;
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
  
  //check the graphs
  if (gui.isMouseOnFFT(mouseX,mouseY)) {
    GraphDataPoint dataPoint = new GraphDataPoint();
    gui.getFFTdataPoint(mouseX,mouseY,dataPoint);
    println("OpenBCI_GUI: FFT data point: " + String.format("%4.2f",dataPoint.x) + " " + dataPoint.x_units + ", " + String.format("%4.2f",dataPoint.y) + " " + dataPoint.y_units);
  }
  
  redrawScreenNow = true; //redraw the screen for any reason
}

void mouseReleased() {
  //gui.stopButton.updateMouseIsReleased();
  gui.stopButton.setIsActive(false);
  redrawScreenNow = true;
}

//execute this function whenver the stop button is pressed
void stopButtonWasPressed() {
  //toggle the data transfer state of the ADS1299...stop it or start it...
  if (isRunning) {
    println("openBCI_GUI: stopButton was pressed...stopping data transfer...");
    if (openBCI != null) openBCI.stopDataTransfer();
  } 
  else { //not running
    openNewLogFile();  //open a new log file
    
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
    wave.amplitude.setLastValue(0); //turn off audio
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
  println("OpenBCI_GUI: deactivating channel " + (Ichan+1));
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
