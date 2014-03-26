
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


//import processing.core.PApplet;
import org.gwoptics.graphics.*;
import org.gwoptics.graphics.graph2D.*;
import org.gwoptics.graphics.graph2D.Graph2D;
import org.gwoptics.graphics.graph2D.LabelPos;
import org.gwoptics.graphics.graph2D.traces.Blank2DTrace;
import org.gwoptics.graphics.graph2D.backgrounds.*;
import ddf.minim.analysis.*; //for FFT
import java.util.*; //for Array.copyOfRange()

class Gui_Manager {
  ScatterTrace montageTrace;
  ScatterTrace_FFT fftTrace;
  Graph2D gMontage, gFFT;
  GridBackground gbMontage, gbFFT;
  Button stopButton;
  PlotFontInfo fontInfo;
  HeadPlot headPlot1;
  Button[] chanButtons;
  Button guiModeButton;
  //boolean showImpedanceButtons;
  Button[] impedanceButtonsP;
  Button[] impedanceButtonsN;
  Button intensityFactorButton;
  Button loglinPlotButton;
  TextBox titleMontage, titleFFT;
  TextBox[] chanValuesMontage;
  TextBox[] impValuesMontage;
  boolean showMontageValues;
  public int guiMode;
  boolean vertScaleAsLog = true;
  
  private float fftYOffset[];
  private float default_vertScale_uV=200.0; //this defines the Y-scale on the montage plots...this is the vertical space between traces
  private float[] vertScaleFactor = {1.0f, 2.0f, 5.0f, 50.0f, 0.25f, 0.5f};
  private int vertScaleFactor_ind = 0;
  float vertScale_uV=200.0;
  float vertScaleMin_uV_whenLog = 0.1f;
  float montage_yoffsets[];
  
  public final static int GUI_MODE_CHANNEL_ONOFF = 0;
  public final static int GUI_MODE_IMPEDANCE_CHECK = 1;
  public final static int GUI_MODE_HEADPLOT_SETUP = 2;
  public final static int N_GUI_MODES = 3;
  
  public final static String stopButton_pressToStop_txt = "Press to Stop";
  public final static String stopButton_pressToStart_txt = "Press to Start";
  
  Gui_Manager(PApplet parent,int win_x, int win_y,int nchan,float displayTime_sec, float default_yScale_uV, String filterDescription) {  
    
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
    fontInfo = new PlotFontInfo();
  
    //setup the montage plot...the right side 
    default_vertScale_uV = default_yScale_uV;  //here is the vertical scaling of the traces
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
    headPlot1 = new HeadPlot(axisHead_relPos[0],axisHead_relPos[1],axisHead_relPos[2],axisHead_relPos[3],win_x,win_y);  

    int w,h,x,y;
           
    //setup stop button
    w = 120;    //button width
    h = 35;     //button height, was 25
    x = win_x - int(gutter_right*float(win_x)) - w;
    y = win_y - int(0.5*gutter_topbot*float(win_y)) - h;
    //int y = win_y - h;
    stopButton = new Button(x,y,w,h,stopButton_pressToStop_txt,fontInfo.buttonLabel_size);
    
    //setup the gui mode button
    w = 60;
    x = (int)(3*gutter_between_buttons*win_x);
    guiModeButton = new Button(x,y,w,h,"Mode",fontInfo.buttonLabel_size);
        
    //setup the channel on/off buttons
    int xoffset = x + w + (int)(2*gutter_between_buttons*win_x);
    w = 80;   //button width
    int w_orig = w;
    if (nchan > 10) w -= (nchan-8)*2; //make the buttons skinnier
    chanButtons = new Button[nchan];
    for (int Ibut = 0; Ibut < nchan; Ibut++) {
      x = calcButtonXLocation(Ibut, win_x, w, xoffset,gutter_between_buttons);
      chanButtons[Ibut] = new Button(x,y,w,h,"Ch " + (Ibut+1),fontInfo.buttonLabel_size);
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

    //setup the headPlot buttons
    w = w_orig;
    h = h;
    x = calcButtonXLocation(0, win_x, w, xoffset,gutter_between_buttons);
    intensityFactorButton = new Button(x,y,w,h,"Vert Scale\n" + round(vertScale_uV) + "uV",fontInfo.buttonLabel_size);
    
    set_vertScaleAsLog(true);
    x = calcButtonXLocation(1, win_x, w, xoffset,gutter_between_buttons);
    loglinPlotButton = new Button(x,y,w,h,"Vert Scale\n" + get_vertScaleAsLogText(),fontInfo.buttonLabel_size);
    
    
    //set the initial display mode for the GUI
    setGUImode(GUI_MODE_CHANNEL_ONOFF);  
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
    if (montageTrace != null) montageTrace.setYScale_uV(vertScale_uV);  //the Y-axis on the montage plot is fixed...the data is simply scaled prior to plotting
    if (gFFT != null) gFFT.setYAxisMax(vertScale_uV);
    headPlot1.setMaxIntensity_uV(vertScale_uV);
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
    headPlot1.set_plotColorAsLog(vertScaleAsLog);
    
    //change the button
    if (loglinPlotButton != null) {
      loglinPlotButton.setString("Vert Scale\n" + get_vertScaleAsLogText());
    }
  }
    
  public void setupMontagePlot(Graph2D g, int win_x, int win_y, float[] axis_relPos,float displayTime_sec, PlotFontInfo fontInfo,String filterDescription) {
  
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
    titleMontage = new TextBox("EEG Data (" + filterDescription + ")",0,0);
    int x2 = x1 + int(round(0.5*axis_relPos[2]*float(win_x)));
    int y2 = y1 - 2;  //deflect two pixels upward
    titleMontage.x = x2;
    titleMontage.y = y2;
    titleMontage.textColor = color(255,255,255);
    titleMontage.setFontSize(16);
    titleMontage.alignH = CENTER;
    
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
    titleFFT = new TextBox("EEG Data (As Received)",0,0);
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
    //montageTrace  = new ScatterTrace();  //I can't have this here because it dies. It must be in setup()
    gMontage.addTrace(montageTrace);
    montageTrace.setXYData_byRef(dataBuffX, dataBuffY);
    montageTrace.setYScaleFac(1f / vertScale_uV);
    
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
    
    
  public void initDataTraces(float[] dataBuffX,float[][] dataBuffY,FFT[] fftBuff,float[] dataBuffY_std, boolean[] is_railed) {      
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
    headPlot1.setIntensityData_byRef(dataBuffY_std,is_railed);
  }
  
  public void setGUImode(int mode) {
    if ((mode >= 0) && (mode < N_GUI_MODES)) {
      guiMode = mode;
    } else {
      guiMode = 0;
    }
  }
  
  public void incrementGUImode() {
    setGUImode( (guiMode+1) % N_GUI_MODES );
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

    //update the text strings
    String fmt; float val;
    for (int Ichan=0; Ichan < data_std_uV.length; Ichan++) {
      //update the voltage values
      val = data_std_uV[Ichan];
      chanValuesMontage[Ichan].string = String.format(getFmt(val),val) + " uVrms";
      if (montageTrace.is_railed != null) {
        if (montageTrace.is_railed[Ichan] == true) {
          chanValuesMontage[Ichan].string = "RAILED";
        }
      } 
      
      //update the impedance values
      val = data_elec_imp_ohm[Ichan]/1000;
      impValuesMontage[Ichan].string = String.format(getFmt(val),val) + " kOhm";
      if (montageTrace.is_railed != null) {
        if (montageTrace.is_railed[Ichan] == true) {
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
    headPlot1.draw();
    gMontage.draw(); titleMontage.draw();//println("completed montage draw..."); 
    gFFT.draw(); titleFFT.draw();//println("completed FFT draw..."); 
    stopButton.draw();
    guiModeButton.draw();
    
    switch (guiMode) {
      //note: GUI_MODE_CHANNEL_ON_OFF is the default at the end
      case GUI_MODE_IMPEDANCE_CHECK:
        //show impedance buttons and text
        for (int Ichan = 0; Ichan < chanButtons.length; Ichan++) {
          impedanceButtonsP[Ichan].draw(); //P-channel buttons
          impedanceButtonsN[Ichan].draw(); //N-channel buttons
          impValuesMontage[Ichan].draw();  //impedance values on montage plot   
        }  
        break;
      case GUI_MODE_HEADPLOT_SETUP:
        intensityFactorButton.draw();
        loglinPlotButton.draw();
        break;
      default:  //assume GUI_MODE_CHANNEL_ONOFF:
        //show channel buttons
        for (int Ichan = 0; Ichan < chanButtons.length; Ichan++) { chanButtons[Ichan].draw(); }
    }
    
    if (showMontageValues) {
      for (int Ichan = 0; Ichan < chanValuesMontage.length; Ichan++) {
        chanValuesMontage[Ichan].draw();
      }
    }
  }
 
};


