
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
  
  //constructor, give it "nValues", which should match the number of values in the
  //data payload in each data packet from the Arduino.  This is likely to be at least
  //the number of EEG channels in the OpenBCI system (ie, 8 channels if a single OpenBCI
  //board) plus whatever auxiliary data the Arduino is sending. 
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

public class DetectionData_FreqDomain {
  public float inband_uV = 0.0f;
  public float inband_freq_Hz = 0.0f;
  public float guard_uV = 0.0f;
  public float thresh_uV = 0.0f;
  public boolean isDetected = false;
  
  DetectionData_FreqDomain() {
  }
};

