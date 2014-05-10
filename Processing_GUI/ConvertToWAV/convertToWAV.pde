/*
Name: convertToWAV
Created: Chip Audette, April-May 2014
Purpose: Read in OpenBCI log files and export them as WAV files
License: MIT License   http://opensource.org/licenses/MIT
*/

float eeg_scale_fac_uV = 500.0f;  //choose this to be what you'd like. It needs to be big enough so that the output values are small enough not to get clipped when written to the WAV.
float aux_scale_fac = 1.0f;  //this is applied instead of the scale factor above to all columns in excess of either 8 or 16 

float fs_Hz = 250.0f;  //assumed sample rate for the EEG data being read in from the file
String [] myInputFileContents ;
File inputFile;
String inputFile_str;
String outputPname_str;
Table_CSV data; 
PFont f;
void setup() {

  // select input file
  selectInput("Select an OpenBCI TXT file: ", "fileSelected");
  while (inputFile_str == null) {//wait
  }

  // load the data
  println("setup: loading playback data from " + inputFile_str);
  try {
    data = new Table_CSV(inputFile.getAbsolutePath());
  } 
  catch (Exception e) {
    println("setup: could not open file for reading: " + inputFile_str);
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
      running_ave[Icol]=(1.0f-learn_fac)*running_ave[Icol]+learn_fac*data.getFloat(Irow, Icol);
      data.setFloat(Irow, Icol, data.getFloat(Irow, Icol) - running_ave[Icol]);
    }
  }

  // write the data
  writeWAV(data);
}

void draw() {
  delay(1000);
  println("The WAV files were written to: " + outputPname_str);
  println("Finished.");
  exit();
}

void fileSelected(File selection) {
  if (selection == null) {
    println("no selection so far...");
  } else {
    inputFile = selection;
    inputFile_str = selection.getAbsolutePath();
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

    // Create a directory for the WAVs
    outputPname_str= inputFile.getParent() + "\\WAVs\\";
    File output_pname = new File(outputPname_str);
    println("creating dir: " + output_pname.toString());
    if (!output_pname.exists()) {
      if (!output_pname.mkdir()) {
        println("Error: could not create " + output_pname.toString());
        output_pname = new File (inputFile.getPath());
      }
    }

    //loop over each data channel and write
    for (int Ichan=0; Ichan<ncol;Ichan++) {
      String output_fname = inputFile.getName();
      output_fname = output_fname.substring(0, output_fname.length()-4) + "_chan";
      if (Ichan < 10) output_fname += "0";
      output_fname += (Ichan+1); //so that filename starts at "Chan01" instead of "Chan00"
      output_fname += ".wav";
      println("output_fname = " + output_fname);
      //WavFile wavFile = WavFile.newWavFile(new File(sketchPath("") + "out.wav"), 1, numFrames, 16, sampleRate);
      WavFile wavFile = WavFile.newWavFile(new File(output_pname.toString() + "\\" + output_fname), 1, numFrames, 16, sampleRate);

      //wavFile.display();


      //send it the samples
      //if (Ichan==0) println("writing " + nrow + " samples = " + samples);
      long counter=0;
      while (counter < numFrames) {
        nwrite = min(nwrite, (int)(numFrames - counter));

        //copy data out of table and into sample buffer
        //int Icol=0;  //count from zero
        for (int Isamp=0; Isamp<nwrite; Isamp++) {
          fsample=data.getFloat(((int)counter+Isamp), Ichan)/eeg_scale_fac_uV;
          fsample=max(min(fsample, 1.0), -1.0);  //limit the signal
          samples[Isamp] = ((int)(32768.0f*fsample));
        }
        //println("counter = " + counter + ", nwrite = " + nwrite);
        counter += nwrite;
        wavFile.writeFrames(samples, nwrite);
      }

      // Close the wavFile
      //wavFile.display();
      wavFile.close();
      //println("closing file...");
    }
  }

  catch (Exception e)
  {
    println("Exception...");
    println(e);
  }
}

