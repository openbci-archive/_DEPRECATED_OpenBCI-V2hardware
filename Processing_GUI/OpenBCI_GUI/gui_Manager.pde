
////////////////////////////////////////////////////
//
// This class creates and manages all of the graphical user interface (GUI) elements
// for the primary display.  This is the display with the head, with the FFT frequency
// traces, and with the montage of time-domain traces.  It also holds all of the buttons.
//
// Created: Chip Audette, Oct 2013.
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

class gui_Manager {
  ScatterTrace sTrace;
  ScatterTrace_FFT fftTrace;
  Graph2D gMontage, gFFT;
  GridBackground gbMontage, gbFFT;
  Button stopButton;
  plotFontInfo fontInfo;
  headPlot headPlot1;
  Button[] chanButtons;
  Button chanModeButton;
  boolean showImpedanceButtons;
  Button[] impedanceButtonsP;
  Button[] impedanceButtonsN;
  textBox titleMontage, titleFFT;
  textBox[] chanValuesMontage;
  boolean showMontageValues;
  
  float fftYOffset[];
  float vertScale_uV = 200.f; //this defines the Y-scale on the montage plots...this is the vertical space between traces
  float montage_yoffsets[];
  
  gui_Manager(PApplet parent,int win_x, int win_y,int nchan,float displayTime_sec, float yScale_uV, String filterDescription) {  
    
     //define some layout parameters
    int axes_x, axes_y;
    float gutter_topbot = 0.03f;
    float gutter_left = 0.08f;  //edge around the GUI
    float gutter_right = 0.015f;  //edge around the GUI
    float height_UI_tray = 0.10f;  //empty space along bottom for UI elements
    float left_right_split = 0.45f;  //notional dividing line between left and right plots, measured from left
    float available_top2bot = 1.0f - 2*gutter_topbot - height_UI_tray;
    float up_down_split = 0.55f;   //notional dividing line between top and bottom plots, measured from top
    float gutter_between_buttons = 0.005f; //space between buttons
    float title_gutter = 0.02f;
    fontInfo = new plotFontInfo();
  
    //setup the montage plot...the right side 
    vertScale_uV = yScale_uV;  //here is the vertical scaling of the traces
    float[] axisMontage_relPos = { 
      left_right_split+gutter_left, 
      gutter_topbot+title_gutter, 
      (1.0f-left_right_split)-gutter_left-gutter_right, 
      available_top2bot-title_gutter
    }; //from left, from top, width, height
    axes_x = int(float(win_x)*axisMontage_relPos[2]);  //width of the axis in pixels
    axes_y = int(float(win_y)*axisMontage_relPos[3]);  //height of the axis in pixels
    gMontage = new Graph2D(parent, axes_x, axes_y, false);  //last argument is whether the axes cross at zero
    setupMontagePlot(gMontage, win_x, win_y, axisMontage_relPos,displayTime_sec,fontInfo,filterDescription);
  
    //setup the FFT plot...bottom on left side
    //float height_subplot = 0.5f*(available_top2bot-2*gutter_topbot);
    float[] axisFFT_relPos = { 
      gutter_left, 
      gutter_topbot+ up_down_split*available_top2bot + gutter_topbot+title_gutter, 
      left_right_split-gutter_left-gutter_right, 
      available_top2bot*(1.0f-up_down_split) - gutter_topbot-title_gutter
    }; //from left, from top, width, height
    axes_x = int(float(win_x)*axisFFT_relPos[2]);  //width of the axis in pixels
    axes_y = int(float(win_y)*axisFFT_relPos[3]);  //height of the axis in pixels
    gFFT = new Graph2D(parent, axes_x, axes_y, false);  //last argument is whether the axes cross at zero
    setupFFTPlot(gFFT, win_x, win_y, axisFFT_relPos,fontInfo);
    
    //setup the head plot...top on the left side
    float[] axisHead_relPos = axisFFT_relPos.clone();
    axisHead_relPos[1] = gutter_topbot;  //set y position to be at top of left side
    axisHead_relPos[3] = available_top2bot*up_down_split  - gutter_topbot;
    headPlot1 = new headPlot(axisHead_relPos[0],axisHead_relPos[1],axisHead_relPos[2],axisHead_relPos[3],win_x,win_y);  

    int w,h,x,y;
           
    //setup stop button
    w = 100;    //button width
    h = 25;     //button height
    x = win_x - int(gutter_right*float(win_x)) - w;
    y = win_y - int(0.5*gutter_topbot*float(win_y)) - h;
    //int y = win_y - h;
    stopButton = new Button(x,y,w,h,stopButton_pressToStop_txt,fontInfo.buttonLabel_size);
    
    //setup the channel mode button
    w = 40;
    x = (int)(3*gutter_between_buttons*win_x);
    chanModeButton = new Button(x,y,w,h,"Mode",fontInfo.buttonLabel_size);
        
    //setup the channel on/off buttons
    int xoffset = x + w + (int)(gutter_between_buttons*win_x);
    w = 70;   //button width
    if (nchan > 10) w -= (nchan-8)*2; //make the buttons skinnier
    chanButtons = new Button[nchan];
    for (int Ibut = 0; Ibut < nchan; Ibut++) {
      x = calcButtonXLocation(Ibut, win_x, w, xoffset,gutter_between_buttons);
      chanButtons[Ibut] = new Button(x,y,w,h,"Ch " + (Ibut+1),fontInfo.buttonLabel_size);
    }

    //setup the impedance measurement (lead-off) control buttons
    showImpedanceButtons = false; //by default, do not show the buttons
    w = w;  //use same width as for buttons above
    h = h/2;  //use buttons with half the height
    impedanceButtonsP = new Button[nchan];
    for (int Ibut = 0; Ibut < nchan; Ibut++) {
      x = calcButtonXLocation(Ibut, win_x, w, xoffset, gutter_between_buttons);
      impedanceButtonsP[Ibut] = new Button(x,y-5,w,h,"Imp P" + (Ibut+1),fontInfo.buttonLabel_size);
    }    
    impedanceButtonsN = new Button[nchan];
    for (int Ibut = 0; Ibut < nchan; Ibut++) {
      x = calcButtonXLocation(Ibut, win_x, w, xoffset, gutter_between_buttons);
      impedanceButtonsN[Ibut] = new Button(x,y+h,w,h,"Imp N" + (Ibut+1),fontInfo.buttonLabel_size);
    }    
  } 
  private int calcButtonXLocation(int Ibut,int win_x,int w, int xoffset, float gutter_between_buttons) {
    return xoffset + (Ibut * (w + (int)(gutter_between_buttons*win_x)));
  }
    
  public void setupMontagePlot(Graph2D g, int win_x, int win_y, float[] axis_relPos,float displayTime_sec, plotFontInfo fontInfo,String filterDescription) {
  
    g.setAxisColour(220, 220, 220);
    g.setFontColour(255, 255, 255);
  
    int x1,y1;
    x1 = int(axis_relPos[0]*float(win_x));
    g.position.x = x1;
    y1 = int(axis_relPos[1]*float(win_y));
    g.position.y = y1;
    //g.position.y = 0;
  
    g.setYAxisMin(-nchan-1.0f);
    g.setYAxisMax(0.0f);
    g.setYAxisTickSpacing(1f);
    g.setYAxisMinorTicks(0);
    g.setYAxisLabelAccuracy(0);
    g.setYAxisLabel("EEG Channel");
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
    titleMontage = new textBox("EEG Data (" + filterDescription + ")",0,0);
    int x2 = x1 + int(round(0.5*axis_relPos[2]*float(win_x)));
    int y2 = y1 - 2;  //deflect two pixels upward
    titleMontage.x = x2;
    titleMontage.y = y2;
    titleMontage.textColor = color(255,255,255);
    titleMontage.setFontSize(16);
    titleMontage.alignH = CENTER;
    
    //add channel data values
    int x3, y3;
    //float w = int(round(axis_relPos[2]*win_x));
    chanValuesMontage = new textBox[nchan];
    Axis2D xAxis = g.getXAxis();
    x3 = x1 + xAxis.valueToPosition(xAxis.getMaxValue()) - 2;  //set to left edge of plot.  nudge 2 pixels to the right
    Axis2D yAxis = g.getYAxis();
    int h = int(round(axis_relPos[3]*win_y));
    for (int i=0; i<nchan; i++) {
      y3 = y1 + h - yAxis.valueToPosition((float)(-(i+1))); //set to be on the centerline of the trace
      chanValuesMontage[i] = new textBox("0.00 uVrms",x3,y3);
      chanValuesMontage[i].textColor = color(0,0,0);
      chanValuesMontage[i].drawBackground = true;
      chanValuesMontage[i].backgroundColor = color(255,255,255);
      chanValuesMontage[i].alignH = RIGHT;
    }
    showMontageValues = true;  // default to having them NOT displayed
  }
  
  public void setupFFTPlot(Graph2D g, int win_x, int win_y, float[] axis_relPos,plotFontInfo fontInfo) {
  
    g.setAxisColour(220, 220, 220);
    g.setFontColour(255, 255, 255);
  
    int x1,y1;
    x1 = int(axis_relPos[0]*float(win_x));
    g.position.x = x1;
    y1 = int(axis_relPos[1]*float(win_y));
    g.position.y = y1;
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
    g.setXAxisMax(65);
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
    titleFFT = new textBox("EEG Data (As Received)",0,0);
    int x2 = x1 + int(round(0.5*axis_relPos[2]*float(win_x)));
    int y2 = y1 - 2;  //deflect two pixels upward
    titleFFT.x = x2;
    titleFFT.y = y2;
    titleFFT.textColor = color(255,255,255);
    titleFFT.setFontSize(16);
    titleFFT.alignH = CENTER;
  }
  
  
  public void initializeMontageTraces(float[] dataBuffX, float [][] dataBuffY) {
    
    //create the trace object, add it to the  plotting object, and set the data and scale factor
    //sTrace  = new ScatterTrace();  //I can't have this here because it dies. It must be in setup()
    gMontage.addTrace(sTrace);
    sTrace.setXYData_byRef(dataBuffX, dataBuffY);
    sTrace.setYScaleFac(1f / vertScale_uV);
    
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
    
    
  public void initDataTraces(float[] dataBuffX,float[][] dataBuffY,FFT[] fftBuff,float[] dataBuffY_std, boolean[] is_railed) {      
    //initialize the time-domain montage-plot traces
    sTrace = new ScatterTrace();
    montage_yoffsets = new float[nchan];
    initializeMontageTraces(dataBuffX,dataBuffY);
    sTrace.set_isRailed(is_railed);
  
    //initialize the FFT traces
    fftTrace = new ScatterTrace_FFT(fftBuff); //can't put this here...must be in setup()
    fftYOffset = new float[nchan];
    initializeFFTTraces(fftTrace,fftBuff,fftYOffset,gFFT);
    
    //link the data to the head plot
    headPlot1.setIntensityData_byRef(dataBuffY_std,is_railed);
  }
  
  
  public boolean isMouseOnGraph2D(Graph2D g, int mouse_x, int mouse_y) {
    graphDataPoint dataPoint = new graphDataPoint();
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

  public void getGraph2DdataPoint(Graph2D g, int mouse_x,int mouse_y, graphDataPoint dataPoint) {
    int rel_x = mouse_x - int(g.position.x);
    int rel_y = g.getYAxis().getLength() - (mouse_y - int(g.position.y));
    dataPoint.x = g.getXAxis().positionToValue(rel_x);
    dataPoint.y = g.getYAxis().positionToValue(rel_y);
  }
  public void getMontageDataPoint(int mouse_x, int mouse_y, graphDataPoint dataPoint) {
    getGraph2DdataPoint(gMontage,mouse_x,mouse_y,dataPoint);
    dataPoint.x_units = "sec";
    dataPoint.y_units = "uV";  
  }  
  public void getFFTdataPoint(int mouse_x,int mouse_y,graphDataPoint dataPoint) {
    getGraph2DdataPoint(gFFT, mouse_x,mouse_y,dataPoint);
    dataPoint.x_units = "Hz";
    dataPoint.y_units = "uV/sqrt(Hz)";
  }
    
//  public boolean isMouseOnHeadPlot(int mouse_x, int mouse_y) {
//    return headPlot1.isPixelInsideHead(mouse_x,mouse_y) {
//  }
  
  public void update(float[] data_std_uV) {
    //assume new data has already arrived via the pre-existing references to dataBuffX and dataBuffY and FftBuff
    sTrace.generate();  //graph doesn't update without this
    fftTrace.generate(); //graph doesn't update without this

    //update the labels on the montage
    String fmt; float val;
    for (int Ichan=0; Ichan < data_std_uV.length; Ichan++) {
      val = data_std_uV[Ichan];
      if (val > 100.0f) {
        fmt = "%.0f";
      } else if (val > 10.0f) {
        fmt = "%.1f";
      } else {
        fmt = "%.2f";
      }
      chanValuesMontage[Ichan].string = String.format(fmt,data_std_uV[Ichan]) + " uVrms";
      if (sTrace.is_railed != null) {
        if (sTrace.is_railed[Ichan] == true) {
          chanValuesMontage[Ichan].string = "RAILED";
        }
      } 
    }
  }

  public void draw() {
    headPlot1.draw();
    gMontage.draw(); titleMontage.draw();//println("completed montage draw..."); 
    gFFT.draw(); titleFFT.draw();//println("completed FFT draw..."); 
    stopButton.draw();
    chanModeButton.draw();
    if (showImpedanceButtons == false) {
      //show channel buttons
      for (int Ichan = 0; Ichan < chanButtons.length; Ichan++) {
        chanButtons[Ichan].draw();
      }
    } else {
      //show impedance buttons
      for (int Ichan = 0; Ichan < chanButtons.length; Ichan++) {
        impedanceButtonsP[Ichan].draw();
        impedanceButtonsN[Ichan].draw();       
      }      
    }
    
    if (showMontageValues) {
      for (int Ichan = 0; Ichan < chanValuesMontage.length; Ichan++) {
        chanValuesMontage[Ichan].draw();
      }
    }
  }
  
}

