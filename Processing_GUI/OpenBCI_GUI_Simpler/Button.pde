
////////////////////
//
// This class creates and manages a button for use on the screen to trigger actions.
//
// Created: Chip Audette, Oct 2013.
// 
// Based on Processing's "Button" example code
//
////////////////////


String stopButton_pressToStop_txt = "Press to Stop";
String stopButton_pressToStart_txt = "Press to Start";
class Button {
  int but_x, but_y, but_dx, but_dy;      // Position of square button
  //int rectSize = 90;     // Diameter of rect
  color color_pressed = color(51);
  color color_highlight = color(102);
  color color_notPressed = color(255);
  color rectHighlight;
  boolean isMouseHere = false;
  boolean isActive = false;
  String but_txt;
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
  }
  
  public boolean isActive() {
    return isActive;
  }
  
  public void setIsActive(boolean val) {
    isActive = val;
  }
  
  public boolean updateIsMouseHere() {
    if ( overRect(but_x, but_y, but_dx, but_dy) ) {
      isMouseHere = true;
    } 
    else {
      isMouseHere = false;
    }
    
    return isMouseHere;
  }

//  boolean updateMouseIsPressed() {
//    updateIsMouseHere();
//    if (isMouseHere) {
//      isActive = true;
//    //} else {
//    //  isActive = false;
//    }
//    return isActive;
//  }

//  void updateMouseIsReleased() {
//    isActive = false;
//  }

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
    text(but_txt,but_x+but_dx/2,but_y+but_dy/2);
  }
}  


