defmodule Wahlanalyse2026Ostallgaeu.GeoJSONTest do
  use ExUnit.Case
  alias Wahlanalyse2026Ostallgaeu.GeoJSON

  describe "load_local_geojson/0" do
    @tag :skip
    test "loads GeoJSON data from local file" do
      # This test requires the GeoJSON file to exist - skipped
      assert {:ok, _data} = GeoJSON.load_local_geojson()
    end
  end

  describe "filter_ostallgaeu/1" do
    test "filters features for Ostallgäu municipalities" do
      features = [
        %{"properties" => %{"ags" => "09777129"}},
        %{"properties" => %{"ags" => "09777130"}},
        %{"properties" => %{"ags" => "09778129"}}
      ]

      filtered = GeoJSON.filter_ostallgaeu(features)
      assert length(filtered) == 2
      assert Enum.all?(filtered, fn f -> String.starts_with?(f["properties"]["ags"], "09777") end)
    end
  end

  describe "match_with_election_data/2" do
    test "matches GeoJSON features with election data" do
      features = [
        %{"properties" => %{"ags" => "09777129", "name" => "Obergünzburg"}},
        %{"properties" => %{"ags" => "09777130", "name" => "Ottobeuren"}}
      ]

      election_data = [
        %Wahlanalyse2026Ostallgaeu.Area{
          id: "09777129",
          name: "Obergünzburg",
          type: "kreisangehörige_gemeinde",
          parteien: [%{kurzbezeichnung: "GRÜNE", anteil: 15.5}]
        },
        %Wahlanalyse2026Ostallgaeu.Area{
          id: "09777130",
          name: "Ottobeuren",
          type: "kreisangehörige_gemeinde",
          parteien: [%{kurzbezeichnung: "GRÜNE", anteil: 12.3}]
        }
      ]

      matched = GeoJSON.match_with_election_data(features, election_data)
      assert length(matched) == 2

      # Verify each matched pair has matching AGS
      assert Enum.all?(matched, fn {f, area} ->
               ags = f["properties"]["ags"]
               ags == area.id
             end)
    end
  end

  describe "calculate_color/2" do
    test "calculates color for Grüne party" do
      assert GeoJSON.calculate_color(0.0, "GRÜNE") == "#ffffff"
      assert GeoJSON.calculate_color(10.0, "GRÜNE") == "#90ee90"
      assert GeoJSON.calculate_color(20.0, "GRÜNE") == "#006400"
      assert GeoJSON.calculate_color(15.0, "GRÜNE") == "#48a948"
    end

    test "calculates color for AfD party" do
      assert GeoJSON.calculate_color(0.0, "AfD") == "#ffffff"
      assert GeoJSON.calculate_color(10.0, "AfD") == "#87ceeb"
      assert GeoJSON.calculate_color(20.0, "AfD") == "#00008b"
      assert GeoJSON.calculate_color(15.0, "AfD") == "#4467bb"
    end
  end
end
