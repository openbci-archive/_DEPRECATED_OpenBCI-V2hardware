import ddf.minim.spi.*;
import ddf.minim.signals.*;
import ddf.minim.*;
import ddf.minim.analysis.*;
import ddf.minim.ugens.*;
import ddf.minim.effects.*;


//for writing to WAV
import javax.sound.sampled.*;
import java.io.*;

//define a new type
//enum IOState {READING, WRITING, CLOSED};

String [] myInputFileContents ;
String myFilePath;

float eeg_scale_fac_uV = 500.0f;
float aux_scale_fac = 1.0f;

Table_CSV data; 
float fs_Hz = 250.0f;  //assumed sample rate
Minim minim;
void setup() {

  // always start Minim before you do anything with it
  minim = new Minim(this);

  // select input file
  selectInput("Select a file : ", "fileSelected");
  while (myFilePath == null) {//wait
  }

  // load the data
  println("setup: loading playback data from " + myFilePath);
  try {
    data = new Table_CSV(myFilePath);
  } 
  catch (Exception e) {
    println("setup: could not open file for playback: " + myFilePath);
    println("   : quitting...");
    exit();
  }
  println("setup: loading complete.  " + data.getRowCount() + " rows of data, which is " + round(float(data.getRowCount())/fs_Hz) + " seconds of EEG data");

  //removing first column of data from data file...the first column is a time index and not eeg data
  data.removeColumn(0);

  // process the data...remove mean via High Pass filtering
  float learn_fac = 1.0/(fs_Hz);
  int ncol = data.getColumnCount();
  int nrow = data.getRowCount();
  float[] running_ave = new float[ncol];
  for (int Irow=0; Irow < nrow; Irow++) {
    for (int Icol=0; Icol < ncol; Icol++) {
      running_ave[Icol]=(1.0f-learn_fac)*running_ave[Icol]+learn_fac*data.getFloat(Irow,Icol);
      data.setFloat(Irow,Icol,data.getFloat(Irow,Icol) - running_ave[Icol]);
    }
  }
  
  // write the data
  writeWAV(data);
}

void draw() {
  //
  delay(1000);
  println("Finished.  Quitting...");
  exit();
}

void fileSelected(File selection) {
  if (selection == null) {
    println("no selection so far...");
  } 
  else {

    myFilePath         = selection.getAbsolutePath();
    //myInputFileContents = loadStrings(myFilePath) ;// this moves here...
    println("User selected " + myFilePath);
  }
}


//use example at http://code.compartmental.net/minim/examples/Minim/createSample/createSample.pde
void writeWAV(Table data) {
  int ncol = data.getColumnCount();
  int nrow = data.getRowCount();
  float fsample;
  
  int nwrite = 10000;
  int[] samples = new int[nwrite];

  try
  {
    int sampleRate = ((int)(fs_Hz));    // Samples per second
    //double duration = 5.0;    // Seconds

    // Calculate the number of frames required for specified duration
    //long numFrames = (long)(duration * sampleRate);
    long numFrames = nrow;

    // Create a wav file with the name specified as the first argument
    WavFile wavFile = WavFile.newWavFile(new File(sketchPath("") + "out.wav"), 1, numFrames, 16, sampleRate);
    
    wavFile.display();
  
  
    //send it the samples
    println("writing " + nrow + " samples?  samples = " + samples);
    long counter=0;
    while (counter < numFrames) {
        nwrite = min(nwrite,(int)(numFrames - counter));
        
        //copy data out of table and into sample buffer
        int Icol=0;  //count from zero
        for (int Isamp=0; Isamp<nwrite; Isamp++) {
          fsample=data.getFloat(((int)counter+Isamp),Icol)/eeg_scale_fac_uV;
          fsample=max(min(fsample, 1.0), -1.0);  //limit the signal
          samples[Isamp] = ((int)(32768.0f*fsample));
        }
        println("counter = " + counter + ", nwrite = " + nwrite);
        counter += nwrite;
        wavFile.writeFrames(samples,nwrite);
    }

    // Close the wavFile
    wavFile.display();
    wavFile.close();
    println("closing file...");
  }
  catch (Exception e)
  {
    println("Exception...");
    println(e);
  }
}

