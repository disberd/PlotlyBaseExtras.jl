module UnitfulExt

using PlotlyBaseExtras: _process_with_names, PlotlyBaseExtras, AttrName
using Unitful: Quantity, ustrip

PlotlyBaseExtras._process_with_names(q::Quantity, fl::Val, @nospecialize(args::Vararg{AttrName})) = _process_with_names(ustrip(q), fl, args...)

end