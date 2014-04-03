Introduction
-------------

Here are some graphical user interfaces for OpenBCI, as written for Processing.  We currently have two styles of GUI:


* OpenBCI_GUI is the heavyweight GUI that shows data for 8 (or more!) EEG channels.  It has a traditional time-domain display, a frequency-domain display, and an illustration of a head that lights up based on the intensity of the EEG energy. 

* OpenBCI_GUI_Simpler is a lighter GUI that just shows the data for fewer EEG channels.  It has a frequency domain plot and a time domain / spectrogram plot.



Dependencies
------------

These GUIs require you to download the Processing environment.  This code was primarily developed using Processing 2.0.3 (* See Note).  It uses the built-in Serial library to communicate to the Arduin (or whatever) microcontroller is hosting the OpenBCI shield.  This GUI also uses the built in 'minim' library for executing the FFT to make the frequency-domain display.

http://processing.org

The OpenBCI Processing GUI requires the 'gwoptics' graphing library.  We developed using the 0.5.0 version of the gwoptics library.

http://www.gwoptics.org/processing/gwoptics_p5lib/

(* This code does NOT work with Processing 2.1 due to the Serial library, which seems to be fixed in Processing 2.1.1.  This code has not been extensively tested in 2.1.1.)


Updates
--------

2014-04-03 OpenBCI_GUI:
		: Added controls for lead_off detection (ie, impedance checking)
		: Added controls for filtering and smoothing and vertical scale
                  factor.  Added buttons to control all of these settings.
		: Added control to toggle bias to a fixed voltage from the
		  normal "auto" generation of the bias based on the common-mode
		  of the active electrodes 
		: Added loading of electrode locations from a text file
		: Added fancier "contour" plotting of EEG voltages on the
		  head plot.
		: Added playback of pre-recorded data from a text file along
		  with a couple of example recorded data files.

2014-02-02 OpenBCI_GUI and OpenBCI_GUI_Simpler:
		: More refinements in handling of incoming serial binary data.
                  Most stable at 115200 bps

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