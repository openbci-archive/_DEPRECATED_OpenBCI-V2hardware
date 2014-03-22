
//////////////////////////////////////////////////////////////
//
// This class creates and manages the head-shaped plot used by the GUI.
// The head includes circles representing the different EEG electrodes.
// The color (brightness) of the electrodes can be adjusted so that the
// electrodes' brightness values dynamically reflect the intensity of the
// EEG signal.  All EEG processing must happen outside of this class.
//
// Created: Chip Audette, Oct 2013
//
// Note: This routine uses aliasing to know which data should be used to
// set the brightness of the electrodes.
//
///////////////////////////////////////////////////////////////

class headPlot {
  private float rel_posX,rel_posY,rel_width,rel_height;
  private int circ_x,circ_y,circ_diam;
  private  int earL_x, earL_y, earR_x, earR_y, ear_width, ear_height;
  private int[] nose_x, nose_y;
  private float[][] electrode_xy;
  //private float[][] electrode_relDist;
  private float[] ref_electrode_xy;
  private int[][] electrode_rgb;
  private int elec_diam;
  PFont font;
  public float[] intensity_data_uV;
  private boolean[] is_railed;
  private float intense_min_uV, intense_max_uV;
  PImage headImage;
  private int image_x,image_y;


  headPlot(float x,float y,float w,float h,int win_x,int win_y) {
    final int n_elec = 8;  //8 electrodes assumed....or 16 for 16-channel?  Change this!!!
    nose_x = new int[3];
    nose_y = new int[3];
    electrode_xy = new float[n_elec][2];   //x-y position of electrodes (pixels?) 
    //electrode_relDist = new float[n_elec][n_elec];  //relative distance between electrodes (pixels)
    ref_electrode_xy = new float[2];  //x-y position of reference electrode
    electrode_rgb = new int[3][n_elec];  //rgb color for each electrode
    font = createFont("Arial",16);
    
    rel_posX = x;
    rel_posY = y;
    rel_width = w;
    rel_height = h;
    setWindowDimensions(win_x,win_y);
    
    intense_min_uV = 5; intense_max_uV = 100;  //default intensity scaling for electrodes
  }
  
  //this method defines all locations of all the subcomponents
  public void setWindowDimensions(int win_width, int win_height){
    
    //define the head itself
    float nose_relLen = 0.075f;
    float nose_relWidth = 0.05f;
    float nose_relGutter = 0.02f;
    float ear_relLen = 0.15f;
    float ear_relWidth = 0.075;   
    
    float square_width = min(rel_width*(float)win_width,
                             rel_height*(float)win_height);  //choose smaller of the two
    
    float total_width = square_width;
    float total_height = square_width;
    float nose_width = total_width * nose_relWidth;
    float nose_height = total_height * nose_relLen;
    ear_width = (int)(ear_relWidth * total_width);
    ear_height = (int)(ear_relLen * total_height);
    int circ_width_foo = (int)(total_width - 2.f*((float)ear_width)/2.0f);
    int circ_height_foo = (int)(total_height - nose_height);
    circ_diam = min(circ_width_foo,circ_height_foo);
    //println("headPlot: circ_diam: " + circ_diam);

    //locations: circle center, measured from upper left
    circ_x = (int)((rel_posX+0.5f*rel_width)*(float)win_width);                  //center of head
    circ_y = (int)((rel_posY+0.5*rel_height)*(float)win_height + nose_height);  //center of head
    
    //locations: ear centers, measured from upper left
    earL_x = circ_x - circ_diam/2;
    earR_x = circ_x + circ_diam/2;
    earL_y = circ_y;
    earR_y = circ_y;
    
    //locations nose vertexes, measured from upper left
    nose_x[0] = circ_x - (int)((nose_relWidth/2.f)*(float)win_width);
    nose_x[1] = circ_x + (int)((nose_relWidth/2.f)*(float)win_width);
    nose_x[2] = circ_x;
    nose_y[0] = circ_y - (int)((float)circ_diam/2.0f - nose_relGutter*(float)win_height);
    nose_y[1] = nose_y[0];
    nose_y[2] = circ_y - (int)((float)circ_diam/2.0f + nose_height);


    //define the electrode positions as the relative position [-1.0 +1.0] within the head
    //remember that negative "Y" is up and positive "Y" is down
    float elec_relDiam = 0.1425f;
    float[][] elec_relXY = new float[8][2]; //change to 16!!!
      elec_relXY[0][0] = -0.125f;             elec_relXY[0][1] = -0.5f + elec_relDiam*(0.5f+0.2f);
      elec_relXY[1][0] = -elec_relXY[0][0];  elec_relXY[1][1] = elec_relXY[0][1];
      elec_relXY[2][0] = -0.2f;            elec_relXY[2][1] = 0f;
      elec_relXY[3][0] = -elec_relXY[2][0];  elec_relXY[3][1] = elec_relXY[2][1];
      
      elec_relXY[4][0] = -0.34f;            elec_relXY[4][1] = 0.25f;
      elec_relXY[5][0] = -elec_relXY[4][0];  elec_relXY[5][1] = elec_relXY[4][1];
      
      elec_relXY[6][0] = -0.125f;             elec_relXY[6][1] = +0.5f - elec_relDiam*(0.5f+0.2f);
      elec_relXY[7][0] = -elec_relXY[6][0];  elec_relXY[7][1] = elec_relXY[6][1];
      
    float[] ref_elec_relXY = new float[2];
      ref_elec_relXY[0] = 0.0f;    ref_elec_relXY[1] = -0.275f;   

    //define the actual locations of the electrodes in pixels
    elec_diam = (int)(elec_relDiam*((float)circ_diam));
    for (int i=0; i < elec_relXY.length; i++) {
      electrode_xy[i][0] = circ_x+(int)(elec_relXY[i][0]*((float)circ_diam));
      electrode_xy[i][1] = circ_y+(int)(elec_relXY[i][1]*((float)circ_diam));
    }
    ref_electrode_xy[0] = circ_x+(int)(ref_elec_relXY[0]*((float)circ_diam));
    ref_electrode_xy[1] = circ_y+(int)(ref_elec_relXY[1]*((float)circ_diam));
    
    //define image to hold all of this
    image_x = int(round(circ_x - 0.5*circ_diam - 0.5*ear_width));
    image_y = nose_y[2];
    headImage = createImage(int(total_width),int(total_height),ARGB);
    
    //initialize the image
    for (int Iy=0; Iy < headImage.height; Iy++) {
      for (int Ix = 0; Ix < headImage.width; Ix++) {
        headImage.set(Ix,Iy,color(0,0,0,0));
      }
    }
  }
  
  public void setIntensityData_byRef(float[] data, boolean[] is_rail) {
    intensity_data_uV = data;  //simply alias the data held externally.  DOES NOT COPY THE DATA ITSEF!  IT'S SIMPLY LINKED!
    is_railed = is_rail;
  }
  
  //step through pixel-by-pixel to update the image
  private void updateHeadImage() {
    int pixel_x, pixel_y;
    int dy = 0; int dx = 0;
    float r;
    float circ_radius = 0.5*float(circ_diam);
    
    //println("headPlot: circ_radius = " + circ_radius);
    for (int Iy=0; Iy < headImage.height; Iy++) {
      pixel_y = image_y + Iy;
      dy = pixel_y - circ_y;
      for (int Ix = 0; Ix < headImage.width; Ix++) {
        pixel_x = image_x + Ix;
        dx = pixel_x - circ_x;
        
        //is this pixel inside the head?
        r = sqrt(float(dx*dx) + float(dy*dy));
        if (r <= circ_radius) {
          //it is inside the head.  set the color based on the electrodes
          headImage.set(Ix,Iy,calcPixelColor(pixel_x,pixel_y));
        } else {
          //pixel is outside the head.  set to black.
          headImage.set(Ix,Iy,color(0,0,0,0));
        }
      }
    }
  }
  
  //compute the color of the pixel given the location
  private color calcPixelColor(int pixel_x, int pixel_y) {
    //get the distance-weighted average of the electrodes
    float new_rgb[] = {0.0,0.0,0.0};
    float dist[] = new float[electrode_xy.length];
    int withinElecInd = -1;
    float elec_radius = 0.5f*elec_diam;
    
    //compute distances to each electrode
    for (int Ielec=0; Ielec < electrode_xy.length; Ielec++) {
      dist[Ielec] = max(1.0,calcDistance(pixel_x,pixel_y,electrode_xy[Ielec][0],electrode_xy[Ielec][1]));
      if (dist[Ielec] < elec_radius) withinElecInd = Ielec;
    }
    
    if (withinElecInd >= 0) {
      //use that electrode's color
      for (int Irgb=0; Irgb<3; Irgb++) new_rgb[Irgb] = electrode_rgb[Irgb][withinElecInd];
    } else {
      //get weighted average based on relative distance
      float sum_weight_fac = 0.0f;
      float weight_fac = 0.0f;
      float foo_dist;
      for (int Ielec=0; Ielec < electrode_xy.length; Ielec++) {
        foo_dist = max(1.0,abs(dist[Ielec] - elec_radius));  //remove radius of the electrode
        weight_fac = 1.0f/foo_dist;  //arbitrarily chosen
        weight_fac = weight_fac*weight_fac*weight_fac;  //again, arbitrary
        for (int Irgb=0; Irgb<3; Irgb++) new_rgb[Irgb] += weight_fac*electrode_rgb[Irgb][Ielec];
        sum_weight_fac += weight_fac;
      }
      for (int Irgb=0; Irgb<3; Irgb++) new_rgb[Irgb] /= sum_weight_fac;  //complete the averaging operation
    }
   
   if (true) {
     //quantize the colors
     int n_colors = 12;
     int ticks_per_color = 256 / (n_colors+1);
     for (int Irgb=0; Irgb<3; Irgb++) new_rgb[Irgb] = min(255.0,float(int(new_rgb[Irgb]/ticks_per_color))*ticks_per_color);
   }
   
    return color(int(new_rgb[0]),int(new_rgb[1]),int(new_rgb[2]),255);
  }

  private float calcDistance(int x,int y,float ref_x,float ref_y) {
    float dx = float(x) - ref_x;
    float dy = float(y) - ref_y;
    return sqrt(dx*dx + dy*dy);
  }
  
  //compute color for the electrode value
  private void updateElectrodeColors() {
    int rgb[] = new int[]{255,0,0}; //color for the electrode when fully light
    float intensity;
    float val;
    int new_rgb[] = new int[3];
    for (int Ielec=0; Ielec < electrode_xy.length; Ielec++) {
      intensity = constrain(intensity_data_uV[Ielec],intense_min_uV,intense_max_uV);
      intensity = map(log10(intensity),log10(intense_min_uV),log10(intense_max_uV),0.0f,1.0f);
      
      //make the intensity fade NOT from black->color, but from white->color
      for (int i=0; i < 3; i++) {
        val = ((float)rgb[i]) / 255.f;
        new_rgb[i] = (int)((val + (1.0f - val)*(1.0f-intensity))*255.f); //adds in white at low intensity.  no white at high intensity
        new_rgb[i] = constrain(new_rgb[i],0,255);
      }
      
      //change color to dark RED if railed
      if (is_railed[Ielec])  new_rgb = new int[]{127,0,0};
      
      //set the electrode color
      electrode_rgb[0][Ielec] = new_rgb[0];
      electrode_rgb[1][Ielec] = new_rgb[1];
      electrode_rgb[2][Ielec] = new_rgb[2];
    }
  }
  
  public void draw() {
    
    //update electrode colors
    updateElectrodeColors();
    
    //update the head image
    updateHeadImage();
       
    //draw head parts
    fill(255,255,255);
    stroke(63,63,63);
    triangle(nose_x[0], nose_y[0],nose_x[1], nose_y[1],nose_x[2], nose_y[2]);  //nose
    ellipse(earL_x, earL_y, ear_width, ear_height); //little circle for the ear
    ellipse(earR_x, earR_y, ear_width, ear_height); //little circle for the ear
    
    //draw head itself    
    image(headImage,image_x,image_y);
    noFill(); //overlay a circle as an outline, but no fill
    strokeWeight(2);
    ellipse(circ_x, circ_y, circ_diam, circ_diam); //big circle for the head
  
    //draw electrodes on the head
    strokeWeight(1);
    //int alpha = 127; //half transparent
    for (int Ielec=0; Ielec < electrode_xy.length; Ielec++) {
      //fill(electrode_rgb[0][Ielec],electrode_rgb[1][Ielec],electrode_rgb[2][Ielec],alpha);
      noFill(); //make transparent to allow color to come through from below   
      ellipse(electrode_xy[Ielec][0], electrode_xy[Ielec][1], elec_diam, elec_diam); //big circle for the head
    }
    
    //add labels to electrodes
    fill(0,0,0);
    textFont(font);
    textAlign(CENTER, CENTER);
    for (int i=0; i < electrode_xy.length; i++) {
            //text(Integer.toString(i),electrode_xy[i][0], electrode_xy[i][1]);
        text(i+1,electrode_xy[i][0], electrode_xy[i][1]);
    }
    text("R",ref_electrode_xy[0],ref_electrode_xy[1]); 
  }
  
};




