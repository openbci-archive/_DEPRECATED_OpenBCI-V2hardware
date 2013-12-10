INTRODUCTION
------------

These are Arduino sketches that for using the OpenBCI in different ways.  These sketches generally upon one or more of the Arduino libraries that we've uploaded seperately.  For example, the "ADS1299" library is required by all of these sketches.  So, be sure to go download it and the other libraries!


SKETCHES
------------

** StreamRawData: This is the main sketch for use on the Arduino to service the OpenBCI shield (V1 and V2).  It configures the shield, it retrieves the EEG data from the shield, and it sends the data out over the serial link to a PC (or whatever is attached to the serial link).  It can format the data in a variety of ways including: (1) ASCII Text, (2) full-resolution Binary for use with our Processing GUI, and (3) the binary "P2" format used by OpenEEG.  Because of this last data format -- the OpenEEG format -- the OpenBCI shield can feed data to a variety of software packages that accept data from OpenEEG (BrainBay is one example).  StreamRawData is a heavy-weight sketch.  We hope to provide a simpler sketch to make it easier to learn how to use OpenBCI.






