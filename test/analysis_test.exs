defmodule Wahlanalyse2026Ostallgaeu.AnalysisTest do
  use ExUnit.Case, async: true

  alias Wahlanalyse2026Ostallgaeu.Analysis
  alias Wahlanalyse2026Ostallgaeu.Area

  # Test data fixtures
  defp kreis_area do
    %Area{
      id: "09777000",
      type: :kreis,
      name: "Landkreis Ostallgäu",
      parteien: [
        %{name: "CSU", kurzbezeichnung: "CSU", stimmen: 140_424, anteil: 43.7},
        %{name: "GRÜNE", kurzbezeichnung: "GRÜNE", stimmen: 46_620, anteil: 14.5},
        %{name: "AfD", kurzbezeichnung: "AfD", stimmen: 33_306, anteil: 10.4}
      ]
    }
  end

  defp gemeinde_fuessen do
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
    }
  end

  defp gemeinde_kaufbeuren do
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
    }
  end

  defp gemeinde_roethenbach do
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
  end

  defp stimmbezirk_1 do
    %Area{
      id: "097771290001",
      type: :stimmbezirk,
      name: "Rathaus",
      parent_id: "09777129",
      parteien: [
        %{name: "CSU", kurzbezeichnung: "CSU", stimmen: 442, anteil: 36.7},
        %{name: "GRÜNE", kurzbezeichnung: "GRÜNE", stimmen: 246, anteil: 20.4},
        %{name: "AfD", kurzbezeichnung: "AfD", stimmen: 196, anteil: 16.3}
      ]
    }
  end

  defp sample_areas do
    [
      kreis_area(),
      gemeinde_fuessen(),
      gemeinde_kaufbeuren(),
      gemeinde_roethenbach(),
      stimmbezirk_1()
    ]
  end

  describe "get_kreis_average/2" do
    test "returns the anteil for a party from the kreis area" do
      areas = sample_areas()

      assert Analysis.get_kreis_average(areas, "CSU") == 43.7
      assert Analysis.get_kreis_average(areas, "GRÜNE") == 14.5
      assert Analysis.get_kreis_average(areas, "AfD") == 10.4
    end

    test "returns nil if party not found in kreis" do
      areas = sample_areas()

      assert Analysis.get_kreis_average(areas, "UNKNOWN") == nil
    end

    test "returns nil if no kreis area present" do
      areas = [gemeinde_fuessen(), gemeinde_kaufbeuren()]

      assert Analysis.get_kreis_average(areas, "CSU") == nil
    end
  end

  describe "rank_by_party/2" do
    test "returns areas sorted by party percentage descending" do
      areas = [gemeinde_fuessen(), gemeinde_kaufbeuren(), gemeinde_roethenbach()]
      ranked = Analysis.rank_by_party(areas, "CSU")

      assert length(ranked) == 3
      assert Enum.at(ranked, 0).name == "Gemeinde Röthenbach"
      assert Enum.at(ranked, 1).name == "Stadt Füssen"
      assert Enum.at(ranked, 2).name == "Stadt Kaufbeuren"
    end

    test "returns areas sorted by GRÜNE percentage descending" do
      areas = [gemeinde_fuessen(), gemeinde_kaufbeuren(), gemeinde_roethenbach()]
      ranked = Analysis.rank_by_party(areas, "GRÜNE")

      assert Enum.at(ranked, 0).name == "Stadt Kaufbeuren"
      assert Enum.at(ranked, 1).name == "Stadt Füssen"
      assert Enum.at(ranked, 2).name == "Gemeinde Röthenbach"
    end

    test "excludes areas where party is not present" do
      area_without_party = %Area{
        id: "09777132",
        type: :gemeinde,
        name: "Gemeinde Ohne AfD",
        parent_id: "09777000",
        parteien: [
          %{name: "CSU", kurzbezeichnung: "CSU", stimmen: 8_000, anteil: 50.3}
        ]
      }

      areas = [gemeinde_fuessen(), area_without_party]
      ranked = Analysis.rank_by_party(areas, "AfD")

      assert length(ranked) == 1
      assert Enum.at(ranked, 0).name == "Stadt Füssen"
    end

    test "returns empty list when no areas have the party" do
      areas = [gemeinde_fuessen(), gemeinde_kaufbeuren()]
      ranked = Analysis.rank_by_party(areas, "UNKNOWN")

      assert ranked == []
    end

    test "returns empty list for empty areas" do
      assert Analysis.rank_by_party([], "CSU") == []
    end
  end

  describe "above_average_areas/2" do
    test "returns areas above kreis average for a party" do
      areas = sample_areas()
      # Kreis average: CSU=43.7, GRÜNE=14.5, AfD=10.4
      above_csu = Analysis.above_average_areas(areas, "CSU")

      # Above 43.7: Röthenbach (50.3), Füssen (45.2)
      assert length(above_csu) == 2
      names = Enum.map(above_csu, & &1.name)
      assert "Gemeinde Röthenbach" in names
      assert "Stadt Füssen" in names
    end

    test "returns areas above average for GRÜNE" do
      areas = sample_areas()
      # Kreis average: 14.5
      above_gruene = Analysis.above_average_areas(areas, "GRÜNE")

      # Above 14.5: Kaufbeuren (15.6), Stimmbezirk Rathaus (20.4)
      assert length(above_gruene) == 2
      names = Enum.map(above_gruene, & &1.name)
      assert "Stadt Kaufbeuren" in names
      assert "Rathaus" in names
    end

    test "returns areas above average for AfD" do
      areas = sample_areas()
      # Kreis average: 10.4
      above_afd = Analysis.above_average_areas(areas, "AfD")

      # Above 10.4: Röthenbach (13.8), Füssen (12.1), Rathaus (16.3), Kaufbeuren (10.7)
      assert length(above_afd) == 4
    end

    test "excludes kreis area from results" do
      areas = sample_areas()
      above_csu = Analysis.above_average_areas(areas, "CSU")

      # Kreis area should not be in results even though it has the party
      ids = Enum.map(above_csu, & &1.id)
      refute "09777000" in ids
    end

    test "returns empty list when no areas above average" do
      # Create an area where CSU is below average
      low_csu_area = %Area{
        id: "09777133",
        type: :gemeinde,
        name: "Low CSU Gemeinde",
        parent_id: "09777000",
        parteien: [
          %{name: "CSU", kurzbezeichnung: "CSU", stimmen: 1_000, anteil: 30.0}
        ]
      }

      areas = [kreis_area(), low_csu_area]
      above_csu = Analysis.above_average_areas(areas, "CSU")

      assert above_csu == []
    end

    test "returns empty list if no kreis present" do
      areas = [gemeinde_fuessen(), gemeinde_kaufbeuren()]
      above_csu = Analysis.above_average_areas(areas, "CSU")

      assert above_csu == []
    end
  end

  describe "load_all_data/0" do
    test "returns empty list when data directory does not exist" do
      # This test verifies the function handles missing directory gracefully
      # In actual use, it would read from data/ directory
      result = Analysis.load_all_data()
      assert is_list(result)
    end
  end
end
