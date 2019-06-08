///////////////////////////////////////////////
//
// GUI for controlling the ADS1299-based OpenBCI Shield
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
import ddf.minim.*;  // To make sound.  Following minim example "frequencyModulation"
import ddf.minim.ugens.*;  // To make sound.  Following minim example "frequencyModulation"
import java.util.*; //for Array.copyOfRange()
import java.lang.Math; //for exp, log, sqrt...they seem better than Processing's built-in
import processing.core.PApplet;


//choose where to get the EEG data
final int DATASOURCE_NORMAL =  0;        //Receive LIVE data from OpenBCI
final int DATASOURCE_NORMAL_W_AUX =  1;  //Receive LIVE data from OpenBCI plus the Aux data recorded by the Arduino  
final int DATASOURCE_SYNTHETIC = 2;    //Generate synthetic signals (steady noise)
final int DATASOURCE_PLAYBACKFILE = 3; //Playback previously recorded data...see "playbackData_fname" down below
final int eegDataSource = DATASOURCE_PLAYBACKFILE;

//Serial communications constants
OpenBCI_ADS1299 openBCI = new OpenBCI_ADS1299(); //dummy creation to get access to constants, create real one later
String openBCI_portName = "COM4";   /************** CHANGE THIS TO MATCH THE COM PORT REPORTED ON *YOUR* COMPUTER *****************/

//these settings are for a single OpenBCI board
int openBCI_baud = 115200; //baud rate from the rArduino
final int OpenBCI_Nchannels = 8; //normal OpenBCI has 8 channels
//use this for when daisy-chaining two OpenBCI boards
//int openBCI_baud = 2*115200; //baud rate from the Arduino
//final int OpenBCI_Nchannels = 16; //daisy chain has 16 channels

//here are variables that are used if loading input data from a CSV text file...double slash ("\\") is necessary to make a single slash
String playbackData_fname = "EEG_Data\\openBCI_2013-12-24_meditation.txt"; //only used if loading input data from a file
//String playbackData_fname = "EEG_Data\\openBCI_2013-12-24_relaxation.txt"; //only used if loading input data from a file
//String playbackData_fname;  //leave blank to cause an "Open File" dialog box to appear at startup.  USEFUL!
float playback_speed_fac = 1.0f;  //make 1.0 for real-time.  larger for faster playback
int currentTableRowIndex = 0;
Table_CSV playbackData_table;
int nextPlayback_millis = -100; //any negative number

//other data fields
float dataBuffX[];
float dataBuffY_uV[][]; //2D array to handle multiple data channels, each row is a new channel so that dataBuffY[3][] is channel 4
float dataBuffY_filtY_uV[][];
float data_elec_imp_ohm[];
//int nchan = 12; //normally, nchan = OpenBCI_Nchannels.  Choose a smaller number to show fewer on the GUI
int nchan = OpenBCI_Nchannels; //normally, nchan = OpenBCI_Nchannels.  Choose a smaller number to show fewer on the GUI
int nchan_active_at_startup = nchan;  //how many channels to be LIVE at startup
int n_aux_ifEnabled = 1;  //if DATASOURCE_NORMAL_W_AUX then this is how many aux channels there will be
int prev_time_millis = 0;
final int nPointsPerUpdate = 50; //update screen after this many data points.  
float yLittleBuff[] = new float[nPointsPerUpdate];
DataStatus is_railed[];
final int threshold_railed = int(pow(2,23)-1000);  //fully railed should be +/- 2^23, so set this threshold close to that value
final int threshold_railed_warn = int(pow(2,23)*0.75); //set a somewhat smaller value as the warning threshold
float yLittleBuff_uV[][] = new float[nchan][nPointsPerUpdate]; //small buffer used to send data to the filters

//create objects that'll do the EEG signal processing
EEG_Processing eegProcessing;
EEG_Processing_User eegProcessing_user;

//fft constants
int Nfft = 256; //set resolution of the FFT.  Use N=256 for normal, N=512 for MU waves
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
OutputFile_rawtxt fileoutput;
String output_fname;

//openBCI data packet
final int nDataBackBuff = 3*(int)openBCI.fs_Hz;
DataPacket_ADS1299 dataPacketBuff[] = new DataPacket_ADS1299[nDataBackBuff]; //allocate the array, but doesn't call constructor.  Still need to call the constructor!
int curDataPacketInd = -1;
int lastReadDataPacketInd = -1;

///////////// Specific to OpenBCI_GUI_Simpler

////signal detection constants
//boolean showFFTFilteringData = false;
//String signalDetectName = "Alpha";
//float inband_Hz[] = {9.0f, 12.0f};  //look at energy within these frequencies
//float guard_Hz[] = {13.5f, 23.5f};  //and compare to energy within these frequencies
//float fft_det_thresh_dB = 10.0;      //how much higher does the in-band signal have to be above the guard band?
//DetectionData_FreqDomain[] detData_freqDomain = new DetectionData_FreqDomain[nchan]; //holds data describing any detections performed in the frequency domain
//
////constants for sound generation for alpha detection
//Minim minim;
//AudioOutput audioOut;  //was just "out" in the Minim example
//Oscil wave;


/////////////////////////////////////////////////////////////////////// functions

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

//set window size
int win_x = 1200;  //window width
int win_y = 768; //window height
//int win_y = 450;   //window height...for OpenBCI_GUI_Simpler
void setup() {

  //get playback file name, if necessary  
  if (eegDataSource == DATASOURCE_PLAYBACKFILE) {
      if ((playbackData_fname==null) || (playbackData_fname.length() == 0)) selectInput("Select an OpenBCI TXT file: ", "fileSelected");
      while ((playbackData_fname==null) || (playbackData_fname.length() == 0)) { delay(100); /* wait until selection is complete */ }
  }
  
  //open window
  size(win_x, win_y, P2D);
  //if (frame != null) frame.setResizable(true);  //make window resizable
  //attach exit handler
  //prepareExitHandler();
  
  println("Starting setup...");
  
  //prepare data variables
  dataBuffX = new float[(int)(dataBuff_len_sec * openBCI.fs_Hz)];
  dataBuffY_uV = new float[nchan][dataBuffX.length];
  dataBuffY_filtY_uV = new float[nchan][dataBuffX.length];
  //data_std_uV = new float[nchan];
  data_elec_imp_ohm = new float[nchan];
  is_railed = new DataStatus[nchan];
  for (int i=0; i<nchan;i++) is_railed[i] = new DataStatus(threshold_railed,threshold_railed_warn);
  for (int i=0; i<nDataBackBuff;i++) { 
    //dataPacketBuff[i] = new DataPacket_ADS1299(nchan+n_aux_ifEnabled);
    dataPacketBuff[i] = new DataPacket_ADS1299(OpenBCI_Nchannels+n_aux_ifEnabled);
  }
  eegProcessing = new EEG_Processing(nchan,openBCI.fs_Hz);
  eegProcessing_user = new EEG_Processing_User(nchan,openBCI.fs_Hz);

  //initialize the data
  prepareData(dataBuffX, dataBuffY_uV,openBCI.fs_Hz);

  //initialize the FFT objects
  for (int Ichan=0; Ichan < nchan; Ichan++) { 
    fftBuff[Ichan] = new FFT(Nfft, openBCI.fs_Hz);
  };  //make the FFT objects
  initializeFFTObjects(fftBuff, dataBuffY_uV, Nfft, openBCI.fs_Hz);

  //prepare some signal processing stuff
  //for (int Ichan=0; Ichan < nchan; Ichan++) { detData_freqDomain[Ichan] = new DetectionData_FreqDomain(); }

  //initilize the GUI
  String filterDescription = eegProcessing.getFilterDescription();
  gui = new Gui_Manager(this, win_x, win_y, nchan,displayTime_sec,default_vertScale_uV,filterDescription, smoothFac[smoothFac_ind]);
  
  //associate the data to the GUI traces
  gui.initDataTraces(dataBuffX, dataBuffY_filtY_uV, fftBuff, eegProcessing.data_std_uV, is_railed,eegProcessing.polarity);

  //limit how much data is plotted...hopefully to speed things up a little
  gui.setDoNotPlotOutsideXlim(true);
  gui.setDecimateFactor(2);
  //show the FFT-based signal detection
  //gui.setGoodFFTBand(inband_Hz); gui.setBadFFTBand(guard_Hz);
  //gui.showFFTFilteringData(showFFTFilteringData);

  //prepare the source of the input data
  switch (eegDataSource) {
    case DATASOURCE_NORMAL: case DATASOURCE_NORMAL_W_AUX:
      //list all the serial ports available...useful for debugging
      println(Serial.list());
      //openBCI_portName = Serial.list()[0];
      
      // Open the serial port to the Arduino that has the OpenBCI
      println("OpenBCI_GUI: Opening Serial " + openBCI_portName);
      int nDataValuesPerPacket = OpenBCI_Nchannels;
      if (eegDataSource == DATASOURCE_NORMAL_W_AUX) nDataValuesPerPacket += n_aux_ifEnabled;
      openBCI = new OpenBCI_ADS1299(this, openBCI_portName, openBCI_baud, nDataValuesPerPacket); //this also starts the data transfer after XX seconds
      break;
    case DATASOURCE_SYNTHETIC:
      //do nothing
      break;
    case DATASOURCE_PLAYBACKFILE:
      //open and load the data file
      println("OpenBCI_GUI: loading playback data from " + playbackData_fname);
      try {
        playbackData_table = new Table_CSV(playbackData_fname);
      } catch (Exception e) {
        println("setup: could not open file for playback: " + playbackData_fname);
        println("   : quitting...");
        exit();
      }
      println("OpenBCI_GUI: loading complete.  " + playbackData_table.getRowCount() + " rows of data, which is " + round(float(playbackData_table.getRowCount())/openBCI.fs_Hz) + " seconds of EEG data");
      
      //removing first column of data from data file...the first column is a time index and not eeg data
      playbackData_table.removeColumn(0);
      break;
    default: 
  }

  //initialize the on/off state of the different channels...only if the user has specified fewer channels
  //than is on the OpenBCI board
  //for (int Ichan=0; Ichan<OpenBCI_Nchannels;Ichan++) {  //what will happen here for the 16-channel board???
  //  if (Ichan < nchan_active_at_startup) { activateChannel(Ichan); } else { deactivateChannel(Ichan);  }
  //}
  for (int Ichan=nchan_active_at_startup; Ichan<OpenBCI_Nchannels;Ichan++) deactivateChannel(Ichan);  //deactivate unused channels
  
  // initialize the minim and audioOut objects...specific to OpenBCI_GUI_Simpler
  //minim = new Minim( this );
  //audioOut   = minim.getLineOut(); 
  //wave = new Oscil( 200, 0.0, Waves.TRIANGLE );  // make the Oscil we will hear.  Arguments are frequency, amplitude, and waveform
  //wave.patch( audioOut );
  //gui.setAudioOscillator(wave);
  
  //final config
  setBiasState(openBCI.isBiasAuto);

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
      //detectInFreqDomain(fftBuff,inband_Hz,guard_Hz,detData_freqDomain);
      //gui.setDetectionData_freqDomain(detData_freqDomain);
      //tell the GUI that it has received new data via dumping new data into arrays that the GUI has pointers to
      gui.update(eegProcessing.data_std_uV,data_elec_imp_ohm);
      
      ///add raw data to spectrogram...if the correct channel...
      //...look for the first channel that is active (meaning button is not active) or, if it
      //     hasn't yet sent any data, send the last channel even if the channel is off
      for (int Ichan = 0; Ichan < nchan; Ichan++) {
        boolean sendToSpectrogram = true;  
        if (sendToSpectrogram & (!(gui.chanButtons[Ichan].isActive()) | (Ichan == (nchan-1)))) { //send data to spectrogram
          sendToSpectrogram = false;  //prevent us from sending more data after this time through
          for (int Idata=0;Idata < nPointsPerUpdate;Idata++) {
            gui.spectrogram.addDataPoint(yLittleBuff_uV[Ichan][Idata]);
            gui.tellGUIWhichChannelForSpectrogram(Ichan);
            //gui.spectrogram.addDataPoint(100.0f+(float)Idata);
          }
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
        frame.setTitle(int(frameRate) + " fps, Byte Count = " + openBCI_byteCount + ", bit rate = " + byteRate_perSec*8 + " bps" + ", " + int(float(fileoutput.getRowsWritten())/openBCI.fs_Hz) + " secs Saved, Writing to " + output_fname);
        break;
      case DATASOURCE_SYNTHETIC:
        frame.setTitle(int(frameRate) + " fps, Using Synthetic EEG Data");
        break;
      case DATASOURCE_PLAYBACKFILE:
        frame.setTitle(int(frameRate) + " fps, Playing " + int(float(currentTableRowIndex)/openBCI.fs_Hz) + " of " + int(float(playbackData_table.getRowCount())/openBCI.fs_Hz) + " secs, Reading from: " + playbackData_fname);
        break;
    } 
    
    //redraw the screen...not every time, get paced by when data is being plotted    
    background(0);  //clear the screen
    gui.draw(); //draw the GUI
  }
}

int getDataIfAvailable(int pointCounter) {
  
  if ( (eegDataSource == DATASOURCE_NORMAL) || (eegDataSource == DATASOURCE_NORMAL_W_AUX) ) {
    //get data from serial port as it streams in

      //first, get the new data (if any is available)
      openBCI.updateState(); //this is trying to listen to the openBCI hardware.  New data is put into dataPacketBuff and increments curDataPacketInd.
      
      //next, gather any new data into the "little buffer"
      while ( (curDataPacketInd != lastReadDataPacketInd) && (pointCounter < nPointsPerUpdate)) {
        lastReadDataPacketInd = (lastReadDataPacketInd+1) % dataPacketBuff.length;  //increment to read the next packet
        for (int Ichan=0; Ichan < nchan; Ichan++) {   //loop over each cahnnel
          //scale the data into engineering units ("microvolts") and save to the "little buffer"
          yLittleBuff_uV[Ichan][pointCounter] = dataPacketBuff[lastReadDataPacketInd].values[Ichan] * openBCI.scale_fac_uVolts_per_count;
        } 
        pointCounter++; //increment counter for "little buffer"
      }
  } else {
    // make or load data to simulate real time
        
    //has enough time passed?
    int current_millis = millis();
    if (current_millis >= nextPlayback_millis) {
      //prepare for next time
      int increment_millis = int(round(float(nPointsPerUpdate)*1000.f/openBCI.fs_Hz)/playback_speed_fac);
      if (nextPlayback_millis < 0) nextPlayback_millis = current_millis;
      nextPlayback_millis += increment_millis;

      // generate or read the data
      lastReadDataPacketInd = 0;
      for (int i = 0; i < nPointsPerUpdate; i++) {
        dataPacketBuff[lastReadDataPacketInd].sampleIndex++;
        switch (eegDataSource) {
          case DATASOURCE_SYNTHETIC: //use synthetic data (for GUI debugging)   
            synthesizeData(nchan, openBCI.fs_Hz, openBCI.scale_fac_uVolts_per_count, dataPacketBuff[lastReadDataPacketInd]);
            break;
          case DATASOURCE_PLAYBACKFILE: 
            currentTableRowIndex=getPlaybackDataFromTable(playbackData_table,currentTableRowIndex,openBCI.scale_fac_uVolts_per_count, dataPacketBuff[lastReadDataPacketInd]);
            break;
          default:
            //no action
        }
        //gather the data into the "little buffer"
        for (int Ichan=0; Ichan < nchan; Ichan++) {
          //scale the data into engineering units..."microvolts"
          yLittleBuff_uV[Ichan][pointCounter] = dataPacketBuff[lastReadDataPacketInd].values[Ichan]* openBCI.scale_fac_uVolts_per_count;
        }
        pointCounter++;
      } //close the loop over data points
      //if (eegDataSource==DATASOURCE_PLAYBACKFILE) println("OpenBCI_GUI: getDataIfAvailable: currentTableRowIndex = " + currentTableRowIndex);
      //println("OpenBCI_GUI: getDataIfAvailable: pointCounter = " + pointCounter);
    } // close "has enough time passed"
  } 
  return pointCounter;
}

void processNewData() {

  byteRate_perSec = (int)(1000.f * ((float)(openBCI_byteCount - prevBytes)) / ((float)(millis() - prevMillis)));
  prevBytes = openBCI_byteCount; 
  prevMillis=millis();
  float foo_val;
  float prevFFTdata[] = new float[fftBuff[0].specSize()];
  double foo;

  //update the data buffers
  for (int Ichan=0;Ichan < nchan; Ichan++) {
    //append the new data to the larger data buffer...because we want the plotting routines
    //to show more than just the most recent chunk of data.  This will be our "raw" data.
    appendAndShift(dataBuffY_uV[Ichan], yLittleBuff_uV[Ichan]);
    
    //make a copy of the data that we'll apply processing to.  This will be what is displayed on the full montage
    dataBuffY_filtY_uV[Ichan] = dataBuffY_uV[Ichan].clone();
  }
    
  //if you want to, re-reference the montage to make it be a mean-head reference
  if (false) rereferenceTheMontage(dataBuffY_filtY_uV);
  
  //update the FFT (frequency spectrum)
  for (int Ichan=0;Ichan < nchan; Ichan++) {  

    //copy the previous FFT data...enables us to apply some smoothing to the FFT data
    for (int I=0; I < fftBuff[Ichan].specSize(); I++) prevFFTdata[I] = fftBuff[Ichan].getBand(I); //copy the old spectrum values
    
    //prepare the data for the new FFT
    float[] fooData_raw = dataBuffY_uV[Ichan];  //use the raw data for the FFT
    fooData_raw = Arrays.copyOfRange(fooData_raw, fooData_raw.length-Nfft, fooData_raw.length);   //trim to grab just the most recent block of data
    float meanData = mean(fooData_raw);  //compute the mean
    for (int I=0; I < fooData_raw.length; I++) fooData_raw[I] -= meanData; //remove the mean (for a better looking FFT
    
    //compute the FFT
    fftBuff[Ichan].forward(fooData_raw); //compute FFT on this channel of data
    
//    //convert fft data to uV_per_sqrtHz
//    //final float mean_winpow_sqr = 0.3966;  //account for power lost when windowing...mean(hamming(N).^2) = 0.3966
//    final float mean_winpow = 1.0f/sqrt(2.0f);  //account for power lost when windowing...mean(hamming(N).^2) = 0.3966
//    final float scale_raw_to_rtHz = pow((float)fftBuff[0].specSize(),1)*fs_Hz*mean_winpow; //normalize the amplitude by the number of bins to get the correct scaling to uV/sqrt(Hz)???
//    double foo;
//    for (int I=0; I < fftBuff[Ichan].specSize(); I++) {  //loop over each FFT bin
//      foo = sqrt(pow(fftBuff[Ichan].getBand(I),2)/scale_raw_to_rtHz);
//      fftBuff[Ichan].setBand(I,(float)foo);
//      //if ((Ichan==0) & (I > 5) & (I < 15)) println("processFreqDomain: uV/rtHz = " + I + " " + foo);
//    }
    
    //average the FFT with previous FFT data so that it makes it smoother in time
    double min_val = 0.01d;
    for (int I=0; I < fftBuff[Ichan].specSize(); I++) {   //loop over each fft bin
      if (prevFFTdata[I] < min_val) prevFFTdata[I] = (float)min_val; //make sure we're not too small for the log calls
      foo = fftBuff[Ichan].getBand(I); if (foo < min_val) foo = min_val; //make sure this value isn't too small
      
       if (true) {
        //smooth in dB power space
        foo =   (1.0d-smoothFac[smoothFac_ind]) * java.lang.Math.log(java.lang.Math.pow(foo,2));
        foo += smoothFac[smoothFac_ind] * java.lang.Math.log(java.lang.Math.pow((double)prevFFTdata[I],2)); 
        foo = java.lang.Math.sqrt(java.lang.Math.exp(foo)); //average in dB space
      } else { 
        //smooth (average) in linear power space
        foo =   (1.0d-smoothFac[smoothFac_ind]) * java.lang.Math.pow(foo,2);
        foo+= smoothFac[smoothFac_ind] * java.lang.Math.pow((double)prevFFTdata[I],2); 
        // take sqrt to be back into uV_rtHz
        foo = java.lang.Math.sqrt(foo);
      }
      fftBuff[Ichan].setBand(I,(float)foo); //put the smoothed data back into the fftBuff data holder for use by everyone else
    } //end loop over FFT bins
  } //end the loop over channels.
  
  //apply additional processing for the time-domain montage plot (ie, filtering)
  eegProcessing.process(yLittleBuff_uV,dataBuffY_uV,dataBuffY_filtY_uV,fftBuff);
  
  //apply user processing
  eegProcessing_user.process(yLittleBuff_uV,dataBuffY_uV,dataBuffY_filtY_uV,fftBuff);
  
  //look to see if the latest data is railed so that we can notify the user on the GUI
  for (int Ichan=0;Ichan < nchan; Ichan++) is_railed[Ichan].update(dataPacketBuff[lastReadDataPacketInd].values[Ichan]);

  //compute the electrode impedance. Do it in a very simple way [rms to amplitude, then uVolt to Volt, then Volt/Amp to Ohm]
  for (int Ichan=0;Ichan < nchan; Ichan++) data_elec_imp_ohm[Ichan] = (sqrt(2.0)*eegProcessing.data_std_uV[Ichan]*1.0e-6) / openBCI.leadOffDrive_amps;     
      
  //add your own processing steps here!
  //for (int Ichan=0;Ichan < nchan; Ichan++) { 
  // ...yLittleBuff_uV[Ichan] is the most recent raw data since the last call to this processing routine
  // ...dataBuffY_filtY_uV[Ichan] is the full set of filtered data as shown in the time-domain plot in the GUI
  // ...fftBuff[Ichan] is the FFT data structure holding the frequency spectrum as shown in the freq-domain plot in the GUI
  //}

}


//here is the routine that listens to the serial port.
//if any data is waiting, get it, parse it, and stuff it into our vector of 
//pre-allocated dataPacketBuff
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
      fileoutput.writeRawData_dataPacket(dataPacketBuff[curDataPacketInd],openBCI.scale_fac_uVolts_per_count,nchan);
    }
  } 
  else {
    inByte = port.read();
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
     String picfname = "OpenBCI-" + getDateString() + ".jpg";
     println("OpenBCI_GUI: 'm' was pressed...taking screenshot:" + picfname);
     saveFrame(picfname);    // take a shot of that!
     break;
    default:
     println("OpenBCI_GUI: '" + key + "' Pressed...sending to OpenBCI...");
     if (openBCI.serial_openBCI != null) openBCI.serial_openBCI.write(key + "\n"); //send the value as ascii with a newline character
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
      //gui.showImpedanceButtons = !gui.showImpedanceButtons;
      gui.incrementGUIpage();
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
String getDateString() {
    String fname = year() + "-";
    if (month() < 10) fname=fname+"0";
    fname = fname + month() + "-";
    if (day() < 10) fname = fname + "0";
    fname = fname + day(); 
    
    fname = fname + "_";
    if (hour() < 10) fname = fname + "0";
    fname = fname + hour() + "-";
    if (minute() < 10) fname = fname + "0";
    fname = fname + minute() + "-";
    if (second() < 10) fname = fname + "0";
    fname = fname + second();
    return fname;
}
  
//swtich yard if a click is detected
void mousePressed() {
   
  //was the stopButton pressed?
  if (gui.stopButton.isMouseHere()) { 
    gui.stopButton.setIsActive(true);
    stopButtonWasPressed(); 
  }
  
  //was the gui page button pressed?
  if (gui.guiPageButton.isMouseHere()) {
    gui.guiPageButton.setIsActive(true);
    gui.incrementGUIpage();
  }

  //check the buttons
  switch (gui.guiPage) {
    case Gui_Manager.GUI_PAGE_CHANNEL_ONOFF:
      //check the channel buttons
      for (int Ibut = 0; Ibut < gui.chanButtons.length; Ibut++) {
        if (gui.chanButtons[Ibut].isMouseHere()) { 
          toggleChannelState(Ibut);
        }
      }

      //check the detection button
      //if (gui.detectButton.updateIsMouseHere()) toggleDetectionState();      
      //check spectrogram button
      //if (gui.spectrogramButton.updateIsMouseHere()) toggleSpectrogramState();
      
      break;
    case Gui_Manager.GUI_PAGE_IMPEDANCE_CHECK:
      //check the impedance buttons
      for (int Ibut = 0; Ibut < gui.impedanceButtonsP.length; Ibut++) {
        if (gui.impedanceButtonsP[Ibut].isMouseHere()) { 
          toggleChannelImpedanceState(gui.impedanceButtonsP[Ibut],Ibut,0);
        }
        if (gui.impedanceButtonsN[Ibut].isMouseHere()) { 
          toggleChannelImpedanceState(gui.impedanceButtonsN[Ibut],Ibut,1);
        }
      }
      if (gui.biasButton.isMouseHere()) { 
        gui.biasButton.setIsActive(true);
        setBiasState(!openBCI.isBiasAuto);
      }      
      break;
    case Gui_Manager.GUI_PAGE_HEADPLOT_SETUP:
      if (gui.intensityFactorButton.isMouseHere()) {
        gui.intensityFactorButton.setIsActive(true);
        gui.incrementVertScaleFactor();
      }
      if (gui.loglinPlotButton.isMouseHere()) {
        gui.loglinPlotButton.setIsActive(true);
        gui.set_vertScaleAsLog(!gui.vertScaleAsLog); //toggle the state
      }
      if (gui.filtBPButton.isMouseHere()) {
        gui.filtBPButton.setIsActive(true);
        incrementFilterConfiguration();
      }
      if (gui.smoothingButton.isMouseHere()) {
        gui.smoothingButton.setIsActive(true);
        incrementSmoothing();
      }
      if (gui.showPolarityButton.isMouseHere()) {
        gui.showPolarityButton.setIsActive(true);
        toggleShowPolarity();
      }
      if (gui.maxDisplayFreqButton.isMouseHere()) {
        gui.maxDisplayFreqButton.setIsActive(true);
        gui.incrementMaxDisplayFreq();
      }
      
//      //check the detection button
//      if (gui.detectButton.updateIsMouseHere()) {
//       gui.detectButton.setIsActive(true);
//       toggleDetectionState();
//      }      
//      //check spectrogram button
//      if (gui.spectrogramButton.updateIsMouseHere()) {
//        gui.spectrogramButton.setIsActive(true);
//        toggleSpectrogramState();
//      }

      break;
    //default:
  }
  
  //check the graphs
  if (gui.isMouseOnFFT(mouseX,mouseY)) {
    GraphDataPoint dataPoint = new GraphDataPoint();
    gui.getFFTdataPoint(mouseX,mouseY,dataPoint);
    println("OpenBCI_GUI: FFT data point: " + String.format("%4.2f",dataPoint.x) + " " + dataPoint.x_units + ", " + String.format("%4.2f",dataPoint.y) + " " + dataPoint.y_units);
  } else if (gui.headPlot1.isPixelInsideHead(mouseX,mouseY)) {
    //toggle the head plot contours
    gui.headPlot1.drawHeadAsContours = !gui.headPlot1.drawHeadAsContours;
  } else if (gui.isMouseOnMontage(mouseX,mouseY)) {
    //toggle the display of the montage values
    gui.showMontageValues  = !gui.showMontageValues;
  }
  
  redrawScreenNow = true;  //command a redraw of the GUI whenever the mouse is pressed
}

void mouseReleased() {
  //some buttons light up only when being actively pressed.  Now that we've
  //released the mouse button, turn off those buttons.
  gui.stopButton.setIsActive(false);
  gui.guiPageButton.setIsActive(false);
  gui.intensityFactorButton.setIsActive(false);
  gui.loglinPlotButton.setIsActive(false);
  gui.filtBPButton.setIsActive(false);
  gui.smoothingButton.setIsActive(false);
  gui.showPolarityButton.setIsActive(false);
  gui.maxDisplayFreqButton.setIsActive(false);
  gui.biasButton.setIsActive(false);
  redrawScreenNow = true;  //command a redraw of the GUI whenever the mouse is released
}

void stopRunning() {
    if (openBCI != null) openBCI.stopDataTransfer();
    //if (wave != null) wave.amplitude.setLastValue(0); //turn off audio
    closeLogFile();
    isRunning = false;
}
void startRunning() {
    if ((eegDataSource == DATASOURCE_NORMAL) || (eegDataSource == DATASOURCE_NORMAL_W_AUX)) openNewLogFile();  //open a new log file
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
    nextPlayback_millis = millis();  //used for synthesizeData and readFromFile.  This restarts the clock that keeps the playback at the right pace.
  }

  //update the push button with new text based on the current running state
  //gui.stopButton.setActive(isRunning);
  if (isRunning) {
    //println("OpenBCI_GUI: stopButtonWasPressed (a): changing string to " + Gui_Manager.stopButton_pressToStop_txt);
    gui.stopButton.setString(Gui_Manager.stopButton_pressToStop_txt); 
  } 
  else {
    //println("OpenBCI_GUI: stopButtonWasPressed (a): changing string to " + Gui_Manager.stopButton_pressToStart_txt);
    gui.stopButton.setString(Gui_Manager.stopButton_pressToStart_txt);
  }
}


final float sine_freq_Hz = 10.0f;
float sine_phase_rad = 0.0;
void synthesizeData(int nchan, float fs_Hz, float scale_fac_uVolts_per_count, DataPacket_ADS1299 curDataPacket) {
  float val_uV;
  for (int Ichan=0; Ichan < nchan; Ichan++) {
    if (isChannelActive(Ichan)) { 
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


int getPlaybackDataFromTable(Table datatable, int currentTableRowIndex, float scale_fac_uVolts_per_count, DataPacket_ADS1299 curDataPacket) {
  float val_uV = 0.0f;
  
  //check to see if we can load a value from the table
  if (currentTableRowIndex >= datatable.getRowCount()) {
    //end of file
    println("OpenBCI_GUI: hit the end of the playback data file.  starting over...");
    //if (isRunning) stopRunning();
    currentTableRowIndex = 0;
  } else {
    //get the row
    TableRow row = datatable.getRow(currentTableRowIndex);
    currentTableRowIndex++; //increment to the next row
    
    //get each value
    for (int Ichan=0; Ichan < nchan; Ichan++) {
      if (isChannelActive(Ichan) && (Ichan < datatable.getColumnCount())) {
        val_uV = row.getFloat(Ichan);
      } else {
        //use zeros for the missing channels
        val_uV = 0.0f;
      }

      //put into data structure
      curDataPacket.values[Ichan] = (int) (0.5f+ val_uV / scale_fac_uVolts_per_count); //convert to counts, the 0.5 is to ensure rounding
    }
  }
  return currentTableRowIndex;
}

//toggleChannelState: : Ichan is [0 nchan-1]
void toggleChannelState(int Ichan) {
  if ((Ichan >= 0) && (Ichan < gui.chanButtons.length)) {
    if (isChannelActive(Ichan)) {
      deactivateChannel(Ichan);      
    } 
    else {
      activateChannel(Ichan);
    }
  }
}


//Ichan is zero referenced (not one referenced)
boolean isChannelActive(int Ichan) {
  boolean return_val = false;
  
  //account for 16 channel case...because the channel 9-16 (aka 8-15) are coupled to channels 1-8 (aka 0-7)
  if ((Ichan > 7) && (OpenBCI_Nchannels > 8)) Ichan = Ichan - 8;
    
  //now check the state of the corresponding channel button
  if ((Ichan >= 0) && (Ichan < gui.chanButtons.length)) {
    boolean button_is_pressed = gui.chanButtons[Ichan].isActive();
    if (button_is_pressed) { //button is pressed, which means the channel was NOT active
      return_val = false;
    } else { //button is not pressed, so channel is active
      return_val = true;
    }
  }
  return return_val;
}

//activateChannel: Ichan is [0 nchan-1] (aka zero referenced)
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

//void toggleDetectionState() {
//  gui.detectButton.setIsActive(!gui.detectButton.isActive());
//  showFFTFilteringData = gui.detectButton.isActive();
//  gui.showFFTFilteringData(showFFTFilteringData);
//}
//
//void toggleSpectrogramState() {
//  gui.spectrogramButton.setIsActive(!gui.spectrogramButton.isActive());
//  gui.setShowSpectrogram(gui.spectrogramButton.isActive());
//}


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
    if (openBCI != null) openBCI.changeImpedanceState(Ichan,newstate,code_P_N_Both);
    
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

void setBiasState(boolean state) {
  openBCI.isBiasAuto = state;
  
  //send message to openBCI
  if (openBCI != null) openBCI.setBiasAutoState(state);
  
  //change button text
  if (openBCI.isBiasAuto) {
    gui.biasButton.but_txt = "Bias\nAuto";
  } else {
    gui.biasButton.but_txt = "Bias\nFixed";
  }
  
}

void openNewLogFile() {
  //close the file if it's open
  if (fileoutput != null) {
    println("OpenBCI_GUI: closing log file");
    closeLogFile();
  }
  
  //open the new file
  fileoutput = new OutputFile_rawtxt(openBCI.fs_Hz);
  output_fname = fileoutput.fname;
  println("openBCI: openNewLogFile: opened output file: " + output_fname);
}

void closeLogFile() {
  if (fileoutput != null) fileoutput.closeFile();
}


void incrementFilterConfiguration() {
  eegProcessing.incrementFilterConfiguration();
  
  //update the button strings
//  gui.filtBPButton.but_txt = "BP Filt\n" + filtCoeff_bp[currentFilt_ind].short_name;
//  gui.titleMontage.string = "EEG Data (" + filtCoeff_bp[currentFilt_ind].name + ", " + filtCoeff_notch[currentFilt_ind].name + ")"; 
  gui.filtBPButton.but_txt = "BP Filt\n" + eegProcessing.getShortFilterDescription();
  gui.titleMontage.string = "EEG Data (" + eegProcessing.getFilterDescription() + ")"; 
  
}
  
void incrementSmoothing() {
  smoothFac_ind++;
  if (smoothFac_ind >= N_SMOOTHEFAC) smoothFac_ind = 0;
  
  //tell the GUI
  gui.setSmoothFac(smoothFac[smoothFac_ind]);
  
  //update the button
  gui.smoothingButton.but_txt = "Smooth\n" + smoothFac[smoothFac_ind];
}

void toggleShowPolarity() {
  gui.headPlot1.use_polarity = !gui.headPlot1.use_polarity;
  
  //update the button
  gui.showPolarityButton.but_txt = "Show Polarity\n" + gui.headPlot1.getUsePolarityTrueFalse();
}

void fileSelected(File selection) {  //called by the Open File dialog box after a file has been selected
  if (selection == null) {
    println("no selection so far...");
  } else {
    //inputFile = selection;
    playbackData_fname = selection.getAbsolutePath();
  }
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

