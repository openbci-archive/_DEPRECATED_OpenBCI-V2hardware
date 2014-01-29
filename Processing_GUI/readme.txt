Introduction
-------------

Here are some graphical user interfaces for OpenBCI, as written for Processing.  We currently have two styles of GUI:


* OpenBCI_GUI is the heavyweight GUI that shows data for 8 (or more!) EEG channels.  It has a traditional time-domain display, a frequency-domain display, and an illustration of a head that lights up based on the intensity of the EEG energy. 

* OpenBCI_GUI_Simpler is a lighter GUI that just shows the data for fewer EEG channels.  It has a frequency domain plot and a time domain / spectrogram plot.



Dependencies
------------

These GUIs require you to download the Processing environment.  This code was developed using Processing 2.0.3.  It uses the built-in Serial library to communicate to the Arduino (or whatever) microcontroller is hosting the OpenBCI shield.  This GUI also uses the built in 'minim' library for executing the FFT to make the frequency-domain display.

http://processing.org

The OpenBCI Processing GUI requires the 'gwoptics' graphing library.  We developed using the 0.5.0 version of the gwoptics library.

http://www.gwoptics.org/processing/gwoptics_p5lib/



Updates
--------

2014-01-29 OpenBCI_GUI_Simpler:
               : Added audio tone as output to Alpha Detection.
                 Now you can know that you're making alpha even when
                 your eyes are closed!

2014-01-26 OpenBCI_GUI and OpenBCI_GUI_Simpler:
               : Improved handling of incoming serial binary data.
                 Now it rejects fewer packets.
               : Updated the date in the file headers.

2014-01-20 OpenBCI_GUI_Simpler: 
               : Added spectrogram plotting option
               : Added initial Alpha wave detector
               : Starts a new file with each start/stop

2014-01-20 OpenBCI_GUI: 
               : Added colored lines for different traces.
               : Starts a new file with each start/stop

2013-12-22 OpenBCI_GUI_Simpler: Added spectrogram plot.

2013-11-15 OpenBCI_GUI_Simpler: First Upload

2013-11-14 OpenBCI_GUI: Added 60Hz notch filtering (hard-coded filter coefficients)

2013-11-13 OpenBCI_GUI: First upload