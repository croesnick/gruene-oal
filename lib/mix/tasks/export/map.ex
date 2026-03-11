defmodule Mix.Tasks.Export.Map do
  use Mix.Task

  @shortdoc "Exports interactive HTML maps for election results"

  @moduledoc """
  Mix task to generate interactive HTML maps showing election results for Grüne and AfD parties.
  Supports drill-down from Gemeinden to Stimmbezirke on double-click.
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

        # Group stimmbezirke by parent_id for drill-down
        stimmbezirke_by_parent = group_stimmbezirke_by_parent(election_data)

        generate_gruene_map(matched_data, stimmbezirke_by_parent)
        generate_afd_map(matched_data, stimmbezirke_by_parent)
        IO.puts("Maps generated successfully!")

      {:error, reason} ->
        IO.puts("Error: #{reason}")
    end
  end

  defp group_stimmbezirke_by_parent(election_data) do
    election_data
    |> Enum.filter(fn a -> a.type == :stimmbezirk end)
    |> Enum.group_by(fn sb -> sb.parent_id end)
  end

  defp generate_gruene_map(matched_data, stimmbezirke_by_parent) do
    matched_data_json = Enum.map(matched_data, fn {feature, area} -> [feature, area] end)
    election_data_js = Jason.encode!(matched_data_json)
    stimmbezirke_js = Jason.encode!(stimmbezirke_by_parent)

    html = """
    <!DOCTYPE html>
    <html lang="de">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Grüne Wahlergebnisse - Kreistagswahl 2026 Ostallgäu</title>
      <script src="https://cdn.tailwindcss.com"></script>
      <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
      <style>
        #map { height: calc(100vh - 80px); }
        .leaflet-popup-content-wrapper { border-radius: 12px; }
        .stimmbezirk-item { transition: all 0.2s; }
        .stimmbezirk-item:hover { transform: translateX(4px); }
      </style>
    </head>
    <body class="bg-gray-50">
      <header class="bg-gradient-to-r from-green-600 to-green-700 text-white shadow-lg">
        <div class="max-w-7xl mx-auto px-4 py-4 flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold" id="header-title">Bündnis 90/Die Grünen</h1>
            <p class="text-green-100 text-sm" id="header-subtitle">Kreistagswahl 2026 - Landkreis Ostallgäu</p>
          </div>
          <button id="back-btn" class="hidden bg-white/20 hover:bg-white/30 px-4 py-2 rounded-lg font-medium transition-all flex items-center gap-2">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"/>
            </svg>
            Zurück
          </button>
        </div>
      </header>
      <main class="relative flex">
        <div id="map" class="flex-1"></div>
        
        <!-- Detail Panel for Stimmbezirke -->
        <div id="detail-panel" class="hidden w-96 bg-white shadow-xl border-l border-gray-200 overflow-y-auto" style="height: calc(100vh - 80px)">
          <div class="p-4">
            <h2 id="detail-title" class="text-xl font-bold text-gray-900 mb-4"></h2>
            <div id="stimmbezirke-list"></div>
          </div>
        </div>
        
        <!-- Legend -->
        <div class="absolute bottom-6 right-6 bg-white rounded-xl shadow-xl p-4 z-[1000]" id="legend">
          <h3 class="text-sm font-semibold text-gray-700 mb-2">Anteil in %</h3>
          <div class="flex items-center gap-2 text-xs mb-1">
            <div class="w-6 h-4 rounded" style="background: #dcfce7"></div>
            <span class="text-gray-600">0 - 10%</span>
          </div>
          <div class="flex items-center gap-2 text-xs mb-1">
            <div class="w-6 h-4 rounded" style="background: #86efac"></div>
            <span class="text-gray-600">10 - 15%</span>
          </div>
          <div class="flex items-center gap-2 text-xs mb-1">
            <div class="w-6 h-4 rounded" style="background: #22c55e"></div>
            <span class="text-gray-600">15 - 20%</span>
          </div>
          <div class="flex items-center gap-2 text-xs">
            <div class="w-6 h-4 rounded" style="background: #15803d"></div>
            <span class="text-gray-600">20%+</span>
          </div>
          <div class="mt-3 pt-3 border-t border-gray-200 text-xs text-gray-500">
            Doppelklick für Stimmbezirke
          </div>
        </div>
      </main>
      <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
      <script>
        const map = L.map("map").setView([47.85, 10.65], 10);
        L.tileLayer("https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png", {
          attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> &copy; <a href="https://carto.com/attributions">CARTO</a>',
          subdomains: "abcd",
          maxZoom: 19
        }).addTo(map);

        const electionData = #{election_data_js};
        const stimmbezirkeByParent = #{stimmbezirke_js};
        
        let currentLayer = null;

        function showOverview() {
          document.getElementById('back-btn').classList.add('hidden');
          document.getElementById('detail-panel').classList.add('hidden');
          document.getElementById('legend').classList.remove('hidden');
          document.getElementById('header-title').textContent = 'Bündnis 90/Die Grünen';
          document.getElementById('header-subtitle').textContent = 'Kreistagswahl 2026 - Landkreis Ostallgäu';
          
          if (currentLayer) map.removeLayer(currentLayer);
          currentLayer = L.layerGroup();
          
          electionData.forEach(([feature, area]) => {
            const name = feature.properties.name;
            const grueneParty = area.parteien.find(p => p.kurzbezeichnung === "GRÜNE");
            const gruenePercentage = grueneParty?.anteil || 0;
            const color = getColor(gruenePercentage);
            const ags = feature.properties.ags;

            const layer = L.geoJSON(feature, {
              style: { fillColor: color, weight: 2, opacity: 1, color: "#ffffff", fillOpacity: 0.75 },
              onEachFeature: (feature, layer) => {
                layer.on({
                  mouseover: (e) => e.target.setStyle({ weight: 4, color: "#666" }),
                  mouseout: (e) => e.target.setStyle({ weight: 2, color: "#fff" }),
                  dblclick: (e) => { L.DomEvent.stopPropagation(e); showStimmbezirke(ags, name, area); }
                });
                layer.bindPopup(`
                  <div class="p-2 min-w-48">
                    <h3 class="font-bold text-gray-900 text-lg">${name}</h3>
                    <div class="mt-2 pt-2 border-t border-gray-200">
                      <div class="flex items-center justify-between">
                        <span class="text-green-600 font-semibold">Grüne</span>
                        <span class="text-2xl font-bold text-gray-900">${gruenePercentage.toFixed(1)}%</span>
                      </div>
                      <div class="w-full bg-gray-200 rounded-full h-2 mt-2">
                        <div class="bg-green-500 h-2 rounded-full" style="width: ${Math.min(gruenePercentage, 100)}%"></div>
                      </div>
                    </div>
                    <div class="mt-3 text-xs text-gray-500 text-center">Doppelklick für Stimmbezirke</div>
                  </div>
                `);
              }
            });
            currentLayer.addLayer(layer);
          });
          
          currentLayer.addTo(map);
          map.setView([47.85, 10.65], 10);
        }

        function showStimmbezirke(ags, gemeindeName, gemeindeArea) {
          const stimmbezirke = stimmbezirkeByParent[ags];
          if (!stimmbezirke || stimmbezirke.length === 0) {
            alert('Keine Stimmbezirksdaten verfügbar für ' + gemeindeName);
            return;
          }
          
          document.getElementById('back-btn').classList.remove('hidden');
          document.getElementById('detail-panel').classList.remove('hidden');
          document.getElementById('legend').classList.add('hidden');
          document.getElementById('header-title').textContent = gemeindeName;
          document.getElementById('header-subtitle').textContent = `${stimmbezirke.length} Stimmbezirke`;
          
          if (currentLayer) map.removeLayer(currentLayer);
          currentLayer = L.layerGroup();
          
          let listHtml = '';
          stimmbezirke.sort((a, b) => {
            const aPct = a.parteien.find(p => p.kurzbezeichnung === "GRÜNE")?.anteil || 0;
            const bPct = b.parteien.find(p => p.kurzbezeichnung === "GRÜNE")?.anteil || 0;
            return bPct - aPct;
          }).forEach((sb) => {
            const gruene = sb.parteien.find(p => p.kurzbezeichnung === "GRÜNE");
            const afd = sb.parteien.find(p => p.kurzbezeichnung === "AfD");
            const gruenePct = gruene?.anteil || 0;
            const afdPct = afd?.anteil || 0;
            const color = getColor(gruenePct);
            
            listHtml += `
              <div class="stimmbezirk-item p-3 rounded-lg mb-2 border border-gray-200" style="border-left: 4px solid ${color}">
                <div class="font-medium text-gray-900">${sb.name}</div>
                <div class="mt-2 grid grid-cols-2 gap-2 text-sm">
                  <div><span class="text-green-600">Grüne:</span> <span class="font-semibold ml-1">${gruenePct.toFixed(1)}%</span></div>
                  <div><span class="text-sky-600">AfD:</span> <span class="font-semibold ml-1">${afdPct.toFixed(1)}%</span></div>
                </div>
                <div class="mt-2 flex gap-1">
                  <div class="flex-1 bg-gray-200 rounded-full h-1.5"><div class="bg-green-500 h-1.5 rounded-full" style="width: ${Math.min(gruenePct, 100)}%"></div></div>
                  <div class="flex-1 bg-gray-200 rounded-full h-1.5"><div class="bg-sky-500 h-1.5 rounded-full" style="width: ${Math.min(afdPct, 100)}%"></div></div>
                </div>
              </div>
            `;
          });
          
          document.getElementById('stimmbezirke-list').innerHTML = listHtml;
          
          const gemeindeFeature = electionData.find(([f, a]) => f.properties.ags === ags);
          if (gemeindeFeature) {
            const [feature, area] = gemeindeFeature;
            const layer = L.geoJSON(feature, {
              style: { fillColor: "#e5e7eb", weight: 2, opacity: 1, color: "#9ca3af", fillOpacity: 0.3 }
            });
            currentLayer.addLayer(layer);
            map.fitBounds(layer.getBounds(), { padding: [50, 50] });
          }
          
          currentLayer.addTo(map);
        }

        document.getElementById('back-btn').addEventListener('click', showOverview);

        function getColor(percentage) {
          if (percentage < 10) return interpolateColor("#dcfce7", "#86efac", percentage / 10);
          if (percentage < 15) return interpolateColor("#86efac", "#22c55e", (percentage - 10) / 5);
          if (percentage < 20) return interpolateColor("#22c55e", "#15803d", (percentage - 15) / 5);
          return "#15803d";
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

        showOverview();
      </script>
    </body>
    </html>
    """

    File.write!("results/karte_gruene.html", html)
  end

  defp generate_afd_map(matched_data, stimmbezirke_by_parent) do
    matched_data_json = Enum.map(matched_data, fn {feature, area} -> [feature, area] end)
    election_data_js = Jason.encode!(matched_data_json)
    stimmbezirke_js = Jason.encode!(stimmbezirke_by_parent)

    html = """
    <!DOCTYPE html>
    <html lang="de">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>AfD Wahlergebnisse - Kreistagswahl 2026 Ostallgäu</title>
      <script src="https://cdn.tailwindcss.com"></script>
      <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
      <style>
        #map { height: calc(100vh - 80px); }
        .leaflet-popup-content-wrapper { border-radius: 12px; }
        .stimmbezirk-item { transition: all 0.2s; }
        .stimmbezirk-item:hover { transform: translateX(4px); }
      </style>
    </head>
    <body class="bg-gray-50">
      <header class="bg-gradient-to-r from-sky-600 to-blue-700 text-white shadow-lg">
        <div class="max-w-7xl mx-auto px-4 py-4 flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold" id="header-title">Alternative für Deutschland (AfD)</h1>
            <p class="text-sky-100 text-sm" id="header-subtitle">Kreistagswahl 2026 - Landkreis Ostallgäu</p>
          </div>
          <button id="back-btn" class="hidden bg-white/20 hover:bg-white/30 px-4 py-2 rounded-lg font-medium transition-all flex items-center gap-2">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"/>
            </svg>
            Zurück
          </button>
        </div>
      </header>
      <main class="relative flex">
        <div id="map" class="flex-1"></div>
        
        <!-- Detail Panel for Stimmbezirke -->
        <div id="detail-panel" class="hidden w-96 bg-white shadow-xl border-l border-gray-200 overflow-y-auto" style="height: calc(100vh - 80px)">
          <div class="p-4">
            <h2 id="detail-title" class="text-xl font-bold text-gray-900 mb-4"></h2>
            <div id="stimmbezirke-list"></div>
          </div>
        </div>
        
        <!-- Legend -->
        <div class="absolute bottom-6 right-6 bg-white rounded-xl shadow-xl p-4 z-[1000]" id="legend">
          <h3 class="text-sm font-semibold text-gray-700 mb-2">Anteil in %</h3>
          <div class="flex items-center gap-2 text-xs mb-1">
            <div class="w-6 h-4 rounded" style="background: #e0f2fe"></div>
            <span class="text-gray-600">0 - 10%</span>
          </div>
          <div class="flex items-center gap-2 text-xs mb-1">
            <div class="w-6 h-4 rounded" style="background: #7dd3fc"></div>
            <span class="text-gray-600">10 - 15%</span>
          </div>
          <div class="flex items-center gap-2 text-xs mb-1">
            <div class="w-6 h-4 rounded" style="background: #0ea5e9"></div>
            <span class="text-gray-600">15 - 20%</span>
          </div>
          <div class="flex items-center gap-2 text-xs">
            <div class="w-6 h-4 rounded" style="background: #0369a1"></div>
            <span class="text-gray-600">20%+</span>
          </div>
          <div class="mt-3 pt-3 border-t border-gray-200 text-xs text-gray-500">
            Doppelklick für Stimmbezirke
          </div>
        </div>
      </main>
      <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
      <script>
        const map = L.map("map").setView([47.85, 10.65], 10);
        L.tileLayer("https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png", {
          attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> &copy; <a href="https://carto.com/attributions">CARTO</a>',
          subdomains: "abcd",
          maxZoom: 19
        }).addTo(map);

        const electionData = #{election_data_js};
        const stimmbezirkeByParent = #{stimmbezirke_js};
        
        let currentLayer = null;

        function showOverview() {
          document.getElementById('back-btn').classList.add('hidden');
          document.getElementById('detail-panel').classList.add('hidden');
          document.getElementById('legend').classList.remove('hidden');
          document.getElementById('header-title').textContent = 'Alternative für Deutschland (AfD)';
          document.getElementById('header-subtitle').textContent = 'Kreistagswahl 2026 - Landkreis Ostallgäu';
          
          if (currentLayer) map.removeLayer(currentLayer);
          currentLayer = L.layerGroup();
          
          electionData.forEach(([feature, area]) => {
            const name = feature.properties.name;
            const afdParty = area.parteien.find(p => p.kurzbezeichnung === "AfD");
            const afdPercentage = afdParty?.anteil || 0;
            const color = getColor(afdPercentage);
            const ags = feature.properties.ags;

            const layer = L.geoJSON(feature, {
              style: { fillColor: color, weight: 2, opacity: 1, color: "#ffffff", fillOpacity: 0.75 },
              onEachFeature: (feature, layer) => {
                layer.on({
                  mouseover: (e) => e.target.setStyle({ weight: 4, color: "#666" }),
                  mouseout: (e) => e.target.setStyle({ weight: 2, color: "#fff" }),
                  dblclick: (e) => { L.DomEvent.stopPropagation(e); showStimmbezirke(ags, name, area); }
                });
                layer.bindPopup(`
                  <div class="p-2 min-w-48">
                    <h3 class="font-bold text-gray-900 text-lg">${name}</h3>
                    <div class="mt-2 pt-2 border-t border-gray-200">
                      <div class="flex items-center justify-between">
                        <span class="text-sky-600 font-semibold">AfD</span>
                        <span class="text-2xl font-bold text-gray-900">${afdPercentage.toFixed(1)}%</span>
                      </div>
                      <div class="w-full bg-gray-200 rounded-full h-2 mt-2">
                        <div class="bg-sky-500 h-2 rounded-full" style="width: ${Math.min(afdPercentage, 100)}%"></div>
                      </div>
                    </div>
                    <div class="mt-3 text-xs text-gray-500 text-center">Doppelklick für Stimmbezirke</div>
                  </div>
                `);
              }
            });
            currentLayer.addLayer(layer);
          });
          
          currentLayer.addTo(map);
          map.setView([47.85, 10.65], 10);
        }

        function showStimmbezirke(ags, gemeindeName, gemeindeArea) {
          const stimmbezirke = stimmbezirkeByParent[ags];
          if (!stimmbezirke || stimmbezirke.length === 0) {
            alert('Keine Stimmbezirksdaten verfügbar für ' + gemeindeName);
            return;
          }
          
          document.getElementById('back-btn').classList.remove('hidden');
          document.getElementById('detail-panel').classList.remove('hidden');
          document.getElementById('legend').classList.add('hidden');
          document.getElementById('header-title').textContent = gemeindeName;
          document.getElementById('header-subtitle').textContent = `${stimmbezirke.length} Stimmbezirke`;
          
          if (currentLayer) map.removeLayer(currentLayer);
          currentLayer = L.layerGroup();
          
          let listHtml = '';
          stimmbezirke.sort((a, b) => {
            const aPct = a.parteien.find(p => p.kurzbezeichnung === "AfD")?.anteil || 0;
            const bPct = b.parteien.find(p => p.kurzbezeichnung === "AfD")?.anteil || 0;
            return bPct - aPct;
          }).forEach((sb) => {
            const gruene = sb.parteien.find(p => p.kurzbezeichnung === "GRÜNE");
            const afd = sb.parteien.find(p => p.kurzbezeichnung === "AfD");
            const gruenePct = gruene?.anteil || 0;
            const afdPct = afd?.anteil || 0;
            const color = getColor(afdPct);
            
            listHtml += `
              <div class="stimmbezirk-item p-3 rounded-lg mb-2 border border-gray-200" style="border-left: 4px solid ${color}">
                <div class="font-medium text-gray-900">${sb.name}</div>
                <div class="mt-2 grid grid-cols-2 gap-2 text-sm">
                  <div><span class="text-green-600">Grüne:</span> <span class="font-semibold ml-1">${gruenePct.toFixed(1)}%</span></div>
                  <div><span class="text-sky-600">AfD:</span> <span class="font-semibold ml-1">${afdPct.toFixed(1)}%</span></div>
                </div>
                <div class="mt-2 flex gap-1">
                  <div class="flex-1 bg-gray-200 rounded-full h-1.5"><div class="bg-green-500 h-1.5 rounded-full" style="width: ${Math.min(gruenePct, 100)}%"></div></div>
                  <div class="flex-1 bg-gray-200 rounded-full h-1.5"><div class="bg-sky-500 h-1.5 rounded-full" style="width: ${Math.min(afdPct, 100)}%"></div></div>
                </div>
              </div>
            `;
          });
          
          document.getElementById('stimmbezirke-list').innerHTML = listHtml;
          
          const gemeindeFeature = electionData.find(([f, a]) => f.properties.ags === ags);
          if (gemeindeFeature) {
            const [feature, area] = gemeindeFeature;
            const layer = L.geoJSON(feature, {
              style: { fillColor: "#e5e7eb", weight: 2, opacity: 1, color: "#9ca3af", fillOpacity: 0.3 }
            });
            currentLayer.addLayer(layer);
            map.fitBounds(layer.getBounds(), { padding: [50, 50] });
          }
          
          currentLayer.addTo(map);
        }

        document.getElementById('back-btn').addEventListener('click', showOverview);

        function getColor(percentage) {
          if (percentage < 10) return interpolateColor("#e0f2fe", "#7dd3fc", percentage / 10);
          if (percentage < 15) return interpolateColor("#7dd3fc", "#0ea5e9", (percentage - 10) / 5);
          if (percentage < 20) return interpolateColor("#0ea5e9", "#0369a1", (percentage - 15) / 5);
          return "#0369a1";
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

        showOverview();
      </script>
    </body>
    </html>
    """

    File.write!("results/karte_afd.html", html)
  end
end
