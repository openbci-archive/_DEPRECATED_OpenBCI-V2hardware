"""
Hardware abstraction model.

Implemented with Traits for easy UI integration, but also accessible programmatically.
(programmatic access will require simulation of the event loop by calling the
data polling function periodically.)

To use serial port directly:
python.exe -m serial.tools.miniterm COM15 230400
"""

# Standard imports
import serial, time
import struct
import logging
import numpy as np

# Enthought imports
import traits.api as t
from pyface.timer.api import do_after

# Custom parameters.
COM_SEARCH_START = 13
COM_SEARCH_END = 15
BAUD = 115200  # * 2
STARTUP_TIMEOUT = 3  # seconds; initial timeout
RUN_TIMEOUT = 1  # seconds; timeout to use once running.
READ_INTERVAL_MS = 250

START_BYTE = bytes(0xA0)  # start of data packet
END_BYTE = bytes(0xC0)  # end of data packet

TIMESERIES_LENGTH = 4500
MIN_HISTORY_LENGTH = 4500
MAX_HISTORY_LENGTH = 65000

# Hardware/Calibration parameters. ###########
gain_fac = 24.0
full_scale_V = 4.5 / gain_fac
correction_factor = 2.0  # Need to revisit why we need this factor, but based on
                        # physical measurements, it is necessary
creare_volts_per_count = full_scale_V / (2.0 ** 24) * correction_factor
creare_volts_per_FS = creare_volts_per_count * 2 ** (24 - 1)  # per full scale: +/- 1.0
#############################

SAMPLE_RATE = 250.0  # Hz
CHANNELS = 8

i_sample = 0

class EEGSensor(t.HasTraits):
    preferences = t.Any()
    connected = t.Bool(False)
    serial_port = t.Instance(serial.Serial)

    com_port = t.Int()  # If None, we just search for it.
    def _com_port_default(self):
        """ Get default com port from preferences. """
        if self.preferences:
            return int(self.preferences.get('sensor.com_port', COM_SEARCH_START))
        return t.undefined
    def _com_port_changed(self, val):
        """ Save any COM port changes to preferences. """
        if self.preferences:
            return self.preferences.set('sensor.com_port', val)

    channels = t.Int(CHANNELS)
    timeseries = t.Array(dtype='float', value=np.zeros([1, CHANNELS + 1]))
    history = t.List()
    data_changed = t.Event()

    # Below, these separate properties and buttons for each channel are a bit
    #  verbose, but it seems to be the most clear way to implement this.
    channel_1_enabled = t.Bool(False)
    channel_2_enabled = t.Bool(False)
    channel_3_enabled = t.Bool(False)
    channel_4_enabled = t.Bool(False)
    channel_5_enabled = t.Bool(False)
    channel_6_enabled = t.Bool(False)
    channel_7_enabled = t.Bool(False)
    channel_8_enabled = t.Bool(False)

    channel_1_on = t.Button()
    channel_2_on = t.Button()
    channel_3_on = t.Button()
    channel_4_on = t.Button()
    channel_5_on = t.Button()
    channel_6_on = t.Button()
    channel_7_on = t.Button()
    channel_8_on = t.Button()

    channel_1_off = t.Button()
    channel_2_off = t.Button()
    channel_3_off = t.Button()
    channel_4_off = t.Button()
    channel_5_off = t.Button()
    channel_6_off = t.Button()
    channel_7_off = t.Button()
    channel_8_off = t.Button()

    # Properties
    history_length = t.Property(t.Int, depends_on="data_changed")
    def _get_history_length(self): return len(self.history)

    timeseries_length = t.Property(t.Int, depends_on="data_changed")
    def _get_timeseries_length(self): return self.timeseries.shape[0]



    @t.on_trait_change(','.join(['channel_%d_on' % i for i in range(1, 9)] +
                                ['channel_%d_off' % i for i in range(1, 9)]))
    def toggle_channels(self, name, new):
        if not self.connected:
            return
        deactivate_codes = ['1', '2', '3', '4', '5', '6', '7', '8']
        activate_codes = ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i']
        if name.endswith('_off'):
            cmd = deactivate_codes[int(name[-len('_off') - 1]) - 1]
        elif name.endswith('_on'):
            cmd = activate_codes[int(name[-len('_on') - 1]) - 1]
        else:
            raise ValueError()
        self.serial_port.write(cmd + '\n')
        # self.serial_port.write('b\n')
        time.sleep(.100)
        # self.serial_port.flushInput()
        # time.sleep(.50)


    def connect(self):
        if self.connected:
            self.disconnect()

        assert self.serial_port is None

        # If no com port is selected, search for it... this search code could
        #  be drastically sped up by analyzing a listing of actual COM ports.
        try:
            if self.com_port is None:
                for i in range(COM_SEARCH_START, COM_SEARCH_END + 1):
                    try:
                        port = 'COM%d' % i
                        self.serial_port = serial.Serial(port, BAUD, timeout=STARTUP_TIMEOUT)
                        if self.serial_port.read(1) == '':
                            self.serial_port.close()
                            self.serial_port = None
                            continue
                        else:
                            # Assume it's the right one...
                            self.serial_port.write('s\n')  # Reset.
                            self.serial_port.write('b\n')  # Start sending binary.
                            self.serial_port.read(5)  # Make sure we can read something
                            # Okay, we're convinced.
                            self.com_port = i
                            self.connected = True
                            self.serial_port.timeout = RUN_TIMEOUT
                            break
                    except serial.SerialException, e:
                        logging.warn("Couldn't open %s: %s" % (port, str(e)))
                else:
                    logging.warn("Couldn't find a functioning serial port." % (port, str(e)))

            else:  # A specific COM port is requested.
                port = 'COM%d' % self.com_port
                try:
                    self.serial_port = serial.Serial(port, BAUD, timeout=STARTUP_TIMEOUT)
                    if self.serial_port.read(1) == '':
                        self.serial_port.close()
                        self.serial_port = None
                        logging.warn('Could not read from serial port...')
                    else:
                        # Assume it's the right one...
                        self.connected = True
                        self.serial_port.timeout = RUN_TIMEOUT
                        self.serial_port.write('s\n')  # Reset.
                        self.serial_port.write('b\n')  # Start sending binary.
                        self.serial_port.read(5)  # Make sure we can read something
                        # Okay, we're convinced.

                except serial.SerialException, e:
                    self.disconnect()
                    logging.warn("Couldn't open %s: %s" % (port, str(e)))
        finally:
            if self.connected:
                self.read_input_continuously()
            else:
                self.disconnect()

    def disconnect(self):
        try:
            if self.serial_port is not None:
                self.serial_port.close()
        finally:
            self.serial_port = None
            self.connected = False

    def _read_mock_data(self, *args, **kwargs):
        """ Make synthetic noise in units of microvolts, for debugging
        purposes. """

        fs_Hz = 250  # Sample rate, Hz
        Nchan = 8  # How many channels of EEG
        Nsamples = 1  # How many samples do you want?
        foo_data = np.random.randn(Nchan)  # Gaussian noise with rms = 1.0
        data_uV = foo_data * np.sqrt(fs_Hz / 2.0)  # scale data to have RMS of 1.0 uV/sqrt(Hz)

        # The Arduino is outputting the ADS1299 as signed integers in 'counts'
        # so we need to convert microvolts to 'counts'

        # full scale at the ADS1299's internal ADC is [0 4.5] volts
        # ADS1299 set to have gain of x24 gain before ADC
        # ADS1299 issues 24-bit data from ADC, so there are 2^24 'counts'
        scale_V_per_count = 4.5 / 24 / (2 ** 24)
        data_counts = np.round((data_uV / 1e6) / scale_V_per_count)  # should be in counts [-2^23 to +2^23]
        return np.array(data_counts) / (2. ** (24 - 1))

    def _read_serial_binary(self, max_bytes_to_skip=3000):
        """
        Returns (and waits if necessary) for the next binary packet. The
        packet is returned as an array [sample_index, data1, data2, ... datan].
        
        RAISES
        ------
        RuntimeError : if it has to skip to many bytes.
        
        serial.SerialTimeoutException : if there isn't enough data to read.
        """
        global i_sample
        def read(n):
            val = self.serial_port.read(n)
            # print bytes(val),
            return val

        n_int_32 = self.channels + 1

        # Look for end of packet.
        for i in xrange(max_bytes_to_skip):
            val = read(1)
            if not val:
                if not self.serial_port.inWaiting():
                    logging.warn('Device appears to be stalled. Restarting...')
                    self.serial_port.write('b\n')  # restart if it's stopped...
                    time.sleep(.100)
                    continue
            # self.serial_port.write('b\n') , s , x
            # self.serial_port.inWaiting()
            if bytes(struct.unpack('B', val)[0]) == END_BYTE:
                # Look for the beginning of the packet, which should be next
                val = read(1)
                if bytes(struct.unpack('B', val)[0]) == START_BYTE:
                    if i > 0:
                        logging.warn("Had to skip %d bytes before finding stop/start bytes." % i)
                    # Read the number of bytes
                    val = read(1)
                    n_bytes = struct.unpack('B', val)[0]
                    if n_bytes == n_int_32 * 4:
                        # Read the rest of the packet.
                        val = read(4)
                        sample_index = struct.unpack('i', val)[0]
#                         if sample_index != 0:
#                             logging.warn("WARNING: sample_index should be zero, but sample_index == %d" % sample_index)
                        # NOTE: using i_sample, a surrogate sample count.
                        t_value = i_sample / float(SAMPLE_RATE)  # sample_index / float(SAMPLE_RATE)
                        i_sample += 1
                        val = read(4 * (n_int_32 - 1))
                        data = struct.unpack('i' * (n_int_32 - 1), val)
                        data = np.array(data) / (2. ** (24 - 1));  # make so full scale is +/- 1.0
                        # should set missing data to np.NAN here, maybe by testing for zeros..
                        # data[np.logical_not(self.channel_array)] = np.NAN  # set deactivated channels to NAN.
                        data[data == 0] = np.NAN
                        # print data
                        return np.concatenate([[t_value], data])  # A list [sample_index, data1, data2, ... datan]
                    elif n_bytes > 0:
                        print "Warning: Message length is the wrong size! %d should be %d" % (n_bytes, n_int_32 * 4)
                        # Clear the buffer of those bytes.
                        _ = read(n_bytes)
                    else:
                        raise ValueError("Warning: Message length is the wrong size! %d should be %d" % (n_bytes, n_int_32 * 4))
        raise RuntimeError("Maximum number of bytes skipped looking for binary packet (%d)" % max_bytes_to_skip)

    def read_input_buffer(self):
        """
        Reads all binary data in input buffer to arrays. If there is new data
        available, it updates the timeseries array and fires a data_changed event.
        
        Returns
        -------
        True :
            if the device is functioning properly and data readout should continue, 
        False :
            if data readout should stop.
        """

        if not self.connected:
            return False

        data_changed = False

        # Read all the data...
        while self.serial_port.inWaiting() > (self.channels + 1 * 4 + 3):

            # New data is raw, as returned from the microprocessor, but scaled -1 -> +1.
            # Here, we scale it -> uV.
            new_data = self._read_serial_binary()

            ########## Uncomment this next line for debugging purposes. #######
            # new_data[1:] = self._read_mock_data()  # overwrites real data with mock data.

            # Now, we scale from -1 -> +1, to uV:
            new_data[1:] = new_data[1:] * creare_volts_per_FS * 1.0e6  # now uV.
            self.history.append(new_data)
            data_changed = True

        if data_changed:
            # If the history gets too long, cull it:
            if len(self.history) > MAX_HISTORY_LENGTH:
                self.history = self.history[-MIN_HISTORY_LENGTH:]

            # Update the numpy timeseries array.
            self.timeseries = np.array(self.history[-TIMESERIES_LENGTH:])

            # Infer which channels are on/off... we don't keep track of this
            #  internally b/c it's safer to infer it from the Arduino output.
            [self.channel_1_enabled,
             self.channel_2_enabled,
             self.channel_3_enabled,
             self.channel_4_enabled,
             self.channel_5_enabled,
             self.channel_6_enabled,
             self.channel_7_enabled,
             self.channel_8_enabled] = np.logical_not(np.isnan(self.history[-1][1:])).tolist()
            self.data_changed = True  # fire data_changed event.

        return True

    def read_input_continuously(self):
        """ Polling function. This polls for any new data once every 
        READ_INTERVAL_MS milliseconds. If there's an error, it stops polling.
        """
        if self.read_input_buffer():
            do_after(READ_INTERVAL_MS, self.read_input_continuously)







