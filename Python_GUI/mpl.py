""" Provides a TraitsUI/PyQT compatible Matplotlib Figure that uses a dark
style compatible with the 'qdarkstyle' package. """

# Standard imports
import matplotlib
matplotlib.use('Qt4Agg')
from matplotlib.backends.backend_qt4agg import FigureCanvasQTAgg as FigureCanvas

# Enthought imports
from traitsui.qt4.editor import Editor
from traitsui.qt4.basic_editor_factory import BasicEditorFactory

# This code is inspired by the MPLTOOLS package, see
# https://github.com/tonysyu/mpltools for more info.
matplotlib.rcParams['lines.color'] = 'white'
matplotlib.rcParams['patch.edgecolor'] = 'white'

matplotlib.rcParams['text.color'] = 'white'

matplotlib.rcParams['axes.facecolor'] = 'black'
matplotlib.rcParams['axes.edgecolor'] = 'white'
matplotlib.rcParams['axes.labelcolor'] = 'white'
matplotlib.rcParams['axes.color_cycle'] = ['#8dd3c7', '#feffb3', '#bfbbd9', '#fa8174', '#81b1d2', '#fdb462', '#b3de69', '#bc82bd', '#ccebc4', '#ffed6f']

matplotlib.rcParams['xtick.color'] = 'white'
matplotlib.rcParams['ytick.color'] = 'white'

matplotlib.rcParams['grid.color'] = 'white'

matplotlib.rcParams['figure.facecolor'] = 'black'
matplotlib.rcParams['figure.edgecolor'] = 'black'

matplotlib.rcParams['savefig.facecolor'] = 'black'
matplotlib.rcParams['savefig.edgecolor'] = 'black'


# To match the qdarkstyle qss
matplotlib.rcParams['figure.facecolor'] = '#302F2F'
matplotlib.rcParams['axes.edgecolor'] = '#3A3939'
matplotlib.rcParams['text.color'] = 'silver'
matplotlib.rcParams['lines.linewidth'] = 2.0
matplotlib.rcParams['lines.solid_joinstyle'] = 'round'
matplotlib.rcParams['lines.solid_capstyle'] = 'round'
# matplotlib.rcParams['ytick.color'] = '#00ff00'
# matplotlib.rcParams['xtick.color'] = '#0ED5D5'
# matplotlib.rcParams['axes.labelcolor'] = '#0ED5D5'
matplotlib.rcParams['axes.facecolor'] = '#201F1F'
matplotlib.rcParams['grid.color'] = '#3A3939'
matplotlib.rcParams['grid.linestyle'] = '-'
matplotlib.rcParams['lines.markeredgewidth'] = 0.0


class _MPLFigureEditor(Editor):

    scrollable = True

    def init(self, parent):
        self.control = self._create_canvas(parent)
        self.set_tooltip()

    def update_editor(self):
        pass

    def _create_canvas(self, parent):
        """ Create the MPL canvas. """
        # matplotlib commands to create a canvas
        mpl_canvas = FigureCanvas(self.value)
        return mpl_canvas

class MPLFigureEditor(BasicEditorFactory):
    klass = _MPLFigureEditor
