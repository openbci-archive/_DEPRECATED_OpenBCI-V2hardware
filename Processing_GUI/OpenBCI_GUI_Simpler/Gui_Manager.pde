
////////////////////////////////////////////////////
//
// This class creates and manages all of the graphical user interface (GUI) elements
// for the primary display.
//
// Created: Chip Audette, November 2013.
//
// Requires the plotting library from gwoptics.  Built on gwoptics 0.5.0
// http://www.gwoptics.org/processing/gwoptics_p5lib/
//
///////////////////////////////////////////////////


import processing.core.PApplet;
import org.gwoptics.graphics.*;
import org.gwoptics.graphics.graph2D.*;
import org.gwoptics.graphics.graph2D.Graph2D;
import org.gwoptics.graphics.graph2D.LabelPos;
import org.gwoptics.graphics.graph2D.traces.Blank2DTrace;
import org.gwoptics.graphics.graph2D.backgrounds.*;
import ddf.minim.analysis.*; //for FFT
import java.util.*; //for Array.copyOfRange() 
import ddf.minim.*;  // To make sound.  Following minim example "frequencyModulation"
import ddf.minim.ugens.*;  // To make sound.  Following minim example "frequencyModulation"

class Gui_Manager {
  ScatterTrace montageTrace;
  ScatterTrace_FFT fftTrace;
  Graph2D gMontage, gFFT, gSpectrogram;
  GridBackground gbMontage, gbFFT;
  Button stopButton;
  Button detectButton;
  Button spectrogramButton;
  PlotFontInfo fontInfo;
  //headPlot headPlot1;
  Button[] chanButtons;
  Button guiPageButton;
  //boolean showImpedanceButtons;
  Button[] impedanceButtonsP;
  Button[] impedanceButtonsN;
  Button biasButton;
  Button intensityFactorButton;
  Button loglinPlotButton;
  Button filtBPButton;
  Button fftNButton;
  Button smoothingButton;
  Button maxDisplayFreqButton;
  TextBox titleMontage, titleFFT,titleSpectrogram;
  TextBox[] chanValuesMontage;
  TextBox[] impValuesMontage;
  boolean showMontageValues;
  public int guiPage;
  boolean vertScaleAsLog = true;
  Spectrogram spectrogram;
  boolean showSpectrogram;
  int whichChannelForSpectrogram;
  
  private float fftYOffset[];
  private float default_vertScale_uV=200.0; //this defines the Y-scale on the montage plots...this is the vertical space between traces
  private float[] vertScaleFactor = {1.0f, 2.0f, 5.0f, 50.0f, 0.25f, 0.5f};
  private int vertScaleFactor_ind = 0;
  float vertScale_uV=default_vertScale_uV;
  float vertScaleMin_uV_whenLog = 0.1f;
  float montage_yoffsets[];
  private float[] maxDisplayFreq_Hz = {20.0f, 40.0f, 60.0f, 120.0f};
  private int maxDisplayFreq_ind = 2;
  
  public final static int GUI_PAGE_CHANNEL_ONOFF = 0;
  public final static int GUI_PAGE_IMPEDANCE_CHECK = 1;
  public final static int GUI_PAGE_HEADPLOT_SETUP = 2;
  public final static int N_GUI_PAGES = 3;
  
  public final static String stopButton_pressToStop_txt = "Press to Stop";
  public final static String stopButton_pressToStart_txt = "Press to Start";
  
  Gui_Manager(PApplet parent,int win_x, int win_y,int nchan,float displayTime_sec, float default_yScale_uV, 
    String filterDescription, float smooth_fac, String detectName) {  
//  Gui_Manager(PApplet parent,int win_x, int win_y,int nchan,float displayTime_sec, float yScale_uV, float fs_Hz,
//      String montageFilterText, String detectName) {
      showSpectrogram = false;  
      whichChannelForSpectrogram = 0; //assume
    
     //define some layout parameters
    int axes_x, axes_y;
    float gutter_topbot = 0.05f; //edge around top and bottom of gui, as fraction of window height
    float gutter_left = 0.08f;  //edge around the left side of the gui, as fraction of window width
    float gutter_right = 0.025f;  //edge around the right side
    float height_UI_tray = 0.17f;  //empty space along bottom for UI elements (ie, the buttons)
    float left_right_split = 0.4f;  //notional dividing line between left and right plots, measured from left
    float available_top2bot = 1.0f - 2*gutter_topbot - height_UI_tray; //compute how much is available for plots
    //float up_down_split = 0.55f;   //notional dividing line between top and bottom plots, measured from top
    float gutter_between_buttons = 0.005f; //space between buttons
    float title_gutter = 0.04f;
    fontInfo = new PlotFontInfo();   //define what fonts to use
    //textOverlayMontage = new TextBox(montageFilterText,fontInfo.textOverlay_size);
  
    //setup the montage plot...the right side 
    default_vertScale_uV = default_yScale_uV;  //here is the vertical scaling of the traces
    //vertScale_uV = yScale_uV;
    float[] axisMontage_relPos = { 
      left_right_split+gutter_left,  //x-position of the plot, as fraction of window width
      gutter_topbot+title_gutter,                 //y-position of the plot, as fraction of window height
      (1.0f-left_right_split)-gutter_left-gutter_right,   //width of plot, as fraction of window width
      available_top2bot-title_gutter              //height of plot, as fraction of window height
    }; //from left, from top, width, height
    axes_x = int(float(win_x)*axisMontage_relPos[2]);  //width of the axis in pixels
    axes_y = int(float(win_y)*axisMontage_relPos[3]);  //height of the axis in pixels
    gMontage = new Graph2D(parent, axes_x, axes_y, false);  //last argument is whether the axes cross at zero
    setupMontagePlot(gMontage, win_x, win_y, axisMontage_relPos,displayTime_sec,fontInfo,filterDescription);
  
    //setup the FFT plot...bottom on left side
    float[] axisFFT_relPos = { 
      gutter_left,       //x-position of the plot, as fraction of window width
      gutter_topbot+title_gutter,     //y-position of the plot, as fractio nof window height
      -gutter_left+left_right_split-gutter_right, //width of plot, as fraction of window width
      available_top2bot-title_gutter  //height of plot, as fraction of window height
    }; //from left, from top, width, height
    axes_x = int(float(win_x)*axisFFT_relPos[2]);  //width of the axis in pixels
    axes_y = int(float(win_y)*axisFFT_relPos[3]);  //height of the axis in pixels
    gFFT = new Graph2D(parent, axes_x, axes_y, false);  //last argument is whether the axes cross at zero
    setupFFTPlot(gFFT, win_x, win_y, axisFFT_relPos,fontInfo);
        
    //setup the spectrogram plot
    float[] axisSpectrogram_relPos = axisMontage_relPos;
    axes_x = int(float(win_x)*axisSpectrogram_relPos[2]);
    axes_y = int(float(win_y)*axisSpectrogram_relPos[3]);
    gSpectrogram = new Graph2D(parent, axes_x, axes_y, false);  //last argument is wheter the axes cross at zero
    setupSpectrogram(gSpectrogram, win_x, win_y, axisMontage_relPos,displayTime_sec,fontInfo);
    int Nspec = 256;
    int Nstep = 32;
    spectrogram = new Spectrogram(Nspec,fs_Hz,Nstep,displayTime_sec);
    spectrogram.clim[0] = java.lang.Math.log(gFFT.getYAxis().getMinValue());   //set the minium value for the color scale on the spectrogram
    spectrogram.clim[1] = java.lang.Math.log(gFFT.getYAxis().getMaxValue()/10.0); //set the maximum value for the color scale on the spectrogram
    updateMaxDisplayFreq();
        
    //setup the buttons
    int w,h,x,y;
           
    //setup stop button
    w = 120;    //button width
    h = 35;     //button height, was 25
    x = win_x - int(gutter_right*float(win_x)) - w;
    y = win_y - int(0.5*gutter_topbot*float(win_y)) - h;
    //int y = win_y - h;
    stopButton = new Button(x,y,w,h,stopButton_pressToStop_txt,fontInfo.buttonLabel_size);
    
    //setup the gui page button
    w = 80; //button width
    x = (int)(3*gutter_between_buttons*win_x);
    guiPageButton = new Button(x,y,w,h,"Page\n" + (guiPage+1) + " of " + N_GUI_PAGES,fontInfo.buttonLabel_size);
        
    //setup the channel on/off buttons...only plot 8 buttons, even if there are more channels
    //because as of 4/3/2014, you can only turn on/off the higher channels (the ones above chan 8)
    //by also turning off the corresponding lower channel.  So, deactiving channel 9 must also
    //deactivate channel 1, therefore, we might as well use just the 1 button.
    int xoffset = x + w + (int)(2*gutter_between_buttons*win_x);
    w = w;   //button width
    int w_orig = w;
    //if (nchan > 10) w -= (nchan-8)*2; //make the buttons skinnier
    int nChanBut = min(nchan,8);
    chanButtons = new Button[nChanBut];
    String txt;
    for (int Ibut = 0; Ibut < nChanBut; Ibut++) {
      x = calcButtonXLocation(Ibut, win_x, w, xoffset,gutter_between_buttons);
      txt = "Chan\n" + Integer.toString(Ibut+1);
      if (nchan > 8) txt = txt + "+" + Integer.toString(Ibut+1+8);
      chanButtons[Ibut] = new Button(x,y,w,h,txt,fontInfo.buttonLabel_size);
    }
    
    //setup the impedance measurement (lead-off) control buttons
    //showImpedanceButtons = false; //by default, do not show the buttons
    int vertspace_pix = max(1,int(gutter_between_buttons*win_x/4));
    int w1 = w_orig;  //use same width as for buttons above
    int h1 = h/2-vertspace_pix;  //use buttons with half the height
    impedanceButtonsP = new Button[nchan];
    for (int Ibut = 0; Ibut < nchan; Ibut++) {
      x = calcButtonXLocation(Ibut, win_x, w1, xoffset, gutter_between_buttons);
      impedanceButtonsP[Ibut] = new Button(x,y,w1,h1,"Imp P" + (Ibut+1),fontInfo.buttonLabel_size);
    }    
    impedanceButtonsN = new Button[nchan];
    for (int Ibut = 0; Ibut < nchan; Ibut++) {
      x = calcButtonXLocation(Ibut, win_x, w1, xoffset, gutter_between_buttons);
      impedanceButtonsN[Ibut] = new Button(x,y+h-h1,w1,h1,"Imp N" + (Ibut+1),fontInfo.buttonLabel_size);
    }
    h1 = h;
    x = calcButtonXLocation(nchan, win_x, w1, xoffset, gutter_between_buttons);
    biasButton = new Button(x,y,w1,h1,"Bias\n" + "Auto",fontInfo.buttonLabel_size);

    //setup the buttons to control the processing and frequency displays
    int Ibut=0;    w = w_orig;    h = h;    
    
    x = calcButtonXLocation(Ibut++, win_x, w, xoffset,gutter_between_buttons);
    filtBPButton = new Button(x,y,w,h,"BP Filt\n" + filtCoeff_bp[currentFilt_ind].short_name,fontInfo.buttonLabel_size);
  
    x = calcButtonXLocation(Ibut++, win_x, w, xoffset,gutter_between_buttons);
    intensityFactorButton = new Button(x,y,w,h,"Vert Scale\n" + round(vertScale_uV) + "uV",fontInfo.buttonLabel_size);
  
    //x = calcButtonXLocation(Ibut++, win_x, w, xoffset,gutter_between_buttons);
    //fftNButton = new Button(x,y,w,h,"FFT N\n" + Nfft,fontInfo.buttonLabel_size);
   
    set_vertScaleAsLog(true);
    x = calcButtonXLocation(Ibut++, win_x, w, xoffset,gutter_between_buttons);
    loglinPlotButton = new Button(x,y,w,h,"Vert Scale\n" + get_vertScaleAsLogText(),fontInfo.buttonLabel_size);
  
    x = calcButtonXLocation(Ibut++, win_x, w, xoffset,gutter_between_buttons);
    //smoothingButton = new Button(x,y,w,h,"Smooth\n" + headPlot1.smooth_fac,fontInfo.buttonLabel_size);
    smoothingButton = new Button(x,y,w,h,"Smooth\n" + "x",fontInfo.buttonLabel_size);

    x = calcButtonXLocation(Ibut++, win_x, w, xoffset,gutter_between_buttons);
    maxDisplayFreqButton = new Button(x,y,w,h,"Max Freq\n" + round(maxDisplayFreq_Hz[maxDisplayFreq_ind]) + " Hz",fontInfo.buttonLabel_size);


    //set the signal detection button...left of center
    w = stopButton.but_dx;
    h = stopButton.but_dy;
    x = (int)(((float)win_x) / 2.0f - (float)w - (gutter_between_buttons*win_x)/2.0f);
    y = stopButton.but_y;
    detectButton = new Button(x,y,w,h,"Detect " + signalDetectName,fontInfo.buttonLabel_size);
    
    //set the show spectrogram button...right of center
    w = stopButton.but_dx;
    h = stopButton.but_dy;
    x = (int)(((float)win_x) / 2.0f + (gutter_between_buttons*win_x)/2.0f);
    y = stopButton.but_y;
    spectrogramButton = new Button(x,y,w,h,"Spectrogram",fontInfo.buttonLabel_size);
       
    //set the initial display page for the GUI
    setGUIpage(GUI_PAGE_CHANNEL_ONOFF);  
  } 
  private int calcButtonXLocation(int Ibut,int win_x,int w, int xoffset, float gutter_between_buttons) {
    return xoffset + (Ibut * (w + (int)(gutter_between_buttons*win_x)));
  }
  
  
  public void setDefaultVertScale(float val_uV) {
    default_vertScale_uV = val_uV;
    updateVertScale();
  }
  public void setVertScaleFactor_ind(int ind) {
    vertScaleFactor_ind = max(0,ind);
    if (ind >= vertScaleFactor.length) vertScaleFactor_ind = 0;
    updateVertScale();
  }
  public void incrementVertScaleFactor() {
    setVertScaleFactor_ind(vertScaleFactor_ind+1);  //wrap-around is handled inside the function
  }
  public void updateVertScale() {
    vertScale_uV = default_vertScale_uV*vertScaleFactor[vertScaleFactor_ind];
    //println("Gui_Manager: updateVertScale: vertScale_uV = " + vertScale_uV);
    
    //update how the plots are scaled
    //if (montageTrace != null) montageTrace.setYScale_uV(vertScale_uV);  //the Y-axis on the montage plot is fixed...the data is simply scaled prior to plotting
    if (montageTrace != null) {
      //montageTrace.setYScale_uV(vertScale_uV);  //the Y-axis on the montage plot is fixed...the data is simply scaled prior to plotting
      montageTrace.setYScale_uV(1.0f);
      gMontage.setYAxisMin(-vertScale_uV);
      gMontage.setYAxisMax(vertScale_uV);
      if (( (vertScale_uV > 45) & (vertScale_uV < 55) ) || ( (vertScale_uV > 450) & (vertScale_uV < 550)) ) {
        gMontage.setYAxisTickSpacing(floor(vertScale_uV/5.0f));
      } else {
        gMontage.setYAxisTickSpacing(floor(vertScale_uV/4.0f));
      }
    }
    if (gFFT != null) gFFT.setYAxisMax(vertScale_uV);
    //headPlot1.setMaxIntensity_uV(vertScale_uV);
    intensityFactorButton.setString("Vert Scale\n" + round(vertScale_uV) + "uV");
    
    //update the Yticks on the FFT plot
    if (gFFT != null) {
      if (vertScaleAsLog) {
        gFFT.setYAxisTickSpacing(1);
      } else {
        gFFT.setYAxisTickSpacing(pow(10.0,floor(log10(vertScale_uV/4))));
      }
    }
  }
    
  public String get_vertScaleAsLogText() {
    if (vertScaleAsLog) {
      return "Log";
    } else {
      return "Linear";
    }
  }
  public void set_vertScaleAsLog(boolean state) {
    vertScaleAsLog = state;
    
    //change the FFT Plot
    if (gFFT != null) {
      if (vertScaleAsLog) {
          gFFT.setYAxisMin(vertScaleMin_uV_whenLog);
          Axis2D ay=gFFT.getYAxis();
          ay.setLogarithmicAxis(true);
          updateVertScale();  //force a re-do of the Yticks
      } else {
          Axis2D ay=gFFT.getYAxis();
          ay.setLogarithmicAxis(false);
          gFFT.setYAxisMin(0.0f);
          updateVertScale();  //force a re-do of the Yticks
      }
    }
    
    //change the head plot
    //headPlot1.set_plotColorAsLog(vertScaleAsLog);
    
    //change the button
    if (loglinPlotButton != null) {
      loglinPlotButton.setString("Vert Scale\n" + get_vertScaleAsLogText());
    }
  }
  
  public void setSmoothFac(float fac) {
    //headPlot1.smooth_fac = fac;
  }
  
  public void setMaxDisplayFreq_ind(int ind) {
    maxDisplayFreq_ind = max(0,ind);
    if (ind >= maxDisplayFreq_Hz.length) maxDisplayFreq_ind = 0;
    updateMaxDisplayFreq();
  }
  public void incrementMaxDisplayFreq() {
    setMaxDisplayFreq_ind(maxDisplayFreq_ind+1);  //wrap-around is handled inside the function
  }
  public void updateMaxDisplayFreq() {
    //set the frequency limit of the display
    float foo_Hz = maxDisplayFreq_Hz[maxDisplayFreq_ind];
    gFFT.setXAxisMax(foo_Hz);
    if (fftTrace != null) fftTrace.set_plotXlim(0.0f,foo_Hz);
    gSpectrogram.setYAxisMax(foo_Hz);
    
    //set the ticks
    if (foo_Hz < 38.0f) {
      foo_Hz = 5.0f;
    } else if (foo_Hz < 78.0f) {
      foo_Hz = 10.0f;
    } else if (foo_Hz < 168.0f) {
      foo_Hz = 20.0f;
    } else {
      foo_Hz = (float)floor(foo_Hz / 50.0) * 50.0f;
    }
    gFFT.setXAxisTickSpacing(foo_Hz);
    gSpectrogram.setYAxisTickSpacing(foo_Hz);
    
    if (maxDisplayFreqButton != null) maxDisplayFreqButton.setString("Max Freq\n" + round(maxDisplayFreq_Hz[maxDisplayFreq_ind]) + " Hz");
  }
      
  
  public void setDoNotPlotOutsideXlim(boolean state) {
    if (state) {
      //println("GUI_Manager: setDoNotPlotAboveXlim: " + gFFT.getXAxis().getMaxValue());
      fftTrace.set_plotXlim(gFFT.getXAxis().getMinValue(),gFFT.getXAxis().getMaxValue());
      montageTrace.set_plotXlim(gMontage.getXAxis().getMinValue(),gMontage.getXAxis().getMaxValue());
    } else {
      fftTrace.set_plotXlim(Float.NaN,Float.NaN);
    }
  }
  public void setDecimateFactor(int fac) {
    montageTrace.setDecimateFactor(fac);
  }
 
  //public void setupMontagePlot(Graph2D g, int win_x, int win_y, float[] axis_relPos,float displayTime_sec, PlotFontInfo fontInfo,TextBox title) {
  public void setupMontagePlot(Graph2D g, int win_x, int win_y, float[] axis_relPos,float displayTime_sec, PlotFontInfo fontInfo,String filterDescription) {
  
    g.setAxisColour(220, 220, 220);
    g.setFontColour(255, 255, 255);
  
    int x1,y1;
    x1 = int(axis_relPos[0]*float(win_x));
    g.position.x = x1;
    y1 = int(axis_relPos[1]*float(win_y));
    g.position.y = y1;
    //g.position.y = 0;
  
//    g.setYAxisMin(-nchan-1.0f);
//    g.setYAxisMax(0.0f);
    g.setYAxisMin(-vertScale_uV);
    g.setYAxisMax(vertScale_uV);
//    g.setYAxisTickSpacing(1f);
//    g.setYAxisMinorTicks(0);
//    if (vertScale_uV > 120.0F) {
//      g.setYAxisTickSpacing(50);
//      g.setYAxisMinorTicks(2);
//    } else {
      //g.setYAxisTickSpacing(25);
      //g.setYAxisMinorTicks(5);
      g.setYAxisTickSpacing((int)(vertScale_uV/5));
      g.setYAxisMinorTicks((int)(vertScale_uV/10));
    //}
    g.setYAxisLabelAccuracy(0);
    g.setYAxisLabel("EEG Amplitude (uV)");
    g.setYAxisLabelFont(fontInfo.fontName,fontInfo.axisLabel_size, true);
    g.setYAxisTickFont(fontInfo.fontName,fontInfo.tickLabel_size, false);
  
    g.setXAxisMin(-displayTime_sec);
    g.setXAxisMax(0f);
    g.setXAxisTickSpacing(1f);
    g.setXAxisMinorTicks(1);
    g.setXAxisLabelAccuracy(0);
    g.setXAxisLabel("Time (sec)");
    g.setXAxisLabelFont(fontInfo.fontName,fontInfo.axisLabel_size, false);
    g.setXAxisTickFont(fontInfo.fontName,fontInfo.tickLabel_size, false);
  
    // switching on Grid, with different colours for X and Y lines
    gbMontage = new  GridBackground(new GWColour(255));
    gbMontage.setGridColour(180, 180, 180, 180, 180, 180);
    g.setBackground(gbMontage);
    
    // add title
    titleMontage = new TextBox("EEG Data (" + filterDescription + ")",0,0);
    int x2 = x1 + int(round(0.5*axis_relPos[2]*float(win_x)));
    int y2 = y1 - 2;  //deflect two pixels upward
    titleMontage.x = x2;
    titleMontage.y = y2;
    titleMontage.textColor = color(255,255,255);
    titleMontage.setFontSize(16);
    titleMontage.alignH = CENTER;

    //add text overlay
    //float[] rel_xy = {0.01,0.03};  //from top-left of the montage plot space...scaled by window size
    //textOverlayMontage.x = (int)(g.position.x + float(win_x)*axis_relPos[3]*rel_xy[0]); //scale by window width and axis width
    //textOverlayMontage.y = (int)(g.position.y + float(win_y)*axis_relPos[2]*rel_xy[1]);//scale by window height and axis height   

    //add channel data values and impedance values
    int x3, y3;
    //float w = int(round(axis_relPos[2]*win_x));
    TextBox fooBox = new TextBox("",0,0); 
    chanValuesMontage = new TextBox[nchan];
    impValuesMontage = new TextBox[nchan];
    Axis2D xAxis = g.getXAxis();
    Axis2D yAxis = g.getYAxis();
    int h = int(round(axis_relPos[3]*win_y));
    for (int i=0; i<nchan; i++) {
      y3 = y1 + h - yAxis.valueToPosition((float)(-(i+1))); //set to be on the centerline of the trace
      for (int j=0; j<2; j++) { //loop over the different text box types
        switch (j) {
          case 0:
            //voltage value text
            x3 = x1 + xAxis.valueToPosition(xAxis.getMaxValue()) - 2;  //set to right edge of plot.  nudge 2 pixels to the left
            fooBox = new TextBox("0.00 uVrms",x3,y3);
            break;
          case 1:
            //impedance value text
            x3 = x1 + xAxis.valueToPosition(xAxis.getMinValue()) + 2;  //set to left edge of plot.  nudge 2 pixels to the right
            fooBox = new TextBox("0.00 kOhm",x3,y3);
            break;
        }
        fooBox.textColor = color(0,0,0);
        fooBox.drawBackground = true;
        fooBox.backgroundColor = color(255,255,255);
        switch (j) {
          case 0:
            //voltage value text
            fooBox.alignH = RIGHT;
            chanValuesMontage[i] = fooBox;
            break;
          case 1:
            //impedance value text
            fooBox.alignH = LEFT;
            impValuesMontage[i] = fooBox;
            break;
        }
      }
    }
    showMontageValues = true;  // default to having them NOT displayed    
  }
  
  //public void setupFFTPlot(Graph2D g, int win_x, int win_y, float[] axis_relPos,PlotFontInfo fontInfo, TextBox title) {
  public void setupFFTPlot(Graph2D g, int win_x, int win_y, float[] axis_relPos,PlotFontInfo fontInfo) {
  
    g.setAxisColour(220, 220, 220);
    g.setFontColour(255, 255, 255);
  
    int x1,y1;
    x1 = int(axis_relPos[0]*float(win_x));
    g.position.x = x1;
    y1 = int(axis_relPos[1]*float(win_y));
    g.position.y = y1;
    //g.position.y = 0;
  
    //setup the y axis
    g.setYAxisMin(vertScaleMin_uV_whenLog);
    g.setYAxisMax(vertScale_uV);
    g.setYAxisTickSpacing(1);
    g.setYAxisMinorTicks(0);
    g.setYAxisLabelAccuracy(0);
    g.setYAxisLabel("EEG Amplitude (uV/sqrt(Hz))");
    g.setYAxisLabelFont(fontInfo.fontName,fontInfo.axisLabel_size, false);
    g.setYAxisTickFont(fontInfo.fontName,fontInfo.tickLabel_size, false);
  
    //get the Y-axis and make it log
    Axis2D ay=g.getYAxis();
    ay.setLogarithmicAxis(true);
  
    //setup the x axis
    g.setXAxisMin(0f);
    g.setXAxisMax(maxDisplayFreq_Hz[maxDisplayFreq_ind]);
    g.setXAxisTickSpacing(10f);
    g.setXAxisMinorTicks(2);
    g.setXAxisLabelAccuracy(0);
    g.setXAxisLabel("Frequency (Hz)");
    g.setXAxisLabelFont(fontInfo.fontName,fontInfo.axisLabel_size, false);
    g.setXAxisTickFont(fontInfo.fontName,fontInfo.tickLabel_size, false);
  
  
    // switching on Grid, with differetn colours for X and Y lines
    gbFFT = new  GridBackground(new GWColour(255));
    gbFFT.setGridColour(180, 180, 180, 180, 180, 180);
    g.setBackground(gbFFT);
    
    // add title
    titleFFT = new TextBox("EEG Data (As Received)",0,0);
    int x2 = x1 + int(round(0.5*axis_relPos[2]*float(win_x)));
    int y2 = y1 - 2;  //deflect two pixels upward
    titleFFT.x = x2;
    titleFFT.y = y2;
    titleFFT.textColor = color(255,255,255);
    titleFFT.setFontSize(16);
    titleFFT.alignH = CENTER;
  }
  
  public void setupSpectrogram(Graph2D g, int win_x, int win_y, float[] axis_relPos,float displayTime_sec, PlotFontInfo fontInfo) {
    //start by setting up as if it were the montage plot
    //setupMontagePlot(g, win_x, win_y, axis_relPos,displayTime_sec,fontInfo,title);
    
    g.setAxisColour(220, 220, 220);
    g.setFontColour(255, 255, 255);
  
    int x1 = int(axis_relPos[0]*float(win_x));
    g.position.x = x1;
    int y1 = int(axis_relPos[1]*float(win_y));
    g.position.y = y1;
    
    //setup the x axis
    g.setXAxisMin(-displayTime_sec);
    g.setXAxisMax(0f);
    g.setXAxisTickSpacing(1f);
    g.setXAxisMinorTicks(1);
    g.setXAxisLabelAccuracy(0);
    g.setXAxisLabel("Time (sec)");
    g.setXAxisLabelFont(fontInfo.fontName,fontInfo.axisLabel_size, false);
    g.setXAxisTickFont(fontInfo.fontName,fontInfo.tickLabel_size, false);
 
    //setup the y axis...frequency
    g.setYAxisMin(0.0f-0.5f);
    g.setYAxisMax(maxDisplayFreq_Hz[maxDisplayFreq_ind]);
    g.setYAxisTickSpacing(10.0f);
    g.setYAxisMinorTicks(2);
    g.setYAxisLabelAccuracy(0);
    g.setYAxisLabel("Frequency (Hz)");
    g.setYAxisLabelFont(fontInfo.fontName,fontInfo.axisLabel_size, false);
    g.setYAxisTickFont(fontInfo.fontName,fontInfo.tickLabel_size, false);
        
        
    //make title
    titleSpectrogram = new TextBox(makeSpectrogramTitle(),0,0);
    int x2 = x1 + int(round(0.5*axis_relPos[2]*float(win_x)));
    int y2 = y1 - 2;  //deflect two pixels upward
    titleSpectrogram.x = x2;
    titleSpectrogram.y = y2;
    titleSpectrogram.textColor = color(255,255,255);
    titleSpectrogram.setFontSize(16);
    titleSpectrogram.alignH = CENTER;
  }
  
  public void initializeMontageTraces(float[] dataBuffX, float [][] dataBuffY) {
    
    //create the trace object, add it to the  plotting object, and set the data and scale factor
    //montageTrace  = new ScatterTrace();  //I can't have this here because it dies. It must be in setup()
    gMontage.addTrace(montageTrace);
    montageTrace.setXYData_byRef(dataBuffX, dataBuffY);
    //montageTrace.setYScaleFac(1f / vertScale_uV);
    montageTrace.setYScaleFac(1.0f); //for OpenBCI_GUI_Simpler
    
    //set the y-offsets for each trace in the fft plot.
    //have each trace bumped down by -1.0.
    for (int Ichan=0; Ichan < nchan; Ichan++) {
      montage_yoffsets[Ichan]=(float)(-(Ichan+1));
    }
    montageTrace.setYOffset_byRef(montage_yoffsets);
  }
  
  
  public void initializeFFTTraces(ScatterTrace_FFT fftTrace,FFT[] fftBuff,float[] fftYOffset,Graph2D gFFT) {
    for (int Ichan = 0; Ichan < fftYOffset.length; Ichan++) {
      //set the Y-offste for the individual traces in the plots
      fftYOffset[Ichan]= 0f;  //set so that there is no additional offset
    }
    
    //make the trace for the FFT and add it to the FFT Plot axis
    //fftTrace = new ScatterTrace_FFT(fftBuff); //can't put this here...must be in setup()
    fftTrace.setYOffset(fftYOffset);
    gFFT.addTrace(fftTrace);
  }
    
    
  public void initDataTraces(float[] dataBuffX,float[][] dataBuffY,FFT[] fftBuff,float[] dataBuffY_std, DataStatus[] is_railed) {      
    //initialize the time-domain montage-plot traces
    montageTrace = new ScatterTrace();
    montage_yoffsets = new float[nchan];
    initializeMontageTraces(dataBuffX,dataBuffY);
    montageTrace.set_isRailed(is_railed);
  
    //initialize the FFT traces
    fftTrace = new ScatterTrace_FFT(fftBuff); //can't put this here...must be in setup()
    fftYOffset = new float[nchan];
    initializeFFTTraces(fftTrace,fftBuff,fftYOffset,gFFT);
    
    //link the data to the head plot
    //headPlot1.setIntensityData_byRef(dataBuffY_std,is_railed);
  }
   

  public void setGoodFFTBand(float[] band) {
    fftTrace.setGoodBand(band);
  }
  public void setBadFFTBand(float[] band) {
    fftTrace.setBadBand(band);
  }
  public void showFFTFilteringData(boolean show) {
    fftTrace.showFFTFilteringData(show);
  }
  public void setDetectionData_freqDomain(DetectionData_FreqDomain[] data) {
    fftTrace.setDetectionData_freqDomain(data);
  }
  public void setAudioOscillator(Oscil wave) {
    fftTrace.setAudioOscillator(wave);
  }
  

  public void setShowSpectrogram(boolean show) {
    showSpectrogram = show;
  } 


  public void tellGUIWhichChannelForSpectrogram(int Ichan) { // Ichan starts at zero
    if (Ichan != whichChannelForSpectrogram) {
      whichChannelForSpectrogram = Ichan;
      titleSpectrogram.string = makeSpectrogramTitle();
    }
  }
  public String makeSpectrogramTitle() {
    return ("Spectrogram, Channel " + (whichChannelForSpectrogram+1) + " (As Received)");
  }
  
 
  public void setGUIpage(int page) {
    if ((page >= 0) && (page < N_GUI_PAGES)) {
      guiPage = page;
    } else {
      guiPage = 0;
    }
    //update the text on the button
    guiPageButton.setString("Page\n" + (guiPage+1) + " of " + N_GUI_PAGES);
  }
  
  public void incrementGUIpage() {
    setGUIpage( (guiPage+1) % N_GUI_PAGES );
  }
  
  public boolean isMouseOnGraph2D(Graph2D g, int mouse_x, int mouse_y) {
    GraphDataPoint dataPoint = new GraphDataPoint();
    getGraph2DdataPoint(g,mouse_x,mouse_y,dataPoint);
    if ( (dataPoint.x >= g.getXAxis().getMinValue()) &
         (dataPoint.x <= g.getXAxis().getMaxValue()) &
         (dataPoint.y >= g.getYAxis().getMinValue()) &
         (dataPoint.y <= g.getYAxis().getMaxValue()) ) {
      return true;
    } else {
      return false;
    }
  }
  
  public boolean isMouseOnMontage(int mouse_x, int mouse_y) {
    return isMouseOnGraph2D(gMontage,mouse_x,mouse_y);
  }
  public boolean isMouseOnFFT(int mouse_x, int mouse_y) {
    return isMouseOnGraph2D(gFFT,mouse_x,mouse_y);
  }

  public void getGraph2DdataPoint(Graph2D g, int mouse_x,int mouse_y, GraphDataPoint dataPoint) {
    int rel_x = mouse_x - int(g.position.x);
    int rel_y = g.getYAxis().getLength() - (mouse_y - int(g.position.y));
    dataPoint.x = g.getXAxis().positionToValue(rel_x);
    dataPoint.y = g.getYAxis().positionToValue(rel_y);
  }
  public void getMontageDataPoint(int mouse_x, int mouse_y, GraphDataPoint dataPoint) {
    getGraph2DdataPoint(gMontage,mouse_x,mouse_y,dataPoint);
    dataPoint.x_units = "sec";
    dataPoint.y_units = "uV";  
  }  
  public void getFFTdataPoint(int mouse_x,int mouse_y,GraphDataPoint dataPoint) {
    getGraph2DdataPoint(gFFT, mouse_x,mouse_y,dataPoint);
    dataPoint.x_units = "Hz";
    dataPoint.y_units = "uV/sqrt(Hz)";
  }
    
//  public boolean isMouseOnHeadPlot(int mouse_x, int mouse_y) {
//    return headPlot1.isPixelInsideHead(mouse_x,mouse_y) {
//  }
  
  public void update(float[] data_std_uV,float[] data_elec_imp_ohm) {
    //assume new data has already arrived via the pre-existing references to dataBuffX and dataBuffY and FftBuff
    montageTrace.generate();  //graph doesn't update without this
    fftTrace.generate(); //graph doesn't update without this
    //headPlot1.update();

    //update the text strings
    String fmt; float val;
    for (int Ichan=0; Ichan < data_std_uV.length; Ichan++) {
      //update the voltage values
      val = data_std_uV[Ichan];
      chanValuesMontage[Ichan].string = String.format(getFmt(val),val) + " uVrms";
      if (montageTrace.is_railed != null) {
        if (montageTrace.is_railed[Ichan].is_railed == true) {
          chanValuesMontage[Ichan].string = "RAILED";
        } else if (montageTrace.is_railed[Ichan].is_railed_warn == true) {
          chanValuesMontage[Ichan].string = "NEAR RAILED";
        }
      } 
      
      //update the impedance values
      val = data_elec_imp_ohm[Ichan]/1000;
      impValuesMontage[Ichan].string = String.format(getFmt(val),val) + " kOhm";
      if (montageTrace.is_railed != null) {
        if (montageTrace.is_railed[Ichan].is_railed == true) {
          impValuesMontage[Ichan].string = "RAILED";
        }
      }
    }
  }
  
  private String getFmt(float val) {
    String fmt;
      if (val > 100.0f) {
        fmt = "%.0f";
      } else if (val > 10.0f) {
        fmt = "%.1f";
      } else {
        fmt = "%.2f";
      }
      return fmt;
  }
    
  public void draw() {
    //headPlot1.draw();
    
    //draw montage or spectrogram
    if (showSpectrogram == false) {
      //show time-domain montage
      gMontage.draw(); titleMontage.draw();
    
      //add annotations
      if (showMontageValues) {
        for (int Ichan = 0; Ichan < chanValuesMontage.length; Ichan++) {
          chanValuesMontage[Ichan].draw();
        }
      }
    } else {
      //show the spectrogram
      gSpectrogram.draw();  //draw the spectrogram axes
      titleSpectrogram.draw(); //draw the spectrogram title

      //draw the spectrogram image
      PVector pos = gSpectrogram.position;
      Axis2D ax = gSpectrogram.getXAxis();
      int x = ax.valueToPosition(ax.getMinValue())+(int)pos.x;
      int w = ax.valueToPosition(ax.getMaxValue());
      ax = gSpectrogram.getYAxis();
      int y =  (int) pos.y - ax.valueToPosition(ax.getMinValue()); //position needs top-left.  The MAX value is at the top-left for this plot.
      int h = ax.valueToPosition(ax.getMaxValue());
      //println("gui_Manager.draw(): x,y,w,h = " + x + " " + y + " " + w + " " + h);
      float max_freq_Hz = gSpectrogram.getYAxis().getMaxValue()-0.5f;
      spectrogram.draw(x,y,w,h,max_freq_Hz);
    }

    //draw the regular FFT spectrum display
    gFFT.draw(); titleFFT.draw();//println("completed FFT draw...");
   
    //draw the UI buttons and other elements 
    stopButton.draw();
    guiPageButton.draw();
    switch (guiPage) {  //the rest of the elements depend upon what GUI page we're on
      //note: GUI_PAGE_CHANNEL_ON_OFF is the default at the end
      case GUI_PAGE_IMPEDANCE_CHECK:
        //show impedance buttons and text
        for (int Ichan = 0; Ichan < chanButtons.length; Ichan++) {
          impedanceButtonsP[Ichan].draw(); //P-channel buttons
          impedanceButtonsN[Ichan].draw(); //N-channel buttons
        }
        for (int Ichan = 0; Ichan < impValuesMontage.length; Ichan++) {
          impValuesMontage[Ichan].draw();  //impedance values on montage plot
        }
        biasButton.draw();
        break;
      case GUI_PAGE_HEADPLOT_SETUP:
        intensityFactorButton.draw();
        loglinPlotButton.draw();
        filtBPButton.draw();
        //fftNButton.draw();
        smoothingButton.draw();
        maxDisplayFreqButton.draw();
        break;
      default:  //assume GUI_PAGE_CHANNEL_ONOFF:
        //show channel buttons
        for (int Ichan = 0; Ichan < chanButtons.length; Ichan++) { chanButtons[Ichan].draw(); }
        detectButton.draw();
        spectrogramButton.draw();
    }
  } 
}

