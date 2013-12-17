# Make sure we use PySide (fixes OS X issue)
import os
os.environ['QT_API'] = 'pyside'

# Set up Traits toolkit.
from traits.etsconfig.etsconfig import ETSConfig
ETSConfig.toolkit = 'qt4'
ETSConfig.company = 'EEGSensor'

# Standard imports
import logging, os, datetime
import numpy as np

# Enthought imports
import traits.api as t
import traitsui.api as tui
from traitsui.api import (View, Label, Item, VGroup, HGroup,
                          spring, Heading)
from traitsui.qt4.extra.qt_view import QtView
from pyface.api import ImageResource
from pyface.timer.api import do_later
from apptools.preferences.api import Preferences

# Internal imports
from hardware import EEGSensor, SAMPLE_RATE, MAX_HISTORY_LENGTH
from matplotlib.figure import Figure
from mpl import MPLFigureEditor

# We package QDarkStyle for convenience. The most current version is
#  at https://pypi.python.org/pypi/QDarkStyle
#  or https://github.com/ColinDuquesnoy/QDarkStyleSheet
# This packages is simply for aesthetics.
import qdarkstyle

preferences = Preferences(filename=os.path.join(ETSConfig.get_application_home(True), 'preferences.ini'))

# Custom parameters.
X_WIDTH_S = 6.0
PLOT_STEP = 1

class SensorOperationController(tui.Controller):
    """ UI for controlling the hardware. """

    model = t.Instance(EEGSensor)
    connect = t.Button()
    disconnect = t.Button()

    def _connect_changed(self):
        self.model.connect()

    def _disconnect_changed(self):
        self.model.disconnect()

    traits_view = View(
                   HGroup(
                       spring,
                       VGroup(
                          HGroup(spring, Heading('EEG Sensor Controls'), spring),
                          VGroup(Item('com_port', style='simple', enabled_when="not object.connected"),
                                 Item('object.connected', style='readonly'),
                                 # Item('history_length', style='readonly'),
                                 # Item('timeseries_length', style='readonly'),
                                 show_labels=True
                                 ),
                          HGroup(# spring,
                              Item('controller.connect', enabled_when='not object.connected'),
                              Item('controller.disconnect', enabled_when='object.connected'),
                              spring,
                              show_labels=False),
                          Label('Last %d points saved to disk on exit.' % MAX_HISTORY_LENGTH),
                          ),
                       spring,
                       tui.VGrid(
                                Heading('Activate Ch:'),
                                Item('channel_1_on', label='1', enabled_when='not channel_1_enabled'),
                                Item('channel_2_on', label='2', enabled_when='not channel_2_enabled'),
                                Item('channel_3_on', label='3', enabled_when='not channel_3_enabled'),
                                Item('channel_4_on', label='4', enabled_when='not channel_4_enabled'),
                                Item('channel_5_on', label='5', enabled_when='not channel_5_enabled'),
                                Item('channel_6_on', label='6', enabled_when='not channel_6_enabled'),
                                Item('channel_7_on', label='7', enabled_when='not channel_7_enabled'),
                                Item('channel_8_on', label='8', enabled_when='not channel_8_enabled'),

                                Heading('Deactivate Ch:'),
                                Item('channel_1_off', label='1', enabled_when='channel_1_enabled'),
                                Item('channel_2_off', label='2', enabled_when='channel_2_enabled'),
                                Item('channel_3_off', label='3', enabled_when='channel_3_enabled'),
                                Item('channel_4_off', label='4', enabled_when='channel_4_enabled'),
                                Item('channel_5_off', label='5', enabled_when='channel_5_enabled'),
                                Item('channel_6_off', label='6', enabled_when='channel_6_enabled'),
                                Item('channel_7_off', label='7', enabled_when='channel_7_enabled'),
                                Item('channel_8_off', label='8', enabled_when='channel_8_enabled'),
                                show_labels=False,
                                show_border=True,
                                columns=9,
                                enabled_when='object.connected'
                            ),
                        spring,
                      ),
                   )

from scipy.signal import lfilter
class TimeDomainFilter(t.HasTraits):
    """ FIR filter """
    b = t.Array()
    a = t.Array()
    type = t.Enum(['BandPass'])

    def apply(self, signal):
        if self.type == 'BandPass':
            return lfilter(self.b, self.a, signal)
        else:
            raise NotImplementedError('Filter type %s not implemented' % self.type)

class SensorTimeseriesController(tui.ModelView):
    """ UI for a "ganged" timeseries plot. """
    model = t.Instance(EEGSensor)
    figure = t.Instance(Figure, ())
    lines = t.List(t.Any)
    axes = t.Any
    axes_r = t.Any
    filters = t.List(t.Instance(TimeDomainFilter))

    y_lim_uv = t.Float(100)

    view = View(Item('figure', editor=MPLFigureEditor(),
                            show_label=False,
                            springy=True,
                     full_size=True,),
                    width=400,
                    height=700,

                    resizable=True)

    def __init__(self, model=None, **metadata):
        """ Set up and initialize the plot. """
        tui.ModelView.__init__(self, model=model, **metadata)
        axes = self.figure.add_subplot(111)
        self.lines = []
        y_ticks = []
        y_labels = []
        y_labels2 = []
        for i in range(self.model.timeseries.shape[1] - 1):
            line, = axes.plot(self.model.timeseries[::PLOT_STEP, 0],
                              self.model.timeseries[::PLOT_STEP, i + 1] / self.y_lim_uv + i,
                              color='mistyrose',
                              alpha=.75,
                              linewidth=0.5)
            self.lines.append(line)
            y_ticks.append(i)
            y_labels.append('Ch %d' % (i + 1))
            y_labels2.append('Mean: 0.0\nRMS: 0.0')
        axes.set_title('EEG Timeseries')
        # axes.set_ylabel('Amplitude')
        axes.set_xlabel('Time [s]')
        axes.set_xlim(0, X_WIDTH_S, auto=False)
        axes.set_ylim(-1, self.model.timeseries.shape[1] - 1, auto=False)
        axes.set_yticks(y_ticks)
        axes.set_yticklabels(y_labels)
        self.axes = axes

        # Right axes
#         self.axes_r = self.figure.add_subplot(1, 1, 1, sharex=axes, frameon=False)
#         self.axes_r.yaxis.tick_right()
#         self.axes_r.yaxis.set_label_position("right")
#         self.axes_r.set_yticks(y_ticks)
#         self.axes_r.tick_params(axis='y', which='both', length=0)
#         self.axes_r.set_yticklabels(y_labels2, {'size':8})
#         self.axes_r.set_ylim(-1, self.model.timeseries.shape[1] - 1, auto=False)

        # l/b/r/t
        do_later(self.figure.tight_layout)  # optimize padding and layout after everything's set up.


    @t.on_trait_change('model.data_changed')
    def update_plot(self):
        """ Update the plot with new data """
        if self.model.timeseries.shape[0] < 2:
            return
        y_labels2 = []
        for i, line in enumerate(self.lines):
            y = self.model.timeseries[:, i + 1]
            nan_mask = np.isnan(y)
            y[nan_mask] = 0  # otherwise, a single NAN causes the filtering to fail.
            y = y - y.mean()
            for filter in self.filters:
                # Note that we re-apply the time-domain filter for every single update.
                y = filter.apply(y)

            y[nan_mask] = np.NAN  # put the NAN's back so they're not plotted.
            line.set_data(self.model.timeseries[::PLOT_STEP, 0] ,  # x
                          y[::PLOT_STEP] / self.y_lim_uv + i  # y
                          )
            y_labels2.append('Mean: %0.3f\nRMS: %0.3f' %
                             (y.mean(), np.sqrt(np.mean(np.square(y))))
                             )

#         self.axes_r.set_yticklabels(y_labels2, {'size':6})
        self.axes.set_xlim(max(np.max(self.model.timeseries[:, 0]), X_WIDTH_S) - X_WIDTH_S,
                      max(np.max(self.model.timeseries[:, 0]), X_WIDTH_S))
        self.figure.canvas.draw()


class SensorFFTController(tui.ModelView):
    """ UI for spectral plot. """

    model = t.Instance(EEGSensor)
    figure = t.Instance(Figure, ())
    lines = t.List(t.Any)
    axes = t.Any

    n_fft = t.Int(256)
    overlap = t.Float(0.75)

    view = View(Item('figure', editor=MPLFigureEditor(),
                            show_label=False,
                            springy=True,
                            full_size=True,),
                    width=350,
                    height=450,
                    resizable=True)

    def __init__(self, model=None, **metadata):
        """ Setup and initialize the plot. """
        tui.ModelView.__init__(self, model=model, **metadata)
        axes = self.figure.add_subplot(111)
        self.lines = []
        for i in range(self.model.timeseries.shape[1] - 1):
            line, = axes.plot([0], [1],
                              color='mistyrose',
                              alpha=.5)
            self.lines.append(line)

        axes.set_title('Frequency Content')
        axes.set_ylabel(r'Signal Strength ($\mu$V/sqrt(Hz))')
        axes.set_xlabel('Frequency (Hz)')
        axes.set_xticks([i * 10 for i in range(10)])  # multiples of 10
        axes.set_xlim(0, 65,  # SAMPLE_RATE / 2,
                      auto=False)

#         axes.set_ylim(-1, self.model.timeseries.shape[1] - 1, auto=False)
#         axes.set_yticks(y_ticks)
#         axes.set_yticklabels(y_labels)
        axes.set_yscale('log')
        self.axes = axes
        # l/b/r/t
        do_later(self.figure.tight_layout)  # optimize padding and layout after everything's set up.

    def _windowed_fft(self, data, fs):
        """ Applies a Hanning window, calculates FFT, and returns one-sided
        FFT as well as corresponding frequency vector.
        """
        N = len(data)
        window = np.hanning(N)
        win_pow = np.mean(window ** 2)
        windowed_data = np.fft.fft(data * window) / np.sqrt(win_pow)
        # freqs = np.linspace(0, 1, N, endpoint=True) * fs
        pD = np.abs(windowed_data * np.conjugate(windowed_data) / N ** 2)
        freqs = np.fft.fftfreq(N, 1 / float(fs))
        f = freqs[:N / 2 ]
        pD = pD[:N / 2 ]
        pD[1:] = pD[1:] * 2
        return pD, f

    @t.on_trait_change('model.data_changed')
    def update_plot(self):
        """ Update the plot with new data """
        n_data_pts = self.model.timeseries.shape[0]
        if n_data_pts < self.n_fft:
            return

        if n_data_pts >= 2 * self.n_fft:
            n_offset = 2 * self.n_fft
        else:
            n_offset = self.n_fft

        data_to_process = self.model.timeseries[-n_offset:]

        hz_per_bin = float(SAMPLE_RATE) / self.n_fft

        min_psds = []
        max_psds = []
        for i, line in enumerate(self.lines):
            y = data_to_process[:, i + 1]
            nan_mask = np.isnan(y)
            y[nan_mask] = 0  # otherwise, a single NAN causes the filtering to fail.
            y = y - y.mean()
            psd, f = self._windowed_fft(y, SAMPLE_RATE)
            psd_per_bin = psd / hz_per_bin
            line.set_data(f,  # x
                          np.sqrt(psd_per_bin)  # y
                          )
            min_psds.append(psd_per_bin.min())
            max_psds.append(psd_per_bin.max())
        self.axes.set_ylim(.1,
                           100)  # np.min(min_psds) * .75 + 1e-10, np.max(max_psds) * 1.33)
        self.figure.canvas.draw()




class AppHandler(tui.Handler):
    def close(self, info, isok):
        app = info.object  # convenience
        app.sensor.disconnect()
        file_name = os.path.join(ETSConfig.get_application_home(True),
                                 'sensor_output %s.csv' % str(datetime.datetime.now()).replace(':', '-'))
        # make sure directory exists.
        if not os.path.exists(ETSConfig.get_application_home(False)):
            os.makedirs(ETSConfig.get_application_home(False))
        arr = np.array(app.sensor.history)

        if not arr.size:
            return isok

        np.savetxt(file_name,
                   arr)
        msg = 'Output (size %s) saved to %s.' % (str(arr.shape), file_name)
        logging.info(msg)
        from pyface.api import information
        information(info.ui.control, msg, title='Array saved to disk.')
        return isok

#     def position(self, info):
#         """ Maximize the window... """
#         ret = tui.Handler.position(self, info)
#         info.ui.control.showMaximized()
#         return ret

class EEGSensorApp(t.HasTraits):

    sensor = t.Instance(EEGSensor)
    filters = t.List(t.Instance(TimeDomainFilter))

    sensor_operation_controller = t.Instance(SensorOperationController)
    def _sensor_operation_controller_default(self):
        return SensorOperationController(model=self.sensor)

    sensor_timeseries_controller = t.Instance(SensorTimeseriesController)
    def _sensor_timeseries_controller_default(self):
        return SensorTimeseriesController(model=self.sensor,
                                          filters=self.filters)

    sensor_fft_controller = t.Instance(SensorFFTController)
    def _sensor_fft_controller_default(self):
        return SensorFFTController(model=self.sensor)


    traits_view = QtView(
                     HGroup(
                         VGroup(
                            Item('sensor_timeseries_controller', style='custom'),
                            show_border=True,
                            show_labels=False
                          ),
                         VGroup(
                            Item('sensor_fft_controller', style='custom'),
                            Item('sensor_operation_controller', style='custom'),
                            show_border=True,
                            show_labels=False
                          ),
                        ),

                    title="EEG Sensor Console",
                    icon=ImageResource('application'),
                    # style_sheet_path='dark_style_sheet.qss',
                    style_sheet=qdarkstyle.load_stylesheet(pyside=True),
                    resizable=True,
                    handler=AppHandler(),
                    )


if __name__ == "__main__":
    try:
        logging.info('---------- STARTING ---------')
        from scipy.io import loadmat
        mat = loadmat('bp_filter_coeff.mat')
        filters = [TimeDomainFilter(b=mat['bp_filter_coeff']['b'][0, 0].squeeze(),
                                    a=mat['bp_filter_coeff']['a'][0, 0].squeeze()),
                   TimeDomainFilter(b=mat['bp_filter_coeff']['b_notch'][0, 0].squeeze(),
                                    a=mat['bp_filter_coeff']['a_notch'][0, 0].squeeze()), ]
        app = EEGSensorApp(sensor=EEGSensor(preferences=preferences),
                           filters=filters)
        app.configure_traits(id='eeg_main_app')
    finally:
        preferences.flush()
        logging.shutdown()

