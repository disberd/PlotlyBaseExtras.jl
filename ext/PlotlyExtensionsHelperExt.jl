module PlotlyExtensionsHelperExt

import PlotlyBaseExtras, PlotlyExtensionsHelper

# Priority 30 is above PlutoPlotly (20), PlotlyJS (10) and PlotlyBase (0), so
# `plotly_plot` uses this package when it is loaded. The call must stay in
# `__init__`: the precompilation cache does not keep a registration made at the
# top level of the module.
__init__() = PlotlyExtensionsHelper.register_plot_func!(:PlotlyBaseExtras, PlotlyBaseExtras.plot; priority = 30)

end
