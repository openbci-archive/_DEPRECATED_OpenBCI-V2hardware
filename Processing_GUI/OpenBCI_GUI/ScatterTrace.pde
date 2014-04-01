
//////////////////
//
// The ScatterTrace class is used to draw and manage the traces on each
// X-Y line plot created using gwoptics graphing library
//
// Created: Chip Audette, Oct 2013
//
// Based on examples in gwoptics graphic library v0.5.0
// http://www.gwoptics.org/processing/gwoptics_p5lib/
//
// Note that this class does NOT store any of the data used for the
// plot.  Instead, you point it to the data that lives in your
// own program.  In Java-speak, I believe that this is called
// "aliasing"...in this class, I have made an "alias" to your data.
// Some people consider this dangerous.  Because Processing is slow,
// this was one technique for making it faster.  By making an alias
// to your data, you don't need to pass me the data for every update
// and I don't need to make a copy of it.  Instead, once you update
// your data array, the alias in this class is already pointing to
// the right place.  Cool, huh?
//
////////////////

//import processing.core.PApplet;
import org.gwoptics.graphics.*;
import org.gwoptics.graphics.graph2D.*;
import org.gwoptics.graphics.graph2D.Graph2D;
import org.gwoptics.graphics.graph2D.LabelPos;
import org.gwoptics.graphics.graph2D.traces.Blank2DTrace;
import org.gwoptics.graphics.graph2D.backgrounds.*;

class ScatterTrace extends Blank2DTrace {
  private float[] dataX;
  private float[][] dataY;
  private float plotYScale = 1f;  //multiplied to data prior to plotting
  private float plotYOffset[];  //added to data prior to plotting, after applying plotYScale
  private int decimate_factor = 1;  // set to 1 to plot all points, 2 to plot every other point, 3 for every third point
  private DataStatus[] is_railed;
  PFont font = createFont("Arial",16);
  float[] plotXlim;

  public ScatterTrace() {
    //font = createFont("Arial",10);
    plotXlim = new float[]{Float.NaN, Float.NaN};
  }

  /* set the plot's X and Y data by overwriting the existing data */
  public void setXYData_byRef(float[] x, float[][] y) {
    //dataX = x.clone();  //makes a copy
    dataX = x;  //just copies the reference!
    setYData_byRef(y);
  }   

  public void setYData_byRef(float[][] y) {
    //dataY = y.clone(); //makes a copy
    dataY = y;//just copies the reference!
  }   

  public void setYOffset_byRef(float[] yoff) {
    plotYOffset = yoff;  //just copies the reference!
  }
  
  public void setYScale_uV(float yscale_uV) {
    setYScaleFac(1.0f/yscale_uV);
  }

  public void setYScaleFac(float yscale) {
    plotYScale = yscale;
  }
  public void set_plotXlim(float val_low,float val_high) {
    if (val_high < val_low) {
      float foo = val_low;
      val_low = val_high;
      val_high = foo;
    }
    plotXlim[0]=val_low;
    plotXlim[1]=val_high;
  }
  public void set_isRailed(DataStatus[] is_rail) {
    is_railed = is_rail;
  }

  public void TraceDraw(Blank2DTrace.PlotRenderer pr) {
    float x_val;
    
    if (dataX.length > 0) {       
      pr.canvas.pushStyle();      //save whatever was the previous style
      //pr.canvas.stroke(255, 0, 0);  //set the new line's color
      //pr.canvas.strokeWeight(1);  //set the new line's linewidth

      //draw all the individual segments
      for (int iChan = 0; iChan < dataY.length; iChan++) {
          switch (iChan % 4) {
           case 0:
             pr.canvas.stroke(0, 0, 255);  //set the new line's color;
             break;
          case 1:
             pr.canvas.stroke(255, 0, 0);  //set the new line's color;
             break;
          case 2:
             pr.canvas.stroke(0, 255, 0);  //set the new line's color;
             break;
          case 3:
             pr.canvas.stroke(64,64,64);  //set the new line's color;
             break;
         }
        
        float new_x = pr.valToX(dataX[0]);  //first point, convert from data coordinates to pixel coordinates
        float new_y = pr.valToY(dataY[iChan][0]*plotYScale+plotYOffset[iChan]);  //first point, convert from data coordinates to pixel coordinate
        float prev_x, prev_y;
        for (int i=1; i < dataY[iChan].length; i+= decimate_factor) {
          prev_x = new_x;
          prev_y = new_y;
          x_val = dataX[i];
          if ( (Float.isNaN(plotXlim[0])) || ((x_val >= plotXlim[0]) && (x_val <= plotXlim[1])) ) {
            new_x = pr.valToX(x_val);
            new_y = pr.valToY(dataY[iChan][i]*plotYScale+plotYOffset[iChan]);
            pr.canvas.line(prev_x, prev_y, new_x, new_y);
            //if (i==1)  println("ScatterTrace: first point: new_x, new_y = " + new_x + ", " + new_y);   
          } else {
           //do nothing
          }     
        }
     
        //add annotation for is_railed...doesn't work right
//        if (is_railed != null) {
//          if (iChan < is_railed.length) {
//            if (is_railed[iChan]) {
//              new_x = pr.valToX(-2.0);  //near time zero
//              new_y = pr.valToY(0.0+plotYOffset[iChan]);
//              println("ScatterTrace: text: new_x, new_y = " + new_x + ", " + new_y);
//              fill(50,50,50);
//              textFont(font);
//              textAlign(RIGHT, BOTTOM);
//              pr.canvas.text("RAILED",new_x,new_y,100);
//            }
//          }
//       }    
      }
      pr.canvas.popStyle(); //restore whatever was the previous style
    }
  }
  
  public void setDecimateFactor(int val) {
    decimate_factor = max(1,val);
    //println("ScatterTrace: setDecimateFactor to " + decimate_factor);
  }
}


// /////////////////////////////////////////////////////////////////////////////////////////////
class ScatterTrace_FFT extends Blank2DTrace {
  private FFT[] fftData;
  private float plotYOffset[];
  private float[] plotXlim = new float[]{Float.NaN,Float.NaN};

  public ScatterTrace_FFT() {
    //plotXlim = new float[]{Float.NaN,Float.NaN};
  }

  public ScatterTrace_FFT(FFT foo_fft[]) {
    setFFT_byRef(foo_fft);
//    if (foo_fft.length != plotYOffset.length) {
//      plotYOffset = new float[foo_fft.length];
//    }
  }

  public void setFFT_byRef(FFT foo_fft[]) {
    fftData = foo_fft;//just copies the reference!
  }   

  public void setYOffset(float yoff[]) {
    plotYOffset = yoff;
  }
  public void set_plotXlim(float val_low,float val_high) {
    if (val_high < val_low) {
      float foo = val_low;
      val_low = val_high;
      val_high = foo;
    }
    plotXlim[0]=val_low;
    plotXlim[1]=val_high;
  }
//  public void setDecimateFactor(int val) {
//    decimate_factor = max(1,val);
//  }
  public void TraceDraw(Blank2DTrace.PlotRenderer pr) {
    float x_val,spec_value;
    
    if (fftData != null) {      
      pr.canvas.pushStyle();      //save whatever was the previous style
      //pr.canvas.stroke(255, 0, 0);  //set the new line's color
      //pr.canvas.strokeWeight(1);  //set the new line's linewidth
      
      //draw all the individual segments
      for (int iChan=0; iChan < fftData.length; iChan++){
         switch (iChan % 4) {
           case 0:
             pr.canvas.stroke(0, 0, 255);  //set the new line's color;
             break;
          case 1:
             pr.canvas.stroke(255, 0, 0);  //set the new line's color;
             break;
          case 2:
             pr.canvas.stroke(0, 255, 0);  //set the new line's color;
             break;
          case 3:
             pr.canvas.stroke(64,64,64);  //set the new line's color;
             break;
         }
        
        float new_x = pr.valToX(fftData[iChan].indexToFreq(0));  //first point, convert from data coordinates to pixel coordinates
        float new_y = pr.valToY(fftData[iChan].getBand(0)+plotYOffset[iChan]);  //first point, convert from data coordinates to pixel coordinate
        float prev_x, prev_y;
        for (int i=1; i < fftData[iChan].specSize(); i++) {
          prev_x = new_x;
          prev_y = new_y;
          x_val = fftData[iChan].indexToFreq(i);
          if ( (Float.isNaN(plotXlim[0])) || ((x_val >= plotXlim[0]) && (x_val <= plotXlim[1])) ) {
            new_x = pr.valToX(x_val);
            spec_value = fftData[iChan].getBand(i)/fftData[iChan].specSize();
            new_y = pr.valToY(spec_value+plotYOffset[iChan]);
            pr.canvas.line(prev_x, prev_y, new_x, new_y);
          } else {
            //do nothing
          }
        }       
      }
      pr.canvas.popStyle(); //restore whatever was the previous style
    }
  }
};


