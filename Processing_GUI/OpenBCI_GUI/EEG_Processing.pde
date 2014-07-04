//import ddf.minim.analysis.*; //for FFT
class DetectedPeak { 
    int bin;
    float freq_Hz;
    float rms_uV_perBin;
    float background_rms_uV_perBin;
    float SNR_dB;
    boolean isDetected;
    float threshold_dB;
    
    DetectedPeak() {
      clear();
    }
    
    void clear() {
      bin=0;
      freq_Hz = 0.0f;
      rms_uV_perBin = 0.0f;
      background_rms_uV_perBin = 0.0f;
      SNR_dB = -100.0f;
      isDetected = false;
      threshold_dB = 0.0f;
    }
    
    void copyTo(DetectedPeak target) {
      target.bin = bin;
      target.freq_Hz = freq_Hz;
      target.rms_uV_perBin = rms_uV_perBin;
      target.background_rms_uV_perBin = background_rms_uV_perBin;
      target.SNR_dB = SNR_dB;
      target.isDetected = isDetected;
      target.threshold_dB = threshold_dB;
    }
}
class EEG_Processing_User {
  private float fs_Hz;  //sample rate
  private int nchan;  
  
  //add your own variables here
  final float min_allowed_peak_freq_Hz = 4.0f; //input, for peak frequency detection
  final float max_allowed_peak_freq_Hz = 15.0f; //input, for peak frequency detection
  final float detection_thresh_dB = 6.0f; //how much bigger must the peak be relative to the background
  final float[] processing_band_low_Hz = {4.0,  6.5,  9,  13.5}; //lower bound for each frequency band of interest (2D classifier only)
  final float[] processing_band_high_Hz = {6.5,  9,  12, 16.5};  //upper bound for each frequency band of interest
  DetectedPeak[] detectedPeak;  //output per channel, from peak frequency detection
  DetectedPeak[] peakPerBand;
  HexBug hexBug;
  boolean showDetectionOnGUI = true;
  public boolean useClassfier_2DTraining = true;  //use the fancier classifier?

  //class constructor
  EEG_Processing_User(){
  } //empty
  EEG_Processing_User(int NCHAN, float sample_rate_Hz, HexBug hBug) {
    nchan = NCHAN;
    fs_Hz = sample_rate_Hz;
    hexBug = hBug;
    detectedPeak = new DetectedPeak[nchan];
    for (int Ichan=0;Ichan<nchan;Ichan++) detectedPeak[Ichan]=new DetectedPeak();
    
    int nBands = processing_band_low_Hz.length;
    peakPerBand = new DetectedPeak[nBands];
    for (int Iband=0;Iband<nBands;Iband++) peakPerBand[Iband] = new DetectedPeak();
  }
  
  //here is the processing routine called by the OpenBCI main program...update this with whatever you'd like to do
  public void process(float[][] data_newest_uV, //holds raw EEG data that is new since the last call
        float[][] data_long_uV, //holds a longer piece of buffered EEG data, of same length as will be plotted on the screen
        float[][] data_forDisplay_uV, //this data has been filtered and is ready for plotting on the screen
        FFT[] fftData) {              //holds the FFT (frequency spectrum) of the latest data

      //user functions here...
      int Ichan = 2-1;  //which channel to act on
      if (fftData != null) findPeakFrequency(fftData,Ichan); //find the frequency for each channel with the peak amplitude
      if (useClassfier_2DTraining) {
        //new processing for improved selectivity
        if (fftData != null) findBestFrequency_2DTraining(fftData,Ichan);      
      }
      
      //issue new command to the Hex Bug, if there is a peak that was detected
      if (detectedPeak[Ichan].isDetected) {
        String txt = "";
        if (detectedPeak[Ichan].freq_Hz < processing_band_high_Hz[1-1]) {
          hexBug.right();txt = "Right";
        } else if (detectedPeak[Ichan].freq_Hz < processing_band_high_Hz[2-1]) {
          hexBug.left();txt = "Left";
        } else if (detectedPeak[Ichan].freq_Hz < processing_band_high_Hz[3-1]) {
          hexBug.forward(); txt = "Forward";
        } else if (detectedPeak[Ichan].freq_Hz < processing_band_high_Hz[4-1]) {
          //the other way to get a LEFT command! 
          hexBug.left();txt = "Left";
        }

        //print some output
        println("EEG_Processing_User: " + txt + "!, Chan " + (Ichan+1) + ", peak = " + detectedPeak[Ichan].rms_uV_perBin + " uV at " 
            + detectedPeak[Ichan].freq_Hz + " Hz with background at = " + detectedPeak[Ichan].background_rms_uV_perBin 
            + ", SNR (dB) = " + detectedPeak[Ichan].SNR_dB);        
        
      }
  }
 
   
  //add some functions here...if you'd like
  void findPeakFrequency(FFT[] fftData,int Ichan) {
    
    //loop over each EEG channel and find the frequency with the peak amplitude
    float FFT_freq_Hz, FFT_value_uV;
    //for (int Ichan=0;Ichan < nchan; Ichan++) {
      
      //clear the data structure that will hold the peak for this channel
      detectedPeak[Ichan].clear();
      
      //loop over each frequency bin to find the one with the strongest peak
      int nBins =  fftData[Ichan].specSize();
      for (int Ibin=0; Ibin < nBins; Ibin++){
        FFT_freq_Hz = fftData[Ichan].indexToFreq(Ibin); //here is the frequency of htis bin
        
        //is this bin within the frequency band of interest?
        if ((FFT_freq_Hz >= min_allowed_peak_freq_Hz) && (FFT_freq_Hz <= max_allowed_peak_freq_Hz)) {
          //we are within the frequency band of interest
          
          //get the RMS voltage (per bin)
          FFT_value_uV = fftData[Ichan].getBand(Ibin) / ((float)nBins); 
           
          //decide if this is the maximum, compared to previous bins for this channel
          if (FFT_value_uV > detectedPeak[Ichan].rms_uV_perBin) {
            //this is bigger, so hold onto this value as the new "maximum"
            detectedPeak[Ichan].bin  = Ibin;
            detectedPeak[Ichan].freq_Hz = FFT_freq_Hz;
            detectedPeak[Ichan].rms_uV_perBin = FFT_value_uV;
          } 
          
        } //close if within frequency band
        
        
      } //close loop over bins
   
      //loop over the bins again (within the sense band) to get the average background power, excluding the bins on either side of the peak
      float sum_pow=0.0;
      int count=0;
      for (int Ibin=0; Ibin < nBins; Ibin++){
        FFT_freq_Hz = fftData[Ichan].indexToFreq(Ibin);
        if ((FFT_freq_Hz >= min_allowed_peak_freq_Hz) && (FFT_freq_Hz <= max_allowed_peak_freq_Hz)) {
          if ((Ibin < detectedPeak[Ichan].bin - 1) || (Ibin > detectedPeak[Ichan].bin + 1)) {
            FFT_value_uV = fftData[Ichan].getBand(Ibin) / ((float)nBins);  //get the RMS per bin
            sum_pow+=pow(FFT_value_uV,2.0f);
            count++;
          }
        }
      }
      //compute mean
      detectedPeak[Ichan].background_rms_uV_perBin = sqrt(sum_pow / count);
      
      //decide if peak is big enough to be detected
      detectedPeak[Ichan].SNR_dB = 20.0f*(float)java.lang.Math.log10(detectedPeak[Ichan].rms_uV_perBin / detectedPeak[Ichan].background_rms_uV_perBin);
      if (detectedPeak[Ichan].SNR_dB >= detection_thresh_dB) {
        detectedPeak[Ichan].threshold_dB = detection_thresh_dB;
        detectedPeak[Ichan].isDetected = true;
      }
      
    //} // end loop over channels    
  } //end method findPeakFrequency
  
  
  void findBestFrequency_2DTraining(FFT[] fftData,int Ichan) {
    
    //loop over each EEG channel
    float FFT_freq_Hz, FFT_value_uV;
    //for (int Ichan=0;Ichan < nchan; Ichan++) {
      int nBins =  fftData[Ichan].specSize();
      
      //loop over all bins and comptue SNR for each bin
      float[] SNR_dB = new float[nBins];
      float noise_pow_uV = detectedPeak[Ichan].background_rms_uV_perBin;
      for (int Ibin=0; Ibin < nBins; Ibin++) {
        FFT_value_uV = fftData[Ichan].getBand(Ibin) / ((float)nBins);  //get the RMS per bin
        SNR_dB[Ibin] = 20.0f*(float)java.lang.Math.log10(FFT_value_uV / noise_pow_uV);
      }
        
      //find peak SNR in each freq band
      float this_SNR_dB=0.0;
      int nBands=peakPerBand.length;
      for (int Iband=0; Iband<nBands; Iband++) {
        //peakPerBand[Iband] = new DetectedPeak();
        //init variables for this frequency band
        peakPerBand[Iband].clear();
        peakPerBand[Iband].SNR_dB = -100.0;
        peakPerBand[Iband].background_rms_uV_perBin = detectedPeak[Ichan].background_rms_uV_perBin;

        //loop over all bins
        for (int Ibin=0; Ibin < nBins; Ibin++) {
          FFT_freq_Hz = fftData[Ichan].indexToFreq(Ibin); //here is the frequency of this bin
          if (FFT_freq_Hz >= processing_band_low_Hz[Iband]) {
            if (FFT_freq_Hz <= processing_band_high_Hz[Iband]) {
              if (SNR_dB[Ibin] > peakPerBand[Iband].SNR_dB) {
                peakPerBand[Iband].bin = Ibin;
                peakPerBand[Iband].freq_Hz = FFT_freq_Hz;
                peakPerBand[Iband].rms_uV_perBin = fftData[Ichan].getBand(Ibin) / ((float)nBins);
                peakPerBand[Iband].SNR_dB = SNR_dB[Ibin];
              }  
            }
          }
        } //end loop over bins    
      } //end loop over frequency bands
    
      //apply new 2D detection rules
      applyDetectionRules_2D(peakPerBand, detectedPeak[Ichan]);
    
    //} // end loop over channels
  }
  
  void applyDetectionRules_2D(DetectedPeak[] peakPerBand, DetectedPeak detectedPeak) {
    int band_A = 0, band_B = 1, band_C = 2, band_D = 3;
    int nRules = 3;
    float[] value_from_each_rule = new float[nRules];
    float primary_value_dB=0.0, secondary_value_dB=0.0;
    int nDetect = 0;
    
    //allocate the per-rule variables
    DetectedPeak[] candidate_detection = new DetectedPeak[nRules];  //one for each rule
    for (int Irule=0; Irule < nRules; Irule++) {
      candidate_detection[Irule] = new DetectedPeak();
    }

    //check rule 1 applying to RIGHT command...here, we care about Band A and Band C
    primary_value_dB = peakPerBand[band_A].SNR_dB;
    peakPerBand[band_A].copyTo(candidate_detection[0]);
    peakPerBand[band_A].threshold_dB = detection_thresh_dB;
    if (primary_value_dB >= detection_thresh_dB) {
      secondary_value_dB = peakPerBand[band_C].SNR_dB;
      float secondary_threshold_dB = 3.0f; 
      if (secondary_value_dB >= secondary_threshold_dB) {
        //detected!
        nDetect++;
        value_from_each_rule[0] = primary_value_dB;
        peakPerBand[band_A].isDetected=true;
        candidate_detection[0].isDetected=true;
        //println("applyDetectionRules_2D: rule 0: nDetect = " + nDetect + ", value_from_each_rule[0] = " + value_from_each_rule[0]); 
      } else {
        //failed. for plotting purposes, adjust the apparent threshold
        peakPerBand[band_A].threshold_dB = primary_value_dB + (secondary_threshold_dB - secondary_value_dB);
      }
    }   
    
    //check rule 2 applying to LEFT command...here, we care about Band B and Band D
    primary_value_dB = peakPerBand[band_B].SNR_dB;
    secondary_value_dB = peakPerBand[band_D].SNR_dB;
    peakPerBand[band_B].threshold_dB = detection_thresh_dB;
    peakPerBand[band_D].threshold_dB = 4.5 * sqrt(abs(1.1 - pow(primary_value_dB/detection_thresh_dB,2.0)));
    if (primary_value_dB >= peakPerBand[band_B].threshold_dB) {
      //for larger SNR values
      if (secondary_value_dB >= 0.0f) {
        //detected!
        nDetect++;
        value_from_each_rule[1] = primary_value_dB;
        peakPerBand[band_B].copyTo(candidate_detection[1]);
        peakPerBand[band_B].isDetected =true;
        candidate_detection[1].isDetected=true;
        //println("applyDetectionRules_2D: rule 1A: nDetect = " + nDetect + ", value_from_each_rule[1] = " + value_from_each_rule[1]); 
      } 
    } else if (primary_value_dB >= 0.0f) {
      //for smaller SNR values
      float second_threshold_dB = peakPerBand[band_D].threshold_dB;
      if (secondary_value_dB >= second_threshold_dB) {
        //detected!
        nDetect++;
        value_from_each_rule[1] = secondary_value_dB;  //create something that is comparable to the other metrics, which are based on detection_thresh_dB
        peakPerBand[band_D].copyTo(candidate_detection[1]);
        peakPerBand[band_D].isDetected=true;
        candidate_detection[1].isDetected=true;
        //println("applyDetectionRules_2D: rule 1B: nDetect = " + nDetect + ", value_from_each_rule[1] = " + value_from_each_rule[1]); 
      }
    }

    //check rule 3 applying to FORWARD command...here, we care about Band B and Band D    
    primary_value_dB = peakPerBand[band_C].SNR_dB;
    peakPerBand[band_C].copyTo(candidate_detection[2]);
    peakPerBand[band_C].threshold_dB = 3.0;
    secondary_value_dB = peakPerBand[band_D].SNR_dB;
    final float slope = (7.5-(-3))/(12-4);
    final float yoffset = 7.5 - slope*12;
    float second_threshold_dB = slope * primary_value_dB + yoffset;
    if (primary_value_dB >= peakPerBand[band_C].threshold_dB) {
      if (secondary_value_dB <= second_threshold_dB) {  //must be below!  Alpha waves (Band C) should quiet the higher bands (Band D)
        //detected!
        nDetect++;
        value_from_each_rule[2] = primary_value_dB;
        peakPerBand[band_C].isDetected=true;
        candidate_detection[2].isDetected=true;
        //println("applyDetectionRules_2D: rule 2: nDetect = " + nDetect + ", value_from_each_rule[2] = " + value_from_each_rule[2]); 
      }
    }    
    peakPerBand[band_C].threshold_dB = max(peakPerBand[band_C].threshold_dB,(secondary_value_dB - yoffset) / slope); //for plotting purposes
    
    
    //clear previous detection
    detectedPeak.isDetected=false;
    
    //see if we've had a detection
    if (nDetect > 0) {
      
      //find the best value (ie, find the maximum "value_from_each_rule" across all rules)
      int rule_ind = findMax(value_from_each_rule);
      //float peak_value = value_from_each_rule[rule_ind];
      
      //copy over the detection data for that rule/band
      candidate_detection[rule_ind].copyTo(detectedPeak);
      //println("applyDetectionRules_2D: detected, rule_ind = " + rule_ind + ", freq = " + detectedPeak.freq_Hz + " Hz, SNR = " + detectedPeak.SNR_dB + " dB");
    } 
  } // end of applyDetectionRules_2D
  
  
  //routine to add detection graphics to the sceen
  void updateGUI_FFTPlot(Blank2DTrace.PlotRenderer pr) {
    float x1,y1,x2,y2;
    boolean is_detected;
    
    //add detection-related graphics
    if (showDetectionOnGUI) {
      
      //add vertical markers showing detection bands
      int nBands = processing_band_low_Hz.length;
      String[] band_txt = {"Right", "Left", "Forward", "Left"};
      for (int Iband=0; Iband<nBands; Iband++) {
        x1 = pr.valToX(processing_band_low_Hz[Iband]); //lower bound for each frequency band of interest (2D classifier only)
        y1 = pr.valToY(0.15f);
        y2 = pr.valToY(50.0f);
        addVertDashedLine(pr,x1,y1,y2,0);
        
        x1 = pr.valToX(processing_band_high_Hz[Iband]); //lower bound for each frequency band of interest (2D classifier only)
        addVertDashedLine(pr,x1,y1,y2,1);
        
        //add label
        x1 = pr.valToX(0.5*(processing_band_low_Hz[Iband]+processing_band_high_Hz[Iband]));
        y1 = pr.valToY(60.0f);
        pr.canvas.pushMatrix(); //hold on to the current canvas state
        pr.canvas.fill(0,0,0); //black
        pr.canvas.scale(1,-1); //modify the canvas up-down scale so as to flip the text (it's normally upside-down for some reason)
        pr.canvas.textAlign(CENTER,TOP);
        pr.canvas.text(band_txt[Iband],(int)x1,-(int)y1);
        pr.canvas.popMatrix();//return to the original canvas state
      }
   
      //add horizontal lines indicating the background noise level
      int Ichan = 2-1; //which channel to show on the GUI
      x1 = pr.valToX(min_allowed_peak_freq_Hz);  //starting coordinate, left
      x2 = pr.valToX(max_allowed_peak_freq_Hz);  //start coordinate, right
      y1 = pr.valToY(detectedPeak[Ichan].background_rms_uV_perBin); //y-coordinate
      addHorizDashedLine(pr,x1,x2,y1,0);
       
      if (useClassfier_2DTraining) {
        //add symbols showing per-band peaks      
        for (int Iband=0; Iband<peakPerBand.length; Iband++) {
          //add required threshold level
          x1 = pr.valToX(processing_band_low_Hz[Iband]);
          x2 = pr.valToX(processing_band_high_Hz[Iband]);
          float thresh_dB = peakPerBand[Iband].threshold_dB;
          float val_uV_perBin = detectedPeak[Ichan].background_rms_uV_perBin * sqrt(pow(10.0,thresh_dB/10.0));
          y1 = pr.valToY(val_uV_perBin); //y-coordinate
          addHorizDashedLine(pr,x1,x2,y1,1);
          
          //add peak
          x1 = pr.valToX(peakPerBand[Iband].freq_Hz);
          y1 = pr.valToY(peakPerBand[Iband].rms_uV_perBin);
          is_detected = peakPerBand[Iband].isDetected;
          addMarker(pr,x1,y1,is_detected); 
        }
      } else {  
        //add symbol showing overall peak
        x1 = pr.valToX(detectedPeak[Ichan].freq_Hz);
        y1 = pr.valToY(detectedPeak[Ichan].rms_uV_perBin);
        is_detected = detectedPeak[Ichan].isDetected;
        addMarker(pr,x1,y1,is_detected); 
      }
    }  
  }
   
  //draw a marker on the axes
  void addMarker(Blank2DTrace.PlotRenderer pr, float new_x2,float new_y2,boolean is_detected) {
    int diam = 8;
    pr.canvas.pushMatrix(); //hold on to the current canvas state
    pr.canvas.stroke(0);  //black
    pr.canvas.fill(255); //white
    pr.canvas.strokeWeight(1);  //set the new line's linewidth
    if (is_detected) { //if there is a detection, make more prominent
      pr.canvas.strokeWeight(4);  //set the new line's linewidth 
    }
    ellipseMode(CENTER);
    pr.canvas.ellipse(new_x2,new_y2,diam,diam);
    pr.canvas.popMatrix(); //hold on to the current canvas state
  }
  
  //draw a horizontal dashed line on the given axes
  void addHorizDashedLine(Blank2DTrace.PlotRenderer pr,float x1,float x2,float y,int style) {
    pr.canvas.pushMatrix(); //hold on to the current canvas state
    pr.canvas.stroke(0,0,0);  //black
    float dx; //it'll be a dashed line, so here is how long is the dash+space, pixels
    if (style==1) {
      dx = 4;
      pr.canvas.strokeWeight(1.0);
    } else {
      dx = 8;
      pr.canvas.strokeWeight(1.5);
    }
    float nudge = 2;
    float foo_x=min(x1+dx,x2); //start here
    while (foo_x < x2) {  //loop to make each dash
      pr.canvas.line(foo_x-dx+nudge,y,foo_x-(5*dx)/8+nudge,y);
      foo_x += dx;  //increment for next time through the loop
    }
    pr.canvas.popMatrix(); //hold on to the current canvas state
  }
  
  //draw a dashed line on the given axes
  void addVertDashedLine(Blank2DTrace.PlotRenderer pr,float x1,float y1,float y2,int colorCode) {
    pr.canvas.pushMatrix(); //hold on to the current canvas state
    //println("EEG_processing: addVertDashedLine: x1, y1, y2: " + x1 + " " + y1 + " " + y2);
    if (colorCode==0) {
        //pr.canvas.stroke(0,190,0);  //dark green
        pr.canvas.stroke(0);  //black
    } else {
        //pr.canvas.stroke(190,0,0);  //dark red
       pr.canvas.stroke(0);  //black
    }
    pr.canvas.strokeWeight(1.0);
    float dy = 4; //it'll be a dashed line, so here is how long is the dash+space, pixels
    float nudge = 2; //correction factor?
    float foo_y=min(y1+dy,y2); //start here
    while (foo_y < y2) {  //loop to make each dash
      float yy1 = foo_y-dy+nudge;
      float yy2 = foo_y-(5*dy)/8+nudge;
      //println("EEG_processing: addVertDashedLine: dash: x1 = " + x1 + ", y = [" + yy1 + " " + yy2 + "]");
      pr.canvas.line(x1,yy1,x1,yy2);
      foo_y += dy;  //increment for next time through the loop
    }
    pr.canvas.popMatrix(); //hold on to the current canvas state
  }
   
} // close class EEG_Process_User
   


class EEG_Processing {
  private float fs_Hz;  //sample rate
  private int nchan;
  final int N_FILT_CONFIGS = 5;
  FilterConstants[] filtCoeff_bp = new FilterConstants[N_FILT_CONFIGS];
  FilterConstants[] filtCoeff_notch = new FilterConstants[N_FILT_CONFIGS];
  private int currentFilt_ind = 0;
  float data_std_uV[];
  float polarity[];


  EEG_Processing(int NCHAN, float sample_rate_Hz) {
    nchan = NCHAN;
    fs_Hz = sample_rate_Hz;
    data_std_uV = new float[nchan];
    polarity = new float[nchan];
    

    //check to make sure the sample rate is acceptable and then define the filters
    if (abs(fs_Hz-250.0f) < 1.0) {
      defineFilters();
    } 
    else {
      println("EEG_Processing: *** ERROR *** Filters can currently only work at 250 Hz");
      defineFilters();  //define the filters anyway just so that the code doesn't bomb
    }
  }
  public float getSampleRateHz() { 
    return fs_Hz;
  };

  //define filters...assumes sample rate of 250 Hz !!!!!
  private void defineFilters() {
    int n_filt = filtCoeff_bp.length;
    double[] b, a, b2, a2;
    String filt_txt, filt_txt2;
    String short_txt, short_txt2; 

    //loop over all of the pre-defined filter types
    for (int Ifilt=0;Ifilt<n_filt;Ifilt++) {

      //define common notch filter
      b2 = new double[] { 
        9.650809863447347e-001, -2.424683201757643e-001, 1.945391494128786e+000, -2.424683201757643e-001, 9.650809863447347e-001
      };
      a2 = new double[] {    
        1.000000000000000e+000, -2.467782611297853e-001, 1.944171784691352e+000, -2.381583792217435e-001, 9.313816821269039e-001
      }; 
      filtCoeff_notch[Ifilt] =  new FilterConstants(b2, a2, "Notch 60Hz", "60Hz");

      //define bandpass filter
      switch (Ifilt) {
      case 0:
        //butter(2,[1 50]/(250/2));  %bandpass filter
        b = new double[] { 
          2.001387256580675e-001, 0.0f, -4.002774513161350e-001, 0.0f, 2.001387256580675e-001
        };
        a = new double[] { 
          1.0f, -2.355934631131582e+000, 1.941257088655214e+000, -7.847063755334187e-001, 1.999076052968340e-001
        };
        filt_txt = "Bandpass 1-50Hz";
        short_txt = "1-50 Hz";
        break;
      case 1:
        //butter(2,[7 13]/(250/2));
        b = new double[] {  
          5.129268366104263e-003, 0.0f, -1.025853673220853e-002, 0.0f, 5.129268366104263e-003
        };
        a = new double[] { 
          1.0f, -3.678895469764040e+000, 5.179700413522124e+000, -3.305801890016702e+000, 8.079495914209149e-001
        };
        filt_txt = "Bandpass 7-13Hz";
        short_txt = "7-13 Hz";
        break;      
      case 2:
        //[b,a]=butter(2,[15 50]/(250/2)); %matlab command
        b = new double[] { 
          1.173510367246093e-001, 0.0f, -2.347020734492186e-001, 0.0f, 1.173510367246093e-001
        };
        a = new double[] { 
          1.0f, -2.137430180172061e+000, 2.038578008108517e+000, -1.070144399200925e+000, 2.946365275879138e-001
        };
        filt_txt = "Bandpass 15-50Hz";
        short_txt = "15-50 Hz";  
        break;    
      case 3:
        //[b,a]=butter(2,[5 50]/(250/2)); %matlab command
        b = new double[] {  
          1.750876436721012e-001, 0.0f, -3.501752873442023e-001, 0.0f, 1.750876436721012e-001
        };       
        a = new double[] { 
          1.0f, -2.299055356038497e+000, 1.967497759984450e+000, -8.748055564494800e-001, 2.196539839136946e-001
        };
        filt_txt = "Bandpass 5-50Hz";
        short_txt = "5-50 Hz";
        break;      
      default:
        //no filtering
        b = new double[] {
          1.0
        };
        a = new double[] {
          1.0
        };
        filt_txt = "No BP Filter";
        short_txt = "No Filter";
        b2 = new double[] {
          1.0
        };
        a2 = new double[] {
          1.0
        };
        filtCoeff_notch[Ifilt] =  new FilterConstants(b2, a2, "No Notch", "No Notch");
      }  //end switch block  

      //create the bandpass filter    
      filtCoeff_bp[Ifilt] =  new FilterConstants(b, a, filt_txt, short_txt);
    } //end loop over filters
  } //end defineFilters method 

  public String getFilterDescription() {
    return filtCoeff_bp[currentFilt_ind].name + ", " + filtCoeff_notch[currentFilt_ind].name;
  }
  public String getShortFilterDescription() {
    return filtCoeff_bp[currentFilt_ind].short_name;   
  }
  
  public void incrementFilterConfiguration() {
    //increment the index
    currentFilt_ind++;
    if (currentFilt_ind >= N_FILT_CONFIGS) currentFilt_ind = 0;
  }

  public void process(float[][] data_newest_uV, //holds raw EEG data that is new since the last call
        float[][] data_long_uV, //holds a longer piece of buffered EEG data, of same length as will be plotted on the screen
        float[][] data_forDisplay_uV, //put data here that should be plotted on the screen
        FFT[] fftData) {              //holds the FFT (frequency spectrum) of the latest data

    //loop over each EEG channel
    for (int Ichan=0;Ichan < nchan; Ichan++) {  

      //filter the data in the time domain
      filterIIR(filtCoeff_notch[currentFilt_ind].b, filtCoeff_notch[currentFilt_ind].a, data_forDisplay_uV[Ichan]); //notch
      filterIIR(filtCoeff_bp[currentFilt_ind].b, filtCoeff_bp[currentFilt_ind].a, data_forDisplay_uV[Ichan]); //bandpass

      //compute the standard deviation of the filtered signal...this is for the head plot
      float[] fooData_filt = dataBuffY_filtY_uV[Ichan];  //use the filtered data
      fooData_filt = Arrays.copyOfRange(fooData_filt, fooData_filt.length-((int)fs_Hz), fooData_filt.length);   //just grab the most recent second of data
      data_std_uV[Ichan]=std(fooData_filt); //compute the standard deviation for the whole array "fooData_filt"
     
    } //close loop over channels
    
    //find strongest channel
    int refChanInd = findMax(data_std_uV);
    //println("EEG_Processing: strongest chan (one referenced) = " + (refChanInd+1));
    float[] refData_uV = dataBuffY_filtY_uV[refChanInd];  //use the filtered data
    refData_uV = Arrays.copyOfRange(refData_uV, refData_uV.length-((int)fs_Hz), refData_uV.length);   //just grab the most recent second of data
      
    
    //compute polarity of each channel
    for (int Ichan=0; Ichan < nchan; Ichan++) {
      float[] fooData_filt = dataBuffY_filtY_uV[Ichan];  //use the filtered data
      fooData_filt = Arrays.copyOfRange(fooData_filt, fooData_filt.length-((int)fs_Hz), fooData_filt.length);   //just grab the most recent second of data
      float dotProd = calcDotProduct(fooData_filt,refData_uV);
      if (dotProd >= 0.0f) {
        polarity[Ichan]=1.0;
      } else {
        polarity[Ichan]=-1.0;
      }
      
    }    
  }
}

