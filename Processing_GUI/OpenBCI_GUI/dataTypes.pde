
//////////////////////////////////////
//
// This file contains classes that are helfpul in some way.
//
// Created: Chip Audette, Oct 2013
//
/////////////////////////////////////

class dataPacket_ADS1299 {
  int sampleIndex;
  int[] values;
  dataPacket_ADS1299(int nValues) {
    values = new int[nValues];
  }
  int printToConsole() {
    print("printToConsole: dataPacket = ");
    print(sampleIndex);
    for (int i=0; i < values.length; i++) {
      print(", " + values[i]);
    }
    println();
    return 0;
  }
  int copyTo(dataPacket_ADS1299 target) {
    target.sampleIndex = sampleIndex;
    for (int i=0; i < values.length; i++) {
      target.values[i] = values[i];
    }
    return 0;
  }
}


public class filterConstants {
  public double[] a;
  public double[] b;
  public String name;
  filterConstants(double[] b_given, double[] a_given, String name_given) {
    b = new double[b_given.length];a = new double[b_given.length];
    for (int i=0; i<b.length;i++) { b[i] = b_given[i];}
    for (int i=0; i<a.length;i++) { a[i] = a_given[i];}
    name = name_given;
  };
};

public class graphDataPoint {
  public double x;
  public double y;
  public String x_units;
  public String y_units;
};

class plotFontInfo {
    String fontName = "Sans Serif";
    int axisLabel_size = 16;
    int tickLabel_size = 14;
    int buttonLabel_size = 12;
};

public class textBox {
  public int x, y;
  public color textColor;
  public color backgroundColor;
  private PFont font;
  private int fontSize;
  public String string;
  public boolean drawBackground;
  public int backgroundEdge_pixels;
  public int alignH,alignV;
  
//  textBox(String s,int x1,int y1) {
//    textBox(s,x1,y1,0);
//  }
  textBox(String s, int x1, int y1) {
    string = s; x = x1; y = y1;
    backgroundColor = color(255,255,255);
    textColor = color(0,0,0);
    fontSize = 12;
    font = createFont("Arial",fontSize);
    backgroundEdge_pixels = 1;
    drawBackground = false;
    alignH = LEFT;
    alignV = BOTTOM;
  }
  public void setFontSize(int size) {
    fontSize = size;
    font = createFont("Arial",fontSize);
  }
  public void draw() {
    //define text
    textFont(font);
    
    //draw the box behind the text
    if (drawBackground == true) {
      int w = int(round(textWidth(string)));
      int xbox = x - backgroundEdge_pixels;
      switch (alignH) {
        case LEFT:
          xbox = x - backgroundEdge_pixels;
          break;
        case RIGHT:
          xbox = x - w - backgroundEdge_pixels;
          break;
        case CENTER:
          xbox = x - int(round(w/2.0)) - backgroundEdge_pixels;
          break;
      }
      w = w + 2*backgroundEdge_pixels;
      int h = int(textAscent())+2*backgroundEdge_pixels;        
      int ybox = y - int(round(textAscent())) - backgroundEdge_pixels -2;
      fill(backgroundColor);
      rect(xbox,ybox,w,h);
    }
    //draw the text itself
    fill(textColor);
    textAlign(alignH,alignV);
    text(string,x,y);
  }
};

