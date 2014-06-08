
////////////////////////////////////////////////////////////
// Class: OutputFile_rawtxt
// Purpose: handle file creation and writing for the text log file
// Created: Chip Audette  May 2, 2014
//
//write data to a text file
public class OutputFile_rawtxt {
  PrintWriter output;
  String fname;
  private int rowsWritten;

  OutputFile_rawtxt(float fs_Hz) {

    //build up the file name
    fname = "SavedData\\openBCI_raw_";

    //add year month day to the file name
    fname = fname + year() + "-";
    if (month() < 10) fname=fname+"0";
    fname = fname + month() + "-";
    if (day() < 10) fname = fname + "0";
    fname = fname + day(); 

    //add hour minute sec to the file name
    fname = fname + "_";
    if (hour() < 10) fname = fname + "0";
    fname = fname + hour() + "-";
    if (minute() < 10) fname = fname + "0";
    fname = fname + minute() + "-";
    if (second() < 10) fname = fname + "0";
    fname = fname + second();

    //add the extension
    fname = fname + ".txt";

    //open the file
    output = createWriter(fname);

    //add the header
    writeHeader(fs_Hz);
    
    //init the counter
    rowsWritten = 0;
  }

  public void writeHeader(float fs_Hz) {
    output.println("%OpenBCI Raw EEG Data");
    output.println("%");
    output.println("%Sample Rate = " + fs_Hz + " Hz");
    output.println("%First Column = SampleIndex");
    output.println("%Other Columns = EEG data in microvolts with optional columns at end being unscaled Aux data");
    output.flush();
  }


  public void writeRawData_dataPacket(DataPacket_ADS1299 data, float scale_to_uV) {
    writeRawData_dataPacket(data, scale_to_uV, data.values.length);
  }
  public void writeRawData_dataPacket(DataPacket_ADS1299 data, float scale_to_uV, int nValsUsingScaleFactor) {
    int nVal = data.values.length;

    if (output != null) {
      output.print(Integer.toString(data.sampleIndex));
      for (int Ival = 0; Ival < nVal; Ival++) {
        output.print(", ");
        if ((Ival >= nValsUsingScaleFactor) || (abs(scale_to_uV-1.0) < 1e-6)) {
          //do not scale the data
          output.print(Integer.toString(data.values[Ival]));
        } 
        else {
          //apply the scale factor
          output.print(String.format("%.2f", scale_to_uV * float(data.values[Ival])));
        }
      }
      output.println(); rowsWritten++;
      //output.flush();
    }
  }


  public void closeFile() {
    output.flush();
    output.close();
  }

  public int getRowsWritten() {
    return rowsWritten;
  }
}


///////////////////////////////////////////////////////////////
// Class: Table_CSV
// Purpose: Extend the Table class to handle data files with comment lines
// Created: Chip Audette  May 2, 2014
//
// Usage: Only invoke this object when you want to read in a data
//    file in CSV format.  Read it in at the time of creation via
//    
//    String fname = "myfile.csv";
//    TableCSV myTable = new TableCSV(fname);
//
//import java.io.*; 
//import processing.core.PApplet;
class Table_CSV extends Table {
  Table_CSV(String fname) throws IOException {
    init();
    readCSV(PApplet.createReader(createInput(fname)));
  }

  //this function is nearly completely copied from parseBasic from Table.java
  void readCSV(BufferedReader reader) throws IOException {
    boolean header=false;  //added by Chip, May 2, 2014;
    boolean tsv = false;  //added by Chip, May 2, 2014;

    String line = null;
    int row = 0;
    if (rowCount == 0) {
      setRowCount(10);
    }
    //int prev = 0;  //-1;
    try {
      while ( (line = reader.readLine ()) != null) {
        //added by Chip, May 2, 2014 to ignore lines that are comments
        if (line.charAt(0) == '%') {
          //println("Table_CSV: readCSV: ignoring commented line...");
          continue;
        }

        if (row == getRowCount()) {
          setRowCount(row << 1);
        }
        if (row == 0 && header) {
          setColumnTitles(tsv ? PApplet.split(line, '\t') : splitLineCSV(line));
          header = false;
        } 
        else {
          setRow(row, tsv ? PApplet.split(line, '\t') : splitLineCSV(line));
          row++;
        }

        // this is problematic unless we're going to calculate rowCount first
        if (row % 10000 == 0) {
          /*
        if (row < rowCount) {
           int pct = (100 * row) / rowCount;
           if (pct != prev) {  // also prevents "0%" from showing up
           System.out.println(pct + "%");
           prev = pct;
           }
           }
           */
          try {
            // Sleep this thread so that the GC can catch up
            Thread.sleep(10);
          } 
          catch (InterruptedException e) {
            e.printStackTrace();
          }
        }
      }
    } 
    catch (Exception e) {
      throw new RuntimeException("Error reading table on line " + row, e);
    }
    // shorten or lengthen based on what's left
    if (row != getRowCount()) {
      setRowCount(row);
    }
  }
}

