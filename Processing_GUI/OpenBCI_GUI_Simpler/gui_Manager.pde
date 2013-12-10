
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
};

class PlotTitle {
  int x,y;
  String string;
  int fontSize;
  PFont font;
  
  PlotTitle() {
    x=0;y=0;
    fontSize=12;
    string="";
    font = loadFont("Sans Serif");
  }
  
  PlotTitle(String s,int size) {
    x=0;y=0;
    string = s;
    fontSize = size;
    font = createFont("Arial",fontSize);
  }
  
  void draw() {
    textFont(font);
    fill(255,255,255);
    textSize(fontSize);
    text(string,x,y);
  }
};

class gui_Manager {
  ScatterTrace sTrace;
  ScatterTrace_FFT fftTrace;
  Graph2D gMontage, gFFT;
  PlotTitle titleMontage,titleFFT;
  GridBackground gbMontage, gbFFT;
  Button stopButton;
  PlotFontInfo fontInfo;
  //headPlot headPlot1;
  Button[] chanButtons;
  
  float fftYOffset[];
  float vertScale_uV = 200.f; //this defines the Y-scale on the montage plots...this is the vertical space between traces...probably overwritten
  float montage_yoffsets[];
  
  gui_Manager(PApplet parent,int win_x, int win_y,int nchan,float displayTime_sec, float yScale_uV) {  
    
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
    titleMontage = new PlotTitle("Time-Domain Plot (Filtered Data)",fontInfo.title_size); //title for the time-domain plot
    titleFFT = new PlotTitle("Frequency-Domain Plot (Data as Received)",fontInfo.title_size); //title for the freq-domain plot
  
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
    setupMontagePlot(gMontage, win_x, win_y, axisMontage_relPos,displayTime_sec,fontInfo);
  
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
    setupFFTPlot(gFFT, win_x, win_y, axisFFT_relPos,fontInfo);
      
    
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
  } 
    
  public void setupMontagePlot(Graph2D g, int win_x, int win_y, float[] axis_relPos,float displayTime_sec, PlotFontInfo fontInfo) {
  
    g.setAxisColour(220, 220, 220);
    g.setFontColour(255, 255, 255);
  
    g.position.x = int(axis_relPos[0]*float(win_x));
    g.position.y = int(axis_relPos[1]*float(win_y));
    //g.position.y = 0;
  
//    g.setYAxisMin(-nchan-1.0f);
//    g.setYAxisMax(0.0f);
//    g.setYAxisTickSpacing(1f);
//    g.setYAxisMinorTicks(0);
//    g.setYAxisLabelAccuracy(0);
//    g.setYAxisLabel("EEG Channel");
    
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
    
    //make title
    float rel_width = axis_relPos[2];
    titleMontage.x = (int)(g.position.x + float(win_x)*0.5f*rel_width);
    titleMontage.y = (int)(g.position.y - float(win_y)*0.05f);
  }
  
  public void setupFFTPlot(Graph2D g, int win_x, int win_y, float[] axis_relPos,PlotFontInfo fontInfo) {
  
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
    titleFFT.x = int(g.position.x + float(win_x) * 0.5f*rel_width);
    titleFFT.y = int(g.position.y - float(win_y) * 0.05f);
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
  
  public void update() {
    //assume new data has already arrived via the pre-existing references to dataBuffX and dataBuffY and FftBuff
    sTrace.generate();  //graph doesn't update without this
    fftTrace.generate(); //graph doesn't update without this
  }
  
  public void draw() {
    //headPlot1.draw();
    gMontage.draw(); //println("completed montage draw..."); 
    titleMontage.draw();
    gFFT.draw(); //println("completed FFT draw..."); 
    titleFFT.draw();
    stopButton.draw();
    for (int Ichan = 0; Ichan < chanButtons.length; Ichan++) {
      chanButtons[Ichan].draw();
    }
  }
  
}

