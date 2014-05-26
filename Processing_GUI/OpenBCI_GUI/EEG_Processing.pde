//import ddf.minim.analysis.*; //for FFT
class DetectedPeak { 
    int bin;
    float freq_Hz;
    float rms_uV_perBin;
    float background_rms_uV_perBin;
    float SNR_dB;
    boolean isDetected;
    
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
    }    
}
class EEG_Processing_User {
  private float fs_Hz;  //sample rate
  private int nchan;  
  
  //add your own variables here
  final float min_allowed_peak_freq_Hz = 4.0f; //input, for peak frequency detection
  final float max_allowed_peak_freq_Hz = 15.0f; //input, for peak frequency detection
  final float detection_thresh_dB = 8.0f; //how much bigger must the peak be relative to the background
  DetectedPeak[] detectedPeak;  //output per channel, from peak frequency detection
  boolean showDetectionOnGUI = true;

  //class constructor
  EEG_Processing_User(int NCHAN, float sample_rate_Hz) {
      nchan = NCHAN;
    fs_Hz = sample_rate_Hz;
    detectedPeak = new DetectedPeak[nchan];
    for (int Ichan=0;Ichan<nchan;Ichan++) {
      detectedPeak[Ichan]=new DetectedPeak();
    }
  }
  
  //here is the processing routine called by the OpenBCI main program...update this with whatever you'd like to do
  public void process(float[][] data_newest_uV, //holds raw EEG data that is new since the last call
        float[][] data_long_uV, //holds a longer piece of buffered EEG data, of same length as will be plotted on the screen
        float[][] data_forDisplay_uV, //this data has been filtered and is ready for plotting on the screen
        FFT[] fftData) {              //holds the FFT (frequency spectrum) of the latest data

      //user functions here...
      if (fftData != null) findPeakFrequency(fftData); //find the frequency for each channel with the peak amplitude
      
      //print some output
      //int Ichan=2-1;
      //println("EEG_Processing_User: Chan " + (Ichan+1) + ", peak = " + detectedPeak[Ichan].rms_uV_perBin + " uV at " 
      //  + detectedPeak[Ichan].freq_Hz + " Hz with background at = " + detectedPeak[Ichan].background_rms_uV_perBin);    
  
      //issue new command to the Hex Bug    
  }
 
   
  //add some functions here...if you'd like
  void findPeakFrequency(FFT[] fftData) {
    
    //loop over each EEG channel and find the frequency with the peak amplitude
    float FFT_freq_Hz, FFT_value_uV;
    for (int Ichan=0;Ichan < nchan; Ichan++) {
      
      //clear the data structure that will hold the peak for this channel
      detectedPeak[Ichan].clear();
      
      //loop over each frequency bin
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
                  
//          if ((Ichan == (7-1)) && (FFT_freq_Hz > 12.2f) && (FFT_freq_Hz <12.5f)) {
//            println("EEG_Processing_User: freq = " + FFT_freq_Hz + ", value = " + FFT_value_uV + ", cur Max = " 
//            + detectedPeak[Ichan].freq_Hz + " Hz " + detectedPeak[Ichan].rms_uV_perBin);
//          }
          
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
        detectedPeak[Ichan].isDetected = true;
      }
      
    } // end loop over channels    
  } //end method findPeakFrequency
  
  //routine to add detection graphics to the sceen
  void updateGUI_FFTPlot(Blank2DTrace.PlotRenderer pr) {
    //add detection-related graphics
    if (showDetectionOnGUI) {
      //add ellipse showing peak
      int Ichan = 2-1; //which channel to show on the GUI
      
      float new_x2 = pr.valToX(detectedPeak[Ichan].freq_Hz);
      float new_y2 = pr.valToY(detectedPeak[Ichan].rms_uV_perBin);
      int diam = 8;
      pr.canvas.strokeWeight(1);  //set the new line's linewidth
      if (detectedPeak[Ichan].isDetected) { //if there is a detection, make more prominent
        diam = 8;
        pr.canvas.strokeWeight(4);  //set the new line's linewidth 
      }
      ellipseMode(CENTER);
      pr.canvas.ellipse(new_x2,new_y2,diam,diam);
      
      //add horizontal lines indicating the detction threshold and guard level (use a dashed line)
      float x1, x2,y;
      x1 = pr.valToX(min_allowed_peak_freq_Hz);  //starting coordinate, left
      x2 = pr.valToX(max_allowed_peak_freq_Hz);  //start coordinate, right
      y = pr.valToY(detectedPeak[Ichan].background_rms_uV_perBin); //y-coordinate
       
      pr.canvas.strokeWeight(1.5);
      float dx = 8; //it'll be a dashed line, so here is how long is the dash+space, pixels
      float nudge = 2;
      float foo_x=min(x1+dx,x2); //start here
      while (foo_x < x2) {  //loop to make each dash
        pr.canvas.line(foo_x-dx+nudge,y,foo_x-(5*dx)/8+nudge,y);
        foo_x += dx;  //increment for next time through the loop
      }
    }  
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


  EEG_Processing(int NCHAN, float sample_rate_Hz) {
    nchan = NCHAN;
    fs_Hz = sample_rate_Hz;
    data_std_uV = new float[nchan];
    

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
    }
  }
}

