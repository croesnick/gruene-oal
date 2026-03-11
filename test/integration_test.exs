defmodule Wahlanalyse2026Ostallgaeu.IntegrationTest do
  use ExUnit.Case, async: true

  alias Wahlanalyse2026Ostallgaeu.{Parser, Analysis, Area, GeoJSON}

  describe "parser workflow" do
    test "parses Kreis fixture and creates valid Area struct" do
      html = File.read!("test/fixtures/kreis.html")
      {:ok, area} = Parser.parse_kreis(html)

      assert %Area{} = area
      assert area.id == "09777000"
      assert area.type == :kreis
      assert area.name == "Landkreis Ostallgäu"
      assert area.wahlbeteiligung == 70.0
      assert area.stimmberechtigte == 140_611
      assert area.waehler == 98_383
    end

    test "parses Gemeinde fixture and creates valid Area struct with parent" do
      html = File.read!("test/fixtures/gemeinde.html")
      {:ok, area} = Parser.parse_gemeinde(html, "09777129")

      assert %Area{} = area
      assert area.id == "09777129"
      assert area.type == :gemeinde
      assert area.name == "Stadt Füssen"
      assert area.parent_id == "09777000"
    end

    test "parses Stimmbezirk fixture and creates valid Area struct" do
      html = File.read!("test/fixtures/stimmbezirk.html")
      {:ok, area} = Parser.parse_stimmbezirk(html, "097771290001")

      assert %Area{} = area
      assert area.id == "097771290001"
      assert area.type == :stimmbezirk
      assert area.name == "Rathaus Kommunaler Ordnungsdienst"
      assert area.parent_id == "09777129"
    end

    test "extracts party results from parsed areas" do
      html = File.read!("test/fixtures/kreis.html")
      {:ok, area} = Parser.parse_kreis(html)

      csu = Area.get_party(area, "CSU")
      assert csu.name == "Christlich-Soziale Union in Bayern e.V."
      assert csu.stimmen == 140_424
      assert_in_delta csu.anteil, 43.7, 0.1

      gruene = Area.get_party(area, "GRÜNE")
      assert gruene.name == "BÜNDNIS 90/DIE GRÜNEN"
      assert gruene.stimmen == 46_620
      assert_in_delta gruene.anteil, 14.5, 0.1

      afd = Area.get_party(area, "AfD")
      assert afd.name == "Alternative für Deutschland"
      assert afd.stimmen == 33_306
      assert_in_delta afd.anteil, 10.4, 0.1
    end

    test "extracts children from parsed areas" do
      html = File.read!("test/fixtures/kreis.html")
      {:ok, area} = Parser.parse_kreis(html)

      assert "gemeinde_09777129" in area.children
      assert "gemeinde_09777130" in area.children
      assert "verbandsgemeinde_097775752" in area.children
    end
  end

  describe "analysis workflow" do
    setup do
      areas = [
        %Area{
          id: "09777000",
          type: :kreis,
          name: "Landkreis Ostallgäu",
          parteien: [
            %{name: "CSU", kurzbezeichnung: "CSU", stimmen: 140_424, anteil: 43.7},
            %{name: "GRÜNE", kurzbezeichnung: "GRÜNE", stimmen: 46_620, anteil: 14.5},
            %{name: "AfD", kurzbezeichnung: "AfD", stimmen: 33_306, anteil: 10.4}
          ]
        },
        %Area{
          id: "09777129",
          type: :gemeinde,
          name: "Stadt Füssen",
          parent_id: "09777000",
          parteien: [
            %{name: "CSU", kurzbezeichnung: "CSU", stimmen: 10_500, anteil: 45.2},
            %{name: "GRÜNE", kurzbezeichnung: "GRÜNE", stimmen: 3_200, anteil: 13.8},
            %{name: "AfD", kurzbezeichnung: "AfD", stimmen: 2_800, anteil: 12.1}
          ]
        },
        %Area{
          id: "09777130",
          type: :gemeinde,
          name: "Stadt Kaufbeuren",
          parent_id: "09777000",
          parteien: [
            %{name: "CSU", kurzbezeichnung: "CSU", stimmen: 12_000, anteil: 41.5},
            %{name: "GRÜNE", kurzbezeichnung: "GRÜNE", stimmen: 4_500, anteil: 15.6},
            %{name: "AfD", kurzbezeichnung: "AfD", stimmen: 3_100, anteil: 10.7}
          ]
        },
        %Area{
          id: "09777131",
          type: :gemeinde,
          name: "Gemeinde Röthenbach",
          parent_id: "09777000",
          parteien: [
            %{name: "CSU", kurzbezeichnung: "CSU", stimmen: 8_000, anteil: 50.3},
            %{name: "GRÜNE", kurzbezeichnung: "GRÜNE", stimmen: 1_800, anteil: 11.3},
            %{name: "AfD", kurzbezeichnung: "AfD", stimmen: 2_200, anteil: 13.8}
          ]
        }
      ]

      {:ok, areas: areas}
    end

    test "ranks areas by CSU percentage descending", %{areas: areas} do
      gemeinden = Enum.filter(areas, &(&1.type == :gemeinde))
      ranked = Analysis.rank_by_party(gemeinden, "CSU")

      assert length(ranked) == 3
      assert Enum.at(ranked, 0).name == "Gemeinde Röthenbach"
      assert Enum.at(ranked, 1).name == "Stadt Füssen"
      assert Enum.at(ranked, 2).name == "Stadt Kaufbeuren"
    end

    test "ranks areas by GRÜNE percentage descending", %{areas: areas} do
      gemeinden = Enum.filter(areas, &(&1.type == :gemeinde))
      ranked = Analysis.rank_by_party(gemeinden, "GRÜNE")

      assert length(ranked) == 3
      assert Enum.at(ranked, 0).name == "Stadt Kaufbeuren"
      assert Enum.at(ranked, 1).name == "Stadt Füssen"
      assert Enum.at(ranked, 2).name == "Gemeinde Röthenbach"
    end

    test "gets Kreis average for parties", %{areas: areas} do
      assert Analysis.get_kreis_average(areas, "CSU") == 43.7
      assert Analysis.get_kreis_average(areas, "GRÜNE") == 14.5
      assert Analysis.get_kreis_average(areas, "AfD") == 10.4
    end

    test "finds areas above Kreis average", %{areas: areas} do
      above_csu = Analysis.above_average_areas(areas, "CSU")

      # Above 43.7: Röthenbach (50.3), Füssen (45.2)
      assert length(above_csu) == 2
      names = Enum.map(above_csu, & &1.name)
      assert "Gemeinde Röthenbach" in names
      assert "Stadt Füssen" in names
    end
  end

  describe "geojson functions" do
    test "filters features for Ostallgäu municipalities" do
      features = [
        %{"properties" => %{"ags" => "09777129"}},
        %{"properties" => %{"ags" => "09777130"}},
        %{"properties" => %{"ags" => "09778129"}},
        %{"properties" => %{"ags" => "09777131"}}
      ]

      filtered = GeoJSON.filter_ostallgaeu(features)

      assert length(filtered) == 3

      assert Enum.all?(filtered, fn f ->
               String.starts_with?(f["properties"]["ags"], "09777")
             end)
    end

    test "matches features with election data" do
      features = [
        %{"properties" => %{"ags" => "09777129", "name" => "Füssen"}},
        %{"properties" => %{"ags" => "09777130", "name" => "Kaufbeuren"}}
      ]

      election_data = [
        %Area{id: "09777129", name: "Stadt Füssen", type: :gemeinde, parteien: []},
        %Area{id: "09777130", name: "Stadt Kaufbeuren", type: :gemeinde, parteien: []}
      ]

      matched = GeoJSON.match_with_election_data(features, election_data)

      assert length(matched) == 2
    end

    test "calculates color for GRÜNE party" do
      assert GeoJSON.calculate_color(0.0, "GRÜNE") == "#ffffff"
      assert GeoJSON.calculate_color(10.0, "GRÜNE") == "#90ee90"
      assert GeoJSON.calculate_color(20.0, "GRÜNE") == "#006400"
    end

    test "calculates color for AfD party" do
      assert GeoJSON.calculate_color(0.0, "AfD") == "#ffffff"
      assert GeoJSON.calculate_color(10.0, "AfD") == "#87ceeb"
      assert GeoJSON.calculate_color(20.0, "AfD") == "#00008b"
    end

    test "color gradient is smooth" do
      # Test intermediate values
      color_5 = GeoJSON.calculate_color(5.0, "GRÜNE")
      color_15 = GeoJSON.calculate_color(15.0, "GRÜNE")

      # Colors should be different and between the bounds
      assert color_5 != "#ffffff"
      assert color_5 != "#90ee90"
      assert color_15 != "#90ee90"
      assert color_15 != "#006400"
    end
  end

  describe "full workflow integration" do
    test "parser and analysis work together" do
      # Parse fixtures
      {:ok, kreis} = Parser.parse_kreis(File.read!("test/fixtures/kreis.html"))

      {:ok, gemeinde} =
        Parser.parse_gemeinde(File.read!("test/fixtures/gemeinde.html"), "09777129")

      areas = [kreis, gemeinde]

      # Verify analysis works on parsed data - use assert_in_delta for floats
      kreis_avg = Analysis.get_kreis_average(areas, "CSU")
      assert_in_delta kreis_avg, 43.7, 0.2

      ranked = Analysis.rank_by_party(areas, "CSU")
      assert length(ranked) == 2

      # Füssen has CSU at ~36.7% (from stimmbezirk data in fixture)
      # Kreis has CSU at 43.7%
      # So Kreis should be ranked first
      assert Enum.at(ranked, 0).type == :kreis
    end

    test "parser and geojson work together" do
      {:ok, gemeinde} =
        Parser.parse_gemeinde(File.read!("test/fixtures/gemeinde.html"), "09777129")

      features = [
        %{"properties" => %{"ags" => "09777129", "name" => "Füssen"}}
      ]

      matched = GeoJSON.match_with_election_data(features, [gemeinde])

      {_, area} = List.first(matched)
      assert area.name == "Stadt Füssen"
    end

    test "full parse → analyze → color workflow" do
      # Parse fixture
      {:ok, kreis} = Parser.parse_kreis(File.read!("test/fixtures/kreis.html"))

      # Get party data
      gruene = Area.get_party(kreis, "GRÜNE")
      afd = Area.get_party(kreis, "AfD")

      # Calculate colors for the parsed data
      gruene_color = GeoJSON.calculate_color(gruene.anteil, "GRÜNE")
      afd_color = GeoJSON.calculate_color(afd.anteil, "AfD")

      # Colors should be valid hex colors
      assert String.starts_with?(gruene_color, "#")
      assert String.starts_with?(afd_color, "#")

      # GRÜNE with ~14.5% should be between 10% and 20% colors
      refute gruene_color == "#ffffff"
      refute gruene_color == "#90ee90"

      # AfD with ~10.4% should be between 10% and 20% (not exactly at 10%)
      refute afd_color == "#ffffff"
    end

    test "hierarchy extraction from parsed data" do
      {:ok, kreis} = Parser.parse_kreis(File.read!("test/fixtures/kreis.html"))

      {:ok, gemeinde} =
        Parser.parse_gemeinde(File.read!("test/fixtures/gemeinde.html"), "09777129")

      # Verify parent-child relationship
      assert gemeinde.parent_id == kreis.id
      assert "gemeinde_09777129" in kreis.children
    end
  end
end
