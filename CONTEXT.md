# Glossary

- **Core**: `PlotlyBaseExtras`, the Plotly-only Julia and JS code that renders a plot with every feature, in no
  particular host.
- **Host**: the program that shows the HTML: Pluto, the VSCode plot pane, a plain HTML file,
  KaimonSlate.
- **Adapter**: the small piece per host, one Julia entry point and one JS file, that connects
  the host to the core. An entry point is whatever the host calls to display a value: a show
  method for a MIME, or a host render hook.
- **Container**: the DOM element that holds one plot and its per-plot state. When a host shows a
  plot again, the adapter uses the old container again, so zoom and size survive. The host can
  give it back, or the adapter can find it itself.
- **Data channel**: the way a host moves the plot data from Julia to the page. Examples: text in
  the HTML, a Pluto published object. _Avoid_: carrier.
- **Export pop-out**: the detached, resizable state of a container. Its header sets the width,
  height, scale and filename of the exported image. A double-click on an export button opens it.
  _Avoid_: detach, popped-out.
- **Copy dialog**: the modal view that shows the exported PNG when the browser refuses a
  clipboard write. The user copies the image from it by hand. _Avoid_: paste receiver, preview.
- **Page**: one standalone HTML file that holds one or more independent plots, each in its own
  container. The plain HTML host shows it. A page is not one figure with subplots.
  _Avoid_: report, dashboard, document.
