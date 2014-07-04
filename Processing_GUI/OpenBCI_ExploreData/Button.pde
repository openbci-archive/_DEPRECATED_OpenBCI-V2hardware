
////////////////////
//
// This class creates and manages a button for use on the screen to trigger actions.
//
// Created: Chip Audette, Oct 2013.
// 
// Based on Processing's "Button" example code
//
////////////////////



class Button {
  
  int but_x, but_y, but_dx, but_dy;      // Position of square button
  //int rectSize = 90;     // Diameter of rect
  color color_pressed = color(51);
  color color_highlight = color(102);
  color color_notPressed = color(255);
  color rectHighlight;
  //boolean isMouseHere = false;
  boolean isActive = false;
  public String but_txt;
  PFont font;

  public Button(int x, int y, int w, int h, String txt, int fontSize) {
    setup(x, y, w, h, txt);
    //println(PFont.list()); //see which fonts are available
    //font = createFont("SansSerif.plain",fontSize);
    //font = createFont("Lucida Sans Regular",fontSize);
    font = createFont("Arial",fontSize);
    //font = loadFont("SansSerif.plain.vlw");
  }

  public void setup(int x, int y, int w, int h, String txt) {
    but_x = x;
    but_y = y;
    but_dx = w;
    but_dy = h;
    setString(txt);
  }
  
  public void setString(String txt) {
    but_txt = txt;
    //println("Button: setString: string = " + txt);
  }
  
  public boolean isActive() {
    return isActive;
  }
  
  public void setIsActive(boolean val) {
    isActive = val;
  }
  
  public boolean isMouseHere() {
    if ( overRect(but_x, but_y, but_dx, but_dy) ) {
      return true;
    } 
    else {
      return false;
    }
  }

  color getColor() {
    if (isActive) {
      return color_pressed;
    } else {    
      return color_notPressed;
    }
  }

  boolean overRect(int x, int y, int width, int height) {
    if (mouseX >= x && mouseX <= x+width && 
      mouseY >= y && mouseY <= y+height) {
      return true;
    } 
    else {
      return false;
    }
  }

  public void draw() {
    //draw the button
    fill(getColor());
    stroke(255);
    rect(but_x,but_y,but_dx,but_dy);
    
    //draw the text
    fill(0);
    stroke(255);
    textFont(font);
    textSize(12);
    textAlign(CENTER, CENTER);
    textLeading(round(0.9*(textAscent()+textDescent())));
//    int x1 = but_x+but_dx/2;
//    int y1 = but_y+but_dy/2;
    int x1, y1;
    if (false) {
      //auto wrap
      x1 = but_x;
      y1 = but_y;
      int w = but_dx-2*2; //use a 2 pixel buffer on the left and right sides 
      int h = but_dy;
      text(but_txt,x1,y1,w,h);
    } else {
      //no auto wrap
      x1 = but_x+but_dx/2;
      y1 = but_y+but_dy/2;
      text(but_txt,x1,y1);
    }
  }
};



