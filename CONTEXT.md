# Glossary

- **Core**: `PlotlyBaseExtras`, the Plotly-only Julia and JS code that renders a plot with every feature, in no
  particular host.
- **Host**: the program that shows the HTML: Pluto, the VSCode plot pane, a plain HTML file,
  KaimonSlate.
- **Adapter**: the small piece per host, one Julia entry point and one JS file, that connects
  the host to the core. An entry point is whatever the host calls to display a value: a show
  method for a MIME, or a host render hook.
- **Container**: the DOM element that holds one plot and its per-plot state. A host that can
  re-render hands the old container back so zoom and size survive.
