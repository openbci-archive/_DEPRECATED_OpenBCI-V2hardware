
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

class PlotFontInfo {
    String fontName = "Sans Serif";
    int axisLabel_size = 16;
    int tickLabel_size = 14;
    int buttonLabel_size = 12;
    int title_size = 18;
    int textOverlay_size = 12;
};


class TextOverlay {
  int x,y;
  String string;
  int fontSize;
  PFont font;
  int[] rgb;
  int alignX,alignY;
  
  TextOverlay() {
    this(" ",10);
  };
  TextOverlay(String s, int fsize) {
    string = new String(s); 
    x=0;
    y=0;
    setColor(0,0,0); //black
    fontSize=fsize;
    font = createFont("Sans Serif",fontSize);
    alignX = LEFT;
    alignY = TOP;
  }

  public void setColor(int r, int g, int b) {
    rgb = new int[3];
    rgb[0]=r;
    rgb[1]=g;
    rgb[2]=b;
  }
  
  public void draw() {
    textFont(font);
    fill(rgb[0],rgb[1],rgb[2]);
    textSize(fontSize);
    textAlign(alignX,alignY);
    textLeading(fontSize+3);  // Set line spacing
    text(string,x,y);

  }
};


class gui_Manager {
  ScatterTrace sTrace;
  ScatterTrace_FFT fftTrace;
  Graph2D gMontage, gFFT, gSpectrogram;
  TextOverlay titleMontage,titleFFT,titleSpectrogram;
  TextOverlay textOverlayMontage;
  GridBackground gbMontage, gbFFT;
  Button stopButton;
  Button detectButton;
  Button spectrogramButton;
  PlotFontInfo fontInfo;
  //headPlot headPlot1;
  Button[] chanButtons;
  Spectrogram spectrogram;
  boolean showSpectrogram;
  int whichChannelForSpectrogram;
  
  float fftYOffset[];
  float vertScale_uV = 200.f; //this defines the Y-scale on the montage plots...this is the vertical space between traces...probably overwritten
  float montage_yoffsets[];
  
  gui_Manager(PApplet parent,int win_x, int win_y,int nchan,float displayTime_sec, float yScale_uV, float fs_Hz,
      String montageFilterText, String detectName) {
      showSpectrogram = false;  
      whichChannelForSpectrogram = 0; //assume
    
     //define some layout parameters
    int axes_x, axes_y;
    float gutter_topbot = 0.1f; //edge around top and bottom of gui, as fraction of window height
    float gutter_left = 0.07f;  //edge around the left side of the gui, as fraction of window width
    float gutter_right = 0.025f;  //edge around the right side
    float height_UI_tray = 0.12f;  //empty space along bottom for UI elements (ie, the buttons)
    float left_right_split = 0.4f;  //notional dividing line between left and right plots, measured from left
    float available_top2bot = 1.0f - 2*gutter_topbot - height_UI_tray; //compute how much is available for plots
    //float up_down_split = 0.55f;   //notional dividing line between top and bottom plots, measured from top
    float gutter_between_buttons = 0.005f; //space between buttons
    fontInfo = new PlotFontInfo();   //define what fonts to use
    titleMontage = new TextOverlay("Time-Domain Plot (Filtered Data)",fontInfo.title_size); //title for the time-domain plot
    titleFFT = new TextOverlay("Frequency-Domain Plot (Data as Received)",fontInfo.title_size); //title for the freq-domain plot
    titleSpectrogram = new TextOverlay(makeSpectrogramTitle(),fontInfo.title_size); //title for the freq-domain plot
    textOverlayMontage = new TextOverlay(montageFilterText,fontInfo.textOverlay_size);
  
    //setup the montage plot...the right side 
    vertScale_uV = yScale_uV;
    float[] axisMontage_relPos = { 
      left_right_split+gutter_left,  //x-position of the plot, as fraction of window width
      gutter_topbot,                 //y-position of the plot, as fractio nof window height
      (1.0f-left_right_split)-gutter_left-gutter_right,   //width of plot, as fraction of window width
      available_top2bot              //height of plot, as fraction of window height
    }; //from left, from top, width, height
    axes_x = int(float(win_x)*axisMontage_relPos[2]);
    axes_y = int(float(win_y)*axisMontage_relPos[3]);
    gMontage = new Graph2D(parent, axes_x, axes_y, false);  //last argument is wheter the axes cross at zero
    setupMontagePlot(gMontage, win_x, win_y, axisMontage_relPos,displayTime_sec,fontInfo,titleMontage);
  
    //setup the FFT plot...bottom on left side
    float[] axisFFT_relPos = { 
      gutter_left,       //x-position of the plot, as fraction of window width
      gutter_topbot,     //y-position of the plot, as fractio nof window height
      -gutter_left+left_right_split-gutter_right, //width of plot, as fraction of window width
      available_top2bot  //height of plot, as fraction of window height
    }; //from left, from top, width, height
    axes_x = int(float(win_x)*axisFFT_relPos[2]);
    axes_y = int(float(win_y)*axisFFT_relPos[3]);
    gFFT = new Graph2D(parent, axes_x, axes_y, false);  //last argument is wheter the axes cross at zero
    setupFFTPlot(gFFT, win_x, win_y, axisFFT_relPos,fontInfo,titleFFT);
      
    //setup the spectrogram plot
    float[] axisSpectrogram_relPos = axisMontage_relPos;
    axes_x = int(float(win_x)*axisSpectrogram_relPos[2]);
    axes_y = int(float(win_y)*axisSpectrogram_relPos[3]);
    gSpectrogram = new Graph2D(parent, axes_x, axes_y, false);  //last argument is wheter the axes cross at zero
    setupSpectrogram(gSpectrogram, win_x, win_y, axisMontage_relPos,displayTime_sec,fontInfo,titleSpectrogram);
    int Nspec = 256;
    int Nstep = 32;
    spectrogram = new Spectrogram(Nspec,fs_Hz,Nstep,displayTime_sec);
    spectrogram.clim[0] = java.lang.Math.log(gFFT.getYAxis().getMinValue());   //set the minium value for the color scale on the spectrogram
    spectrogram.clim[1] = java.lang.Math.log(gFFT.getYAxis().getMaxValue()/10.0); //set the maximum value for the color scale on the spectrogram
    
    //setup stop button
    int w = 100;    //button width
    int h = 25;     //button height
    int x = win_x - int(gutter_right*float(win_x)) - w;
    int y = win_y - int(0.5*gutter_topbot*float(win_y)) - h;
    //int y = win_y - h;
    stopButton = new Button(x,y,w,h,stopButton_pressToStop_txt,fontInfo.buttonLabel_size);
    
    //setup the channel on/off buttons
    w = 70;   //button width
    if (nchan > 10) w -= (nchan-8)*2; //make the buttons skinnier
    chanButtons = new Button[nchan];
    for (int Ibut = 0; Ibut < nchan; Ibut++) {
      x = ((int)(3*gutter_between_buttons*win_x)) + (Ibut * (w + (int)(gutter_between_buttons*win_x)));
      chanButtons[Ibut] = new Button(x,y,w,h,"Ch " + (Ibut+1),fontInfo.buttonLabel_size);
    }  
  
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
       
  } 
    
  public void setupMontagePlot(Graph2D g, int win_x, int win_y, float[] axis_relPos,float displayTime_sec, PlotFontInfo fontInfo,TextOverlay title) {
  
    g.setAxisColour(220, 220, 220);
    g.setFontColour(255, 255, 255);
  
    g.position.x = int(axis_relPos[0]*float(win_x));
    g.position.y = int(axis_relPos[1]*float(win_y));
    
    g.setYAxisMin(-vertScale_uV);
    g.setYAxisMax(vertScale_uV);
    if (vertScale_uV > 120.0F) {
      g.setYAxisTickSpacing(50);
      g.setYAxisMinorTicks(2);
    } else {
      g.setYAxisTickSpacing(25);
      g.setYAxisMinorTicks(5);
    }
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
  
    // switching on Grid, with differetn colours for X and Y lines
    gbMontage = new  GridBackground(new GWColour(255));
    gbMontage.setGridColour(180, 180, 180, 180, 180, 180);
    g.setBackground(gbMontage);
    
    //add text overlay
    float[] rel_xy = {0.01,0.03};  //from top-left of the montage plot space...scaled by window size
    textOverlayMontage.x = (int)(g.position.x + float(win_x)*axis_relPos[3]*rel_xy[0]); //scale by window width and axis width
    textOverlayMontage.y = (int)(g.position.y + float(win_y)*axis_relPos[2]*rel_xy[1]);//scale by window height and axis height
   
    
    //make title
    float rel_width = axis_relPos[2];
    title.x = (int)(g.position.x + float(win_x)*0.5f*rel_width);
    title.y = (int)(g.position.y - float(win_y)*0.01f);
    title.setColor(255,255,255);//make it white
    title.alignX = CENTER;
    title.alignY = BOTTOM;
  }
  
  public void setupFFTPlot(Graph2D g, int win_x, int win_y, float[] axis_relPos,PlotFontInfo fontInfo, TextOverlay title) {
  
    g.setAxisColour(220, 220, 220);
    g.setFontColour(255, 255, 255);
  
    g.position.x = int(axis_relPos[0]*float(win_x));
    g.position.y = int(axis_relPos[1]*float(win_y));
    //g.position.y = 0;
  
    //setup the y axis
    g.setYAxisMin(0.1f);
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
    //g.setXAxisMax(65);
    g.setXAxisMax(40);
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
    
    //make title
    float rel_width = axis_relPos[2];
    title.x = int(g.position.x + float(win_x) * 0.5f*rel_width);
    title.y = int(g.position.y - float(win_y) * 0.01f);
    title.setColor(255,255,255);//make it white
    title.alignX = CENTER;
    title.alignY = BOTTOM;
  }
  
  public void setupSpectrogram(Graph2D g, int win_x, int win_y, float[] axis_relPos,float displayTime_sec, PlotFontInfo fontInfo, TextOverlay title) {
    //start by setting up as if it were the montage plot
    //setupMontagePlot(g, win_x, win_y, axis_relPos,displayTime_sec,fontInfo,title);
    
    g.setAxisColour(220, 220, 220);
    g.setFontColour(255, 255, 255);
  
    g.position.x = int(axis_relPos[0]*float(win_x));
    g.position.y = int(axis_relPos[1]*float(win_y));
    
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
    g.setYAxisMax(40.0f+0.5f);
    g.setYAxisTickSpacing(10f);
    g.setYAxisMinorTicks(2);
    g.setYAxisLabelAccuracy(0);
    g.setYAxisLabel("Frequency (Hz)");
    g.setYAxisLabelFont(fontInfo.fontName,fontInfo.axisLabel_size, false);
    g.setYAxisTickFont(fontInfo.fontName,fontInfo.tickLabel_size, false);
        
        
    //make title
    float rel_width = axis_relPos[2];
    title.x = (int)(g.position.x + float(win_x)*0.5f*rel_width);
    title.y = (int)(g.position.y - float(win_y)*0.01f);
    title.setColor(255,255,255);//make it white
    title.alignX = CENTER;
    title.alignY = BOTTOM;
  }
  
  public void initializeMontageTraces(float[] dataBuffX, float [][] dataBuffY) {
    
    //create the trace object, add it to the  plotting object, and set the data and scale factor
    //sTrace  = new ScatterTrace();  //I can't have this here because it dies. It must be in setup()
    gMontage.addTrace(sTrace);
    sTrace.setXYData_byRef(dataBuffX, dataBuffY);
    //sTrace.setYScaleFac(1f / vertScale_uV);
    sTrace.setYScaleFac(1.0f);
    
    //set the y-offsets for each trace in the fft plot.
    //have each trace bumped down by -1.0.
    for (int Ichan=0; Ichan < nchan; Ichan++) {
      montage_yoffsets[Ichan]=(float)(-(Ichan+1));
    }
    sTrace.setYOffset_byRef(montage_yoffsets);
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
    
    
  public void initDataTraces(float[] dataBuffX,float[][] dataBuffY,FFT[] fftBuff) {      
    //initialize the time-domain montage-plot traces
    sTrace = new ScatterTrace();
    montage_yoffsets = new float[nchan];
    initializeMontageTraces(dataBuffX,dataBuffY);
  
    //initialize the FFT traces
    fftTrace = new ScatterTrace_FFT(fftBuff); //can't put this here...must be in setup()
    fftYOffset = new float[nchan];
    initializeFFTTraces(fftTrace,fftBuff,fftYOffset,gFFT);
    
    //link the data to the head plot
    //headPlot1.setIntensityData_byRef(dataBuffY_std);
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
  
  
  public void update() {
    //assume new data has already arrived via the pre-existing references to dataBuffX and dataBuffY and FftBuff
    sTrace.generate();  //graph doesn't update without this
    fftTrace.generate(); //graph doesn't update without this
  }
    
  public void draw() {
    //headPlot1.draw();
    if (showSpectrogram == false) {
      //show time-domain montage
      gMontage.draw(); //println("completed montage draw...");
      titleMontage.draw();
      textOverlayMontage.draw();
    } else {
      //show the spectrogram
      
      //draw the axis
      gSpectrogram.draw();
      titleSpectrogram.draw();

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

    gFFT.draw(); //println("completed FFT draw..."); 
    titleFFT.draw();
    stopButton.draw();
    detectButton.draw();
    spectrogramButton.draw();
    for (int Ichan = 0; Ichan < chanButtons.length; Ichan++) {
      chanButtons[Ichan].draw();
    }
  }
  
}

