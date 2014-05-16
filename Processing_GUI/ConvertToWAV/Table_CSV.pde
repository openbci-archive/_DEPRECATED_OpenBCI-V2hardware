
/*

Name: Table_CSV
Created: Chip Audette, April-May 2014
Purpose: Extend the read functionality of Processing's built-in "Table" class.
    Specifically, have Table ignore commented lines (ie, with "%") when
    reading the table.
Origin: Most of this code is taken directly from Table.java and then modified
    to have it ignore lines that start with '%'
License: MIT License   http://opensource.org/licenses/MIT

*/

class Table_CSV extends Table {
  Table_CSV(String fname) throws IOException {
    //println("Table_CSV: fname: " + fname);
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

