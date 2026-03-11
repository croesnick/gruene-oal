defmodule Mix.Tasks.Wahlanalyse2026Ostallgaeu.ExportMap do
  use Mix.Task

  @moduledoc "Exports interactive HTML maps for election results"

  @moduledoc """
  Mix task to generate interactive HTML maps showing election results for Grüne and AfD parties.
  """
  alias Wahlanalyse2026Ostallgaeu.GeoJSON

  def run(_args) do
    Mix.Task.run("app.start")

    election_data = Wahlanalyse2026Ostallgaeu.Analysis.load_all_data()

    case GeoJSON.load_local_geojson() do
      {:ok, geojson_data} ->
        features = geojson_data["features"]
        ostallgaeu_features = GeoJSON.filter_ostallgaeu(features)

        matched_data =
          GeoJSON.match_with_election_data(
            ostallgaeu_features,
            election_data
          )

        generate_gruene_map(matched_data)
        generate_afd_map(matched_data)
        IO.puts("Maps generated successfully!")

      {:error, reason} ->
        IO.puts("Error: #{reason}")
    end
  end

  defp generate_gruene_map(matched_data) do
    election_data_js = Jason.encode!(matched_data)

    html = """
    <!DOCTYPE html>
    <html lang="de">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Wahlergebnisse für Bündnis 90/Die Grünen in Ostallgaeu</title>
      <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
      <style>
        #map { height: 600px; }
        .legend {
          position: absolute;
          bottom: 10px;
          right: 10px;
          background: white;
          padding: 10px;
          border: 1px solid #ccc;
          border-radius: 5px;
        }
        .legend-item {
          display: flex;
          align-items: center;
          margin-bottom: 5px;
        }
        .legend-color {
          width: 20px;
          height: 20px;
          margin-right: 5px;
        }
      </style>
    </head>
    <body>
      <div id="map"></div>
      <div class="legend">
        <div class="legend-item"><div class="legend-color" style="background-color: #ffffff;"></div> <span>0%</span></div>
        <div class="legend-item"><div class="legend-color" style="background-color: #90ee90;"></div> <span>10%</span></div>
        <div class="legend-item"><div class="legend-color" style="background-color: #006400;"></div> <span>20%+</span></div>
      </div>
      <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
      <script>
        const map = L.map("map").setView([47.8, 10.5], 9);
        L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
          attribution: "&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors"
        }).addTo(map);
        const electionData = #{election_data_js};
        electionData.forEach(([feature, area]) => {
          const ags = feature.properties.ags;
          const name = feature.properties.name;
          const gruenePercentage = area.parteien.find(p => p.kurzbezeichnung === "GRÜNE")?.anteil || 0;
          const color = calculateColor(gruenePercentage, "GRÜNE");
          const geoJsonLayer = L.geoJSON(feature, {
            style: {
              fillColor: color,
              weight: 2,
              opacity: 1,
              color: "white",
              dashArray: "3",
              fillOpacity: 0.7
            },
            onEachFeature: (feature, layer) => {
              layer.bindTooltip(
                "<strong>" + name + "</strong><br>" +
                "Grüne: " + gruenePercentage.toFixed(1) + "%",
                {permanent: false, direction: "top"}
              );
            }
          }).addTo(map);
        });
        function calculateColor(percentage, party) {
          if (party === "GRÜNE") {
            if (percentage <= 10) {
              return interpolateColor("#ffffff", "#90ee90", percentage / 10);
            } else {
              return interpolateColor("#90ee90", "#006400", (percentage - 10) / 10);
            }
          } else if (party === "AfD") {
            if (percentage <= 10) {
              return interpolateColor("#ffffff", "#87ceeb", percentage / 10);
            } else {
              return interpolateColor("#87ceeb", "#00008b", (percentage - 10) / 10);
            }
          }
          return "#ffffff";
        }
        function interpolateColor(color1, color2, ratio) {
          const r1 = parseInt(color1.slice(1, 3), 16);
          const g1 = parseInt(color1.slice(3, 5), 16);
          const b1 = parseInt(color1.slice(5, 7), 16);
          const r2 = parseInt(color2.slice(1, 3), 16);
          const g2 = parseInt(color2.slice(3, 5), 16);
          const b2 = parseInt(color2.slice(5, 7), 16);
          const r = Math.round(r1 + (r2 - r1) * ratio);
          const g = Math.round(g1 + (g2 - g1) * ratio);
          const b = Math.round(b1 + (b2 - b1) * ratio);
          return "#" + r.toString(16).padStart(2, "0") + g.toString(16).padStart(2, "0") + b.toString(16).padStart(2, "0");
        }
      </script>
    </body>
    </html>
    """

    File.write!("docs/kreistag2026.html", html)
  end

  defp generate_afd_map(matched_data) do
    election_data_js = Jason.encode!(matched_data)

    html = """
    <!DOCTYPE html>
    <html lang="de">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Wahlergebnisse für Alternative für Deutschland in Ostallgaeu</title>
      <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
      <style>
        #map { height: 600px; }
        .legend {
          position: absolute;
          bottom: 10px;
          right: 10px;
          background: white;
          padding: 10px;
          border: 1px solid #ccc;
          border-radius: 5px;
        }
        .legend-item {
          display: flex;
          align-items: center;
          margin-bottom: 5px;
        }
        .legend-color {
          width: 20px;
          height: 20px;
          margin-right: 5px;
        }
      </style>
    </head>
    <body>
      <div id="map"></div>
      <div class="legend">
        <div class="legend-item"><div class="legend-color" style="background-color: #ffffff;"></div> <span>0%</span></div>
        <div class="legend-item"><div class="legend-color" style="background-color: #87ceeb;"></div> <span>10%</span></div>
        <div class="legend-item"><div class="legend-color" style="background-color: #00008b;"></div> <span>20%+</span></div>
      </div>
      <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
      <script>
        const map = L.map("map").setView([47.8, 10.5], 9);
        L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
          attribution: "&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors"
        }).addTo(map);
        const electionData = #{election_data_js};
        electionData.forEach(([feature, area]) => {
          const ags = feature.properties.ags;
          const name = feature.properties.name;
          const afdPercentage = area.parteien.find(p => p.kurzbezeichnung === "AfD")?.anteil || 0;
          const color = calculateColor(afdPercentage, "AfD");
          const geoJsonLayer = L.geoJSON(feature, {
            style: {
              fillColor: color,
              weight: 2,
              opacity: 1,
              color: "white",
              dashArray: "3",
              fillOpacity: 0.7
            },
            onEachFeature: (feature, layer) => {
              layer.bindTooltip(
                "<strong>" + name + "</strong><br>" +
                "AfD: " + afdPercentage.toFixed(1) + "%",
                {permanent: false, direction: "top"}
              );
            }
          }).addTo(map);
        });
        function calculateColor(percentage, party) {
          if (party === "GRÜNE") {
            if (percentage <= 10) {
              return interpolateColor("#ffffff", "#90ee90", percentage / 10);
            } else {
              return interpolateColor("#90ee90", "#006400", (percentage - 10) / 10);
            }
          } else if (party === "AfD") {
            if (percentage <= 10) {
              return interpolateColor("#ffffff", "#87ceeb", percentage / 10);
            } else {
              return interpolateColor("#87ceeb", "#00008b", (percentage - 10) / 10);
            }
          }
          return "#ffffff";
        }
        function interpolateColor(color1, color2, ratio) {
          const r1 = parseInt(color1.slice(1, 3), 16);
          const g1 = parseInt(color1.slice(3, 5), 16);
          const b1 = parseInt(color1.slice(5, 7), 16);
          const r2 = parseInt(color2.slice(1, 3), 16);
          const g2 = parseInt(color2.slice(3, 5), 16);
          const b2 = parseInt(color2.slice(5, 7), 16);
          const r = Math.round(r1 + (r2 - r1) * ratio);
          const g = Math.round(g1 + (g2 - g1) * ratio);
          const b = Math.round(b1 + (b2 - b1) * ratio);
          return "#" + r.toString(16).padStart(2, "0") + g.toString(16).padStart(2, "0") + b.toString(16).padStart(2, "0");
        }
      </script>
    </body>
    </html>
    """

    File.write!("docs/karte_afd.html", html)
  end
end
